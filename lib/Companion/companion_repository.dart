import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/services/image_cache_service.dart';
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
      
      print('Supabase response: $response'); 
            
      final companions = response.map((json) => AICompanion.fromJson(json)).toList();
      // Prefetch images in background without awaiting
      prefetchCompanionImages(companions);
      return companions;
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

  Future<void> prefetchCompanionImages(List<AICompanion> companions) async {
    for (final companion in companions) {
      if (companion.avatarUrl.isNotEmpty) {
        try {
          // Pre-download the image to cache
          await CompanionImageCacheManager.instance.getSingleFile(companion.avatarUrl);
        } catch (e) {
          print('Error prefetching image: $e');
        }
      }
    }
  }
  
  // Future<bool> generateAllImagePrompts() async {
  //   try {
  //     final companions = await getAllCompanions();
      
  //     final directory = Directory('${Directory.current.path}/lib/AI');
  //     if (!await directory.exists()) {
  //       await directory.create(recursive: true);
  //     }
      
  //     // Create a single file for all prompts
  //     final allPromptsFile = File('${Directory.current.path}/lib/AI/all_image_prompts.txt');
  //     final buffer = StringBuffer();
      
  //     // Create individual files for each companion
  //     for (final companion in companions) {
  //       final prompt = ImagePromptService.createPrompt(companion);
        
  //       // Write to individual file
  //       final individualFile = File('${Directory.current.path}/lib/AI/${companion.name.replaceAll(' ', '_')}_prompt.txt');
  //       await individualFile.writeAsString(prompt);
        
  //       // Append to combined file
  //       buffer.writeln(prompt);
  //       buffer.writeln('\n' + '=' * 60 + '\n');
  //     }
      
  //     // Write combined file
  //     await allPromptsFile.writeAsString(buffer.toString());
  //     return true;
  //   } catch (e) {
  //     print('Error generating all prompts: $e');
  //     return false;
  //   }
  // }
}