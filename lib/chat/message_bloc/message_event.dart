import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/msg_fragmentation/fragments/fragment_manager.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_queue/message_queue.dart' as queue;
import 'package:equatable/equatable.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();

  @override
  List<Object?> get props => [];
}

// Add new events for offline support
class ConnectivityChangedEvent extends MessageEvent {
  final bool isOnline;
  
  const ConnectivityChangedEvent(this.isOnline);
  
  @override
  List<Object> get props => [isOnline];
}

class ProcessPendingMessagesEvent extends MessageEvent {}

class InitializeCompanionEvent extends MessageEvent {
  final AICompanion companion;
  final String userId;
  final CustomAuthUser? user;
  final bool shouldLoadMessages;

  const InitializeCompanionEvent({
    required this.companion,
    required this.userId,
    this.user,
    this.shouldLoadMessages = false,
  });

  @override
  List<Object?> get props => [companion, userId, user, shouldLoadMessages];
}

class SendMessageEvent extends MessageEvent {
  final Message message;

  const SendMessageEvent({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class LoadMessagesEvent extends MessageEvent {
  final String userId;
  final String companionId;

  const LoadMessagesEvent({
    required this.userId,
    required this.companionId,
  });

  @override
  List<Object?> get props => [userId, companionId];
}

class AddFragmentMessageEvent extends MessageEvent {
  final Message fragmentMessage;
  
  const AddFragmentMessageEvent(this.fragmentMessage);
  
  @override
  List<Object?> get props => [fragmentMessage];
}

class NotifyFragmentationCompleteEvent extends MessageEvent {
  final String conversationId;
  
  const NotifyFragmentationCompleteEvent(this.conversationId);
  
  @override
  List<Object?> get props => [conversationId];
}

class CompleteFragmentedMessageEvent extends MessageEvent {
  final Message originalMessage;
  final Message userMessage;
  
  const CompleteFragmentedMessageEvent(this.originalMessage, this.userMessage);
  
  @override
  List<Object?> get props => [originalMessage, userMessage];
}

class FragmentedMessageReceivedEvent extends MessageEvent {
  final List<String> fragments;
  final Message originalMessage;
  
  const FragmentedMessageReceivedEvent(this.fragments, this.originalMessage);
  
  @override
  List<Object?> get props => [fragments, originalMessage];
}

class DeleteMessageEvent extends MessageEvent {
  final String messageId;

  const DeleteMessageEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class LoadMoreMessages extends MessageEvent {
  final String userId;
  final String companionId;
  final int offset;
  final int limit;

  const LoadMoreMessages({
    required this.userId,
    required this.companionId,
    this.offset = 0,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, companionId, offset, limit];
}

class RefreshMessages extends MessageEvent {}

class ClearConversation extends MessageEvent {
  final String userId;
  final String companionId;

  const ClearConversation({
    required this.userId,
    required this.companionId,
  });

  @override
  List<Object?> get props => [userId, companionId];
}

class RetryChatRequest extends MessageEvent {
  final Message failedMessage;

  const RetryChatRequest(this.failedMessage);

  @override
  List<Object?> get props => [failedMessage];
}

// NEW: Enhanced queue system events
class EnqueueMessageEvent extends MessageEvent {
  final Message message;
  final queue.MessagePriority priority;
  
  const EnqueueMessageEvent(this.message, {this.priority = queue.MessagePriority.normal});
  
  @override
  List<Object?> get props => [message, priority];
}

class ProcessQueuedMessageEvent extends MessageEvent {
  final queue.QueuedMessage queuedMessage;
  const ProcessQueuedMessageEvent(this.queuedMessage);
  
  @override
  List<Object?> get props => [queuedMessage];
}

class HandleFragmentEvent extends MessageEvent {
  final FragmentEvent fragmentEvent;
  const HandleFragmentEvent(this.fragmentEvent);
  
  @override
  List<Object?> get props => [fragmentEvent];
}

// Enhanced message processing events
class MessageQueuedEvent extends MessageEvent {
  final List<Message> messages;
  final int queueLength;
  
  const MessageQueuedEvent({
    required this.messages,
    required this.queueLength,
  });
  
  @override
  List<Object?> get props => [messages, queueLength];
}

// NEW: Fragment sequence completion events
class ForceCompleteFragmentationEvent extends MessageEvent {
  final String sequenceId;
  final bool markAsRead;
  
  const ForceCompleteFragmentationEvent({
    required this.sequenceId,
    this.markAsRead = false,
  });
  
  @override
  List<Object> get props => [sequenceId, markAsRead];
}

class CheckFragmentCompletionStatusEvent extends MessageEvent {
  final String conversationId;
  
  const CheckFragmentCompletionStatusEvent(this.conversationId);
  
  @override
  List<Object> get props => [conversationId];
}

// NEW: Event to render fragments immediately without delays (for chat re-entry)
class RenderFragmentsImmediatelyEvent extends MessageEvent {
  final String conversationId;
  
  const RenderFragmentsImmediatelyEvent(this.conversationId);
  
  @override
  List<Object> get props => [conversationId];
}