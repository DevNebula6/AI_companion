
import 'package:ai_companion/chat/conversation.dart';

abstract class ConversationEvent {}

class LoadConversations extends ConversationEvent {}

class MarkConversationAsRead extends ConversationEvent {
  final String conversationId;
  
  MarkConversationAsRead(this.conversationId);
}

class PinConversation extends ConversationEvent {
  final String conversationId;
  final bool isPinned;
  
  PinConversation(this.conversationId, this.isPinned);
}

class DeleteConversation extends ConversationEvent {
  final String conversationId;
  
  DeleteConversation(this.conversationId);
}

class CreateConversation extends ConversationEvent {
  final String companionId;
  
  CreateConversation(this.companionId);
}

// Internal events
class _ConversationsUpdated extends ConversationEvent {
  final List<Conversation> conversations;
  
  _ConversationsUpdated(this.conversations);
}

class _ConversationError extends ConversationEvent {
  final String message;
  
  _ConversationError(this.message);
}