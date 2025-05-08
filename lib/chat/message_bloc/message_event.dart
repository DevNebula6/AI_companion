import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/message.dart';
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

  const InitializeCompanionEvent({
    required this.companion,
    required this.userId,
    this.user,
  });

  @override
  List<Object?> get props => [companion, userId, user];
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