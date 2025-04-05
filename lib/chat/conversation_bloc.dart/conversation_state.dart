import 'package:ai_companion/chat/conversation.dart';
import 'package:equatable/equatable.dart';

abstract class ConversationState extends Equatable {
  const ConversationState();
  
  @override
  List<Object?> get props => [];
}

class ConversationInitial extends ConversationState {}

class ConversationLoading extends ConversationState {}

class ConversationLoaded extends ConversationState {
  final List<Conversation> conversations;
  final List<Conversation> pinnedConversations;
  final List<Conversation> regularConversations;
  
  const ConversationLoaded({
    required this.conversations,
    required this.pinnedConversations,
    required this.regularConversations,
  });
  
  @override
  List<Object?> get props => [conversations, pinnedConversations, regularConversations];
}

class ConversationError extends ConversationState {
  final String message;
  
  const ConversationError(this.message);
  
  @override
  List<Object?> get props => [message];
}

class ConversationCreated extends ConversationState {
  final String conversationId;
  
  const ConversationCreated(this.conversationId);
  
  @override
  List<Object?> get props => [conversationId];
}