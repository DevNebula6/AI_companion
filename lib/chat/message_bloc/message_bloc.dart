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
  final GeminiService _geminiService;
  final ChatCacheService _cacheService;

  String? _currentUserId;
  String? _currentCompanionId;
  Timer? _syncTimer;
  List<Message> _currentMessages = [];
  AICompanion? _currentCompanion;
  CustomAuthUser? _currentUser;
  
  // Add a BehaviorSubject for typing indicators
  final BehaviorSubject<bool> _typingSubject = BehaviorSubject.seeded(false);
  Stream<bool> get typingStream => _typingSubject.stream;
  
  MessageBloc(this._repository, this._geminiService, this._cacheService) 
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
  
  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _backgroundSync(),
    );
  }
  
  Future<void> _backgroundSync() async {
    if (_currentUserId != null && _currentCompanionId != null && 
        _cacheService.needsSync(_currentUserId!)) {
      try {
        final messages = await _repository.getMessages(_currentUserId!, _currentCompanionId!);
        await _cacheService.cacheMessages(_currentUserId!, messages);
      } catch (e) {
        print('Background sync error: $e');
      }
    }
  }
  
  Future<void> _onInitializeCompanion(
    InitializeCompanionEvent event, 
    Emitter<MessageState> emit
  ) async {
    try {
      emit(MessageLoading());
      
      _currentUserId = event.userId;
      _currentCompanionId = event.companion.id;
      _currentCompanion = event.companion;
      _currentUser = event.user;
      
      // Initialize the AI companion with user information
      await _geminiService.initializeCompanion(
        companion: event.companion,
        userId: event.userId,
        userName: event.user?.fullName,
        userProfile: event.user?.toAIFormat(),
      );
      
      emit(CompanionInitialized(event.companion));
    } catch (e) {
      print('Error initializing companion: $e');
      emit(MessageError(error: e as Exception));
    }
  }
  
  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessageState> emit) async {
    try {
      final userMessage = event.message;


      // 1. Optimistic update for immediate UI feedback
      _currentMessages.add(userMessage);
      emit(MessageLoaded(
        messages: _currentMessages,
      ));
      
      // 2. Send to database in background (don't await)
      Future(() async {
        await _repository.sendMessage(userMessage);
        await _repository.updateConversation(
          userMessage.conversationId,
          lastMessage: userMessage.message,
          incrementUnread: null,
        );
      });
      
      // 5. Show typing indicator
      _typingSubject.add(true);
      emit(MessageReceiving(userMessage.message));
      
      // 6. Generate AI response
      final String aiResponse = await _geminiService.generateResponse(
        userMessage.message,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => "I'm having trouble with my thoughts right now. Could you give me a moment?"
      );
      
      // 7. Hide typing indicator
      _typingSubject.add(false);
      
      // 8. Create AI message
      final metrics = _geminiService.getRelationshipMetrics();
      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      
      // 9. Update local state
      _currentMessages.add(aiMessage);
      await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      
      // 10. Update UI with both messages
      emit(MessageLoaded(
        messages: _currentMessages,
      ));
      emit(MessageSent());

      // 13. Update database in background
      Future(() async {
        await _repository.sendMessage(aiMessage);
        await _repository.updateConversation(
          userMessage.conversationId,
          lastMessage: aiMessage.message,
          incrementUnread: 1,
        );
      });
    } catch (e) {
      print('Error sending message: $e');
      // Remove the optimistically added message if error occurs
      if (_currentMessages.isNotEmpty) {
        _currentMessages.removeLast();
        await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      }
      
      _typingSubject.add(false);
      emit(MessageError(error: e as Exception));
    }
  }
  
Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    try {
      emit(MessageLoading());
      _currentUserId = event.userId;
      _currentCompanionId = event.companionId;
      
      // 1. Get companion data
      final companion = await _repository.getCompanion(event.companionId);
      if (companion != null) {
        _currentCompanion = companion;
      } else {
        throw Exception('Companion not found');
      }
      
      // 2. Try cached messages first for immediate response
      _currentMessages = _cacheService.getCachedMessages(event.userId);
      if (_currentMessages.isNotEmpty) {
        emit(MessageLoaded(messages: _currentMessages));
      }
      
      // 3. Then fetch fresh messages
      final messages = await _repository.getMessages(event.userId, event.companionId);
      
      if (messages.isNotEmpty) {
        _currentMessages = messages;
        await _cacheService.cacheMessages(event.userId, messages);
      }
      
      // 4. Get current user
      final user = await CustomAuthUser.getCurrentUser();
      _currentUser = user;
      
      // 5. Initialize AI companion if not initialised
      
      await _geminiService.initializeCompanion(
        companion: companion,
        userId: event.userId,
        userName: user?.fullName,
        userProfile: user?.toAIFormat(),
      );
          
      // 6. Handle welcome message if needed
      if (_currentMessages.isEmpty) {
        // Generate greeting and create welcome message
        final greeting = await _geminiService.generateGreeting();
        
        // Get conversation ID
        final conversationId = await _repository.getOrCreateConversation(
          event.userId, 
          event.companionId
        );
        
        final welcomeMessage = Message(
          id: "welcome-${DateTime.now().millisecondsSinceEpoch}",
          message: greeting,
          userId: event.userId,
          companionId: event.companionId,
          conversationId: conversationId,
          isBot: true,
          created_at: DateTime.now(),
          metadata: {
            'is_greeting': true,
            'relationship_level': _geminiService.relationshipLevel,
          },
        );
        
        // Add to local state first
        _currentMessages = [welcomeMessage];
        await _cacheService.cacheMessages(event.userId, _currentMessages);
        
        // Update UI with local state
        emit(MessageLoaded(messages: _currentMessages));
        
        // Then send to database
        await _repository.sendMessage(welcomeMessage);
        await _repository.updateConversation(
          conversationId,
          lastMessage: welcomeMessage.message,
          incrementUnread: 1,
        );
      } else {
        // Just emit loaded state with messages
        emit(MessageLoaded(messages: _currentMessages));
      }
    } catch (e) {
      print('Error loading messages: $e');
      
      // Fallback to cached messages
      if (_currentMessages.isNotEmpty) {
        emit(MessageLoaded(messages:_currentMessages));
      } else {
        emit(MessageError(error: e as Exception));
      }
    }
  }
  
  Future<void> _onClearConversation(
    ClearConversation event, 
    Emitter<MessageState> emit
  ) async {
    try {
      emit(MessageLoading());
      
      // Clear cached messages
      _cacheService.clearCache(event.userId);
      _currentMessages = [];
      
      // Reset AI conversation
      _geminiService.resetConversation();
      
      _repository.deleteAllMessages(companionId: event.companionId);
      
      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error clearing conversation: $e');
      emit(MessageError(error: e as Exception));
    }
  }
  
  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<MessageState> emit
  ) async {
    // Implementation for pagination...
  }
  
  Future<void> _onRetryChatRequest(
    RetryChatRequest event,
    Emitter<MessageState> emit
  ) async {
    try {
      emit(MessageLoading());
      
      // Get the failed message
      final failedMessage = event.failedMessage;
      
      // Try to resend the message
      if (failedMessage.isBot) {
        // If it's a bot message that failed, regenerate the response
        final previousUserMessage = _currentMessages
            .lastWhere((msg) => !msg.isBot && msg.id != failedMessage.id,
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
      emit(MessageError(error: e as Exception));
    }
  }
  
  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<MessageState> emit
  ) async {
    try {
      emit(MessageLoading());
      await _repository.deleteMessage(event.messageId);
      
      // Update local cache
      _currentMessages.removeWhere((msg) => msg.id == event.messageId);
      await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      
      emit(MessageLoaded(
        messages: _currentMessages,
      ));
    } catch (e) {
      print('Error deleting message: $e');
      emit(MessageError(error: e as Exception));
    }
  }

  Future<void> _onRefreshMessages(RefreshMessages event, Emitter<MessageState> emit) async {
    if (_currentUserId != null && _currentCompanionId != null) {
      await _onLoadMessages(
        LoadMessagesEvent(
          userId: _currentUserId!, 
          companionId: _currentCompanionId!
        ), 
        emit
      );
    }
  }

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    await _typingSubject.close();
    await _geminiService.saveState();
    return super.close();
  }
}