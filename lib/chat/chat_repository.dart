
import 'package:ai_companion/chat/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  final _supabase = Supabase.instance.client;

  //Storing messages in supabase
  Future<void> sendMessage(String userId, String message,bool isBot ) async {
    await _supabase.from('messages').insert({
      'user_id': userId,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'is_bot': isBot
    });
  }

  Stream<List<Message>> getMessages(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at',ascending: true)
        .map((data) => data.map((item) => Message.fromJson(item)).toList());
  }
  
  Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from('messages')
        .delete()
        .eq('id', messageId);
  }
}