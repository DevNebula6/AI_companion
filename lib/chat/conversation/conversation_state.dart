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
  final bool isFromCache; // New property to track if data is from cache
  final bool isSyncing;
  final bool hasError;

  const ConversationLoaded({
    required this.conversations,
    required this.pinnedConversations,
    required this.regularConversations,
    this.isFromCache = false,
    this.isSyncing = false,
    this.hasError = false,
  });
  
  @override
  List<Object?> get props => [
    conversations, 
    pinnedConversations, 
    regularConversations, 
    isFromCache,
    isSyncing,
    hasError,
  ];
}

class ConversationCreated extends ConversationState {
  final String conversationId;
  
  const ConversationCreated(this.conversationId);
  
  @override
  List<Object> get props => [conversationId];
}

class ConversationError extends ConversationState {
  final String message;
  
  const ConversationError(this.message);
  
  @override
  List<Object> get props => [message];
}