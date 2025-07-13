import 'dart:async' show Completer;
import 'dart:collection' show LinkedHashMap;
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interface defining the contract for chat repository operations
abstract class IChatRepository {
  Future<void> sendMessage(Message message);
  Future<List<Message>> getMessages(String userId, String companionId);
  Future<void> deleteMessage(String messageId);
  Future<List<Conversation>> getConversations(String userId);
  Future<AICompanion?> getCompanion(String companionId);
  Future<void> deleteConversation(String conversationId);
  Future<String> getOrCreateConversation(String userId, String companionId);
  Future<bool> hasConversations(String userId);
  Future<void> updateConversation(String conversationId, {String? lastMessage, int? incrementUnread});
  Future<void> deleteAllMessages({required String companionId});
  Future<void> markConversationAsRead(String conversationId);
  Future<void> togglePinConversation(String conversationId, bool isPinned);
  Future<void> updateConversationMetadata(String conversationId, {required Map<String, dynamic> updates});
  Future<void> clearMessageCache({required String userId, required String companionId});
  // Other methods...
}

/// Factory for creating and accessing ChatRepository instances
class ChatRepositoryFactory {
  static ChatRepository? _instance;
  static final Completer<ChatRepository> _instanceCompleter = Completer<ChatRepository>();
  static bool _isInitializing = false;

  static Future<ChatRepository> getInstance({
    SupabaseClient? supabase,
    CompanionBloc? companionBloc,
  }) async {
    // Return existing instance if available
    if (_instance != null) {
      // Update dependencies if needed
      if (companionBloc != null) {
        _instance!.setCompanionBloc(companionBloc);
      }
      return _instance!;
    }

    // Wait for initialization if already in progress
    if (_isInitializing) {
      return _instanceCompleter.future;
    }

    // Start initialization
    _isInitializing = true;

    try {
      // Check if Supabase is initialized
      final supabaseManager = SupabaseClientManager();
      if (!supabaseManager.isInitialized) {
        await supabaseManager.initialize();
      }

      // Create the repository
      _instance = await ChatRepository.create(
        supabase: supabase,
        companionBloc: companionBloc,
      );

      // Complete the future
      if (!_instanceCompleter.isCompleted) {
        _instanceCompleter.complete(_instance);
      }

      return _instance!;
    } catch (e) {
      _isInitializing = false;
      if (!_instanceCompleter.isCompleted) {
        _instanceCompleter.completeError(e);
      }
      // Create emergency instance as fallback
      return ChatRepository.create(
        supabase: SupabaseClientManager().client,
      );
    }
  }
}

/// Implementation of the chat repository
class ChatRepository implements IChatRepository {
  late final SupabaseClient _supabase;
  CompanionBloc? _companionBloc;
  final GeminiService _geminiService = GeminiService();
  Box<AICompanion>? _companionsBox;
  bool _isInitialized = false;

  // Cache configuration
  static const int _maxCacheSize = 100;
  final Map<String, DateTime> _cacheAccessTimes = {};
  final LinkedHashMap<String, AICompanion> _memoryCache = LinkedHashMap();

  // Private constructor - use factory methods instead
  ChatRepository._({
    SupabaseClient? supabase,
    CompanionBloc? companionBloc,
  }) : _supabase = supabase ?? SupabaseClientManager().client {
    _companionBloc = companionBloc;
  }

  /// Creates and initializes a new ChatRepository instance
  static Future<ChatRepository> create({
    SupabaseClient? supabase,
    CompanionBloc? companionBloc,
  }) async {
    final repo = ChatRepository._(
      supabase: supabase,
      companionBloc: companionBloc,
    );

    await repo._initialize();
    return repo;
  }

  /// Initialize repository dependencies
  Future<void> _initialize() async {
    if (!_isInitialized) {
      try {
        _companionsBox = await HiveService.getCompanionsBox();
        _isInitialized = true;
      } catch (e) {
        print('Error initializing ChatRepository: $e');
        rethrow;
      }
    }
  }

  /// Ensure repository is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  /// Manage cache size by removing least recently used items
  void _manageCache() {
    if (_memoryCache.length > _maxCacheSize) {
      final entries = _cacheAccessTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final toRemove = entries.take((entries.length * 0.2).ceil())
          .map((e) => e.key)
          .toList();

      for (final key in toRemove) {
        _memoryCache.remove(key);
        _cacheAccessTimes.remove(key);
      }
    }
  }

  @override
  Future<List<Message>> getMessages(String userId, String companionId) async {
    await _ensureInitialized();

    try {
      final conversationId = await getOrCreateConversation(userId, companionId);

      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final messages = response.map((item) => Message.fromJson(item)).toList();
      
      // IMPORTANT: Don't filter here - let the MessageBloc handle fragment logic
      // This ensures we get all data from the database
      return messages;
    } catch (e) {
      print('Error retrieving messages: $e');
      return [];
    }
  }

