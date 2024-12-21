import 'package:equatable/equatable.dart';
import '../message.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}
class ChatError extends ChatState {
  const ChatError();
}


class ChatLoaded extends ChatState {
  final Stream<List<Message>> messageStream;
  final List<Message> currentMessages;
  
  const ChatLoaded({
    required this.messageStream,
    required this.currentMessages,
  });
  
  @override
  List<Object?> get props => [messageStream, currentMessages];
}

class MessageSent extends ChatState {}
class MessageReceiving extends ChatState {
  final String message;
  const MessageReceiving(this.message);
  
  @override
  List<Object?> get props => [message];
}