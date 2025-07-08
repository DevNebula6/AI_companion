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
import 'package:ai_companion/chat/message_queue/message_queue.dart' as queue;
import 'package:ai_companion/chat/fragments/fragment_manager.dart';
import 'package:ai_companion/chat/msg_fragmentation/message_fragmentation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final ChatRepository _repository;
  final GeminiService _geminiService = GeminiService();
  final ChatCacheService _cacheService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Enhanced queue and fragment system
  final queue.MessageQueue _messageQueue = queue.MessageQueue();
  final FragmentManager _fragmentManager = FragmentManager();
  
  String? _currentUserId;
  String? _currentCompanionId;
  Timer? _syncTimer;
  List<Message> _currentMessages = [];
  
  // Offline support
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _fragmentSubscription;
  final List<Message> _pendingMessages = [];
  final String _pendingMessagesKey = 'pending_messages';

  // Add a BehaviorSubject for typing indicators
  final BehaviorSubject<bool> _typingSubject = BehaviorSubject.seeded(false);
  Stream<bool> get typingStream => _typingSubject.stream;
  

  MessageBloc(this._repository, this._cacheService) : super(MessageInitial()) {
    // Core message handlers
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
    
    // Enhanced queue and fragment handlers
    on<EnqueueMessageEvent>(_onEnqueueMessage);
    on<ProcessQueuedMessageEvent>(_onProcessQueuedMessage);
    on<HandleFragmentEvent>(_onHandleFragment);
    on<MessageQueuedEvent>(_onMessageQueued);
    
    // Fragment handling
    on<AddFragmentMessageEvent>(_onAddFragmentMessage);
    on<NotifyFragmentationCompleteEvent>(_onNotifyFragmentationComplete);
    on<FragmentedMessageReceivedEvent>(_onFragmentedMessageReceived);
    on<CompleteFragmentedMessageEvent>(_onCompleteFragmentedMessage);
    
    _setupPeriodicSync();
    _setupConnectivityListener();
    _setupQueueProcessing();
    _setupFragmentHandling();
    _loadPendingMessages();
  }

  void _setupQueueProcessing() {
    _queueSubscription = _messageQueue.processingStream?.listen((queuedMessage) {
      add(ProcessQueuedMessageEvent(queuedMessage));
    });
  }
  
  void _setupFragmentHandling() {
    _fragmentSubscription = _fragmentManager.events.listen((fragmentEvent) {
      add(HandleFragmentEvent(fragmentEvent));
    });
  }

  List<Message> get currentMessages => List<Message>.from(_currentMessages);

  // ENHANCED: Message sending with queue integration
  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessageState> emit) async {
    // Route through queue system for better management
    add(EnqueueMessageEvent(event.message, priority: queue.MessagePriority.normal));
  }

  // Enhanced queue message handler
  Future<void> _onEnqueueMessage(EnqueueMessageEvent event, Emitter<MessageState> emit) async {
    try {
      // Add message to queue
      _messageQueue.enqueueUserMessage(event.message);
      
      // Optimistic UI update
      _currentMessages.add(event.message);
      
      // Provide immediate feedback
      emit(MessageQueued(
        messages: List.from(_currentMessages),
        queueLength: _messageQueue.queueLength,
      ));
      
      // Cache optimistic update
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }
    } catch (e) {
      emit(MessageError(error: Exception('Failed to enqueue message: $e')));
    }
  }

  // Process queued messages
  Future<void> _onProcessQueuedMessage(ProcessQueuedMessageEvent event, Emitter<MessageState> emit) async {
    final queuedMessage = event.queuedMessage;
    
    try {
      switch (queuedMessage.type) {
        case queue.MessageType.user:
          await _processUserMessage(queuedMessage.message, emit);
          break;
        case queue.MessageType.system:
          await _processSystemMessage(queuedMessage.message, emit);
          break;
        case queue.MessageType.fragment:
          // Handled by FragmentManager
          break;
        case queue.MessageType.notification:
          await _processNotification(queuedMessage.message, emit);
          break;
      }
    } catch (e) {
      emit(MessageError(error: Exception('Failed to process queued message: $e')));
    }
  }

  // Enhanced user message processing
  Future<void> _processUserMessage(Message message, Emitter<MessageState> emit) async {
    try {
      // Update conversation identifier in GeminiService metadata
      final metrics = _geminiService.getRelationshipMetrics();
      if (!metrics.containsKey('conversation_id')) {
        _geminiService.addMemoryItem('conversation_id', message.conversationId);
      }

      // Save to repository if online
      if (_connectivityService.isOnline) {
        await _repository.sendMessage(message);
        await _repository.updateConversation(
          message.conversationId,
          lastMessage: message.message,
        );
      } else {
        await _addPendingMessage(message);
      }
      
      // Update current state
      emit(MessageLoaded(messages: List.from(_currentMessages)));
      
      // Generate AI response
      await _processAIResponse(message, emit);
    } catch (e) {
      emit(MessageError(error: Exception('Failed to process user message: $e')));
    }
  }

  // Enhanced AI response processing with fragment support
  Future<void> _processAIResponse(Message userMessage, Emitter<MessageState> emit) async {
    try {
      // Show typing indicator
      _typingSubject.add(true);
      emit(MessageReceiving(userMessage.message, messages: _currentMessages));

      // Generate AI response
      final String aiResponse = await _geminiService.generateResponse(
        userMessage.message,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => "I'm having trouble with my thoughts right now. Could you give me a moment?",
      );

      // Hide typing indicator
      _typingSubject.add(false);

      // Create AI message
      final metrics = _geminiService.getRelationshipMetrics();
      final aiMessage = Message(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
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
        // Use FragmentManager for fragmented responses
        _fragmentManager.startFragmentSequence(aiMessage, fragments);
      } else {
        // Single response
        await _processSingleMessage(aiMessage, userMessage, emit);
      }
    } catch (e) {
      print('Error generating AI response: $e');
      _typingSubject.add(false);
      await _handleAIResponseError(userMessage, e, emit);
    }
  }

  // Handle AI response errors
  Future<void> _handleAIResponseError(Message userMessage, dynamic error, Emitter<MessageState> emit) async {
    final errorMessage = Message(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      message: "I'm having trouble responding right now. Please try again later.",
      companionId: userMessage.companionId,
      userId: userMessage.userId,
      conversationId: userMessage.conversationId,
      isBot: true,
      created_at: DateTime.now(),
      metadata: {'error': true},
    );
    
    _currentMessages.add(errorMessage);
    emit(MessageLoaded(messages: List.from(_currentMessages), hasError: true));
    
    // Cache error message
    if (_currentUserId != null && _currentCompanionId != null) {
      await _cacheService.cacheMessages(
        _currentUserId!,
        _currentMessages,
        companionId: _currentCompanionId!,
      );
    }
  }

  // FIXED: Enhanced fragment event handler with proper single-sequence handling
  Future<void> _onHandleFragment(HandleFragmentEvent event, Emitter<MessageState> emit) async {
    final fragmentEvent = event.fragmentEvent;
    
    try {
      if (fragmentEvent is FragmentSequenceStarted) {
        print('Fragment sequence started: ${fragmentEvent.sequence.id}');

        // Show initial typing indicator
        _typingSubject.add(true);
        
        emit(MessageFragmentInProgress(
          sequence: fragmentEvent.sequence,
          currentFragment: Message(
            id: 'typing_${DateTime.now().millisecondsSinceEpoch}',
            message: 'typing...',
            companionId: fragmentEvent.sequence.originalMessage.companionId,
            userId: fragmentEvent.sequence.originalMessage.userId,
            conversationId: fragmentEvent.sequence.originalMessage.conversationId,
            isBot: true,
            created_at: DateTime.now(),
          ),
          messages: List.from(_currentMessages),
        ));
        
      } else if (fragmentEvent is FragmentTypingStarted) {
        print('Fragment typing started for fragment: ${fragmentEvent.sequence.currentIndex + 1}');
        
        // Show typing indicator for next fragment
        _typingSubject.add(true);
        
        emit(MessageFragmentTyping(
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
      } else if (fragmentEvent is FragmentDisplayed) {
        print('Fragment displayed: ${fragmentEvent.fragment.metadata['fragment_index']}');
        
        // Hide typing indicator when fragment is displayed
        _typingSubject.add(false);
        
        // Add fragment to current messages
        _currentMessages.add(fragmentEvent.fragment);
        
        // Emit fragment displayed state
        emit(MessageFragmentDisplayed(
          fragment: fragmentEvent.fragment,
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
        // Cache the fragment immediately
        if (_currentUserId != null && _currentCompanionId != null) {
          await _cacheService.cacheMessages(
            _currentUserId!,
            _currentMessages,
            companionId: _currentCompanionId!,
          );
        }
        
        // Save fragment to repository if online
        if (_connectivityService.isOnline) {
          await _repository.sendMessage(fragmentEvent.fragment);
        } else {
          await _addPendingMessage(fragmentEvent.fragment);
        }
        
      } else if (fragmentEvent is FragmentSequenceCompleted) {
        print('Fragment sequence completed: ${fragmentEvent.sequence.id}');
        
        // Hide typing indicator
        _typingSubject.add(false);
        
        emit(MessageFragmentSequenceCompleted(
          sequence: fragmentEvent.sequence,
          messages: List.from(_currentMessages),
        ));
        
        // Update conversation metadata
        if (_connectivityService.isOnline) {
          await _repository.updateConversation(
            fragmentEvent.sequence.originalMessage.conversationId,
            lastMessage: fragmentEvent.sequence.fragments.last,
            incrementUnread: 1,
          );
        }
        
        // Mark conversation as read
        await _repository.markConversationAsRead(
          fragmentEvent.sequence.originalMessage.conversationId
        );
        
        // Final emission to stable state
        emit(MessageLoaded(messages: List.from(_currentMessages)));
      }
    } catch (e) {
      print('Error handling fragment event: $e');
      _typingSubject.add(false);
      emit(MessageError(error: Exception('Failed to handle fragment event: $e')));
    }
  }

  // Process system messages
  Future<void> _processSystemMessage(Message message, Emitter<MessageState> emit) async {
    _currentMessages.add(message);
    
    if (_connectivityService.isOnline) {
      await _repository.sendMessage(message);
    } else {
      await _addPendingMessage(message);
    }
    
    emit(MessageLoaded(messages: List.from(_currentMessages)));
  }

  // Process notification messages
  Future<void> _processNotification(Message message, Emitter<MessageState> emit) async {
    _currentMessages.add(message);
    emit(MessageLoaded(messages: List.from(_currentMessages)));
  }

  // Enhanced queue state handler
  Future<void> _onMessageQueued(MessageQueuedEvent event, Emitter<MessageState> emit) async {
    emit(MessageQueued(
      messages: event.messages,
      queueLength: event.queueLength,
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

    emit(MessageLoaded(messages: List.from(_currentMessages)));
    emit(MessageSent());

    if (_connectivityService.isOnline) {
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

  // Handle individual fragment messages
  Future<void> _onAddFragmentMessage(AddFragmentMessageEvent event, Emitter<MessageState> emit) async {
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

    // Only emit state if not during active fragmentation
    if (state is! MessageFragmentInProgress) {
      emit(MessageLoaded(messages: List.from(_currentMessages)));
    }

    // Save fragment to database if online
    if (_connectivityService.isOnline) {
      try {
        await _repository.sendMessage(event.fragmentMessage);
      } catch (e) {
        print('Error saving fragment to database: $e');
      }
    } else {
      await _addPendingMessage(event.fragmentMessage);
    }
  }

  // Handle fragmentation completion notification
  Future<void> _onNotifyFragmentationComplete(NotifyFragmentationCompleteEvent event, Emitter<MessageState> emit) async {
    // Update conversation metadata
    if (_connectivityService.isOnline) {
      try {
        await _repository.updateConversation(
          event.conversationId,
          lastMessage: "New message",
          incrementUnread: 1,
        );
        
        await _repository.markConversationAsRead(event.conversationId);
      } catch (e) {
        print('Error updating conversation after fragmentation: $e');
      }
    }

    // Final state update
    await Future.delayed(const Duration(milliseconds: 200), () {
      if (!isClosed && !emit.isDone) {
        emit(MessageLoaded(messages: List.from(_currentMessages)));
        emit(MessageSent());
      }
    });
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

  // Simplified completion handler
  Future<void> _onCompleteFragmentedMessage(
    CompleteFragmentedMessageEvent event,
    Emitter<MessageState> emit,
  ) async {
    final originalMessage = event.originalMessage;
    final userMessage = event.userMessage;

    // Save complete message to database for search/backup purposes
    if (_connectivityService.isOnline) {
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

  // Setup connectivity monitoring using centralized service
  void _setupConnectivityListener() {
    try {
      _isOnline = _connectivityService.isOnline;
      
      _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) {
        if (isOnline != _isOnline) {
          _isOnline = isOnline;
          add(ConnectivityChangedEvent(isOnline));
          
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

  Future<void> _onConnectivityChanged(
    ConnectivityChangedEvent event,
    Emitter<MessageState> emit,
  ) async {
    _isOnline = event.isOnline;
    print('MessageBloc connectivity changed, online: $_isOnline');
    
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
    
    for (int i = 0; i < _pendingMessages.length; i++) {
      try {
        final pendingMessage = _pendingMessages[i];
        
        if (!isLocalId(pendingMessage.id!)) continue;
        
        await _repository.sendMessage(pendingMessage);
        
        if (!pendingMessage.isBot) {
          await _processAIResponse(pendingMessage, emit);
        }
        
        await _repository.updateConversation(
          pendingMessage.conversationId,
          lastMessage: pendingMessage.message,
          incrementUnread: pendingMessage.isBot ? 1 : 0,
        );
        
      } catch (e) {
        print('Error processing pending message: $e');
      }
    }
    
    _pendingMessages.clear();
    await _savePendingMessages();
    
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
        await _cacheService.cacheMessages(
          _currentUserId!,
          messages,
          companionId: _currentCompanionId!,
        );

        _triggerConversationRefresh();
      } catch (e) {
        print('Background sync error: $e');
      }
    }
  }

  void _triggerConversationRefresh() {
    if (_currentUserId != null) {
      // This is handled by the UI when needed
    }
  }

  bool isLocalId(String id) {
    return id.startsWith('local_') || id.startsWith('fallback-');
  }

  // CRUD operations and other methods remain unchanged

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _queueSubscription?.cancel();
    _fragmentSubscription?.cancel();
    await _typingSubject.close();
    _fragmentManager.dispose();
    _messageQueue.dispose();

    if (_currentUserId != null && _currentCompanionId != null) {
      await _geminiService.saveState();
    }

    return super.close();
  }

  Future<void> _onInitializeCompanion(
    InitializeCompanionEvent event,
    Emitter<MessageState> emit,
  ) async {
    // Check if bloc is still active
    if (isClosed) {
      print('MessageBloc is closed, cannot initialize companion');
      return;
    }
    
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

        if (!isClosed) {
          emit(CompanionInitialized(event.companion));
        }
      } catch (e) {
        print('Error in GeminiService.initializeCompanion: $e');
        // Even if Gemini initialization fails, we can still show the UI
        if (!isClosed) {
          emit(CompanionInitialized(event.companion));
        }
      }
    } catch (e) {
      print('Error initializing companion: $e');
      if (!isClosed) {
        emit(MessageError(error: e is Exception ? e : Exception(e.toString())));
      }
    }
  }

  // MODIFIED: Load messages with fragment detection
  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    // Check if bloc is still active
    if (isClosed) {
      print('MessageBloc is closed, cannot load messages');
      return;
    }
    
    try {
      emit(MessageLoading());
      _currentUserId = event.userId;
      _currentCompanionId = event.companionId;

      // 1. Get companion data
      final companion = await _repository.getCompanion(event.companionId);
      if (companion == null) {
        throw Exception('Companion not found');
      }

      // Check if still active before proceeding
      if (isClosed) return;

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

      if (_currentMessages.isNotEmpty && !isClosed) {
        print("Found ${_currentMessages.length} cached messages for companion ${event.companionId}");
        
        // CRITICAL: Filter out complete versions if fragments exist
        _currentMessages = _filterDuplicateMessages(_currentMessages);
        
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
        ));
      }

      // 3. If online, get messages from server
      if (_connectivityService.isOnline && !isClosed) {
        try {
          final messages = await _repository.getMessages(event.userId, event.companionId);

          if (messages.isNotEmpty && !isClosed) {
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
              
              if (!isClosed) {
                emit(MessageLoaded(
                  messages: _currentMessages,
                  pendingMessageIds: pendingMessageIds,
                ));
              }
            }
          }
        } catch (e) {
          print('Error fetching messages from server: $e');
        }
      }

      // Check if still active before AI initialization
      if (isClosed) return;

      // 5. Get current user
      final user = await CustomAuthUser.getCurrentUser();

      // 6. Initialize AI companion if needed
      try {
        if (!_geminiService.isCompanionInitialized(event.userId, event.companionId) && !isClosed) {
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

      // Check if still active before creating conversation
      if (isClosed) return;

      // 7. Create conversation if needed
      await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );

      // 8. Final state emission
      if (state is! MessageLoaded && !isClosed) {
        emit(MessageLoaded(
          messages: _currentMessages,
          pendingMessageIds: pendingMessageIds,
          isFromCache: true,
        ));
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!isClosed) {
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
}
// Helper method to allow unawaited futures
void unawaited(Future<void> future) {}