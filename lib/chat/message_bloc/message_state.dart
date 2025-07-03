import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/message.dart';
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
