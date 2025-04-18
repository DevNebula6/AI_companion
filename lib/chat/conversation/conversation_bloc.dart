import 'dart:async';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository _repository;
  StreamSubscription? _conversationSubscription;
  Timer? _refreshTimer;
  String? _currentUserId;

  ConversationBloc(this._repository) : super(ConversationInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<MarkConversationAsRead>(_onMarkAsRead);
    on<PinConversation>(_onPinConversation);
    on<DeleteConversation>(_onDeleteConversation);
    on<CreateConversation>(_onCreateConversation);
    on<ConversationsUpdated>(_onConversationsUpdated);
    on<ConversationErrorEvent>(_onConversationError);
    on<RefreshConversations>(_onRefreshConversations);
    
    // Start a background refresh timer
    _setupRefreshTimer();
  }
  
  // Setting up a periodic refresh timer
  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1), 
      (_) => _backgroundRefresh()
    );
  }
  
  // Background refresh of conversations
  Future<void> _backgroundRefresh() async {
    try {
      if (_currentUserId != null && state is ConversationLoaded) {
        // Only fetch if there's a user and we're already loaded
        final conversations = await _repository.getConversations(_currentUserId!);
        // Only update if there are differences
        if (_hasChanges(conversations, (state as ConversationLoaded).conversations)) {
          add(ConversationsUpdated(conversations));
        }
      }
    } catch (e) {
      print('Background refresh error: $e');
    }
  }
  
  // Determine if conversations list has meaningful changes
  bool _hasChanges(newConversations, oldConversations) {
    if (newConversations.length != oldConversations.length) return true;
    
    // Check for unread count or message changes
    for (var i = 0; i < newConversations.length; i++) {
      final newConv = newConversations[i];
      final oldConv = oldConversations.firstWhere(
        (c) => c.id == newConv.id, 
        orElse: () => null
      );
      
      if (oldConv == null || 
          oldConv.unreadCount != newConv.unreadCount ||
          oldConv.lastMessage != newConv.lastMessage ||
          oldConv.isPinned != newConv.isPinned) {
        return true;
      }
    }
    
    return false;
  }
  
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      _currentUserId = event.userId;
      
      // Keep current data visible while loading if possible
      if (!(state is ConversationLoaded)) {
        emit(ConversationLoading());
      }
      
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
      print('Error loading conversations: $e');
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
      
      // Update local state without full reload
      if (state is ConversationLoaded && _currentUserId != null) {
        // Refresh from server after the operation
        add(RefreshConversations(userId: _currentUserId!));
      }
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
      
      // Update optimistically then refresh
      if (state is ConversationLoaded) {
        final currentState = state as ConversationLoaded;
        final updatedConversations = currentState.conversations.map((c) {
          if (c.id == event.conversationId) {
            return c.copyWith(isPinned: event.isPinned);
          }
          return c;
        }).toList();
        
        emit(ConversationLoaded(
          conversations: updatedConversations,
          pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
          regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
        ));
        
        // Refresh from server
        if (_currentUserId != null) {
          add(RefreshConversations(userId: _currentUserId!));
        }
      }
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
        // Update optimistically first
        final updatedConversations = currentState.conversations
            .where((c) => c.id != event.conversationId)
            .toList();
            
        emit(ConversationLoaded(
          conversations: updatedConversations,
          pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
          regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
        ));
        
        // Delete from database
        await _repository.deleteConversation(
          event.conversationId,
        );
        
        // Full refresh to ensure consistency
        if (_currentUserId != null) {
          add(RefreshConversations(userId: _currentUserId!));
        }
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
      // Try to get current user ID
      String? userId;
      
      if (_currentUserId != null) {
        userId = _currentUserId;
      } else {
        final user = await CustomAuthUser.getCurrentUser();
        if (user != null) {
          userId = user.id;
          _currentUserId = userId;
        } else {
          throw Exception('User not authenticated');
        }
      }
      
      if (userId != null) {
        final conversationId = await _repository.getOrCreateConversation(
          userId,
          event.companionId
        );
        
        emit(ConversationCreated(conversationId));
        
        // Refresh conversation list with the new conversation
        add(RefreshConversations(userId: userId));
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
    _refreshTimer?.cancel();
    return super.close();
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event, 
    Emitter<ConversationState> emit
  ) async {
    try {
      // Keep current data visible while refreshing
      final oldState = state;
      if (!(state is ConversationLoaded)) {
        emit(ConversationLoading());
      }
      
      // Get conversations directly
      final conversations = await _repository.getConversations(event.userId);
      
      // Update state
      emit(ConversationLoaded(
        conversations: conversations,
        pinnedConversations: conversations.where((c) => c.isPinned).toList(),
        regularConversations: conversations.where((c) => !c.isPinned).toList(),
      ));
    } catch (e) {
      // On error, keep old state if possible
      if (state is ConversationLoaded) {
        // Do nothing, keep current state
      } else {
        emit(ConversationError('Failed to refresh conversations: $e'));
      }
    }
  }
}

extension ConversationBlocExtension on ConversationBloc {
  getRepository() => _repository;
}