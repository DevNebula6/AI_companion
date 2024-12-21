
import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  
  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends ChatEvent {
  final String userId;
  final String message;
  
  const SendMessageEvent({
    required this.userId,
    required this.message,
  });
  
  @override
  List<Object?> get props => [userId, message];
}

class LoadMessagesEvent extends ChatEvent {
  final String userId;
  final String userName;
  
  const LoadMessagesEvent({
    required this.userId,
    required this.userName,
  });
  
  @override
  List<Object?> get props => [userId, userName];
}

class DeleteMessageEvent extends ChatEvent {
  final String messageId;
  const DeleteMessageEvent(this.messageId);
  
  @override
  List<Object?> get props => [messageId];
}