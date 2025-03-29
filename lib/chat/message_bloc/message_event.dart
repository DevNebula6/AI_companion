
import 'package:equatable/equatable.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();
  
  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends MessageEvent {
  final String userId;
  final String message;
  
  const SendMessageEvent({
    required this.userId,
    required this.message,
  });
  
  @override
  List<Object?> get props => [userId, message];
}

class LoadMessagesEvent extends MessageEvent {
  final String userId;
  final String userName;
  
  const LoadMessagesEvent({
    required this.userId,
    required this.userName,
  });
  
  @override
  List<Object?> get props => [userId, userName];
}

class DeleteMessageEvent extends MessageEvent {
  final String messageId;
  const DeleteMessageEvent(this.messageId);
  
  @override
  List<Object?> get props => [messageId];
}