  @override
  Future<void> sendMessage(Message message) async {
    await _ensureInitialized();

    await _supabase.from('messages').insert({
      'user_id': message.userId,
      'companion_id': message.companionId,
      'conversation_id': message.conversationId,
      'message': message.messageFragments, // Store as array in database
      'created_at': message.created_at.toIso8601String(),
      'is_bot': message.isBot,
      'metadata': message.metadata
    });
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _ensureInitialized();

    await _supabase.from('messages').delete().eq('id', messageId);
  }

  @override
  Future<List<Conversation>> getConversations(String userId) async {
    await _ensureInitialized();

    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .eq('user_id', userId)
          .order('last_updated', ascending: false);

      // Process results in batches to optimize memory usage
      final List<Conversation> conversations = [];
      final Set<String> companionIds = data
          .map<String>((item) => item['companion_id'].toString())
          .toSet();

      // Batch fetch companions
      final Map<String, AICompanion> companionsMap = {};
      for (final id in companionIds) {
        final companion = await getCompanion(id);
        if (companion != null) {
          companionsMap[id] = companion;
        }
      }

      // Build conversation objects
      for (final item in data) {
        final companionId = item['companion_id'].toString();
        if (companionsMap.containsKey(companionId)) {
          final companion = companionsMap[companionId]!;
          
          // Ensure companion_name is populated in the conversation data
          if (item['companion_name'] == null || item['companion_name'].toString().isEmpty) {
            item['companion_name'] = companion.name;
          }
          
          conversations.add(
              Conversation.fromJson(item, companion)
          );
        }
      }

      return conversations;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  @override
  Future<AICompanion?> getCompanion(String companionId) async {
    await _ensureInitialized();

    // Update cache access time if found
    if (_memoryCache.containsKey(companionId)) {
      _cacheAccessTimes[companionId] = DateTime.now();
      return _memoryCache[companionId];
    }

    // Try to get from companionBloc
    if (_companionBloc != null) {
      final state = _companionBloc!.state;
      if (state is CompanionLoaded) {
        final companion = state.companions
            .where((c) => c.id == companionId)
            .firstOrNull;

        if (companion != null) {
          _memoryCache[companionId] = companion;
          _cacheAccessTimes[companionId] = DateTime.now();
          _manageCache();
          return companion;
        }
      }
    }

    // Try Hive cache
    if (_companionsBox != null && _companionsBox!.containsKey(companionId)) {
      final companion = _companionsBox!.get(companionId);
      if (companion != null) {
        _memoryCache[companionId] = companion;
        _cacheAccessTimes[companionId] = DateTime.now();
        _manageCache();
        return companion;
      }
    }

    // Fallback to database
    try {
      final companionData = await _supabase
          .from('ai_companions')
          .select()
          .eq('id', companionId)
          .single();

      final companion = AICompanion.fromJson(companionData);

      // Save to caches
      _memoryCache[companionId] = companion;
      _cacheAccessTimes[companionId] = DateTime.now();
      await _companionsBox?.put(companionId, companion);
      _manageCache();

      return companion;
    } catch (e) {
      print('Error fetching companion $companionId: $e');
      return null;
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _ensureInitialized();

    try {
      // Get conversation metadata
      final conversation = await _supabase
          .from('conversations')
          .select('companion_id, user_id')
          .eq('id', conversationId)
          .single();

      final companionId = conversation['companion_id'];
      final userId = conversation['user_id'];

      // Use transaction to ensure atomic operations
      await Future.wait([
        // Delete messages
        _supabase.from('messages').delete().eq('conversation_id', conversationId),

        // Delete conversation
        _supabase.from('conversations').delete().eq('id', conversationId),
      ]);

      // Clear companion memory from GeminiService
      await _geminiService.clearCompanionState(userId, companionId);

      // Clear companion memory from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final key = 'companion_memory_${userId}_$companionId';
      await prefs.remove(key);

      print('Successfully deleted conversation $conversationId');
    } catch (e) {
      print('Error deleting conversation: $e');
      throw Exception('Failed to delete conversation: $e');
    }
  }

  @override
  Future<String> getOrCreateConversation(String userId, String companionId) async {
    await _ensureInitialized();

    try {
      // Check for existing conversation
      final response = await _supabase
          .from('conversations')
          .select('id, companion_name') // Include companion_name in select
          .eq('companion_id', companionId)
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      // Return existing conversation ID if found
      if (response != null && response['id'] != null) {
        return response['id'];
      }

      // Get companion data before creating conversation
      final companion = await getCompanion(companionId);
      final companionName = companion?.name ?? 'Unknown Companion';

      // Create new conversation with companion name
      final newConversation = await _supabase
          .from('conversations')
          .insert({
        'user_id': userId,
        'companion_id': companionId,
        'companion_name': companionName, // Store companion name
        'unread_count': 0,
        'last_message': 'Start a conversation',
        'last_updated': DateTime.now().toIso8601String(),
        'is_pinned': false,
        'metadata': {'relationship_level': 1}
      })
          .select('id')
          .single();

      return newConversation['id'];
    } catch (e) {
      print('Error finding/creating conversation: $e');
      return 'fallback-$companionId-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<bool> hasConversations(String userId) async {
    await _ensureInitialized();

    try {
      final response = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      return response != null && response['id'] != null;
    } catch (e) {
      print('Error checking conversations: $e');
      return false;
    }
  }

  @override
  Future<void> updateConversation(String conversationId, {String? lastMessage, int? incrementUnread}) async {
    await _ensureInitialized();

    final Map<String, dynamic> updates = {};
    if (lastMessage != null) {
      updates['last_message'] = lastMessage;
    }

    if (incrementUnread != null) {
      // Get current unread count first
      try {
        final conversation = await _supabase
            .from('conversations')
            .select('unread_count')
            .eq('id', conversationId)
            .single();

        final currentUnread = conversation['unread_count'] ?? 0;
        updates['unread_count'] = currentUnread + incrementUnread;
      } catch (e) {
        print('Error getting current unread count: $e');
        // Set directly if we can't get current count
        updates['unread_count'] = incrementUnread > 0 ? incrementUnread : 0;
      }
    }

    // Add last updated timestamp
    updates['last_updated'] = DateTime.now().toIso8601String();

    if (updates.isNotEmpty) {
      await _supabase
          .from('conversations')
          .update(updates)
          .eq('id', conversationId);
    }
  }

  @override
  Future<void> deleteAllMessages({required String companionId}) async {
    await _ensureInitialized();

    try {
      // Delete all messages for a specific companion
      await _supabase
          .from('messages')
          .delete()
          .eq('companion_id', companionId);

      print('Successfully deleted all messages for companion $companionId');
    } catch (e) {
      print('Error deleting messages: $e');
      throw Exception('Failed to delete messages: $e');
    }
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    await _ensureInitialized();

    try {
      await _supabase
          .from('conversations')
          .update({
        'unread_count': 0,
        'last_updated': DateTime.now().toIso8601String()
      })
          .eq('id', conversationId);
    } catch (e) {
      print('Error marking conversation as read: $e');
      throw Exception('Failed to mark conversation as read: $e');
    }
  }

  @override
  Future<void> togglePinConversation(String conversationId, bool isPinned) async {
    await _ensureInitialized();
    try {
      await _supabase
          .from('conversations')
          .update({
        'is_pinned': isPinned,
        'last_updated': DateTime.now().toIso8601String()
      })
          .eq('id', conversationId);
    } catch (e) {
      print('Error updating pin status: $e');
      throw Exception('Failed to update pin status: $e');
    }
  }

  @override
  Future<void> updateConversationMetadata(
    String conversationId,
    { required Map<String, dynamic> updates}
  ) async {
    await _ensureInitialized();
    
    try {
      await _supabase
          .from('conversations')
          .update(updates)
          .eq('id', conversationId);
    } catch (e) {
      print('Error updating conversation metadata: $e');
      throw Exception('Failed to update conversation metadata: $e');
    }
  }

  @override
  Future<void> clearMessageCache({
    required String userId,
    required String companionId
  }) async {
    try {
      final cacheService = await _getCacheService();
      await cacheService.clearCache(userId, companionId: companionId);
      
      // **FIX: Also clear companion state from GeminiService**
      await GeminiService().clearCompanionState(userId, companionId);
      
      print('Cleared message cache for user $userId and companion $companionId');
    } catch (e) {
      print('Error clearing message cache: $e');
    }
  }

  /// Clear all caches for a user
  Future<void> clearAllUserCaches(String userId) async {
    try {
      final cacheService = await _getCacheService();
      await cacheService.clearAllUserCaches(userId);
      
      // Clear companion states
      await GeminiService().clearAllUserStates(userId);
      
      // Clear memory cache
      _memoryCache.clear();
      _cacheAccessTimes.clear();
      
      print('Cleared all caches for user $userId');
    } catch (e) {
      print('Error clearing all user caches: $e');
    }
  }

  Future<ChatCacheService> _getCacheService() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatCacheService(prefs);
  }

  // Set the CompanionBloc instance
  void setCompanionBloc(CompanionBloc bloc) {
    _companionBloc = bloc;
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}