// lib/services/image_prompt_service.dart
import 'dart:io';
import 'package:ai_companion/Companion/ai_model.dart';

class ImagePromptService {
  
  static Future<bool> savePromptToFile(AICompanion companion) async {
    try {
      final prompt = createPrompt(companion);
      final directory = Directory('${Directory.current.path}/lib/AI');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${Directory.current.path}/lib/AI/imagePrompt_${companion.name}.txt');
      await file.writeAsString(prompt);
      return true;
    } catch (e) {
      print('Error saving prompt: $e');
      return false;
    }
  }
  
  static String createPrompt(AICompanion companion) {
    final physical = companion.physical;
    final personality = companion.personality;
    
    return '''
=== Image Generation Prompt for ${companion.name} ===

A ${physical.age} year old ${companion.gender.toString().split('.').last}, 
${physical.height} tall with ${physical.bodyType} build. 
${physical.hairColor} hair and ${physical.eyeColor} eyes. 
Style: ${physical.style}
Distinguishing features: ${physical.distinguishingFeatures.join(', ')}

Personality expressed through: 
Primary traits: ${personality.primaryTraits.join(', ')}
Secondary traits: ${personality.secondaryTraits.join(', ')}
Expression: ${_getExpressionFromTraits(personality.primaryTraits)}

Technical specifications:
- Art style: ${companion.artStyle.toString().split('.').last}
- Lighting: Soft, natural lighting
- Composition: Portrait or three-quarter shot
- Background: Clean setting reflecting personality
- Details: Focus on distinguishing features

Negative prompts:
- No exaggerated features
- No unrealistic proportions
- No cluttered background
- No artificial poses
''';
  }
  
  static String _getExpressionFromTraits(List<String> traits) {
    if (traits.contains('Cheerful') || traits.contains('Optimistic')) {
      return 'Warm, genuine smile';
    } else if (traits.contains('Serious') || traits.contains('Professional')) {
      return 'Composed, thoughtful expression';
    } else if (traits.contains('Creative') || traits.contains('Artistic')) {
      return 'Inspired, engaged look';
    }
    return 'Natural, relaxed expression';
  }
}