import 'dart:async';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation.dart' show Conversation;
import 'package:ai_companion/chat/gemini/gemini_service.dart' show GeminiService;
import 'package:ai_companion/services/connectivity_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository _repository;
  final ChatCacheService _cacheService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  StreamSubscription? _conversationSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _refreshTimer;
  String? _currentUserId;
  bool _isOnline = true;

  // Debouncing and deduplication
  Timer? _networkSyncDebouncer;
  Timer? _metadataUpdateDebouncer;
  bool _isNetworkSyncInProgress = false;
  bool _hasLoadedConversations = false;
  String? _lastLoadedUserId;
  DateTime? _lastNetworkSync;
  static const Duration _networkSyncCooldown = Duration(seconds: 2);
  static const Duration _debounceDelay = Duration(milliseconds: 500);

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
    
    // Use centralized connectivity service
    _setupConnectivityListener();
  }
  
  void _setupConnectivityListener() {
    try {
      // Get initial status
      _isOnline = _connectivityService.isOnline;
      
      // Listen to connectivity changes from centralized service
      _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
        if (isOnline != _isOnline) {
          _isOnline = isOnline;
          add(ConnectivityChangedEvent(isOnline));
          
          // If we're coming back online, debounce the sync
          if (isOnline && _currentUserId != null) {
            _debouncedNetworkSync(_currentUserId!);
          }
        }
      }, onError: (e) {
        print('Connectivity stream error in ConversationBloc: $e');
      });
      
    } catch (e) {
      print('Failed to setup connectivity listener in ConversationBloc: $e');
      _isOnline = true;
    }
  }

  // Debounced network sync to prevent rapid consecutive calls
  void _debouncedNetworkSync(String userId) {
    _networkSyncDebouncer?.cancel();
    _networkSyncDebouncer = Timer(_debounceDelay, () {
      if (!_isNetworkSyncInProgress && _connectivityService.isOnline) {
        // Check cooldown period
        if (_lastNetworkSync != null && 
            DateTime.now().difference(_lastNetworkSync!) < _networkSyncCooldown) {
          print('Network sync skipped due to cooldown period');
          return;
        }
        
        add(RefreshConversations(userId: userId));
      }
    });
  }

  // Debounced metadata updates to batch rapid changes
  void _debouncedMetadataUpdate(String conversationId, Map<String, dynamic> updates) {
    _metadataUpdateDebouncer?.cancel();
    _metadataUpdateDebouncer = Timer(_debounceDelay, () {
      if (_connectivityService.isOnline) {
        _repository.updateConversationMetadata(conversationId, updates: updates);
      }
    });
  }
  
  Future<void> _onConnectivityChanged(
    ConnectivityChangedEvent event,
    Emitter<ConversationState> emit,
  ) async {
    _isOnline = event.isOnline;
    print('ConversationBloc connectivity changed, online: $_isOnline');
  }
  
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Prevent duplicate loads for same user
      if (_hasLoadedConversations && 
          _lastLoadedUserId == event.userId && 
          state is ConversationLoaded) {
        print('Conversations already loaded for user ${event.userId}, skipping duplicate load');
        return;
      }

      _currentUserId = event.userId;
      _lastLoadedUserId = event.userId;
      
      // DEBUG: Check what's in cache first
      _cacheService.debugCacheContents(event.userId);
      
      // Always try to load from cache first for immediate response
      final cachedConversations = _cacheService.getCachedConversations(event.userId);
      
      if (cachedConversations.isNotEmpty) {
        print('Loading ${cachedConversations.length} cached conversations for user ${event.userId}');
        // Enrich cached conversations with companion names if missing
        final enrichedConversations = await _enrichConversationsWithCompanionNames(cachedConversations);
        
        emit(ConversationLoaded(
          conversations: enrichedConversations,
          pinnedConversations: enrichedConversations.where((c) => c.isPinned).toList(),
          regularConversations: enrichedConversations.where((c) => !c.isPinned).toList(),
          isFromCache: true,
        ));
        
        _hasLoadedConversations = true;
      } else if (state is! ConversationLoaded) {
        print('No cached conversations found, emitting loading state');
        emit(ConversationLoading());
      }
      
      // Check connectivity using centralized service
      if (!_connectivityService.isOnline) {
        print('App is offline. Using cached conversations only.');
        if (cachedConversations.isEmpty) {
          emit(ConversationLoaded(
            conversations: [],
            pinnedConversations: [],
            regularConversations: [],
            isFromCache: true,
            hasError: false,
          ));
        }
        return;
      }
      
      // Prevent duplicate network calls
      if (_isNetworkSyncInProgress) {
        print('Network sync already in progress, skipping duplicate call');
        return;
      }
      
      _isNetworkSyncInProgress = true;
      
      // If we're online, try to sync with server
      try {
        print('App is online. Syncing conversations with server...');
        final conversations = await _repository.getConversations(event.userId);
        
        // Only update if data has changed
        if (!_conversationsEqual(conversations, cachedConversations)) {
          // Enrich conversations with companion names
          final enrichedConversations = await _enrichConversationsWithCompanionNames(conversations);
          
          // Cache the fresh conversations with companion names
          await _cacheService.cacheConversations(event.userId, enrichedConversations);
          
          // Update state with fresh data
          emit(ConversationLoaded(
            conversations: enrichedConversations,
            pinnedConversations: enrichedConversations.where((c) => c.isPinned).toList(),
            regularConversations: enrichedConversations.where((c) => !c.isPinned).toList(),
            isFromCache: false,
          ));
          
          print('Updated conversations: ${enrichedConversations.length} conversations loaded');
        } else {
          print('No changes in conversations, but ensuring final state is emitted');
          
          // This handles the case where cache and server both return empty lists
          final enrichedConversations = await _enrichConversationsWithCompanionNames(conversations);
          
          emit(ConversationLoaded(
            conversations: enrichedConversations,
            pinnedConversations: enrichedConversations.where((c) => c.isPinned).toList(),
            regularConversations: enrichedConversations.where((c) => !c.isPinned).toList(),
            isFromCache: false,
          ));
          
          print('Emitted final state with ${enrichedConversations.length} conversations (no changes detected)');
        }
        
        _hasLoadedConversations = true;
        _lastNetworkSync = DateTime.now();
        
      } catch (e) {
        print('Error syncing conversations with server: $e');
        
        // If sync fails but we have cached data, keep using cache
        if (cachedConversations.isNotEmpty) {
          final enrichedConversations = await _enrichConversationsWithCompanionNames(cachedConversations);
          emit(ConversationLoaded(
            conversations: enrichedConversations,
            pinnedConversations: enrichedConversations.where((c) => c.isPinned).toList(),
            regularConversations: enrichedConversations.where((c) => !c.isPinned).toList(),
            isFromCache: true,
            hasError: true,
          ));
        } else {
          emit(ConversationError('Failed to load conversations: $e'));
        }
      } finally {
        _isNetworkSyncInProgress = false;
      }
    } catch (e) {
      _isNetworkSyncInProgress = false;
      print('Error in _onLoadConversations: $e');
      emit(ConversationError('Failed to load conversations: $e'));
    }
  }

  // Helper method to compare conversations for changes
  bool _conversationsEqual(List<Conversation> a, List<Conversation> b) {
    if (a.length != b.length) return false;
    
    // Create maps for efficient lookup
    final mapB = {for (var conv in b) conv.id: conv};
    
    for (final conv in a) {
      final other = mapB[conv.id];
      if (other == null || 
          conv.lastMessage != other.lastMessage ||
          conv.lastUpdated != other.lastUpdated ||
          conv.unreadCount != other.unreadCount ||
          conv.isPinned != other.isPinned) {
        return false;
      }
    }
    return true;
  }
  
  // Helper method to enrich conversations with companion names
  Future<List<Conversation>> _enrichConversationsWithCompanionNames(List<Conversation> conversations) async {
    final enrichedConversations = <Conversation>[];
    
    for (final conversation in conversations) {
      if (conversation.companionName == null || conversation.companionName!.isEmpty) {
        // Try to get companion data to populate the name
        try {
          final companion = await _repository.getCompanion(conversation.companionId);
          if (companion != null) {
            enrichedConversations.add(conversation.copyWith(companionName: companion.name));
          } else {
            enrichedConversations.add(conversation);
          }
        } catch (e) {
          print('Error getting companion ${conversation.companionId}: $e');
          enrichedConversations.add(conversation);
        }
      } else {
        enrichedConversations.add(conversation);
      }
    }
    
    return enrichedConversations;
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
      
      // Debounce database update
      if (_connectivityService.isOnline) {
        _debouncedMetadataUpdate(event.conversationId, {'unread_count': 0});
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
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
      
      // Debounce database update
      if (_connectivityService.isOnline) {
        _debouncedMetadataUpdate(event.conversationId, {'is_pinned': event.isPinned});
      }
    } catch (e) {
      print('Error updating pin status: $e');
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
      
      // If we have internet, delete from the server (no debouncing for delete operations)
      if (_connectivityService.isOnline) {
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
        
        // Immediately cache the new conversation
        try {
          final companion = await _repository.getCompanion(event.companionId);
          if (companion != null) {
            final newConversation = Conversation(
              id: conversationId,
              userId: userId,
              companionId: event.companionId,
              companionName: companion.name,
              lastMessage: 'Start a conversation',
              unreadCount: 0,
              lastUpdated: DateTime.now(),
              isPinned: false,
              metadata: {'relationship_level': 1},
            );
            
            // Add to cache immediately
            await _cacheService.updateCachedConversation(userId, newConversation);
            
            // Update local state
            if (state is ConversationLoaded) {
              final currentState = state as ConversationLoaded;
              final updatedConversations = [newConversation, ...currentState.conversations];
              
              emit(ConversationLoaded(
                conversations: updatedConversations,
                pinnedConversations: updatedConversations.where((c) => c.isPinned).toList(),
                regularConversations: updatedConversations.where((c) => !c.isPinned).toList(),
                isFromCache: currentState.isFromCache,
              ));
            }
          }
        } catch (e) {
          print('Error caching new conversation: $e');
        }
        
        // Debounce the refresh to avoid immediate network call
        _debouncedNetworkSync(userId);
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
        if (event.markAsRead){
          updates['unread_count'] = 0;
        } else {
          updates['unread_count'] = event.unreadCount;
        }
      }
      if (event.markAsRead){
          updates['unread_count'] = 0;
        }
      
      // Only proceed if we have updates to make
      if (updates.isEmpty) return;
      
      // Update local state first
      if (state is ConversationLoaded && _currentUserId != null) {
        final currentState = state as ConversationLoaded;
        final matchingConversations = currentState.conversations
            .where((c) => c.id == event.conversationId)
            .toList();
            
        if (matchingConversations.isNotEmpty) {
          final conversation = matchingConversations.first;
          
          // Create updated conversation
          final updatedConversation = conversation.copyWith(
            lastMessage: event.lastMessage ?? conversation.lastMessage,
            lastUpdated: event.lastUpdated ?? conversation.lastUpdated,
            unreadCount: event.markAsRead ? 0 : (event.unreadCount ?? conversation.unreadCount),
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
          
          // Always update cache immediately
          await _cacheService.updateCachedConversation(_currentUserId!, updatedConversation);
        }
      }
      
      // Debounce database update
      if (_connectivityService.isOnline) {
        _debouncedMetadataUpdate(event.conversationId, updates);
      }
    } catch (e) {
      print('Error updating conversation metadata: $e');
    }
  }

  Future<void> _onRefreshConversations(
    RefreshConversations event, 
    Emitter<ConversationState> emit
  ) async {
    // Skip if offline or already syncing
    if (!_connectivityService.isOnline || _isNetworkSyncInProgress) {
      print('Skipping refresh - offline: ${!_connectivityService.isOnline}, syncing: $_isNetworkSyncInProgress');
      return;
    }
    
    _isNetworkSyncInProgress = true;
    
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
      
      _lastNetworkSync = DateTime.now();
    } catch (e) {
      print('Error refreshing conversations: $e');
    } finally {
      _isNetworkSyncInProgress = false;
    }
  }

  Future<void> _onClearAllCacheForUser(
    ClearAllCacheForUser event, 
    Emitter<ConversationState> emit
  ) async {
    try {
      // Use provided userId or fall back to current userId
      final userIdToClear = event.userId ?? _currentUserId;
      
      if (userIdToClear != null) {
        print('Clearing all caches for user: $userIdToClear');
        
        // Clear companion states from GeminiService
        await GeminiService().clearAllUserStates(userIdToClear);
        
        // Clear any chat repository caches
        await _repository.clearAllUserCaches(userIdToClear);
      
        // Reset current state only if we're clearing the current user
        if (userIdToClear == _currentUserId) {
          _currentUserId = null;
          _lastLoadedUserId = null;
          _hasLoadedConversations = false;
          _isNetworkSyncInProgress = false;
          _lastNetworkSync = null;
          
          // Cancel any pending timers
          _networkSyncDebouncer?.cancel();
          _metadataUpdateDebouncer?.cancel();
        }
        
        // Emit initial state
        emit(ConversationInitial());
        
        print('✅ Successfully cleared all caches for user: $userIdToClear');
      } else {
        print('❌ Cannot clear caches: no userId provided and no current user');
      }
    } catch (e) {
      print('Error clearing all cache for user: $e');
    }
  }

  @override
  Future<void> close() {
    _conversationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _refreshTimer?.cancel();
    _networkSyncDebouncer?.cancel();
    _metadataUpdateDebouncer?.cancel();
    return super.close();
  }
}

extension ConversationBlocExtension on ConversationBloc {
  getRepository() => _repository;
}