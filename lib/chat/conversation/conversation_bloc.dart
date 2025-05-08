import 'dart:async';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository _repository;
  final ChatCacheService _cacheService;
  StreamSubscription? _conversationSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _refreshTimer;
  String? _currentUserId;
  bool _isOnline = true;

  ConversationBloc(this._repository, this._cacheService) : super(ConversationInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<MarkConversationAsRead>(_onMarkAsRead);
    on<PinConversation>(_onPinConversation);
    on<DeleteConversation>(_onDeleteConversation);
    on<CreateConversation>(_onCreateConversation);
    on<ConversationsUpdated>(_onConversationsUpdated);
    on<ConversationErrorEvent>(_onConversationError);
    on<RefreshConversations>(_onRefreshConversations);
    on<UpdateConversationMetadata>(_onUpdateMetadata);
    on<ConnectivityChangedEvent>(_onConnectivityChanged);
    on<ClearAllCacheForUser>(_onClearAllCacheForUser);
    // Monitor connectivity changes
    _setupConnectivityListener();
  }
  
  void _setupConnectivityListener() {
    try {
      // Safe connectivity initialization
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        final isOnline = result != ConnectivityResult.none;
        if (isOnline != _isOnline) {
          _isOnline = isOnline;
          add(ConnectivityChangedEvent(isOnline));
          
          // If we're coming back online, sync data
          if (isOnline && _currentUserId != null) {
            add(RefreshConversations(userId: _currentUserId!));
          }
        }
      }, onError: (e) {
        print('Connectivity stream error: $e');
        // Assume online if connectivity check fails
        if (!_isOnline) {
          _isOnline = true;
          add(ConnectivityChangedEvent(true));
        }
      });
      
      // Check initial connectivity safely
      Connectivity().checkConnectivity().then((result) {
        _isOnline = result != ConnectivityResult.none;
      }).catchError((e) {
        print('Initial connectivity check failed: $e');
        // Assume online if connectivity check fails
        _isOnline = true;
      });
    } catch (e) {
      print('Failed to setup connectivity listener: $e');
      // Assume online if setup fails
      _isOnline = true;
    }
  }
  
  Future<void> _onConnectivityChanged(
    ConnectivityChangedEvent event,
    Emitter<ConversationState> emit,
  ) async {
    // No need to emit a new state, just update internal flag
    // This event is primarily to trigger syncing when connectivity is restored
    _isOnline = event.isOnline;
    print('Connectivity changed, online: $_isOnline');
  }
  
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      _currentUserId = event.userId;
      
      // Check for cached data first
      final hasCachedData = _cacheService.hasCachedConversations(event.userId);
      
      // Initially load from cache if available
      if (hasCachedData) {
        final cachedConversations = _cacheService.getCachedConversations(event.userId);
        if (cachedConversations.isNotEmpty) {
          emit(ConversationLoaded(
            conversations: cachedConversations,
            pinnedConversations: cachedConversations.where((c) => c.isPinned).toList(),
            regularConversations: cachedConversations.where((c) => !c.isPinned).toList(),
            isFromCache: true,
          ));
        }
      } else if (state is! ConversationLoaded) {
        // Only show loading if we don't have any data
        emit(ConversationLoading());
      }
      
      // If we're offline and have cached data, don't try to fetch from network
      if (!_isOnline && hasCachedData) {
        print('Using cached conversations while offline');
        return;
      }
      
      // Load from network
      final conversations = await _repository.getConversations(event.userId);
      
      // Cache the conversations
      await _cacheService.cacheConversations(event.userId, conversations);
      
      // Update state
      emit(ConversationLoaded(
        conversations: conversations,
        pinnedConversations: conversations.where((c) => c.isPinned).toList(),
        regularConversations: conversations.where((c) => !c.isPinned).toList(),
        isFromCache: false,
      ));
    } catch (e) {
      print('Error loading conversations: $e');
      
      // If we have cached data, use that on error
      if (_cacheService.hasCachedConversations(event.userId)) {
        final cachedConversations = _cacheService.getCachedConversations(event.userId);
        emit(ConversationLoaded(
          conversations: cachedConversations,
          pinnedConversations: cachedConversations.where((c) => c.isPinned).toList(),
          regularConversations: cachedConversations.where((c) => !c.isPinned).toList(),
          isFromCache: true,
          hasError: true,
        ));
      } else {
        emit(ConversationError('Failed to load conversations: $e'));
      }
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
      // Apply change to local state first for immediate UI update
      if (state is ConversationLoaded) {
        final currentState = state as ConversationLoaded;
        final updatedConversations = currentState.conversations.map((c) {
          if (c.id == event.conversationId) {
            return c.copyWith(unreadCount: 0);
          }
          return c;
        }).toList();
        
        // Emit optimistic update
        emit(ConversationLoaded(
          conversations: updatedConversations,
          pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
          regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
          isFromCache: currentState.isFromCache,
        ));
        
        // Also update the cache
        if (_currentUserId != null) {
          // Find conversation safely without using orElse: () => null
          final matchingConversations = updatedConversations
              .where((c) => c.id == event.conversationId)
              .toList();
              
          if (matchingConversations.isNotEmpty) {
            await _cacheService.updateCachedConversation(
              _currentUserId!, 
              matchingConversations.first
            );
          }
        }
      }
      
      // Update the database if online
      if (_isOnline) {
        await _repository.markConversationAsRead(event.conversationId);
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
      // Don't emit error state to prevent UI disruption
    }
  }
  
  Future<void> _onPinConversation(
    PinConversation event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Update optimistically first
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
          isFromCache: currentState.isFromCache,
        ));
        
        // Also update the cache
        if (_currentUserId != null) {
          // Find conversation safely without using orElse: () => null
          final matchingConversations = updatedConversations
              .where((c) => c.id == event.conversationId)
              .toList();
              
          if (matchingConversations.isNotEmpty) {
            await _cacheService.updateCachedConversation(
              _currentUserId!, 
              matchingConversations.first
            );
          }
        }
      }
      
      // Update the database if online
      if (_isOnline) {
        await _repository.togglePinConversation(
          event.conversationId, 
          event.isPinned
        );
      }
    } catch (e) {
      print('Error updating pin status: $e');
      // Don't emit error state to prevent UI disruption
    }
  }
  
  Future<void> _onDeleteConversation(
    DeleteConversation event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Find the conversation to be deleted
      String? companionId;
      if (state is ConversationLoaded) {
        final currentState = state as ConversationLoaded;
        
        // Get the companion ID before removing the conversation
        final matchingConversations = currentState.conversations
            .where((c) => c.id == event.conversationId)
            .toList();
            
        if (matchingConversations.isNotEmpty) {
          companionId = matchingConversations.first.companionId;
        }
        
        // Update UI immediately
        final updatedConversations = currentState.conversations
            .where((c) => c.id != event.conversationId)
            .toList();
            
        emit(ConversationLoaded(
          conversations: updatedConversations,
          pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
          regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
          isFromCache: currentState.isFromCache,
        ));
        
        // Update local cache
        if (_currentUserId != null) {
          await _cacheService.removeCachedConversation(_currentUserId!, event.conversationId);
        }
      }
      
      // If we have internet, delete from the server
      if (_isOnline) {
        // Delete from database
        await _repository.deleteConversation(event.conversationId);
        
        // Delete messages from cache if we have the companion ID
        if (companionId != null && _currentUserId != null) {
          await _repository.clearMessageCache(
            userId: _currentUserId!,
            companionId: companionId
          );
        }
      }
    } catch (e) {
      print('Error in _onDeleteConversation: $e');
      // Don't emit error to avoid UI disruption
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
  
  Future<void> _onUpdateMetadata(
    UpdateConversationMetadata event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Build updates map
      final updates = <String, dynamic>{};
      if (event.lastMessage != null) {
        updates['last_message'] = event.lastMessage;
      }
      if (event.lastUpdated != null) {
        updates['last_updated'] = event.lastUpdated!.toIso8601String();
      }
      if (event.unreadCount != null) {
        updates['unread_count'] = event.unreadCount;
      }
      
      // Only proceed if we have updates to make
      if (updates.isEmpty) return;
      
      // Update local state first
      if (state is ConversationLoaded && _currentUserId != null) {
        final currentState = state as ConversationLoaded;
        // Find conversation safely without using orElse: () => null
        final matchingConversations = currentState.conversations
            .where((c) => c.id == event.conversationId)
            .toList();
            
        if (matchingConversations.isNotEmpty) {
          final conversation = matchingConversations.first;
          
          // Create updated conversation
          final updatedConversation = conversation.copyWith(
            lastMessage: event.lastMessage ?? conversation.lastMessage,
            lastUpdated: event.lastUpdated ?? conversation.lastUpdated,
            unreadCount: event.unreadCount ?? conversation.unreadCount,
          );
          
          // Update in memory state
          final updatedConversations = currentState.conversations.map((c) {
            if (c.id == event.conversationId) {
              return updatedConversation;
            }
            return c;
          }).toList();
          
          // Sort by last updated
          updatedConversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          
          // Update UI
          emit(ConversationLoaded(
            conversations: updatedConversations,
            pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
            regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
            isFromCache: currentState.isFromCache,
          ));
          
          // Update cache
          await _cacheService.updateCachedConversation(_currentUserId!, updatedConversation);
        }
      }
      
      // Update the database if online
      if (_isOnline) {
        await _repository.updateConversationMetadata(
          event.conversationId,
          updates: updates,
        );
      }
    } catch (e) {
      print('Error updating conversation metadata: $e');
      // Don't emit error state to prevent UI disruption
    }
  }
  
  @override
  Future<void> close() {
    _conversationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _refreshTimer?.cancel();
    return super.close();
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event, 
    Emitter<ConversationState> emit
  ) async {
    // Skip if offline
    if (!_isOnline) {
      print('Skipping refresh while offline');
      return;
    }
    
    try {
      // Get conversations from network
      final conversations = await _repository.getConversations(event.userId);
      
      // Cache the refreshed data
      await _cacheService.cacheConversations(event.userId, conversations);
      
      // Update state
      emit(ConversationLoaded(
        conversations: conversations,
        pinnedConversations: conversations.where((c) => c.isPinned).toList(),
        regularConversations: conversations.where((c) => !c.isPinned).toList(),
        isFromCache: false,
      ));
    } catch (e) {
      print('Error refreshing conversations: $e');
      // On error, keep current state if possible
    }
  }

  FutureOr<void> _onClearAllCacheForUser(
    ClearAllCacheForUser event, 
    Emitter<ConversationState> emit
    ) {
      if (_currentUserId != null) {
        // Clear all cached conversations for the user
        _cacheService.clearConversationsCache(_currentUserId!);
        // Emit a state to indicate that the cache has been cleared
        // emit(ConversationLoading());
      }
  }
}

extension ConversationBlocExtension on ConversationBloc {
  getRepository() => _repository;
}