import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:hive/hive.dart';

class ChatRepository {
  final _supabase = SupabaseClientManager().client;
  Box<AICompanion>? _companionsBox;

  //Storing messages in supabase
  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert({
      'user_id': message.companionId,
      'companion_id': message.userId,
      'message': message.message,
      'created_at': message.created_at.toIso8601String(),
      'is_bot': message.isBot
    });
  }

  Stream<List<Message>> getMessages(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        // .eq('companion_id', companionId) 
        .order('created_at', ascending: true)
        .map((data) => data.map((item) => Message.fromJson(item)).toList());
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
  Stream<List<Conversation>> watchConversations() {
    AICompanion? companion;
    return _supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .order('last_updated', ascending: false)
      .asyncMap((data) async {
        final List<Conversation> conversations = [];
        for (final item in data) {
          // Get companion data
          final companionId = item['companion_id'];

          // Check if companion box is not empty
          _companionsBox = await HiveService.getCompanionsBox();
          if (_companionsBox!.isNotEmpty && _companionsBox!.containsKey(companionId)) {
            // Get companion from local box
            companion = _companionsBox!.get(companionId);
          } else {
            // Fetch companion from Supabase
            final companionData = await _supabase
              .from('companions')
              .select()
              .eq('companion_id', companionId)
              .single();
            
            companion = AICompanion.fromJson(companionData);
            
          }
          if (companion != null) {
            
            conversations.add(
              Conversation(
                id: item['id'],
                userId: item['user_id'],
                companionId: companion!.id,
                lastMessage: item['last_message'].toString(),
                unreadCount: item['unread_count'] ?? 0,
                lastUpdated: DateTime.parse(item['last_updated']),
                isPinned: item['is_pinned'] ?? false,
              )
            );
          }
        }
        return conversations;
      });
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
    
    if (incrementUnread != null) {
      // Use Supabase's SQL function to increment unread count
      await _supabase.rpc('increment_unread_count', params: {
        'conversation_id': conversationId,
        'increment_by': incrementUnread
      });
    } else {
      await _supabase
        .from('conversations')
        .update(updateData)
        .eq('id', conversationId);
    }
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
          'companion_id': companionId,
          'unread_count': 0,
          'last_updated': DateTime.now().toIso8601String(),
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