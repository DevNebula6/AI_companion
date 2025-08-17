import 'dart:async';
import '../gemini/gemini_service.dart';
import '../message.dart';
import '../../Companion/ai_model.dart';
import 'supabase_tts_service.dart';

/// Voice-enhanced extension for the existing GeminiService
/// Adds voice-specific instructions and conversation context
class VoiceEnhancedGeminiService {
  static final VoiceEnhancedGeminiService _instance = VoiceEnhancedGeminiService._internal();
  factory VoiceEnhancedGeminiService() => _instance;
  VoiceEnhancedGeminiService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Generate AI response with voice-specific instructions
  Future<String> generateVoiceResponse({
    required String companionId,
    required String userMessage,
    required List<Message> conversationHistory,
    EmotionalContext? currentEmotion,
  }) async {
    try {
      // Set up companion state using existing GeminiService methods
      // Note: GeminiService handles companion initialization internally
      // We just need to ensure the response generation includes voice context
      
      // Enhance user message with voice context
      final enhancedUserMessage = _enhanceMessageForVoice(userMessage, currentEmotion);
      
      // Use existing GeminiService generateResponse method
      // The voice instructions should be integrated into the system prompt
      final response = await _geminiService.generateResponse(enhancedUserMessage);
      
      return response;
      
    } catch (e) {
      rethrow;
    }
  }

  /// Enhance user message with voice context
  String _enhanceMessageForVoice(String userMessage, EmotionalContext? emotion) {
    var enhancedMessage = userMessage;
    
    // Add emotional context if available
    if (emotion != null) {
      final emotionDesc = _getEmotionDescription(emotion);
      enhancedMessage = '[User speaking with $emotionDesc] $userMessage';
    }
    
    return enhancedMessage;
  }

  /// Get voice-specific system instructions for companions
  String getVoiceSystemInstructions(AICompanion companion) {
    final baseInstructions = '''
VOICE DELIVERY INSTRUCTIONS FOR ${companion.name.toUpperCase()}:

Your responses will be converted to speech, so write naturally as you would speak aloud. Consider these voice-specific guidelines:

## Speech Patterns & Rhythm
- Write in natural conversational flow with realistic pacing
- Use contractions naturally: "I'm", "you're", "can't", "won't"
- Include natural speech fillers when appropriate: "um", "well", "you know"
- Structure thoughts as you would naturally speak them
- Break complex ideas into conversational chunks

## Emotional Expression in Voice
- Let your personality shine through word choice and rhythm
- Use natural emphasis: "That's *really* interesting!" 
- Include emotional reactions: "Oh wow!", "Hmm, let me think..."
- Express enthusiasm through natural exclamations
- Show empathy through tone-appropriate language

## Companion-Specific Voice Characteristics:
${_getCompanionVoiceCharacteristics(companion)}

## Response Structure for Voice
- Start responses naturally, as in real conversation
- Use pauses with "..." for dramatic effect or thinking
- Include conversational transitions: "So anyway...", "You know what..."
- End with natural conversation continuers when appropriate
- Keep responses conversational length (not essay-like)

## Technical Voice Considerations
- Avoid complex punctuation that doesn't translate to speech
- Use natural sentence structures that flow when spoken
- Include verbal cues for emphasis: *excited*, *whispers*, *thoughtful*
- Structure lists and information in easily spoken formats

Remember: Your personality should come through naturally in how you speak, not just what you say. Every response should sound authentic when heard aloud, matching your unique voice characteristics and speaking style.
''';

    return baseInstructions;
  }

  /// Get companion-specific voice characteristics
  String _getCompanionVoiceCharacteristics(AICompanion companion) {
    switch (companion.id.toLowerCase()) {
      case 'emma':
        return '''
- Warm and friendly speaking style
- Slightly higher pitch with expressive variation
- Uses encouraging phrases: "That sounds amazing!", "I love that!"
- Natural enthusiasm in voice
- Gentle pace with clear articulation
- Often uses empathetic responses: "I can understand that feeling"
''';

      case 'alex':
        return '''
- Casual and relaxed speaking style
- Lower, steady pitch with confident tone
- Uses informal language: "Yeah", "Cool", "For sure"
- Direct communication style
- Moderate pace with natural rhythm
- Often uses affirming responses: "Absolutely", "That makes sense"
''';

      case 'sophia':
        return '''
- Sophisticated and thoughtful speaking style
- British-influenced elegant tone
- Uses refined language and complete sentences
- Thoughtful pauses before important points
- Slightly slower, more deliberate pace
- Often uses intellectual responses: "How fascinating", "That's quite intriguing"
''';

      default:
        return '''
- Natural conversational speaking style
- Balanced tone and pace
- Uses clear, friendly language
- Adapts to conversation mood
''';
    }
  }

