import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository _repository;
  StreamSubscription? _conversationSubscription;
  
  ConversationBloc(this._repository) : super(ConversationInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<MarkConversationAsRead>(_onMarkAsRead);
    on<PinConversation>(_onPinConversation);
    on<DeleteConversation>(_onDeleteConversation);
    on<CreateConversation>(_onCreateConversation);
    on<_ConversationsUpdated>(_onConversationsUpdated);
  }
  
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      emit(ConversationLoading());
      
      await _conversationSubscription?.cancel();
      
      _conversationSubscription = _repository
        .watchConversations()
        .listen(
          (conversations) {
            if (!isClosed) {
              add(_ConversationsUpdated(conversations));
            }
          },
          onError: (error) {
            if (!isClosed) {
              add(ConversationError('Failed to load conversations: $error'));
            }
          }
        );
    } catch (e) {
      emit(ConversationError('Failed to load conversations: $e'));
    }
  }
  
  Future<void> _onConversationsUpdated(
    _ConversationsUpdated event,
    Emitter<ConversationState> emit,
  ) async {
    emit(ConversationLoaded(
      conversations: event.conversations,
      pinnedConversations: event.conversations.where((c) => c.isPinned).toList(),
      regularConversations: event.conversations.where((c) => !c.isPinned).toList(),
    ));
  }
  
  Future<void> _onMarkAsRead(
    MarkConversationAsRead event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      await _repository.markConversationAsRead(event.conversationId);
    } catch (e) {
      emit(ConversationError('Failed to mark conversation as read: $e'));
    }
  }
  
  Future<void> _onPinConversation(
    PinConversation event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      await _repository.togglePinConversation(
        event.conversationId, 
        event.isPinned
      );
    } catch (e) {
      emit(ConversationError('Failed to update pin status: $e'));
    }
  }
  
  Future<void> _onDeleteConversation(
    DeleteConversation event,
    Emitter<ConversationState> emit,
  ) async {
    // Implement deletion logic
  }
  
  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      final conversationId = await _repository.createConversation(
        event.companionId
      );
      emit(ConversationCreated(conversationId));
    } catch (e) {
      emit(ConversationError('Failed to create conversation: $e'));
    }
  }
  
  @override
  Future<void> close() {
    _conversationSubscription?.cancel();
    return super.close();
  }
}