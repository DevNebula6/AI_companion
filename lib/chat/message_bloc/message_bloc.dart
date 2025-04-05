import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  
  // Stream subscriptions and controllers
  StreamSubscription<List<Message>>? _messageSubscription;
  String? _currentUserId;
  Timer? _syncTimer;
  Stream<List<Message>>? _messageStream;
  List<Message> _currentMessages = [];
  
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
    if (_currentUserId != null && _cacheService.needsSync(_currentUserId!)) {
      try {
        final messages = await _repository.getMessages(_currentUserId!).first;
        await _cacheService.cacheMessages(_currentUserId!, messages);
      } catch (e) {
        print('Background sync error: $e');
      }
    }
  }
  
  Future<void> _initializeAI(String userId, String userName) async {
    try {
      // Initialize AI with user info for personalized responses
      await _geminiService.initializeChat(
        userName: userName,
        additionalInfo: {
          'userId': userId,
          'timezone': DateTime.now().timeZoneName,
        },
      );
    } catch (e) {
      print('Error initializing AI: $e');
    }
  }
  
  Future<void> _onSendMessage(SendMessageEvent event, Emitter<MessageState> emit) async {
    try {
      final message = event.message;
      
      // 1. Optimistic update for immediate UI feedback
      _currentMessages.add(message);
      emit(MessageLoaded(
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
      
      // 2. Send to Supabase
      await _repository.sendMessage(message);
      
      // 3. Get or create conversation for this companion
      String conversationId = await 
        _repository.getOrCreateConversation(
          message.userId,
          message.companionId,
          );
      
      // 4. Update conversation with last message
      await _repository.updateConversation(
        conversationId,
        lastMessage: message.message,
        incrementUnread: null, // Don't increment for user messages
      );
      
      // 5. Show typing indicator
      _typingSubject.add(true);
      emit(MessageReceiving(message.message));
      
      // 6. Get AI response with timeout handling
      String aiResponse;
      try {
        aiResponse = await _geminiService.generateResponse(message.message)
            .timeout(const Duration(seconds: 15));
      } catch (timeoutError) {
        aiResponse = "I'm having trouble processing that right now. Could you try again?";
      }
      
      // 7. Hide typing indicator
      _typingSubject.add(false);
      
      // 8. Create AI message
      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: aiResponse,
        companionId: message.companionId,
        userId: message.userId,
        isBot: true,
        created_at: DateTime.now(),
        // Add metadata for enhanced context
      );
      
      // 9. Update conversation with AI response
      await _repository.updateConversation(
        conversationId,
        lastMessage: aiMessage.message,
        incrementUnread: 1, // Increment unread count for bot message
      );
      
      // 10. Optimistically update UI and Emit loaded state with updated messages
      emit(MessageLoaded(
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
      // 11. Send AI message to Supabase
      await _repository.sendMessage(aiMessage);
      
      // 12. Update local state
      _currentMessages.add(aiMessage);
      await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
            
      emit(MessageSent());
    } catch (e) {
      print('Error sending message: $e');
      
      // Remove the optimistically added message if error occurs
      if (_currentMessages.isNotEmpty) {
        _currentMessages.removeLast();
        await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      }
      
      _typingSubject.add(false);
      emit(const MessageError());
    }
  }
  
  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    try {
      emit(MessageLoading());
      _currentUserId = event.userId;
      
      // 1. Get cached messages for instant display
      _currentMessages = _cacheService.getCachedMessages(event.userId);
      
      // 2. Setup message stream from Supabase
      _messageStream = _repository.getMessages(event.userId);
      
      // 3. Setup stream subscription for real-time updates
      await _messageSubscription?.cancel();
      _messageSubscription = _messageStream!.listen(
        (messages) async {
          _currentMessages = messages;
          await _cacheService.cacheMessages(event.userId, messages);
          
          if (_currentUserId == event.userId && !emit.isDone) {
            emit(MessageLoaded(
              messageStream: _messageStream!,
              currentMessages: messages,
            ));
          }
        },
        onError: (error) {
          print('Stream error: $error');
          if (!emit.isDone) {
            emit(MessageLoaded(
              messageStream: _messageStream!,
              currentMessages: _currentMessages,
            ));
          }
        },
      );

      // 4. Initialize AI with user info
      await _initializeAI(event.userId, event.companionId);
      
      // 5. Send welcome message if this is user's first time
      if (_currentMessages.isEmpty) {
        // Generate personalized greeting
        final greeting = await _geminiService.generateInitialGreeting(event.userId);
        
        // Create welcome message
        final welcomeMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: greeting,
          userId: event.userId,
          companionId: event.companionId,
          isBot: true,
          created_at: DateTime.now(),
        );
        
        // Send to Supabase
        await _repository.sendMessage(welcomeMessage);
        
        // Create or update conversation
        String conversationId = await _repository.getOrCreateConversation(
          event.userId,
          event.companionId,
        );
        await _repository.updateConversation(
          conversationId,
          lastMessage: welcomeMessage.message,
          incrementUnread: 1,
        );
        
        // Add to local cache
        _currentMessages.add(welcomeMessage);
        await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      }
      
      // 6. Emit loaded state
      if (!emit.isDone) {
        emit(MessageLoaded(
          messageStream: _messageStream!,
          currentMessages: _currentMessages,
        ));
      }
    } catch (e) {
      print('Error loading messages: $e');
      
      if (!emit.isDone) {
        // Fallback to cached messages if available
        if (_currentMessages.isNotEmpty) {
          emit(MessageLoaded(
            messageStream: _messageStream!,
            currentMessages: _currentMessages,
          ));
        } else {
          emit(const MessageError());
        }
      }
    }
  }
  
  // Other event handlers...
  
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
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
    } catch (e) {
      print('Error clearing conversation: $e');
      emit(const MessageError());
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
    // Implementation for retrying failed messages...
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
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
    } catch (e) {
      print('Error deleting message: $e');
      emit(const MessageError()); 
    }
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    _syncTimer?.cancel();
    await _typingSubject.close();
    return super.close();
  }
}