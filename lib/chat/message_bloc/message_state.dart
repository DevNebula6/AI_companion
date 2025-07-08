import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/fragments/fragment_manager.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_queue/message_queue.dart' as queue;
import 'package:equatable/equatable.dart';

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {}

class CompanionInitialized extends MessageState {
  final AICompanion companion;

  const CompanionInitialized(this.companion);

  @override
  List<Object> get props => [companion];
}

class MessageLoaded extends MessageState {
  final List<Message> messages;
  final List<String> pendingMessageIds; // New field for pending messages
  final bool isFromCache; // New field for cache source
  final bool hasError;
  
  const MessageLoaded({
    required this.messages,
    this.pendingMessageIds = const [], // Default to empty list
    this.isFromCache = false, // Default to not from cache
    this.hasError = false,
  });

  @override
  List<Object> get props => [
    messages, 
    pendingMessageIds,
    isFromCache,
    hasError,
  ];
}

class MessageFragmenting extends MessageState {
  final List<String> fragments;
  final int currentFragmentIndex;
  final List<Message> messages;
  final Message originalMessage;

  const MessageFragmenting({
    required this.fragments,
    required this.currentFragmentIndex,
    required this.messages,
    required this.originalMessage,
  });

  @override
  List<Object?> get props => [fragments, currentFragmentIndex, messages, originalMessage];
}

class MessageReceiving extends MessageLoaded {
  final String userMessage;

  const MessageReceiving(
    this.userMessage, 
    {required super.messages}
  );

  @override
  List<Object> get props => [userMessage, messages];
}

class MessageSent extends MessageState {}

class MessageError extends MessageState {
  final Exception error;

  const MessageError({required this.error});

  @override
  List<Object> get props => [error];
}

class MessagesCleared extends MessageState {}

class MessageQueued extends MessageState {
  final List<Message> messages;
  final int queueLength;
  
  const MessageQueued({
    required this.messages,
    required this.queueLength,
  });
}

class MessageFragmentDisplayed extends MessageState {
  final Message fragment;
  final FragmentSequence sequence;
  final List<Message> messages;
  
  const MessageFragmentDisplayed({
    required this.fragment,
    required this.sequence,
    required this.messages,
  });
}

class MessageFragmentSequenceCompleted extends MessageState {
  final FragmentSequence sequence;
  final List<Message> messages;
  
  const MessageFragmentSequenceCompleted({
    required this.sequence,
    required this.messages,
  });
}

// NEW: Enhanced processing state
class MessageProcessingQueue extends MessageState {
  final List<Message> messages;
  final int queueLength;
  final queue.QueuedMessage? currentlyProcessing;
  
  const MessageProcessingQueue({
    required this.messages,
    required this.queueLength,
    this.currentlyProcessing,
  });

  @override
  List<Object?> get props => [messages, queueLength, currentlyProcessing];
}

// NEW: Enhanced fragment state with better tracking
class MessageFragmentInProgress extends MessageState {
  final FragmentSequence sequence;
  final Message currentFragment;
  final List<Message> messages;
  
  const MessageFragmentInProgress({
    required this.sequence,
    required this.currentFragment,
    required this.messages,
  });

  @override
  List<Object> get props => [sequence, currentFragment, messages];
}

class MessageFragmentTyping extends MessageState {
  final FragmentSequence sequence;
  final List<Message> messages;
  
  const MessageFragmentTyping({
    required this.sequence,
    required this.messages,
  });
  
  @override
  List<Object?> get props => [sequence, messages];
}
