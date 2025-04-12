import 'package:ai_companion/Companion/ai_model.dart';
import 'package:equatable/equatable.dart';
import '../message.dart';

abstract class MessageState extends Equatable {
  const MessageState();
  
  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}
class MessageLoading extends MessageState {}
class MessageError extends MessageState {
  final Exception error;  
  const MessageError({required this.error});
}


class MessageLoaded extends MessageState {
  final List<Message> messages;
  
  const MessageLoaded({
    required this.messages,
  });
  
  @override
  List<Object?> get props => [ messages];
}
class CompanionInitialized extends MessageState {
  final AICompanion companion;
  
  const CompanionInitialized(this.companion);
  
  @override
  List<Object?> get props => [companion];
}
class MessageSent extends MessageState {}
class MessageReceiving extends MessageState {
  final String message;
  const MessageReceiving(this.message);
  
  @override
  List<Object?> get props => [message];
}

class LoadingMoreMessages extends MessageState {
  final List<Message> currentMessages;
  
  const LoadingMoreMessages(this.currentMessages);
  
  @override
  List<Object?> get props => [currentMessages];
}
