import 'dart:async';
import 'dart:convert';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/services/connectivity_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/chat/message_bloc/fragment_sequence_status.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart' as conv_events;
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_queue/message_queue.dart' as queue;
import 'package:ai_companion/chat/msg_fragmentation/fragments/fragment_manager.dart';
import 'package:ai_companion/chat/msg_fragmentation/message_fragmentation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final ChatRepository _repository;
  final GeminiService _geminiService = GeminiService();
  final ChatCacheService _cacheService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Enhanced queue and fragment system
  final queue.MessageQueue _messageQueue = queue.MessageQueue();
  final FragmentManager _fragmentManager = FragmentManager();
  
  String? _currentUserId;
  String? _currentCompanionId;
  Timer? _syncTimer;
  List<Message> _currentMessages = [];
  
  // NEW: Fragment sequence tracking
  final Map<String, FragmentSequenceStatus> _fragmentSequences = {};
  String? _currentActiveSequenceId;
  
  // Cross-bloc communication
  final ConversationBloc _conversationBloc;
  
  // Offline support
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _fragmentSubscription;
  final List<Message> _pendingMessages = [];
  final String _pendingMessagesKey = 'pending_messages';

  // Add a BehaviorSubject for typing indicators
  final BehaviorSubject<bool> _typingSubject = BehaviorSubject.seeded(false);
  Stream<bool> get typingStream => _typingSubject.stream;
  
  // OPTIMIZATION: Debounce conversation metadata updates to prevent spam
  Timer? _conversationUpdateDebouncer;
  final Duration _conversationUpdateDelay = const Duration(milliseconds: 500);
  final Map<String, conv_events.UpdateConversationMetadata> _pendingConversationUpdates = {};

  MessageBloc(this._repository, this._cacheService, this._conversationBloc,) : super(MessageInitial()) {
    // Core message handlers
    on<SendMessageEvent>(_onSendMessage);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<ClearConversation>(_onClearConversation);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<RetryChatRequest>(_onRetryChatRequest);
    on<InitializeCompanionEvent>(_onInitializeCompanion);
    on<RefreshMessages>(_onRefreshMessages);
    on<ConnectivityChangedEvent>(_onConnectivityChanged);
    on<ProcessPendingMessagesEvent>(_onProcessPendingMessages);
    
    // Enhanced queue and fragment handlers
    on<EnqueueMessageEvent>(_onEnqueueMessage);
    on<ProcessQueuedMessageEvent>(_onProcessQueuedMessage);
    on<HandleFragmentEvent>(_onHandleFragment);
    on<MessageQueuedEvent>(_onMessageQueued);
    
    // Fragment handling
    on<AddFragmentMessageEvent>(_onAddFragmentMessage);
    on<NotifyFragmentationCompleteEvent>(_onNotifyFragmentationComplete);
    on<FragmentedMessageReceivedEvent>(_onFragmentedMessageReceived);
    on<CompleteFragmentedMessageEvent>(_onCompleteFragmentedMessage);
    
    // NEW: Fragment sequence completion handlers
    on<ForceCompleteFragmentationEvent>(_onForceCompleteFragmentation);
    on<CheckFragmentCompletionStatusEvent>(_onCheckFragmentCompletionStatus);
    on<RenderFragmentsImmediatelyEvent>(_onRenderFragmentsImmediately);
    
    _setupPeriodicSync();
    _setupConnectivityListener();
    _setupQueueProcessing();
    _setupFragmentHandling();
    _loadPendingMessages();
  }

  void _setupQueueProcessing() {
    _queueSubscription = _messageQueue.processingStream?.listen((queuedMessage) {
      add(ProcessQueuedMessageEvent(queuedMessage));
    });
  }
  
  void _setupFragmentHandling() {
    _fragmentSubscription = _fragmentManager.events.listen((fragmentEvent) {
      add(HandleFragmentEvent(fragmentEvent));
    });
  }

  List<Message> get currentMessages => List<Message>.from(_currentMessages);
  
  /// Get the currently active fragment sequence ID
  String? get currentActiveSequenceId => _currentActiveSequenceId;

  /// Check if there are any active sequences
  bool get hasActiveSequences => _fragmentSequences.values.any((seq) => !seq.isCompleted);
  
  /// SIMPLIFIED: Force complete method (not needed with simplified approach)
  void forceCompleteAllActiveFragments() {
    print('Force completing all active fragments - simplified approach');
    
    // With simplified approach, just ensure typing indicators are cleared
    _typingSubject.add(false);
    
    // Clear any fragment tracking (backward compatibility)
    _fragmentSequences.clear();
    _currentActiveSequenceId = null;
    
    print('Fragment force completion done - simplified');
  }
  
  
  /// OPTIMIZATION: Debounced conversation metadata update to prevent spam
  void _debouncedConversationUpdate(conv_events.UpdateConversationMetadata updateEvent) {
    // Store the latest update for this conversation
    _pendingConversationUpdates[updateEvent.conversationId] = updateEvent;
    
    // Cancel previous timer and start new one
    _conversationUpdateDebouncer?.cancel();
    _conversationUpdateDebouncer = Timer(_conversationUpdateDelay, () {
      // Send all pending updates
      final updates = Map<String, conv_events.UpdateConversationMetadata>.from(_pendingConversationUpdates);
      _pendingConversationUpdates.clear();
      
      if (!_conversationBloc.isClosed) {
        for (final update in updates.values) {
          _conversationBloc.add(update);
          print('Debounced conversation update: ${update.conversationId} (unread: ${update.unreadCount})');
        }
      }
    });
  }

  // NEW: Update fragment progress
  void _updateFragmentProgress(String sequenceId) {
    final sequence = _fragmentSequences[sequenceId];
    if (sequence != null && !sequence.isCompleted) {
      _fragmentSequences[sequenceId] = sequence.copyWith(
        displayedCount: sequence.displayedCount + 1,
      );
      
      // Check if sequence is now complete
      if (sequence.displayedCount + 1 >= sequence.totalFragments) {
        _fragmentSequences[sequenceId] = sequence.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        
        if (_currentActiveSequenceId == sequenceId) {
          _currentActiveSequenceId = null;
        }
      }
    }
  }

  // NEW: Calculate unread fragment count for a conversation
  int _calculateUnreadFragmentCount(String conversationId) {
    int unreadCount = 0;
    
    for (final sequence in _fragmentSequences.values) {
      if (sequence.originalMessage.conversationId == conversationId && !sequence.isCompleted) {
        // Count remaining fragments as unread
        unreadCount += sequence.remainingFragments.length;
      }
    }
    
    return unreadCount;
  }

  // SIMPLIFIED: Remove complex fragment sequence tracking (not needed with our approach)
  bool hasIncompleteFragments(String conversationId) {
    // With simplified approach, fragments are stored in single messages
    // No incomplete fragments to track
    return false;
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessageState> emit) async {
    // Route through queue system for better management
    add(EnqueueMessageEvent(event.message, priority: queue.MessagePriority.normal));
  }

  // Enhanced queue message handler
  Future<void> _onEnqueueMessage(EnqueueMessageEvent event, Emitter<MessageState> emit) async {
    try {
      // Add message to queue
      _messageQueue.enqueueUserMessage(event.message);
      
      // Optimistic UI update
      _currentMessages.add(event.message);
      
      // Provide immediate feedback
      emit(MessageQueued(
        messages: List.from(_currentMessages),
        queueLength: _messageQueue.queueLength,
      ));
      
      // Cache optimistic update
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }
    } catch (e) {
      emit(MessageError(error: Exception('Failed to enqueue message: $e')));
    }
  }

  // Process queued messages
  Future<void> _onProcessQueuedMessage(ProcessQueuedMessageEvent event, Emitter<MessageState> emit) async {
    final queuedMessage = event.queuedMessage;
    
    try {
      switch (queuedMessage.type) {
        case queue.MessageType.user:
          await _processUserMessage(queuedMessage.message, emit);
          break;
        case queue.MessageType.system:
          await _processSystemMessage(queuedMessage.message, emit);
          break;
        case queue.MessageType.fragment:
          // Handled by FragmentManager
          break;
        case queue.MessageType.notification:
          await _processNotification(queuedMessage.message, emit);
          break;
      }
    } catch (e) {
      emit(MessageError(error: Exception('Failed to process queued message: $e')));
    }
  }

  // Enhanced user message processing
  Future<void> _processUserMessage(Message message, Emitter<MessageState> emit) async {
    try {
      // Update conversation identifier in GeminiService metadata
      final metrics = _geminiService.getRelationshipMetrics();
      if (!metrics.containsKey('conversation_id')) {
        _geminiService.addMemoryItem('conversation_id', message.conversationId);
      }

      // Save to repository if online
      if (_connectivityService.isOnline) {
        await _repository.sendMessage(message);
      } else {
        await _addPendingMessage(message);
      }
      
      // Update current state
      emit(MessageLoaded(messages: List.from(_currentMessages)));
      
      // Generate AI response
      await _processAIResponse(message, emit);
    } catch (e) {
      emit(MessageError(error: Exception('Failed to process user message: $e')));
    }
  }

  // SIMPLIFIED: AI response processing with streamlined fragment support
  Future<void> _processAIResponse(Message userMessage, Emitter<MessageState> emit) async {
    try {
      // Show typing indicator
      _typingSubject.add(true);
      emit(MessageReceiving(userMessage.messageFragments.join(' '), messages: _currentMessages));

      // Generate AI response
      final String aiResponse = await _geminiService.generateResponse(
        userMessage.messageFragments.join(' '),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => "I'm having trouble with my thoughts right now. Could you give me a moment?",
      );

      // Hide typing indicator after AI response generation
      _typingSubject.add(false);

      // Fragment the response
      final fragments = MessageFragmenter.fragmentResponse(aiResponse);

      // Create a SINGLE AI message with fragments stored directly
      final metrics = _geminiService.getRelationshipMetrics();
      final aiMessage = Message(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        messageFragments: fragments,
        companionId: userMessage.companionId,
        userId: userMessage.userId,
        conversationId: userMessage.conversationId,
        isBot: true,
        created_at: DateTime.now(),
        metadata: {
          'relationship_level': metrics['level'],
          'emotion': metrics['dominant_emotion'],
          'has_fragments': fragments.length > 1,
          'total_fragments': fragments.length,
        },
      );

      // FIXED: Don't add to _currentMessages yet - let fragment display handle it
      // Store SINGLE message to repository first (complete message with fragments)
      if (_connectivityService.isOnline) {
        await _repository.sendMessage(aiMessage);
      } else {
        await _addPendingMessage(aiMessage);
      }

      // NEW: For real-time display, show fragments progressively with typing indicators
      if (fragments.length > 1) {
        await _displayFragmentsWithTiming(aiMessage, emit);
      } else {
        // Single fragment - add to messages and display immediately
        _currentMessages.add(aiMessage);
        emit(MessageLoaded(messages: List.from(_currentMessages)));
      }

      // Cache the complete message after fragment display
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      // Update conversation metadata
      if (!_conversationBloc.isClosed) {
        final updateEvent = conv_events.UpdateConversationMetadata(
          conversationId: userMessage.conversationId,
          lastMessage: aiResponse,
          lastUpdated: DateTime.now(),
          unreadCount: 0,
          markAsRead: true,
        );
        _debouncedConversationUpdate(updateEvent);
      }

    } catch (e) {
      print('Error generating AI response: $e');
      _typingSubject.add(false);
      await _handleAIResponseError(userMessage, e, emit);
    }
  }

  // Handle AI response errors
  Future<void> _handleAIResponseError(Message userMessage, dynamic error, Emitter<MessageState> emit) async {
    final errorMessage = Message(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      messageFragments: ["I'm having trouble responding right now. Please try again later."],
      companionId: userMessage.companionId,
      userId: userMessage.userId,
      conversationId: userMessage.conversationId,
      isBot: true,
      created_at: DateTime.now(),
      metadata: {'error': true},
    );
    
    _currentMessages.add(errorMessage);
    emit(MessageLoaded(messages: List.from(_currentMessages), hasError: true));
    
    // Cache error message
    if (_currentUserId != null && _currentCompanionId != null) {
      await _cacheService.cacheMessages(
        _currentUserId!,
        _currentMessages,
        companionId: _currentCompanionId!,
      );
    }
  }

  // FIXED: Enhanced fragment event handler with proper single-sequence handling
  Future<void> _onHandleFragment(HandleFragmentEvent event, Emitter<MessageState> emit) async {
    final fragmentEvent = event.fragmentEvent;
    
    try {
      if (fragmentEvent is FragmentSequenceStarted) {
        print('Fragment sequence started: ${fragmentEvent.sequence.id}');

        // Show initial typing indicator
        _typingSubject.add(true);
        
        emit(MessageFragmentInProgress(
          sequence: fragmentEvent.sequence,
          currentFragment: Message(
            id: 'typing_${DateTime.now().millisecondsSinceEpoch}',
            messageFragments: ['typing...'],
            companionId: fragmentEvent.sequence.originalMessage.companionId,
            userId: fragmentEvent.sequence.originalMessage.userId,
            conversationId: fragmentEvent.sequence.originalMessage.conversationId,
            isBot: true,
            created_at: DateTime.now(),
          ),
          messages: List.from(_currentMessages),
        ));
        
      } else if (fragmentEvent is FragmentTypingStarted) {
        print('Fragment typing started for fragment: ${fragmentEvent.sequence.currentIndex + 1}');
        
        // Show typing indicator for next fragment
        _typingSubject.add(true);
        
        emit(MessageFragmentTyping(
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
      } else if (fragmentEvent is FragmentDisplayed) {
        print('Fragment displayed: ${fragmentEvent.fragment.metadata['fragment_index']}');
        
        // Hide typing indicator when fragment is displayed
        _typingSubject.add(false);
        
        // Add fragment to current messages
        _currentMessages.add(fragmentEvent.fragment);
        
        // Emit fragment displayed state
        emit(MessageFragmentDisplayed(
          fragment: fragmentEvent.fragment,
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
        // Cache the fragment immediately
        if (_currentUserId != null && _currentCompanionId != null) {
          await _cacheService.cacheMessages(
            _currentUserId!,
            _currentMessages,
            companionId: _currentCompanionId!,
          );
        }
      } else if (fragmentEvent is FragmentSequenceCompleted) {
        print('Fragment sequence completed: ${fragmentEvent.sequence.id}');
        
        // Hide typing indicator
        _typingSubject.add(false);
        
        emit(MessageFragmentSequenceCompleted(
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
        // Update conversation metadata
        if (_connectivityService.isOnline) {
          await _repository.updateConversation(
            fragmentEvent.sequence.originalMessage.conversationId,
            lastMessage: fragmentEvent.sequence.fragments.last,
            incrementUnread: 1,
          );
        }
        
        // Mark conversation as read
        await _repository.markConversationAsRead(
          fragmentEvent.sequence.originalMessage.conversationId
        );
        
        // Final emission to stable state
        emit(MessageLoaded(messages: List.from(_currentMessages)));
      }
    } catch (e) {
      print('Error handling fragment event: $e');
      _typingSubject.add(false);
      emit(MessageError(error: Exception('Failed to handle fragment event: $e')));
    }
  }

  // Process system messages
  Future<void> _processSystemMessage(Message message, Emitter<MessageState> emit) async {
    _currentMessages.add(message);
    
    if (_connectivityService.isOnline) {
      await _repository.sendMessage(message);
    } else {
      await _addPendingMessage(message);
    }
    
    emit(MessageLoaded(messages: List.from(_currentMessages)));
  }

  // Process notification messages
  Future<void> _processNotification(Message message, Emitter<MessageState> emit) async {
    _currentMessages.add(message);
    emit(MessageLoaded(messages: List.from(_currentMessages)));
  }

  // Enhanced queue state handler
  Future<void> _onMessageQueued(MessageQueuedEvent event, Emitter<MessageState> emit) async {
    emit(MessageQueued(
      messages: event.messages,
      queueLength: event.queueLength,
    ));
  }

  // Handle individual fragment messages
  Future<void> _onAddFragmentMessage(AddFragmentMessageEvent event, Emitter<MessageState> emit) async {
    final fragmentMessage = event.fragmentMessage;
    
    // Add fragment to current messages
    _currentMessages.add(fragmentMessage);
    
    // Check if this is a force-completed fragment (batch processing optimization)
    final isForceCompleted = fragmentMessage.metadata['force_completed'] == true;
    final sequenceId = fragmentMessage.metadata['sequence_id']?.toString();
    
    // Update fragment progress tracking
    if (sequenceId != null) {
      _updateFragmentProgress(sequenceId);
    }
    
    // Cache immediately (but don't emit state for force-completed fragments to avoid UI spam)
    if (_currentUserId != null && _currentCompanionId != null) {
      await _cacheService.cacheMessages(
        _currentUserId!,
        _currentMessages,
        companionId: _currentCompanionId!,
      );
    }

    // Only emit state for natural fragments, not force-completed ones
    if (!isForceCompleted && state is! MessageFragmentInProgress) {
      emit(MessageLoaded(messages: List.from(_currentMessages)));
    }
  }

  // Handle fragmentation completion notification
  Future<void> _onNotifyFragmentationComplete(NotifyFragmentationCompleteEvent event, Emitter<MessageState> emit) async {
    // Update conversation metadata
    if (_connectivityService.isOnline) {
      try {
        await _repository.updateConversation(
          event.conversationId,
          lastMessage: "New message",
          incrementUnread: 1,
        );
        
        await _repository.markConversationAsRead(event.conversationId);
      } catch (e) {
        print('Error updating conversation after fragmentation: $e');
      }
    }

    // Final state update
    await Future.delayed(const Duration(milliseconds: 200), () {
      if (!isClosed && !emit.isDone) {
        emit(MessageLoaded(messages: List.from(_currentMessages)));
        emit(MessageSent());
      }
    });
  }

  // Handle fragmented message display
  Future<void> _onFragmentedMessageReceived(
    FragmentedMessageReceivedEvent event,
    Emitter<MessageState> emit,
  ) async {
    emit(MessageFragmenting(
      fragments: event.fragments,
      currentFragmentIndex: 0,
      messages: _currentMessages,
      originalMessage: event.originalMessage,
    ));
  }

  // Simplified completion handler
  Future<void> _onCompleteFragmentedMessage(
    CompleteFragmentedMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    final userMessage = event.userMessage;
    
    /// ai response is saved in the database in _processAIResponse method so no need to save it again here
    // // Save complete message to database for search/backup purposes
    // if (_connectivityService.isOnline) {
    //   try {
    //     final completeMessage = originalMessage.copyWith(
    //       id: 'complete_${DateTime.now().millisecondsSinceEpoch}',
    //       metadata: {
    //         ...originalMessage.metadata, 
    //         'is_complete_version': true,
    //         'fragment_count': originalMessage.metadata['total_fragments'] ?? 1,
    //       }
    //     );
    //     await _repository.sendMessage(completeMessage);
    //     await _repository.updateConversation(
    //       userMessage.conversationId,
    //       lastMessage: originalMessage.message,
    //       incrementUnread: 1,
    //     );
    //   } catch (e) {
    //     print('Error saving complete message: $e');
    //   }
    // }

    await _repository.markConversationAsRead(userMessage.conversationId);
  }

  // Setup connectivity monitoring using centralized service
  void _setupConnectivityListener() {
    try {
      _isOnline = _connectivityService.isOnline;
      
      _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
        if (isOnline != _isOnline) {
          _isOnline = isOnline;
          add(ConnectivityChangedEvent(isOnline));
          
          if (isOnline && _pendingMessages.isNotEmpty) {
            add(ProcessPendingMessagesEvent());
          }
        }
      }, onError: (e) {
        print('Connectivity stream error in MessageBloc: $e');
      });
      
    } catch (e) {
      print('Failed to setup connectivity listener in MessageBloc: $e');
      _isOnline = true;
    }
  }

  Future<void> _onConnectivityChanged(
    ConnectivityChangedEvent event,
    Emitter<MessageState> emit,
  ) async {
    _isOnline = event.isOnline;
    print('MessageBloc connectivity changed, online: $_isOnline');
    
    if (_isOnline && _pendingMessages.isNotEmpty) {
      add(ProcessPendingMessagesEvent());
    }
  }

  // Process messages that were sent while offline
  Future<void> _onProcessPendingMessages(
    ProcessPendingMessagesEvent event,
    Emitter<MessageState> emit,
  ) async {
    if (_pendingMessages.isEmpty || !_isOnline) return;
    
    print('Processing ${_pendingMessages.length} pending messages');
    
    for (int i = 0; i < _pendingMessages.length; i++) {
      try {
        final pendingMessage = _pendingMessages[i];
        
        if (!isLocalId(pendingMessage.id!)) continue;
        
        await _repository.sendMessage(pendingMessage);
        
        if (!pendingMessage.isBot) {
          await _processAIResponse(pendingMessage, emit);
        }
        
        await _repository.updateConversation(
          pendingMessage.conversationId,
          lastMessage: pendingMessage.messageFragments.join(' '),
          incrementUnread: pendingMessage.isBot ? 1 : 0,
        );
        
      } catch (e) {
        print('Error processing pending message: $e');
      }
    }
    
    _pendingMessages.clear();
    await _savePendingMessages();
    
    if (_currentUserId != null && _currentCompanionId != null) {
      add(RefreshMessages());
    }
  }

  // Load pending messages from SharedPreferences
  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = prefs.getStringList(_pendingMessagesKey) ?? [];
      
      _pendingMessages.clear();
      for (final json in pendingMessagesJson) {
        try {
          final Map<String, dynamic> messageData = jsonDecode(json);
          final message = Message.fromJson(messageData);
          _pendingMessages.add(message);
        } catch (e) {
          print('Error parsing pending message: $e');
        }
      }
      
      print('Loaded ${_pendingMessages.length} pending messages');
    } catch (e) {
      print('Error loading pending messages: $e');
    }
  }

  // Save pending messages to SharedPreferences
  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = _pendingMessages.map(
        (m) => jsonEncode(m.toJson())
      ).toList();
      
      await prefs.setStringList(_pendingMessagesKey, pendingMessagesJson);
    } catch (e) {
      print('Error saving pending messages: $e');
    }
  }

  // Add a pending message
  Future<void> _addPendingMessage(Message message) async {
    _pendingMessages.add(message);
    await _savePendingMessages();
  }

  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _backgroundSync(),
    );
  }

  Future<void> _backgroundSync() async {
    if (_currentUserId != null && _currentCompanionId != null) {
      try {
        final messages = await _repository.getMessages(_currentUserId!, _currentCompanionId!);
        await _cacheService.cacheMessages(
          _currentUserId!,
          messages,
          companionId: _currentCompanionId!,
        );

        _triggerConversationRefresh();
      } catch (e) {
        print('Background sync error: $e');
      }
    }
  }

  void _triggerConversationRefresh() {
    if (_currentUserId != null) {
      // This is handled by the UI when needed
    }
  }

  bool isLocalId(String id) {
    return id.startsWith('local_') || id.startsWith('fallback-');
  }

  // CRUD operations and other methods remain unchanged

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _queueSubscription?.cancel();
    _fragmentSubscription?.cancel();
    _conversationUpdateDebouncer?.cancel(); // Clean up debouncer
    await _typingSubject.close();
    _fragmentManager.dispose();
    _messageQueue.dispose();

    if (_currentUserId != null && _currentCompanionId != null) {
      await _geminiService.saveState();
    }

    return super.close();
  }

  Future<void> _onInitializeCompanion(
    InitializeCompanionEvent event,
    Emitter<MessageState> emit,
  ) async {
    // Check if bloc is still active
    if (isClosed) {
      print('MessageBloc is closed, cannot initialize companion');
      return;
    }
    
    try {
      emit(MessageLoading());

      _currentUserId = event.userId;
      _currentCompanionId = event.companion.id;

      // Save current state if there's an active companion
      if (_geminiService.isInitialized) {
        await _geminiService.saveState();
      }

      // Initialize the AI companion with user information
      try {
        await _geminiService.initializeCompanion(
          companion: event.companion,
          userId: event.userId,
          messageBloc: this,
          userName: event.user?.fullName,
          userProfile: event.user?.toAIFormat(),
        );

        if (!isClosed) {
          emit(CompanionInitialized(event.companion));
        }
      } catch (e) {
        print('Error in GeminiService.initializeCompanion: $e');
        // Even if Gemini initialization fails, we can still show the UI
        if (!isClosed) {
          emit(CompanionInitialized(event.companion));
        }
      }
    } catch (e) {
      print('Error initializing companion: $e');
      if (!isClosed) {
        emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
      }
    }
  }

  // MODIFIED: Load messages with fragment detection
  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    // Check if bloc is still active
    if (isClosed) {
      print('MessageBloc is closed, cannot load messages');
      return;
    }
    
    try {
      // Force complete any existing fragments before loading new conversation
      if(hasActiveSequences){
        forceCompleteAllActiveFragments();
      }
      
      emit(MessageLoading());

      _currentUserId = event.userId;
      _currentCompanionId = event.companionId;

      // 1. Get companion data
      final companion = await _repository.getCompanion(event.companionId);
      if (companion == null) {
        throw Exception('Companion not found');
      }

      // Check if still active before proceeding
      if (isClosed) return;

      // 2. Try cached messages first
      _currentMessages = _cacheService.getCachedMessages(
        event.userId,
        companionId: event.companionId,
      );

      // Find any pending messageIds
      final pendingMessageIds = _pendingMessages
          .where((m) => m.companionId == event.companionId && m.userId == event.userId)
          .map((m) => m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (_currentMessages.isNotEmpty && !isClosed) {
        // CRITICAL: Filter out complete versions if fragments exist
        _currentMessages = _filterDuplicateMessages(_currentMessages);
        
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
        ));
      }

      // 3. If online, get messages from server
      if (_connectivityService.isOnline && !isClosed) {
        try {
          final messages = await _repository.getMessages(event.userId, event.companionId);

          if (messages.isNotEmpty && !isClosed) {
            // Filter out complete versions if fragments exist
            final filteredMessages = _filterDuplicateMessages(messages);
            
            if (filteredMessages.isNotEmpty &&
                (_currentMessages.isEmpty ||
                    filteredMessages.length != _currentMessages.length ||
                    _messagesNeedUpdate(filteredMessages, _currentMessages))) {
              _currentMessages = filteredMessages;
              
              await _cacheService.cacheMessages(
                event.userId,
                _currentMessages,
                companionId: event.companionId,
              );
              
              if (!isClosed) {
                emit(MessageLoaded(
                  messages: _currentMessages,
                  pendingMessageIds: pendingMessageIds,
                ));
              }
            }
          }
        } catch (e) {
          print('Error fetching messages from server: $e');
        }
      }

      // Check if still active before AI initialization
      if (isClosed) return;

      // 5. Get current user
      final user = await CustomAuthUser.getCurrentUser();

      // 6. Initialize AI companion if needed
      try {
        if (!_geminiService.isCompanionInitialized(event.userId, event.companionId) && !isClosed) {
          await _geminiService.initializeCompanion(
            companion: companion,
            userId: event.userId,
            userName: user?.fullName,
            userProfile: user?.toAIFormat(),
            messageBloc: this,
          );
        } else {
          print('Companion already initialized, skipping initialization');
        }
      } catch (e) {
        print('Error initializing AI in message loading: $e');
      }

      // Check if still active before creating conversation
      if (isClosed) return;

      // 7. Create conversation if needed
      await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );

      // 8. Final state emission
      if (state is! MessageLoaded && !isClosed) {
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
          isFromCache: true,
        ));
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!isClosed) {
        if (_currentMessages.isNotEmpty) {
          emit(MessageLoaded(
            messages: _currentMessages,
            isFromCache: true,
            hasError: true,
          ));
        } else {
          emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
        }
      }
    }
  }

  // Helper to check if messages have meaningful differences
  bool _messagesNeedUpdate(List<Message> newMessages, List<Message> oldMessages) {
    if (newMessages.length != oldMessages.length) return true;

    // Check last message is different
    if (newMessages.isNotEmpty && oldMessages.isNotEmpty) {
      // Compare last messages by content and timestamp
      final lastNew = newMessages.last;
      final lastOld = oldMessages.last;

      return lastNew.messageFragments.join(' ') != lastOld.messageFragments.join(' ') ||
          lastNew.created_at.isAfter(lastOld.created_at);
    }

    return false;
  }

  // BALANCED: Handle both stored complete messages and live fragment display
  List<Message> _filterDuplicateMessages(List<Message> messages) {
    final fragmentGroups = <String, List<Message>>{};
    final completeMessages = <String, Message>{};
    final nonFragmentedMessages = <Message>[];

    // Group messages by content/timestamp
    for (final message in messages) {
      if (message.metadata['is_fragment'] == true) {
        // Individual fragment messages (from live display)
        final baseId = message.metadata['base_message_id']?.toString() ??
                      (message.id?.contains('_fragment_') == true 
                        ? message.id!.split('_fragment_')[0]
                        : message.id?.replaceAll(RegExp(r'_fragment_\d+'), '')) ??
                      '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
        
        fragmentGroups.putIfAbsent(baseId, () => []).add(message);
      } else if (message.metadata['is_complete_version'] == true) {
        // Complete version messages (rarely used)
        final baseId = message.metadata['original_id']?.toString() ?? 
                      message.id?.toString() ?? 
                      '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
        completeMessages[baseId] = message;
      } else if (message.metadata['has_fragments'] == true && message.messageFragments.length > 1) {
        // Complete messages with multiple fragments (from storage) - expand for consistent UI
        final baseId = message.id ?? '${message.companionId}_${message.created_at.millisecondsSinceEpoch}';
        final expandedFragments = <Message>[];
        
        for (int i = 0; i < message.messageFragments.length; i++) {
          final fragmentMessage = Message(
            id: '${baseId}_fragment_$i',
            messageFragments: [message.messageFragments[i]],
            companionId: message.companionId,
            userId: message.userId,
            conversationId: message.conversationId,
            isBot: message.isBot,
            created_at: message.created_at.add(Duration(milliseconds: i * 100)),
            metadata: {
              'is_fragment': true,
              'fragment_index': i,
              'total_fragments': message.messageFragments.length,
              'base_message_id': baseId,
              'is_from_storage': true, // Mark as loaded from storage
              ...message.metadata,
            },
          );
          expandedFragments.add(fragmentMessage);
        }
        
        fragmentGroups[baseId] = expandedFragments;
      } else {
        // Regular single messages (no fragments)
        nonFragmentedMessages.add(message);
      }
    }

    final result = <Message>[];
    
    // Add non-fragmented messages
    result.addAll(nonFragmentedMessages);
    
    // For each fragment group, add fragments (not complete version)
    fragmentGroups.forEach((baseId, fragments) {
      // Sort fragments by index
      fragments.sort((a, b) {
        final indexA = a.metadata['fragment_index'] as int? ?? 0;
        final indexB = b.metadata['fragment_index'] as int? ?? 0;
        return indexA.compareTo(indexB);
      });
      result.addAll(fragments);
    });
    
    // Add complete messages only if no fragments exist for them
    completeMessages.forEach((baseId, completeMessage) {
      if (!fragmentGroups.containsKey(baseId)) {
        result.add(completeMessage);
      }
    });

    // Sort by timestamp
    result.sort((a, b) => a.created_at.compareTo(b.created_at));
    
    return result;
  }

  Future<void> _onClearConversation(
    ClearConversation event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      // Clear from database
      await _repository.deleteAllMessages(companionId: event.companionId);

      // Clear cached messages for this specific companion
      await _cacheService.clearCache(
        event.userId,
        companionId: event.companionId,
      );
      _currentMessages = [];

      // Reset AI conversation
      _geminiService.resetConversation(messageBloc: this);

      // Update conversation in database
      final conversationId = await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );
      final updateEvent = conv_events.UpdateConversationMetadata(
        conversationId: conversationId,
        lastMessage: "Start a conversation",
        lastUpdated: DateTime.now(),
        markAsRead: true,
      );
        
      _conversationBloc.add(updateEvent);

      emit(MessageLoaded(messages: const []));

      // Trigger conversation list refresh
      _triggerConversationRefresh();
      print('Conversation cleared successfully');
    } catch (e) {
      print('Error clearing conversation: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<MessageState> emit,
  ) async {
    // Implementation for pagination...
  }

  Future<void> _onRetryChatRequest(
    RetryChatRequest event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      // Get the failed message
      final failedMessage = event.failedMessage;

      // Try to resend the message
      if (failedMessage.isBot) {
        // If it's a bot message that failed, regenerate the response
        final previousUserMessage = _currentMessages.lastWhere(
          (msg) => !msg.isBot && msg.id != failedMessage.id,
        );

        add(SendMessageEvent(message: previousUserMessage));
      } else {
        // If it's a user message that failed, try sending again
        add(SendMessageEvent(message: failedMessage));
      }

      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error retrying message: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());
      await _repository.deleteMessage(event.messageId);

      // Update local cache
      _currentMessages.removeWhere((msg) => msg.id == event.messageId);
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error deleting message: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onRefreshMessages(RefreshMessages event, Emitter<MessageState> emit) async {
    // Use centralized connectivity service
    if (!_connectivityService.isOnline) {
      print('Skipping message refresh - device is offline');
      return;
    }
    
    if (_currentUserId != null && _currentCompanionId != null) {
      try {
        final messages = await _repository.getMessages(
          _currentUserId!,
          _currentCompanionId!,
        );
        
        if (messages.isNotEmpty) {
          _currentMessages = messages;
          
          // Update cache
          await _cacheService.cacheMessages(
            _currentUserId!,
            messages,
            companionId: _currentCompanionId!,
          );
          
          // Find any pending messageIds
          final pendingMessageIds = _pendingMessages
              .where((m) => m.companionId == _currentCompanionId && m.userId == _currentUserId)
              .map((m) => m.id ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
              
          emit(MessageLoaded(
            messages: _currentMessages,
            pendingMessageIds: pendingMessageIds,
          ));
        }
      } catch (e) {
        print('Error refreshing messages: $e');
      }
    }
  }

  // NEW: Force complete fragmentation event handler
  Future<void> _onForceCompleteFragmentation(
    ForceCompleteFragmentationEvent event,
    Emitter<MessageState> emit,
  ) async {
    print('Force completing fragment sequence: ${event.sequenceId}');
    
    final sequenceStatus = _fragmentSequences[event.sequenceId];
    if (sequenceStatus == null) {
      print('No sequence found for ID: ${event.sequenceId}');
      return;
    }
    
    // Calculate unread count BEFORE updating sequence (this is the key fix)
    final remainingFragmentCount = sequenceStatus.remainingFragments.length;
    print('Remaining fragments to complete: $remainingFragmentCount');
    
    // Force complete in FragmentManager (this will emit events for each remaining fragment)
    _fragmentManager.forceCompleteSequence(event.sequenceId);
    
    // Update sequence status to completed
    _fragmentSequences[event.sequenceId] = sequenceStatus.copyWith(
      isCompleted: true,
      displayedCount: sequenceStatus.totalFragments,
      completedAt: DateTime.now(),
    );
    
      // Calculate final unread count based on force completion
    int finalUnreadCount;
    if (event.markAsRead) {
      finalUnreadCount = 0; // User explicitly marked as read
      print('Marking all fragments as read due to markAsRead=true');
    } else {
      // Count remaining fragments as unread since user didn't see them naturally
      finalUnreadCount = remainingFragmentCount;
      print('Counting $remainingFragmentCount fragments as unread');
    }
    
    // Update conversation metadata with proper unread count
    if (!_conversationBloc.isClosed) {
      final updateEvent = conv_events.UpdateConversationMetadata(
        conversationId: sequenceStatus.originalMessage.conversationId,
        unreadCount: finalUnreadCount,
        markAsRead: event.markAsRead,
        lastUpdated: DateTime.now(),
        lastMessage: sequenceStatus.originalMessage.messageFragments.join(' '), // Use original message for last message
      );
      
      print('Updating conversation unread count to: $finalUnreadCount');
      // Use debounced update to prevent spam
      _debouncedConversationUpdate(updateEvent);
    }
    
    // Emit completion state
    emit(MessageFragmentCompleted(
      messages: List.from(_currentMessages),
      completedFragmentSequenceId: event.sequenceId,
      totalFragmentsCompleted: sequenceStatus.totalFragments,
    ));
  }

  // NEW: Fragment completion status checker
  Future<void> _onCheckFragmentCompletionStatus(
    CheckFragmentCompletionStatusEvent event,
    Emitter<MessageState> emit,
  ) async {
    final unreadCount = _calculateUnreadFragmentCount(event.conversationId);
    
    if (!_conversationBloc.isClosed) {
      // Create UpdateConversationMetadata event
      final updateEvent = conv_events.UpdateConversationMetadata(
        conversationId: event.conversationId,
        unreadCount: unreadCount,
        markAsRead: unreadCount == 0,
        lastUpdated: DateTime.now(),
      );
      
      _conversationBloc.add(updateEvent);
    }
  }

  // NEW: Render fragments immediately when re-entering chat
  Future<void> _onRenderFragmentsImmediately(
    RenderFragmentsImmediatelyEvent event,
    Emitter<MessageState> emit,
  ) async {
    print('Rendering fragments immediately for conversation: ${event.conversationId}');
    
    // Find any incomplete fragment sequences for this conversation
    final incompleteSequences = _fragmentSequences.values.where((sequence) =>
      !sequence.isCompleted &&
      sequence.originalMessage.conversationId == event.conversationId
    ).toList();
    
    if (incompleteSequences.isNotEmpty) {
      for (final sequence in incompleteSequences) {
        print('Force completing sequence immediately: ${sequence.sequenceId}');
        
        // Force complete this sequence with zero delays
        _fragmentManager.forceCompleteSequence(sequence.sequenceId);
        
        // Update our tracking
        _fragmentSequences[sequence.sequenceId] = sequence.copyWith(
          isCompleted: true,
          displayedCount: sequence.totalFragments,
          completedAt: DateTime.now(),
        );
      }
      
      // Emit the current messages state
      emit(MessageLoaded(
        messages: List.from(_currentMessages),
        pendingMessageIds: [],
      ));
    }
  }

  // OPTIMIZED: Display fragments with proper typing indicators between each fragment
  Future<void> _displayFragmentsWithTiming(Message aiMessage, Emitter<MessageState> emit) async {
    try {
      final fragments = aiMessage.messageFragments;
      print('Starting fragment display for ${fragments.length} fragments');
      
      // Start with current messages without any version of the AI message
      final baseMessages = List<Message>.from(_currentMessages);
      final List<Message> finalFragments = []; // Track fragments for final state
      
      for (int i = 0; i < fragments.length; i++) {
        print('Displaying fragment ${i + 1}/${fragments.length}');
        
        // Show typing indicator before each fragment (except first which should already be showing)
        if (i > 0) {
          // Show typing indicator between fragments
          _typingSubject.add(true);
          print('Showing typing indicator for fragment ${i + 1}');
          
          // Calculate delay for typing animation
          final typingDelay = MessageFragmenter.calculateTypingDelay(fragments[i], i);
          await Future.delayed(Duration(milliseconds: typingDelay));
        }
        
        // Hide typing indicator before showing fragment
        _typingSubject.add(false);
        
        // Create current display state with fragments up to current index
        final currentDisplayMessages = List<Message>.from(baseMessages);
        
        // Add all fragments up to current index for smooth progressive display
        for (int j = 0; j <= i; j++) {
          final displayFragment = Message(
            id: '${aiMessage.id}_fragment_$j',
            messageFragments: [fragments[j]],
            companionId: aiMessage.companionId,
            userId: aiMessage.userId,
            conversationId: aiMessage.conversationId,
            isBot: true,
            created_at: aiMessage.created_at.add(Duration(milliseconds: j * 100)),
            metadata: {
              'is_fragment': true,
              'fragment_index': j,
              'total_fragments': fragments.length,
              'base_message_id': aiMessage.id,
              'relationship_level': aiMessage.metadata['relationship_level'],
              'emotion': aiMessage.metadata['emotion'],
            },
          );
          currentDisplayMessages.add(displayFragment);
          
          // Track this fragment for final state (only add once)
          if (j == i) {
            finalFragments.add(displayFragment);
          }
        }
        
        // Emit state with current fragments
        emit(MessageLoaded(messages: currentDisplayMessages));
        print('Emitted fragment ${i + 1}, total messages: ${currentDisplayMessages.length}');
        
        // Small delay between fragments for natural flow (but only if not the last fragment)
        if (i < fragments.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      
      // CRITICAL FIX: Keep fragments in _currentMessages for UI display, NOT the complete message
      _currentMessages.addAll(finalFragments);
      print('Fragment display complete, added ${finalFragments.length} individual fragments to _currentMessages');
      
      // Emit final state with fragments (NOT complete message)
      emit(MessageLoaded(messages: List.from(_currentMessages)));
      
    } catch (e) {
      print('Error displaying fragments: $e');
      _typingSubject.add(false); // Ensure typing indicator is hidden on error
      
      // Fallback: add complete message and emit
      if (!_currentMessages.any((m) => m.id == aiMessage.id)) {
        _currentMessages.add(aiMessage);
      }
      emit(MessageLoaded(messages: List.from(_currentMessages)));
    }
  }
}
// Helper method to allow unawaited futures
void unawaited(Future<void> future) {}