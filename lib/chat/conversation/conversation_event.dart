import 'package:ai_companion/chat/conversation.dart';

abstract class ConversationEvent {}

class LoadConversations extends ConversationEvent {
  final String userId;
  
  LoadConversations(this.userId);
}

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
class RefreshConversations extends ConversationEvent {
  final String userId;
  
  RefreshConversations({
    required this.userId,
  });
}
class ConversationsUpdated extends ConversationEvent {
  final List<Conversation> conversations;
  
  ConversationsUpdated(this.conversations);
}

class ConversationErrorEvent extends ConversationEvent {
  final String message;
  
  ConversationErrorEvent(this.message);
}