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
  const MessageError();
}


class MessageLoaded extends MessageState {
  final Stream<List<Message>> messageStream;
  final List<Message> currentMessages;
  
  const MessageLoaded({
    required this.messageStream,
    required this.currentMessages,
  });
  
  @override
  List<Object?> get props => [messageStream, currentMessages];
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
