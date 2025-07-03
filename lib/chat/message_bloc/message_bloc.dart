import 'dart:async';
import 'dart:convert';
import 'package:ai_companion/services/connectivity_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../msg_fragmentation/message_fragmentation.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final ChatRepository _repository;
  final GeminiService _geminiService = GeminiService();
  final ChatCacheService _cacheService;
  final ConnectivityService _connectivityService = ConnectivityService();

  String? _currentUserId;
  String? _currentCompanionId;
  Timer? _syncTimer;
  List<Message> _currentMessages = [];
  
  // Fragmentation support
  Timer? _fragmentTimer;
  StreamController<String>? _fragmentController;

  // Offline support
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  final List<Message> _pendingMessages = [];
  final String _pendingMessagesKey = 'pending_messages';

  // Add a BehaviorSubject for typing indicators
  final BehaviorSubject<bool> _typingSubject = BehaviorSubject.seeded(false);
  Stream<bool> get typingStream => _typingSubject.stream;

  MessageBloc(this._repository, this._cacheService)
      : super(MessageInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<ClearConversation>(_onClearConversation);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<RetryChatRequest>(_onRetryChatRequest);
    on<InitializeCompanionEvent>(_onInitializeCompanion);
    on<RefreshMessages>(_onRefreshMessages);
    on<ConnectivityChangedEvent>(_onConnectivityChanged);
    on<ProcessPendingMessagesEvent>(_onProcessPendingMessages);
    on<FragmentedMessageReceivedEvent>(_onFragmentedMessageReceived);
    on<CompleteFragmentedMessageEvent>(_onCompleteFragmentedMessage);
    on<AddFragmentMessageEvent>(_onAddFragmentMessage);
    on<NotifyFragmentationCompleteEvent>(_onNotifyFragmentationComplete);
    
    _setupPeriodicSync();
    _setupConnectivityListener();
    _loadPendingMessages();
  }

  List<Message> get currentMessages => List<Message>.from(_currentMessages);

  // Setup connectivity monitoring using centralized service
  void _setupConnectivityListener() {
    try {
      // Get initial status
      _isOnline = _connectivityService.isOnline;
      
      // Listen to connectivity changes from centralized service
      _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
        if (isOnline != _isOnline) {
          _isOnline = isOnline;
          add(ConnectivityChangedEvent(isOnline));
          
          // Process any pending messages when coming back online
          if (isOnline && _pendingMessages.isNotEmpty) {
            add(ProcessPendingMessagesEvent());
          }
        }
      }, onError: (e) {
        print('Connectivity stream error in MessageBloc: $e');
      });
      
    } catch (e) {
      print('Failed to setup connectivity listener in MessageBloc: $e');
      _isOnline = true;
    }
  }

  // Handle connectivity changes
  Future<void> _onConnectivityChanged(
    ConnectivityChangedEvent event,
    Emitter<MessageState> emit,
  ) async {
    _isOnline = event.isOnline;
    print('MessageBloc connectivity changed, online: $_isOnline');
    
    // Process pending messages when back online
    if (_isOnline && _pendingMessages.isNotEmpty) {
      add(ProcessPendingMessagesEvent());
    }
  }

  // Process messages that were sent while offline
  Future<void> _onProcessPendingMessages(
    ProcessPendingMessagesEvent event,
    Emitter<MessageState> emit,
  ) async {
    if (_pendingMessages.isEmpty || !_isOnline) return;
    
    print('Processing ${_pendingMessages.length} pending messages');
    
    // Process one message at a time to maintain order
    for (int i = 0; i < _pendingMessages.length; i++) {
      try {
        final pendingMessage = _pendingMessages[i];
        
        // Skip messages that are already in the database
        if (!isLocalId(pendingMessage.id!)) continue;
        
        // Send the message to the database
        await _repository.sendMessage(pendingMessage);
        
        // If it's a user message, generate AI response
        if (!pendingMessage.isBot) {
          await _processAIResponse(pendingMessage, emit);
        }
        
        // Update conversation
        await _repository.updateConversation(
          pendingMessage.conversationId,
          lastMessage: pendingMessage.message,
          incrementUnread: pendingMessage.isBot ? 1 : 0,
        );
        
      } catch (e) {
        print('Error processing pending message: $e');
        // Continue with other messages even if one fails
      }
    }
    
    // Clear pending messages after processing
    _pendingMessages.clear();
    await _savePendingMessages();
    
    // Refresh messages from server now that we're online
    if (_currentUserId != null && _currentCompanionId != null) {
      add(RefreshMessages());
    }
  }

  // Load pending messages from SharedPreferences
  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = prefs.getStringList(_pendingMessagesKey) ?? [];
      
      _pendingMessages.clear();
      for (final json in pendingMessagesJson) {
        try {
          final Map<String, dynamic> messageData = jsonDecode(json);
          final message = Message.fromJson(messageData);
          _pendingMessages.add(message);
        } catch (e) {
          print('Error parsing pending message: $e');
        }
      }
      
      print('Loaded ${_pendingMessages.length} pending messages');
    } catch (e) {
      print('Error loading pending messages: $e');
    }
  }

  // Save pending messages to SharedPreferences
  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = _pendingMessages.map(
        (m) => jsonEncode(m.toJson())
      ).toList();
      
      await prefs.setStringList(_pendingMessagesKey, pendingMessagesJson);
    } catch (e) {
      print('Error saving pending messages: $e');
    }
  }

  // Add a pending message
  Future<void> _addPendingMessage(Message message) async {
    _pendingMessages.add(message);
    await _savePendingMessages();
  }

  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _backgroundSync(),
    );
  }

  Future<void> _backgroundSync() async {
    if (_currentUserId != null && _currentCompanionId != null) {
      try {
        final messages = await _repository.getMessages(_currentUserId!, _currentCompanionId!);
        // Update companion-specific cache with latest messages
        await _cacheService.cacheMessages(
          _currentUserId!,
          messages,
          companionId: _currentCompanionId!,
        );

        // Also notify conversation bloc that a sync happened
        _triggerConversationRefresh();
      } catch (e) {
        print('Background sync error: $e');
      }
    }
  }

  void _triggerConversationRefresh() {
    if (_currentUserId != null) {
      // Find ConversationBloc instance and add refresh event
      // This is handled by the UI when needed
    }
  }

  bool isLocalId(String id) {
    return id.startsWith('local_') || id.startsWith('fallback-');
  }

  Future<void> _onInitializeCompanion(
    InitializeCompanionEvent event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      _currentUserId = event.userId;
      _currentCompanionId = event.companion.id;

      // Save current state if there's an active companion
      if (_geminiService.isInitialized) {
        await _geminiService.saveState();
      }

      // Initialize the AI companion with user information
      try {
        await _geminiService.initializeCompanion(
          companion: event.companion,
          userId: event.userId,
          messageBloc: this,
          userName: event.user?.fullName,
          userProfile: event.user?.toAIFormat(),
        );

        emit(CompanionInitialized(event.companion));
      } catch (e) {
        print('Error in GeminiService.initializeCompanion: $e');
        // Even if Gemini initialization fails, we can still show the UI
        emit(CompanionInitialized(event.companion));
      }
    } catch (e) {
      print('Error initializing companion: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessageState> emit) async {
    try {
      final userMessage = event.message;

      // Update conversation identifier in GeminiService metadata
      final metrics = _geminiService.getRelationshipMetrics();
      if (!metrics.containsKey('conversation_id')) {
        _geminiService.addMemoryItem('conversation_id', userMessage.conversationId);
      }

      // 1. Optimistic update for immediate UI feedback
      final localMessage = event.message.copyWith();
      _currentMessages.add(localMessage);
      
      // Mark message as pending if offline (using centralized service)
      final isPending = !_connectivityService.isOnline;
      
      // 2. Emit state with pending indicator if offline
      emit(MessageLoaded(
        messages: _currentMessages, 
        pendingMessageIds: isPending ? [localMessage.id ?? ''] : []
      ));

      // 3. Cache current messages with companion-specific key
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      // 4. If offline, add to pending queue and return
      if (!_connectivityService.isOnline) {
        await _addPendingMessage(localMessage);
        return;
      }

      // 5. Send to database if online
      await _repository.sendMessage(userMessage);
      await _repository.updateConversation(
        userMessage.conversationId,
        lastMessage: userMessage.message,
      );

      // 6. Process AI response
      await _processAIResponse(userMessage, emit);

      // 7. Trigger conversation list refresh
      _triggerConversationRefresh();
      
    } catch (e) {
      print('Error sending message: $e');
      
      // Remove the optimistically added message if error occurs
      if (_currentMessages.isNotEmpty) {
        _currentMessages.removeLast();
        if (_currentUserId != null && _currentCompanionId != null) {
          await _cacheService.cacheMessages(
            _currentUserId!,
            _currentMessages,
            companionId: _currentCompanionId!,
          );
        }
      }

      _typingSubject.add(false);
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  // Helper method to process AI response
  Future<void> _processAIResponse(Message userMessage, Emitter<MessageState> emit) async {
    // Show typing indicator
    _typingSubject.add(true);
    emit(MessageReceiving(userMessage.message, messages: _currentMessages));

    try {
      // Generate AI response
      final String aiResponse = await _geminiService.generateResponse(
        userMessage.message,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => "I'm having trouble with my thoughts right now. Could you give me a moment?",
      );
      print('AI response generated: $aiResponse');
      // Hide typing indicator
      _typingSubject.add(false);

      // Create AI message
      final metrics = _geminiService.getRelationshipMetrics();
      final aiMessage = Message(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        message: aiResponse,
        companionId: userMessage.companionId,
        userId: userMessage.userId,
        conversationId: userMessage.conversationId,
        isBot: true,
        created_at: DateTime.now(),
        metadata: {
          'relationship_level': metrics['level'],
          'emotion': metrics['dominant_emotion'],
        },
      );

      // Check if response should be fragmented
      final fragments = MessageFragmenter.fragmentResponse(aiResponse);
      
      if (fragments.length > 1) {
        // Emit fragmented response
        add(FragmentedMessageReceivedEvent(fragments, aiMessage));
      } else {
        // Single message - process normally
        await _processSingleMessage(aiMessage, userMessage, emit);
      }
    } catch (e) {
      print('Error generating AI response: $e');
      _typingSubject.add(false);
      
      // Create error message from AI
      final errorMessage = Message(
        id: 'local_error_${DateTime.now().millisecondsSinceEpoch}',
        message: "I'm having trouble responding right now. Please try again later.",
        companionId: userMessage.companionId,
        userId: userMessage.userId,
        conversationId: userMessage.conversationId,
        isBot: true,
        created_at: DateTime.now(),
        metadata: {'error': true},
      );
      
      _currentMessages.add(errorMessage);
      emit(MessageLoaded(
        messages: _currentMessages,
        hasError: true
      ));
      
      // Cache error message
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }
    }
  }

  // Handle fragmented message display
  Future<void> _onFragmentedMessageReceived(
    FragmentedMessageReceivedEvent event,
    Emitter<MessageState> emit,
  ) async {
    emit(MessageFragmenting(
      fragments: event.fragments,
      currentFragmentIndex: 0,
      messages: _currentMessages,
      originalMessage: event.originalMessage,
    ));
  }

  // Process single message (extracted for reuse)
  Future<void> _processSingleMessage(Message aiMessage, Message userMessage, Emitter<MessageState> emit) async {
    _currentMessages.add(aiMessage);
    
    if (_currentUserId != null && _currentCompanionId != null) {
      await _cacheService.cacheMessages(
        _currentUserId!,
        _currentMessages,
        companionId: _currentCompanionId!,
      );
    }

    emit(MessageLoaded(messages: _currentMessages));
    emit(MessageSent());

    if (_isOnline) {
      await _repository.sendMessage(aiMessage);
      await _repository.updateConversation(
        userMessage.conversationId,
        lastMessage: aiMessage.message,
        incrementUnread: 1,
      );
    } else {
      await _addPendingMessage(aiMessage);
    }

    await _repository.markConversationAsRead(userMessage.conversationId);
  }
  
  // NEW: Handle individual fragment messages
  Future<void> _onAddFragmentMessage(
    AddFragmentMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    // Add fragment to current messages
    _currentMessages.add(event.fragmentMessage);
    
    // Cache immediately
    if (_currentUserId != null && _currentCompanionId != null) {
      await _cacheService.cacheMessages(
        _currentUserId!,
        _currentMessages,
        companionId: _currentCompanionId!,
      );
    }

    // FIXED: Only emit state if this is not during active fragmentation
    // This prevents reloading fragments while they're being displayed
    if (state is! MessageFragmenting) {
      emit(MessageLoaded(messages: _currentMessages));
    }

    // Save fragment to database if online
    if (_isOnline) {
      try {
        await _repository.sendMessage(event.fragmentMessage);
      } catch (e) {
        print('Error saving fragment to database: $e');
        // Continue - fragment is still in local cache
      }
    } else {
      await _addPendingMessage(event.fragmentMessage);
    }
  }

  // NEW: Handle fragmentation completion notification
  Future<void> _onNotifyFragmentationComplete(
    NotifyFragmentationCompleteEvent event,
    Emitter<MessageState> emit,
  ) async {
    // Get the last fragment message to use as conversation preview
    final lastFragmentMessage = _currentMessages
        .where((m) => m.metadata['is_fragment'] == true)
        .lastOrNull;
    
    // Use the first fragment as preview (more meaningful than last)
    final firstFragmentMessage = _currentMessages
        .where((m) => m.metadata['is_fragment'] == true && m.metadata['fragment_index'] == 0)
        .lastOrNull;
    
    final lastMessagePreview = firstFragmentMessage?.message ?? 
                              lastFragmentMessage?.message ?? 
                              "New message";
    
    // Update conversation metadata with actual fragment content
    if (_isOnline) {
      try {
        await _repository.updateConversation(
          event.conversationId,
          lastMessage: lastMessagePreview, // Use actual fragment content
          incrementUnread: 1,
        );
        
        await _repository.markConversationAsRead(event.conversationId);
        
        // Trigger conversation list refresh with updated content
        _triggerConversationRefresh();
      } catch (e) {
        print('Error updating conversation after fragmentation: $e');
      }
    }

    // FIXED: Final state emission with smooth transition
    // Add a small delay to ensure UI has settled before final update
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isClosed) {
        emit(MessageLoaded(messages: _currentMessages));
        emit(MessageSent());
      }
    });
  }

  // MODIFIED: Simplified completion handler
  Future<void> _onCompleteFragmentedMessage(
    CompleteFragmentedMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    // This event is now mainly for database consistency
    // The fragments are already in _currentMessages via AddFragmentMessageEvent
    
    final originalMessage = event.originalMessage;
    final userMessage = event.userMessage;

    // Save complete message to database for search/backup purposes
    if (_isOnline) {
      try {
        final completeMessage = originalMessage.copyWith(
          id: 'complete_${DateTime.now().millisecondsSinceEpoch}',
          metadata: {
            ...originalMessage.metadata, 
            'is_complete_version': true,
            'fragment_count': originalMessage.metadata['total_fragments'] ?? 1,
          }
        );
        await _repository.sendMessage(completeMessage);
        await _repository.updateConversation(
          userMessage.conversationId,
          lastMessage: originalMessage.message,
          incrementUnread: 1,
        );
      } catch (e) {
        print('Error saving complete message: $e');
      }
    }

    await _repository.markConversationAsRead(userMessage.conversationId);
  }

  // MODIFIED: Load messages with fragment detection
  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    try {
      emit(MessageLoading());
      _currentUserId = event.userId;
      _currentCompanionId = event.companionId;

      // 1. Get companion data
      final companion = await _repository.getCompanion(event.companionId);
      if (companion == null) {
        throw Exception('Companion not found');
      }

      // 2. Try cached messages first
      _currentMessages = _cacheService.getCachedMessages(
        event.userId,
        companionId: event.companionId,
      );

      // Find any pending messages
      final pendingMessageIds = _pendingMessages
          .where((m) => m.companionId == event.companionId && m.userId == event.userId)
          .map((m) => m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (_currentMessages.isNotEmpty) {
        print("Found ${_currentMessages.length} cached messages for companion ${event.companionId}");
        
        // CRITICAL: Filter out complete versions if fragments exist
        _currentMessages = _filterDuplicateMessages(_currentMessages);
        
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
        ));
      }

      // 3. If online, get messages from server
      if (_connectivityService.isOnline) {
        try {
          final messages = await _repository.getMessages(event.userId, event.companionId);

          if (messages.isNotEmpty) {
            // Filter out complete versions if fragments exist
            final filteredMessages = _filterDuplicateMessages(messages);
            
            if (filteredMessages.isNotEmpty &&
                (_currentMessages.isEmpty ||
                    filteredMessages.length != _currentMessages.length ||
                    _messagesNeedUpdate(filteredMessages, _currentMessages))) {
              _currentMessages = filteredMessages;
              
              await _cacheService.cacheMessages(
                event.userId,
                _currentMessages,
                companionId: event.companionId,
              );
              emit(MessageLoaded(
                messages: _currentMessages,
                pendingMessageIds: pendingMessageIds,
              ));
            }
          }
        } catch (e) {
          print('Error fetching messages from server: $e');
        }
      }

      // 5. Get current user
      final user = await CustomAuthUser.getCurrentUser();

      // 6. Initialize AI companion if needed
      try {
        if (!_geminiService.isCompanionInitialized(event.userId, event.companionId)) {
          await _geminiService.initializeCompanion(
            companion: companion,
            userId: event.userId,
            userName: user?.fullName,
            userProfile: user?.toAIFormat(),
            messageBloc: this,
          );
        } else {
          print('Companion already initialized, skipping initialization');
        }
      } catch (e) {
        print('Error initializing AI in message loading: $e');
      }


      // 7. Create conversation if needed
      await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );

      // 8. Final state emission
      if (state is! MessageLoaded) {
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
          isFromCache: true,
        ));
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (_currentMessages.isNotEmpty) {
        emit(MessageLoaded(
          messages: _currentMessages,
          isFromCache: true,
          hasError: true,
        ));
      } else {
        emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
      }
    }
  }

  // Helper to check if messages have meaningful differences
  bool _messagesNeedUpdate(List<Message> newMessages, List<Message> oldMessages) {
    if (newMessages.length != oldMessages.length) return true;

    // Check last message is different
    if (newMessages.isNotEmpty && oldMessages.isNotEmpty) {
      // Compare last messages by content and timestamp
      final lastNew = newMessages.last;
      final lastOld = oldMessages.last;

      return lastNew.message != lastOld.message ||
          lastNew.created_at.isAfter(lastOld.created_at);
    }

    return false;
  }

  // NEW: Filter out complete messages if fragments exist
  List<Message> _filterDuplicateMessages(List<Message> messages) {
    final fragmentGroups = <String, List<Message>>{};
    final completeMessages = <String, Message>{};
    final nonFragmentedMessages = <Message>[];

    // Group messages by content/timestamp
    for (final message in messages) {
      if (message.metadata['is_fragment'] == true) {
        // FIXED: Use base_message_id if available, otherwise extract from ID
        final baseId = message.metadata['base_message_id']?.toString() ??
                      (message.id?.contains('_fragment_') == true 
                        ? message.id!.split('_fragment_')[0]
                        : message.id?.replaceAll(RegExp(r'_fragment_\d+'), '')) ??
                      '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
        
        fragmentGroups.putIfAbsent(baseId, () => []).add(message);
      } else if (message.metadata['is_complete_version'] == true) {
        final baseId = message.metadata['original_id']?.toString() ?? 
                      message.id?.toString() ?? 
                      '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
        completeMessages[baseId] = message;
      } else {
        nonFragmentedMessages.add(message);
      }
    }

    final result = <Message>[];
    
    // Add non-fragmented messages
    result.addAll(nonFragmentedMessages);
    
    // For each fragment group, add fragments (not complete version)
    fragmentGroups.forEach((baseId, fragments) {
      // Sort fragments by index
      fragments.sort((a, b) {
        final indexA = a.metadata['fragment_index'] as int? ?? 0;
        final indexB = b.metadata['fragment_index'] as int? ?? 0;
        return indexA.compareTo(indexB);
      });
      result.addAll(fragments);
    });
    
    // Add complete messages only if no fragments exist for them
    completeMessages.forEach((baseId, completeMessage) {
      if (!fragmentGroups.containsKey(baseId)) {
        result.add(completeMessage);
      }
    });

    // Sort by timestamp
    result.sort((a, b) => a.created_at.compareTo(b.created_at));
    
    return result;
  }

  Future<void> _onClearConversation(
    ClearConversation event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      // Clear from database
      await _repository.deleteAllMessages(companionId: event.companionId);

      // Clear cached messages for this specific companion
      await _cacheService.clearCache(
        event.userId,
        companionId: event.companionId,
      );
      _currentMessages = [];

      // Reset AI conversation
      _geminiService.resetConversation(messageBloc: this);

      // Update conversation in database
      final conversationId = await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );
      await _repository.updateConversation(
        conversationId,
        lastMessage: "Start a conversation",
        incrementUnread: 0,
      );

      emit(MessageLoaded(messages: const []));

      // Trigger conversation list refresh
      _triggerConversationRefresh();
    } catch (e) {
      print('Error clearing conversation: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<MessageState> emit,
  ) async {
    // Implementation for pagination...
  }

  Future<void> _onRetryChatRequest(
    RetryChatRequest event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      // Get the failed message
      final failedMessage = event.failedMessage;

      // Try to resend the message
      if (failedMessage.isBot) {
        // If it's a bot message that failed, regenerate the response
        final previousUserMessage = _currentMessages.lastWhere(
          (msg) => !msg.isBot && msg.id != failedMessage.id,
        );

        add(SendMessageEvent(message: previousUserMessage));
      } else {
        // If it's a user message that failed, try sending again
        add(SendMessageEvent(message: failedMessage));
      }

      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error retrying message: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());
      await _repository.deleteMessage(event.messageId);

      // Update local cache
      _currentMessages.removeWhere((msg) => msg.id == event.messageId);
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error deleting message: $e');
      emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
    }
  }

  Future<void> _onRefreshMessages(RefreshMessages event, Emitter<MessageState> emit) async {
    // Use centralized connectivity service
    if (!_connectivityService.isOnline) {
      print('Skipping message refresh - device is offline');
      return;
    }
    
    if (_currentUserId != null && _currentCompanionId != null) {
      try {
        final messages = await _repository.getMessages(
          _currentUserId!,
          _currentCompanionId!,
        );
        
        if (messages.isNotEmpty) {
          _currentMessages = messages;
          
          // Update cache
          await _cacheService.cacheMessages(
            _currentUserId!,
            messages,
            companionId: _currentCompanionId!,
          );
          
          // Find any pending messages
          final pendingMessageIds = _pendingMessages
              .where((m) => m.companionId == _currentCompanionId && m.userId == _currentUserId)
              .map((m) => m.id ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
              
          emit(MessageLoaded(
            messages: _currentMessages,
            pendingMessageIds: pendingMessageIds,
          ));
        }
      } catch (e) {
        print('Error refreshing messages: $e');
      }
    }
  }

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    await _typingSubject.close();
    _fragmentTimer?.cancel();
    _fragmentController?.close();

    // Save current AI state before closing
    if (_currentUserId != null && _currentCompanionId != null) {
      await _geminiService.saveState();
    }

    return super.close();
  }
}

// Helper method to allow unawaited futures
void unawaited(Future<void> future) {}