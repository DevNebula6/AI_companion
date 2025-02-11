import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';

class AICompanionRepository {
  final _supabase = SupabaseClientManager().client;

  Future<List<AICompanion>> getAllCompanions() async {
    final response = await _supabase
        .from('ai_companions')
        .select()
        .order('created_at');
    
    return response.map((json) => AICompanion.fromJson(json)).toList();
  }

  Future<List<AICompanion>> getCompanionsByTraits(List<String> traits) async {
    final response = await _supabase
        .from('ai_companions')
        .select()
        .containedBy('personality->primaryTraits', traits);
    
    return response.map((json) => AICompanion.fromJson(json)).toList();
  }

  Future<AICompanion> getCompanionById(String id) async {
    final response = await _supabase
        .from('ai_companions')
        .select()
        .eq('id', id)
        .single();
    
    return AICompanion.fromJson(response);
  }
}