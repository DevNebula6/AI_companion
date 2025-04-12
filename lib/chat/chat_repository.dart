import 'dart:collection' show LinkedHashMap;

import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:hive/hive.dart';

class ChatRepository {
  final _supabase = SupabaseClientManager().client;
  final CompanionBloc? _companionBloc;
  Box<AICompanion>? _companionsBox;

  final LinkedHashMap<String, AICompanion> _memoryCache = LinkedHashMap();

  ChatRepository({CompanionBloc? companionBloc}) : 
    _companionBloc = companionBloc {
    _initializeCache();
  }
  Future<void> _initializeCache() async {
    // Initialize the box only once when repository is created
    _companionsBox = await HiveService.getCompanionsBox();
  }

  //Storing messages in supabase
  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert({
      'user_id': message.userId,
      'companion_id': message.companionId,
      'conversation_id': message.conversationId,
      'message': message.message,
      'created_at': message.created_at.toIso8601String(),
      'is_bot': message.isBot
    });
  }

  Future<List<Message>> getMessages(String userId, String companionId) async {
    try {
      // Get the conversation ID first
      final conversationId = await getOrCreateConversation(userId, companionId);
      
      // Fetch messages directly
    final response = await _supabase
      .from('messages')
      .select()
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true);
    
    return response.map((item) => Message.fromJson(item)).toList();
  
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }
  
  Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from('messages')
        .delete()
        .eq('id', messageId);
  }

  Future<void> deleteAllMessages({required String companionId}) async {
    await _supabase
        .from('messages')
        .delete()
        .eq('companion_id', companionId);
  }

  // Get all conversations for the user
  Future<List<Conversation>> getConversations(String currentUserId) async {
      try {
      final data = await _supabase
        .from('conversations')
        .select()
        .eq('user_id', currentUserId)
        .order('last_updated', ascending: false);
      
      // Extract companion IDs
      final companionIds = data
        .map((item) => item['companion_id'].toString())
        .toSet()
        .toList();
      
      // Fetch companions
      final Map<String, AICompanion> companionsMap = {};
      
      for (final id in companionIds) {
        final companion = await getCompanion(id);
        if (companion != null) {
          companionsMap[id] = companion;
        }
      }
      
      // Build conversation objects
      final List<Conversation> conversations = [];
      for (final item in data) {
        final companionId = item['companion_id'].toString();
        if (companionsMap.containsKey(companionId)) {
          conversations.add(
            Conversation(
              id: item['id'],
              userId: item['user_id'],
              companionId: companionId,
              lastMessage: item['last_message']?.toString() ?? '',
              unreadCount: item['unread_count'] ?? 0,
              lastUpdated: DateTime.parse(item['last_updated']),
              isPinned: item['is_pinned'] ?? false,
            )
          );
        }
      }
      return conversations;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    } 
  }

  Future<AICompanion?> getCompanion(String companionId) async {
    // 1. Try to get from companionBloc first (most up-to-date)
    if (_companionBloc != null) {
      final state = _companionBloc.state;
      if (state is CompanionLoaded) {
        final companion = state.companions
        .where((c) => c.id == companionId)
        .firstOrNull;
        
        // If found, update memory cache and return
        if (companion != null) {
          _memoryCache[companionId] = companion;
          return companion;
        }
      }
    }
    // 2. Check memory cache
    if (_memoryCache.containsKey(companionId)) {
      return _memoryCache[companionId];
    }
    // 3. Check Hive cache
    if (_companionsBox != null && _companionsBox!.containsKey(companionId)) {
      final companion = _companionsBox!.get(companionId);
      if (companion != null) {
        _memoryCache[companionId] = companion;
        return companion;
      }
    }
    // 4. Fallback to Supabase if necessary
    try {
      final companionData = await _supabase
        .from('companions')
        .select()
        .eq('id', companionId)
        .single();
        
      final companion = AICompanion.fromJson(companionData);
      // Add to caches
      _memoryCache[companionId] = companion;
      await _companionsBox?.put(companionId, companion);
      
      return companion;
    } catch (e) {
      print('Error fetching companion $companionId: $e');
      return null;
    }
  }

  Future<bool> hasConversations(String userId) async {
    try {
      final result = await _supabase
        .from('conversations')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
      
      return result != null;
    } catch (e) {
      print('Error checking for conversations: $e');
      return false;
    }
  }
  
  // Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    await _supabase
      .from('conversations')
      .update({'unread_count': 0})
      .eq('id', conversationId);
  }
  
  // Update conversation data when sending messages
  Future<void> updateConversation(String conversationId, {
  String? lastMessage, 
  int? incrementUnread,
  }) async {
    final Map<String, dynamic> updateData = {
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    if (lastMessage != null) {
      updateData['last_message'] = lastMessage;
    }
    
    // Instead of using a non-existent RPC function, we'll use a two-step approach
    if (incrementUnread != null) {
      // First, get the current unread count
      final response = await _supabase
        .from('conversations')
        .select('unread_count')
        .eq('id', conversationId)
        .single();
      
      // Calculate the new unread count
      final currentUnread = response['unread_count'] as int? ?? 0;
      final newUnread = currentUnread + incrementUnread;
      
      // Add to the update data
      updateData['unread_count'] = newUnread;
    }
    
    // Perform the update operation
    await _supabase
      .from('conversations')
      .update(updateData)
      .eq('id', conversationId);
  }
  
  // Toggle pinned status
  Future<void> togglePinConversation(String conversationId, bool isPinned) async {
    await _supabase
      .from('conversations')
      .update({'is_pinned': isPinned})
      .eq('id', conversationId);
  }

  // Create new conversation
  Future<String> getOrCreateConversation(String userId,String companionId) async {
    try {
      // Try to find existing conversation
      final response = await _supabase
        .from('conversations')
        .select('id')
        .eq('companion_id', companionId)
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
      
      if (response != null && response['id'] != null) {
        return response['id'];
      }
      
      // Create new conversation
      final newConversation = await _supabase
        .from('conversations')
        .insert({
          'user_id': userId,
          'companion_id': companionId,
          'unread_count': 0,
          'last_message': 'Start a conversation',
          'last_updated': DateTime.now().toIso8601String(),
          'is_pinned': false
        })
        .select('id')
        .single();
      
      return newConversation['id'];
    } catch (e) {
      print('Error finding/creating conversation: $e');
      // Create a fallback ID if needed
      return 'fallback-$companionId-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
extension IterableExtension<T> on Iterable<T> {
    T? get firstOrNull => isEmpty ? null : first;
  }