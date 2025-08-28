import 'dart:async';
import '../gemini/gemini_service.dart';
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
    required AICompanion companion,
    EmotionalContext? currentEmotion,
  }) async {
    try {
      // CORRECTED: Since we're using the existing chat session, the full conversation
      // context (text + voice) is ALREADY available in the session.
      // No need to send additional context - this would be redundant and wasteful!
      
      // Only enhance the user message with emotional context if present
      final enhancedUserMessage = _enhanceUserMessageOnly(userMessage, currentEmotion);
      
      // Use existing GeminiService generateResponse method with voice mode enabled
      // The session already contains full conversation history and voice instructions
      final response = await _geminiService.generateResponse(enhancedUserMessage, isVoiceMode: true);
      
      return response;
      
    } catch (e) {
      rethrow;
    }
  }

  /// Generate voice conversation summary with companion-specific context
  Future<String> generateVoiceConversationSummary({
    required List<String> conversationFragments,
    required AICompanion companion,
  }) async {
    try {
      if (conversationFragments.isEmpty) return 'Empty voice conversation';

      final conversationText = conversationFragments.join('\n');
      
      // Build voice-specific summary prompt
      final summaryPrompt = _buildVoiceSummaryPrompt(
        conversationText: conversationText,
        companion: companion,
      );
      
      // Use GeminiService but with voice-specific instructions
      final summary = await _geminiService.generateResponse(summaryPrompt, isVoiceMode: false);
      
      return _refineSummaryForVoice(summary, companion);
      
    } catch (e) {
      throw Exception('Voice conversation summary generation failed: $e');
    }
  }

  /// Build voice-specific summary prompt
  String _buildVoiceSummaryPrompt({
    required String conversationText,
    required AICompanion companion,
  }) {

    return '''
You are summarizing a VOICE conversation between a user and ${companion.name}, an AI companion with these characteristics:
- Personality: ${companion.personality.primaryTraits.join(', ')}
- Communication Style: ${companion.voice.join(', ')}
- Background: ${companion.background.take(2).join(', ')}

VOICE CONVERSATION ANALYSIS:
Focus on these voice-specific elements:
1. **Emotional Tone & Atmosphere**: How did the conversation feel? What emotions were expressed?
2. **Key Topics & Information**: Main subjects discussed and important details shared
3. **User Personality Insights**: What did you learn about the user's character, preferences, communication style?
4. **Relationship Development**: How did the connection between user and ${companion.name} evolve?
5. **${companion.name}'s Response Style**: How did ${companion.name} adapt their voice and personality?
6. **Context for Future Conversations**: Critical information that should influence future interactions

CONVERSATION TRANSCRIPT:
$conversationText

Create a comprehensive summary (150-200 words) that captures both the content and the emotional essence of this voice interaction. Focus on elements that will help ${companion.name} maintain continuity and deepen the relationship in future voice conversations.

SUMMARY:''';
  }

  /// Refine summary for voice conversation context
  String _refineSummaryForVoice(String rawSummary, AICompanion companion) {
    // Remove any technical artifacts
    String refined = rawSummary
        .replaceAll(RegExp(r'```\w*'), '')
        .replaceAll('SUMMARY:', '')
        .trim();
    
    // Ensure summary mentions voice context if missing
    if (!refined.toLowerCase().contains('voice') && 
        !refined.toLowerCase().contains('conversation') &&
        !refined.toLowerCase().contains('spoke')) {
      refined = 'Voice conversation: $refined';
    }
    
    // Add companion context if not present
    if (!refined.contains(companion.name)) {
      refined = '$refined [Conversation with ${companion.name}]';
    }
    
    return refined;
  }

  /// Enhance ONLY the user message with emotional context (no redundant history)
  String _enhanceUserMessageOnly(String userMessage, EmotionalContext? emotion) {
    // Add emotional context if available
    if (emotion != null) {
      final emotionDesc = _getEmotionDescription(emotion);
      return '[User speaking with $emotionDesc] $userMessage';
    }
    
    return userMessage;
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

  /// Get companion-specific voice characteristics from their voice field
  String _getCompanionVoiceCharacteristics(AICompanion companion) {
    if (companion.voice.isEmpty) {
      return '''
- Natural conversational speaking style
- Balanced tone and pace
- Uses clear, friendly language
- Adapts to conversation mood
''';
    }
    
    // Format the voice characteristics as bullet points for instructions
    final characteristics = companion.voice.map((char) => '- $char').join('\n');
    
    return '''
$characteristics

Voice Style Notes:
- Speaks naturally reflecting these characteristics
- Adapts tone and delivery to match personality
- Maintains authentic voice throughout conversation
''';
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

  /// Get companion's voice style instructions from their voice characteristics
  String getCompanionVoiceStyle(AICompanion companion) {
    if (companion.voice.isEmpty) {
      return 'Natural, friendly conversational style';
    }
    
    return '''
${companion.name}'s Voice Style:
${companion.voice.map((char) => '- $char').join('\n')}

Voice Delivery Notes:
- Maintains authentic personality through speech
- Adapts tone naturally to conversation context
- Uses voice characteristics consistently throughout interaction
''';
  }

  /// Check if GeminiService is available
  bool get isAvailable => true; // Uses existing GeminiService

  /// Clean up resources
  void dispose() {
    // GeminiService handles its own cleanup as singleton
  }
}
