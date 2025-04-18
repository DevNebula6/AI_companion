import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final ChatRepository _repository;
  final GeminiService _geminiService = GeminiService();
  final ChatCacheService _cacheService;

  String? _currentUserId;
  String? _currentCompanionId;
  Timer? _syncTimer;
  List<Message> _currentMessages = [];

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

    _setupPeriodicSync();
  }

  List<Message> get currentMessages => List<Message>.from(_currentMessages);

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

  // Add this helper method to trigger conversation refresh
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
      _currentMessages.add(userMessage);
      emit(MessageLoaded(messages: _currentMessages));

      // 2. Send to database (don't await to keep UI responsive)
      unawaited(_repository.sendMessage(userMessage));
      unawaited(_repository.updateConversation(
        userMessage.conversationId,
        lastMessage: userMessage.message,
      ));

      // 3. Cache current messages with companion-specific key
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      // 4. Show typing indicator
      _typingSubject.add(true);
      emit(MessageReceiving(userMessage.message, messages: _currentMessages));

      // 5. Generate AI response
      final String aiResponse = await _geminiService.generateResponse(
        userMessage.message,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => "I'm having trouble with my thoughts right now. Could you give me a moment?",
      );

      // 6. Hide typing indicator
      _typingSubject.add(false);

      // 7. Create AI message
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

      // 8. Update local state and cache
      _currentMessages.add(aiMessage);
      if (_currentUserId != null && _currentCompanionId != null) {
        await _cacheService.cacheMessages(
          _currentUserId!,
          _currentMessages,
          companionId: _currentCompanionId!,
        );
      }

      // 9. Update UI
      emit(MessageLoaded(messages: _currentMessages));
      emit(MessageSent());

      // 10. Save AI message to database
      unawaited(_repository.sendMessage(aiMessage));
      unawaited(_repository.updateConversation(
        userMessage.conversationId,
        lastMessage: aiMessage.message,
        incrementUnread: 1,
      ));

      // 11. Trigger conversation list refresh
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

      // 2. Try cached messages first for immediate response
      _currentMessages = _cacheService.getCachedMessages(
        event.userId,
        companionId: event.companionId,
      );

      if (_currentMessages.isNotEmpty) {
        print("Found ${_currentMessages.length} cached messages for companion ${event.companionId}");
        emit(MessageLoaded(messages: _currentMessages));
      }

      // 3. Get messages from server
      final messages = await _repository.getMessages(event.userId, event.companionId);

      // 4. Check if there are differences and update cache if needed
      if (messages.isNotEmpty &&
          (_currentMessages.isEmpty ||
              messages.length != _currentMessages.length ||
              _messagesNeedUpdate(messages, _currentMessages))) {
        _currentMessages = messages;
        // Update companion-specific cache
        await _cacheService.cacheMessages(
          event.userId,
          messages,
          companionId: event.companionId,
        );
        emit(MessageLoaded(messages: _currentMessages));
      }

      // 5. Get current user
      final user = await CustomAuthUser.getCurrentUser();

      // 6. Initialize AI companion if needed
      try {
        await _geminiService.initializeCompanion(
          companion: companion,
          userId: event.userId,
          userName: user?.fullName,
          userProfile: user?.toAIFormat(),
        );
      } catch (e) {
        print('Error initializing AI in message loading: $e');
        // Continue anyway to show messages
      }

      // 7. Create conversation if needed
      await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );

      // 8. Final state emission
      if (_currentMessages.isEmpty) {
        emit(MessageLoaded(messages: const []));
      }
    } catch (e) {
      print('Error loading messages: $e');
      // Fallback to cached messages
      if (_currentMessages.isNotEmpty) {
        emit(MessageLoaded(messages: _currentMessages));
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

  Future<void> _onClearConversation(
    ClearConversation event,
    Emitter<MessageState> emit,
  ) async {
    try {
      emit(MessageLoading());

      // Clear cached messages for this specific companion
      await _cacheService.clearCache(
        event.userId,
        companionId: event.companionId,
      );
      _currentMessages = [];

      // Reset AI conversation
      _geminiService.resetConversation();

      // Clear from database
      await _repository.deleteAllMessages(companionId: event.companionId);

      // Update conversation in database
      final conversationId = await _repository.getOrCreateConversation(
        event.userId,
        event.companionId,
      );
      await _repository.updateConversation(
        conversationId,
        lastMessage: '',
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
    if (_currentUserId != null && _currentCompanionId != null) {
      await _onLoadMessages(
        LoadMessagesEvent(
          userId: _currentUserId!,
          companionId: _currentCompanionId!,
        ),
        emit,
      );
    }
  }

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    await _typingSubject.close();

    // Save current AI state before closing
    if (_currentUserId != null && _currentCompanionId != null) {
      await _geminiService.saveState();
    }

    return super.close();
  }
}

// Helper method to allow unawaited futures
void unawaited(Future<void> future) {}