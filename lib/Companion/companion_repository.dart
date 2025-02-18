import 'package:ai_companion/Companion/ai_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AICompanionRepository {
final SupabaseClient _supabase;

  AICompanionRepository(this._supabase);
  
  Future<List<AICompanion>> getAllCompanions() async {
    try {
      final response = await _supabase
          .from('ai_companions')
          .select()
          .order('created_at');
      
      print('Supabase response: $response'); // Debug print
            
      return response.map((json) => AICompanion.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching companions: $e'); // Debug print
      rethrow;
    }
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
  
  Stream<List<AICompanion>> watchCompanions() {
    return _supabase
      .from('ai_companions')
      .stream(primaryKey: ['id'])
      .map((data) {
        print('Received companion update from Supabase'); // Debug print
        return data.map((json) => AICompanion.fromJson(json)).toList();
      });
  }
}