import 'dart:async';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
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
    on<ConversationsUpdated>(_onConversationsUpdated);
    on<ConversationErrorEvent>(_onConversationError);
    on<RefreshConversations>(_onRefreshConversations);
  }
  
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      emit(ConversationLoading());
      
      await _conversationSubscription?.cancel();
      
      // Get conversations directly
      final conversations = await _repository.getConversations(event.userId);
      
      // Update state
      emit(ConversationLoaded(
        conversations: conversations,
        pinnedConversations: conversations.where((c) => c.isPinned).toList(),
        regularConversations: conversations.where((c) => !c.isPinned).toList(),
      ));
    } catch (e) {
      emit(ConversationError('Failed to load conversations: $e'));
    }
  }
  
  Future<void> _onConversationsUpdated(
    ConversationsUpdated event,
    Emitter<ConversationState> emit,
  ) async {
    emit(ConversationLoaded(
      conversations: event.conversations,
      pinnedConversations: event.conversations.where((c) => c.isPinned).toList(),
      regularConversations: event.conversations.where((c) => !c.isPinned).toList(),
    ));
  }

  Future<void> _onConversationError(
    ConversationErrorEvent event,
    Emitter<ConversationState> emit,
  ) async {
    emit(ConversationError(event.message));
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
    try {
      final currentState = state;
      if (currentState is ConversationLoaded) {
        emit(ConversationLoading());
        
        // Delete the conversation from the repository
        await _repository.deleteConversation(
          event.conversationId,
        );
        // Update the UI state
        final updatedConversations = currentState.conversations
            .where((c) => c.id != event.conversationId)
            .toList();
            
        emit(ConversationLoaded(
          conversations: updatedConversations,
          pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
          regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
        ));
      }
    } catch (e) {
      print('Error in _onDeleteConversation: $e');
      emit(ConversationError('Failed to delete conversation: $e'));
    }
  }
  
  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Get current user ID from auth
      final currentUser = SupabaseClientManager().client.auth.currentUser;
      
      if (currentUser != null) {
        final userId = currentUser.id;
        
        final conversationId = await _repository.getOrCreateConversation(
          userId,
          event.companionId
        );
        
        emit(ConversationCreated(conversationId));
      } else {
        emit(ConversationError('User not authenticated'));
      }
    } catch (e) {
      emit(ConversationError('Failed to create conversation: $e'));
    }
  }
  
  @override
  Future<void> close() {
    _conversationSubscription?.cancel();
    return super.close();
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event, 
    Emitter<ConversationState> emit) async {
    try {
      emit(ConversationLoading());
      
      // Get conversations directly
      final conversations = await _repository.getConversations(event.userId);
      
      // Update state
      emit(ConversationLoaded(
        conversations: conversations,
        pinnedConversations: conversations.where((c) => c.isPinned).toList(),
        regularConversations: conversations.where((c) => !c.isPinned).toList(),
      ));
    } catch (e) {
      emit(ConversationError('Failed to refresh conversations: $e'));
    }
  }
}
extension ConversationBlocExtension on ConversationBloc {
  getRepository() => _repository;
}