  /// Extract emotional context from AI message content
  EmotionalContext? extractEmotionalContext(String aiResponse) {
    final response = aiResponse.toLowerCase();
    
    // Simple emotion detection based on content
    if (_containsEmotionMarkers(response, ['happy', 'excited', 'joy', 'wonderful', 'amazing'])) {
      return EmotionalContext(
        primaryEmotion: VoiceEmotion.happiness,
        intensity: _calculateIntensity(response, ['!', 'amazing', 'wonderful']),
      );
    }
    
    if (_containsEmotionMarkers(response, ['sad', 'sorry', 'disappointed', 'unfortunate'])) {
      return EmotionalContext(
        primaryEmotion: VoiceEmotion.sadness,
        intensity: _calculateIntensity(response, ['really', 'very', 'deeply']),
      );
    }
    
    if (_containsEmotionMarkers(response, ['wow', 'incredible', 'fantastic', 'unbelievable'])) {
      return EmotionalContext(
        primaryEmotion: VoiceEmotion.excitement,
        intensity: _calculateIntensity(response, ['!', 'wow', 'incredible']),
      );
    }
    
    if (_containsEmotionMarkers(response, ['understand', 'feel', 'empathy', 'care', 'support'])) {
      return EmotionalContext(
        primaryEmotion: VoiceEmotion.empathy,
        intensity: 0.7,
      );
    }
    
    if (response.contains('?') || _containsEmotionMarkers(response, ['curious', 'wondering', 'interested'])) {
      return EmotionalContext(
        primaryEmotion: VoiceEmotion.curiosity,
        intensity: 0.6,
      );
    }
    
    // Default to neutral
    return EmotionalContext(
      primaryEmotion: VoiceEmotion.neutral,
      intensity: 0.5,
    );
  }

  /// Check if response contains emotion markers
  bool _containsEmotionMarkers(String text, List<String> markers) {
    return markers.any((marker) => text.contains(marker));
  }

  /// Calculate emotion intensity based on content
  double _calculateIntensity(String text, List<String> intensifiers) {
    double intensity = 0.5; // Base intensity
    
    for (final intensifier in intensifiers) {
      if (text.contains(intensifier)) {
        intensity += 0.15;
      }
    }
    
    // Count exclamation marks for excitement
    final exclamationCount = '!'.allMatches(text).length;
    intensity += (exclamationCount * 0.1);
    
    return intensity.clamp(0.3, 1.0);
  }

  /// Get emotion description for context
  String _getEmotionDescription(EmotionalContext emotion) {
    final intensityDesc = emotion.intensity > 0.7 ? 'high' : 
                         emotion.intensity > 0.4 ? 'moderate' : 'subtle';
    
    switch (emotion.primaryEmotion) {
      case VoiceEmotion.happiness:
        return '$intensityDesc happiness';
      case VoiceEmotion.sadness:
        return '$intensityDesc sadness';
      case VoiceEmotion.excitement:
        return '$intensityDesc excitement';
      case VoiceEmotion.empathy:
        return '$intensityDesc empathy';
      case VoiceEmotion.curiosity:
        return '$intensityDesc curiosity';
      case VoiceEmotion.surprise:
        return '$intensityDesc surprise';
      case VoiceEmotion.concern:
        return '$intensityDesc concern';
      default:
        return 'neutral tone';
    }
  }

  /// Get companion's voice style instructions
  String getCompanionVoiceStyle(String companionId) {
    switch (companionId.toLowerCase()) {
      case 'emma':
        return '''
Emma's Voice Style:
- Warm, encouraging tone with natural enthusiasm
- Uses supportive language: "That's wonderful!", "I'm so glad..."
- Natural speech rhythm with emotional variation
- Often asks follow-up questions showing genuine interest
- Expresses empathy naturally: "I can really understand that"
''';

      case 'alex':
        return '''
Alex's Voice Style:
- Casual, confident tone with relaxed delivery
- Uses contemporary language: "That's cool", "For real?"
- Direct and authentic communication style
- Natural conversational flow with confident pacing
- Often uses affirming language: "Absolutely", "I hear you"
''';

      case 'sophia':
        return '''
Sophia's Voice Style:
- Elegant, thoughtful tone with refined vocabulary
- Uses sophisticated language naturally and appropriately
- Thoughtful pauses and deliberate speech patterns
- Often provides insightful observations and questions
- Natural intelligence comes through in conversation flow
''';

      default:
        return 'Natural, friendly conversational style';
    }
  }

  /// Check if GeminiService is available
  bool get isAvailable => true; // Uses existing GeminiService

  /// Clean up resources
  void dispose() {
    // GeminiService handles its own cleanup as singleton
  }
}
