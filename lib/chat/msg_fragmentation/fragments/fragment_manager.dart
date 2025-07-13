import 'dart:async';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/msg_fragmentation/message_fragmentation.dart';

enum FragmentState { idle, displayingWithTyping, displaying, completed, error }

class FragmentSequence {
  final String id;
  final List<String> fragments;
  final Message originalMessage;
  int currentIndex;
  FragmentState state;
  final List<Message> displayedFragments;
  DateTime? startTime;
  
  FragmentSequence({
    required this.id,
    required this.fragments,
    required this.originalMessage,
    this.currentIndex = 0,
    this.state = FragmentState.idle,
  }) : displayedFragments = [];
  
  bool get isComplete => currentIndex >= fragments.length;
  bool get hasNext => currentIndex < fragments.length;
  String? get currentFragment => hasNext ? fragments[currentIndex] : null;
  
  void advance() {
    if (hasNext) currentIndex++;
  }
  
  void markCompleted() {
    state = FragmentState.completed;
  }
  
  void markError() {
    state = FragmentState.error;
  }
}

class FragmentManager {
  final Map<String, FragmentSequence> _activeSequences = {};
  final StreamController<FragmentEvent> _eventController = StreamController.broadcast();
  Timer? _displayTimer;
  
  Stream<FragmentEvent> get events => _eventController.stream;
  
  void startFragmentSequence(Message originalMessage, List<String> fragments) {
    final sequenceId = originalMessage.id ?? 'fragment_${DateTime.now().millisecondsSinceEpoch}';
    
    final sequence = FragmentSequence(
      id: sequenceId,
      fragments: fragments,
      originalMessage: originalMessage,
    );
    
    _activeSequences[sequenceId] = sequence;
    
    print('Starting fragment sequence: $sequenceId with ${fragments.length} fragments');
    
    // Emit start event
    _eventController.add(FragmentSequenceStarted(sequence));
    
    // Show typing indicator first, then start first fragment
    _showTypingAndScheduleFragment(sequence);
  }
  
  void _showTypingAndScheduleFragment(FragmentSequence sequence) {
    if (sequence.isComplete) {
      _completeSequence(sequence);
      return;
    }
    
    // Show typing indicator for current fragment
    sequence.state = FragmentState.displayingWithTyping;
    _eventController.add(FragmentTypingStarted(sequence));
    
    // Calculate delay for typing indicator
    final typingDelay = MessageFragmenter.calculateTypingDelay(
      sequence.currentFragment!, 
      sequence.currentIndex
    );
    
    print('Showing typing indicator for fragment ${sequence.currentIndex + 1}/${sequence.fragments.length} with delay: ${typingDelay}ms');
    
    _displayTimer?.cancel();
    _displayTimer = Timer(Duration(milliseconds: typingDelay), () {
      _displayCurrentFragment(sequence);
    });
  }
  
  void _displayCurrentFragment(FragmentSequence sequence) {
    if (sequence.isComplete) {
      _completeSequence(sequence);
      return;
    }
    
    // Hide typing indicator and show fragment
    sequence.state = FragmentState.displaying;
    final fragment = sequence.currentFragment!;
    
    // Create fragment message
    final fragmentMessage = Message(
      id: '${sequence.id}_fragment_${sequence.currentIndex}',
      messageFragments: [fragment],
      companionId: sequence.originalMessage.companionId,
      userId: sequence.originalMessage.userId,
      conversationId: sequence.originalMessage.conversationId,
      isBot: true,
      created_at: DateTime.now(),
      metadata: {
        'is_fragment': true,
        'fragment_index': sequence.currentIndex,
        'total_fragments': sequence.fragments.length,
        'sequence_id': sequence.id,
        'base_message_id': sequence.originalMessage.id,
      },
    );
    
    sequence.displayedFragments.add(fragmentMessage);
    
    print('Displaying fragment ${sequence.currentIndex + 1}/${sequence.fragments.length}: ${fragment.substring(0, fragment.length.clamp(0, 50))}...');
    
    // Emit fragment displayed event
    _eventController.add(FragmentDisplayed(fragmentMessage, sequence));
    
    // Advance to next fragment
    sequence.advance();
    
    // Schedule next fragment with typing indicator if there are more
    if (!sequence.isComplete) {
      // Add a small delay before showing next typing indicator
      _displayTimer?.cancel();
      _displayTimer = Timer(Duration(milliseconds: 200), () {
        _showTypingAndScheduleFragment(sequence);
      });
    } else {
      // Complete sequence if this was the last fragment
      _completeSequence(sequence);
    }
  }
  
