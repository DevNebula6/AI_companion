import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/chat/message.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final ChatRepository _repository;
  final GeminiService _geminiService;
  final ChatCacheService _cacheService;
  StreamSubscription<List<Message>>? _messageSubscription;
  String? _currentUserId;
  Timer? _syncTimer;
  Stream<List<Message>>? _messageStream;
  List<Message> _currentMessages = [];
  

 MessageBloc(this._repository, this._geminiService, this._cacheService) 
  : super(MessageInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<DeleteMessageEvent>(_onDeleteMessage);
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
      // 1. Add user message with optimistic update
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: event.message,
        userId: event.userId,
        isBot: false,
        created_at: DateTime.now(),
      );
      // Send to supabase 
      await _repository.sendMessage(event.userId, event.message, false);

      _currentMessages.add(userMessage);
      
      emit(MessageLoaded(
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
      
      // Get AI response
      final aiResponse = await _geminiService.generateResponse(event.message);
      
      // Add AI message
      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: aiResponse,
        userId: event.userId,
        isBot: true,
        created_at: DateTime.now(),
      );
      // Update cache and repository
      await _repository.sendMessage(event.userId, aiResponse, true);
      _currentMessages.add(aiMessage);
      await _cacheService.cacheMessages(_currentUserId!, _currentMessages);

      emit(MessageLoaded(
        messageStream: _messageStream!,
        currentMessages: _currentMessages,
      ));
      emit(MessageSent());

    } catch (e) {
      print('Error sending message: $e');
      if (_currentMessages.isNotEmpty) {
        _currentMessages.removeLast();
        await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
      }
      emit(const MessageError());
    }
  }

  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<MessageState> emit) async {
    try {
      emit(MessageLoading());

      _currentUserId = event.userId;

      // Get cached messages
      _currentMessages = _cacheService.getCachedMessages(event.userId);
      // Setup message stream
      _messageStream = _repository.getMessages(event.userId);
      // Setup stream subscription for real-time updates
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

      // Initialize AI with user info
      await _initializeAI(event.userId, event.userName);
      
      // Send welcome message if this is user's first time
      if (_currentMessages.isEmpty) {
        final greeting = await _geminiService.generateInitialGreeting(event.userName);
        
        await _repository.sendMessage(event.userId, greeting, true);

        final welcomeMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: greeting,
          userId: event.userId,
          isBot: true,
          created_at: DateTime.now(),
        );
        // Add to cache and repository
        _currentMessages.add(welcomeMessage);
        await _cacheService.cacheMessages(_currentUserId!, _currentMessages);
        }

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
  
  Future<void> _onDeleteMessage(
    DeleteMessageEvent event,
    Emitter<MessageState> emit
  ) async {
    try {
      emit(MessageLoading());
      await _repository.deleteMessage(event.messageId);
      emit(MessageSent());
    } catch (e) {
      emit(const MessageError()); 
    }
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    _syncTimer?.cancel();
    return super.close();
  }
}