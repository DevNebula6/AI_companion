import 'package:ai_companion/chat/conversation.dart';
import 'package:equatable/equatable.dart';

abstract class ConversationEvent extends Equatable {
  const ConversationEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadConversations extends ConversationEvent {
  final String userId;
  
  const LoadConversations(this.userId);
  
  @override
  List<Object> get props => [userId];
}

class MarkConversationAsRead extends ConversationEvent {
  final String conversationId;
  
  const MarkConversationAsRead(this.conversationId);
  
  @override
  List<Object> get props => [conversationId];
}

class PinConversation extends ConversationEvent {
  final String conversationId;
  final bool isPinned;
  
  const PinConversation(this.conversationId, this.isPinned);
  
  @override
  List<Object> get props => [conversationId, isPinned];
}

class DeleteConversation extends ConversationEvent {
  final String conversationId;
  
  const DeleteConversation(this.conversationId);
  
  @override
  List<Object> get props => [conversationId];
}

class CreateConversation extends ConversationEvent {
  final String companionId;
  
  const CreateConversation(this.companionId);
  
  @override
  List<Object> get props => [companionId];
}

class RefreshConversations extends ConversationEvent {
  final String userId;
  
  const RefreshConversations({
    required this.userId,
  });
  
  @override
  List<Object> get props => [userId];
}

class ConversationsUpdated extends ConversationEvent {
  final List<Conversation> conversations;
  
  const ConversationsUpdated(this.conversations);
  
  @override
  List<Object> get props => [conversations];
}

class ConversationErrorEvent extends ConversationEvent {
  final String message;
  
  const ConversationErrorEvent(this.message);
  
  @override
  List<Object> get props => [message];
}

class UpdateConversationMetadata extends ConversationEvent {
  final String conversationId;
  final String? lastMessage;
  final DateTime? lastUpdated;
  final int? unreadCount;
  final bool markAsRead;

  const UpdateConversationMetadata({
    required this.conversationId,
    this.lastMessage,
    this.lastUpdated,
    this.unreadCount,
    this.markAsRead = false,
  });
  
  @override
  List<Object?> get props => [conversationId, lastMessage, lastUpdated, unreadCount, markAsRead];
}

class ClearAllCacheForUser extends ConversationEvent {
  final String? userId;
  
  const ClearAllCacheForUser({this.userId});

  @override
  List<Object?> get props => [userId];
}

class ConnectivityChangedEvent extends ConversationEvent {
  final bool isOnline;
  
  const ConnectivityChangedEvent(this.isOnline);
  
  @override
  List<Object> get props => [isOnline];
}