  void _completeSequence(FragmentSequence sequence) {
    sequence.markCompleted();
    print('Fragment sequence completed: ${sequence.id}');
    _eventController.add(FragmentSequenceCompleted(sequence));
    _activeSequences.remove(sequence.id);
    _displayTimer?.cancel();
  }
  
  void cancelSequence(String sequenceId) {
    final sequence = _activeSequences[sequenceId];
    if (sequence != null) {
      sequence.markError();
      _eventController.add(FragmentSequenceCancelled(sequence));
      _activeSequences.remove(sequenceId);
      _displayTimer?.cancel();
    }
  }
  
  /// Force complete all remaining fragments in a sequence immediately (no delays)
  void forceCompleteSequence(String sequenceId) {
    final sequence = _activeSequences[sequenceId];
    if (sequence == null) return;
    
    print('Force completing sequence: $sequenceId');
    
    // Cancel any pending timers
    _displayTimer?.cancel();
    
    // Display all remaining fragments immediately
    while (!sequence.isComplete) {
      final fragment = sequence.currentFragment!;
      
      // Create fragment message
      final fragmentMessage = Message(
        id: '${sequence.id}_fragment_forced_${sequence.currentIndex}',
        messageFragments: [fragment],
        companionId: sequence.originalMessage.companionId,
        userId: sequence.originalMessage.userId,
        conversationId: sequence.originalMessage.conversationId,
        isBot: true,
        created_at: DateTime.now(),
        metadata: {
          'is_fragment': true,
          'fragment_index': sequence.currentIndex,
          'total_fragments': sequence.fragments.length,
          'sequence_id': sequence.id,
          'base_message_id': sequence.originalMessage.id,
          'force_completed': true,
        },
      );
      
      sequence.displayedFragments.add(fragmentMessage);
      
      // Emit fragment displayed event immediately
      _eventController.add(FragmentDisplayed(fragmentMessage, sequence));
      
      // Advance to next fragment
      sequence.advance();
    }
    
    // Complete the sequence
    _completeSequence(sequence);
  }
  
  /// Force complete ALL active sequences immediately
  void forceCompleteAllSequences() {
    print('Force completing all active sequences- fragment manager');
    final sequenceIds = List<String>.from(_activeSequences.keys);
    
    for (final sequenceId in sequenceIds) {
      forceCompleteSequence(sequenceId);
    }
  }
  
  /// Get all active sequence IDs
  List<String> get activeSequenceIds => List<String>.from(_activeSequences.keys);
  
  /// Check if there are any active sequences
  bool get hasActiveSequences => _activeSequences.isNotEmpty;
  
  /// Get information about active sequences for debugging
  Map<String, String> getActiveSequencesInfo() {
    final info = <String, String>{};
    for (final entry in _activeSequences.entries) {
      final sequence = entry.value;
      info[entry.key] = 'Fragments: ${sequence.currentIndex}/${sequence.fragments.length}, State: ${sequence.state}';
    }
    return info;
  }
  
  void dispose() {
    _displayTimer?.cancel();
    _activeSequences.clear();
    _eventController.close();
  }
}

// Events
abstract class FragmentEvent {}

class FragmentSequenceStarted extends FragmentEvent {
  final FragmentSequence sequence;
  FragmentSequenceStarted(this.sequence);
}

class FragmentTypingStarted extends FragmentEvent {
  final FragmentSequence sequence;
  FragmentTypingStarted(this.sequence);
}

class FragmentDisplayed extends FragmentEvent {
  final Message fragment;
  final FragmentSequence sequence;
  FragmentDisplayed(this.fragment, this.sequence);
}

class FragmentSequenceCompleted extends FragmentEvent {
  final FragmentSequence sequence;
  FragmentSequenceCompleted(this.sequence);
}

class FragmentSequenceCancelled extends FragmentEvent {
  final FragmentSequence sequence;
  FragmentSequenceCancelled(this.sequence);
}
