import 'package:ai_companion/Companion/ai_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AICompanionRepository {
final SupabaseClient _supabase;

  AICompanionRepository(this._supabase);
  
  Future<List<AICompanion>> getAllCompanions() async {
    try {
      final response = await _supabase
          .from('ai_companions')
          .select('''
          id,
          name,
          gender,
          "artStyle",
          "avatarUrl",
          description,
          physical,
          personality,
          background,
          skills,
          voice,
          metadata
          ''')
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
  
//   Future<List<String>> generateImagePrompts() async {
//     try {
//       final companions = await getAllCompanions();
//       return companions.map((companion) => _createImagePrompt(companion)).toList();
//     } catch (e) {
//       print('Error generating prompts: $e');
//       return [];
//     }
//   }

//   String _createImagePrompt(AICompanion companion) {
//     final physical = companion.physical;
//     final personality = companion.personality;

//     return '''
// A ${physical.age} year old ${companion.gender.toString().split('.').last}, 
// ${physical.height} tall with ${physical.bodyType} build. 
// ${physical.hairColor} hair and ${physical.eyeColor} eyes. 
// Style: ${physical.style}
// Distinguishing features: ${physical.distinguishingFeatures.join(', ')}

// Personality expressed through: 
// Primary traits: ${personality.primaryTraits.join(', ')}
// Expression: ${_getExpressionFromTraits(personality.primaryTraits)}

// Technical specifications:
// - Style: ${companion.artStyle.toString().split('.').last}
// - Lighting: Soft, natural lighting
// - Composition: Portrait or three-quarter shot
// - Background: Modern, clean setting
// - Details: High focus on distinguishing features and style elements

// Negative prompts:
// - No exaggerated features
// - No unrealistic proportions
// - No cluttered background
// - No artificial poses
// ''';
//   }

//   String _getExpressionFromTraits(List<String> traits) {
//     if (traits.contains('Cheerful') || traits.contains('Optimistic')) {
//       return 'Warm, genuine smile';
//     } else if (traits.contains('Serious') || traits.contains('Professional')) {
//       return 'Composed, thoughtful expression';
//     } else if (traits.contains('Creative') || traits.contains('Artistic')) {
//       return 'Inspired, engaged look';
//     }
//     return 'Natural, relaxed expression';
//   }
}