import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Companion/ai_model.dart';

/// Supabase-native TTS service using Azure Cognitive Services
/// Optimized for your existing tech stack and database structure
class SupabaseTTSService {
  static final SupabaseTTSService _instance = SupabaseTTSService._internal();
  factory SupabaseTTSService() => _instance;
  SupabaseTTSService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Azure TTS Configuration (best value for your use case)
  String? _azureApiKey;
  String? _azureRegion;
  bool _isInitialized = false;

  /// Initialize TTS service with API keys
  Future<void> initialize({
    String? azureApiKey,
    String? azureRegion,
  }) async {
    _azureApiKey = azureApiKey;
    _azureRegion = azureRegion;
    
    // Test Azure TTS availability
    if (_azureApiKey != null && _azureRegion != null) {
      try {
        await _testAzureTTS();
        _isInitialized = true;
        debugPrint('✅ Azure TTS initialized successfully');
      } catch (e) {
        debugPrint('❌ Azure TTS initialization failed: $e');
      }
    }
  }

  /// Test Azure TTS connection
  Future<void> _testAzureTTS() async {
    final url = 'https://$_azureRegion.tts.speech.microsoft.com/cognitiveservices/voices/list';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Ocp-Apim-Subscription-Key': _azureApiKey!,
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Azure TTS test failed: ${response.statusCode}');
    }
  }

  /// Synthesize speech with companion-specific voice profile
  Future<VoiceSynthesisResult> synthesizeSpeech({
    required String text,
    required AICompanion companion,
    EmotionalContext? emotion,
  }) async {
    if (!_isInitialized) {
      throw Exception('TTS service not initialized. Call initialize() first.');
    }

    try {
      // Get companion-specific voice profile
      final voiceProfile = _getCompanionVoiceProfile(companion);
      
      // Generate SSML with emotional context
      final ssml = _generateSSML(text, voiceProfile, emotion);
      
      // Synthesize with Azure TTS
      final audioData = await _synthesizeWithAzure(ssml, voiceProfile);
      
      // Upload to Supabase Storage
      final audioUrl = await _uploadAudioToSupabase(audioData, companion.id);
      
      return VoiceSynthesisResult(
        audioData: audioData,
        audioUrl: audioUrl,
        duration: _estimateAudioDuration(text, voiceProfile.speechRate),
        voiceProfile: voiceProfile,
        emotion: emotion,
        success: true,
      );
      
    } catch (e) {
      debugPrint('❌ TTS synthesis failed: $e');
      return VoiceSynthesisResult(
        audioData: Uint8List(0),
        audioUrl: null,
        duration: 0,
        voiceProfile: _getDefaultVoiceProfile(),
        emotion: emotion,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Synthesize with Azure Cognitive Services TTS
  Future<Uint8List> _synthesizeWithAzure(String ssml, CompanionVoiceProfile profile) async {
    final url = 'https://$_azureRegion.tts.speech.microsoft.com/cognitiveservices/v1';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Ocp-Apim-Subscription-Key': _azureApiKey!,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        'User-Agent': 'AI-Companion-App',
      },
      body: utf8.encode(ssml),
    );
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Azure TTS synthesis failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Upload synthesized audio to Supabase Storage
  Future<String?> _uploadAudioToSupabase(Uint8List audioData, String companionId) async {
    try {
      final fileName = 'voice_${companionId}_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final path = 'voice-messages/$fileName';
      
      await _supabase.storage
          .from('chat-audio')
          .uploadBinary(path, audioData);
      
      final publicUrl = _supabase.storage
          .from('chat-audio')
          .getPublicUrl(path);
      
      return publicUrl;
      
    } catch (e) {
      debugPrint('❌ Audio upload failed: $e');
      return null;
    }
  }

  /// Generate SSML for Azure TTS with companion personality
  String _generateSSML(String text, CompanionVoiceProfile profile, EmotionalContext? emotion) {
    // Escape XML special characters
    final escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    // Apply emotional modulation
    var pitch = profile.pitch;
    var rate = profile.speechRate;
    var volume = profile.volume;

    if (emotion != null) {
      switch (emotion.primaryEmotion) {
        case VoiceEmotion.happiness:
          pitch += 0.1 * emotion.intensity;
          rate += 0.1 * emotion.intensity;
          break;
        case VoiceEmotion.sadness:
          pitch -= 0.2 * emotion.intensity;
          rate -= 0.15 * emotion.intensity;
          break;
        case VoiceEmotion.excitement:
          pitch += 0.15 * emotion.intensity;
          rate += 0.2 * emotion.intensity;
          volume += 0.1 * emotion.intensity;
          break;
        case VoiceEmotion.empathy:
          rate -= 0.1 * emotion.intensity;
          volume -= 0.05 * emotion.intensity;
          break;
        case VoiceEmotion.curiosity:
          pitch += 0.05 * emotion.intensity;
          break;
        default:
          break;
      }
    }

    // Clamp values to valid ranges
    pitch = pitch.clamp(0.5, 2.0);
    rate = rate.clamp(0.5, 2.0);
    volume = volume.clamp(0.1, 1.0);

    return '''
<speak version="1.0" xml:lang="${profile.language}">
  <voice name="${profile.voiceName}">
    <prosody 
      pitch="${_formatProsodyValue(pitch)}" 
      rate="${_formatProsodyValue(rate)}" 
      volume="${_formatVolumeValue(volume)}">
      $escapedText
    </prosody>
  </voice>
</speak>
    '''.trim();
  }

  /// Format prosody values for SSML
  String _formatProsodyValue(double value) {
    if (value == 1.0) return 'default';
    if (value > 1.0) return '+${((value - 1.0) * 100).round()}%';
    return '-${((1.0 - value) * 100).round()}%';
  }

  /// Format volume values for SSML
  String _formatVolumeValue(double value) {
    if (value == 1.0) return 'default';
    return '${(value * 100).round()}%';
  }

  /// Get companion-specific voice profile
  CompanionVoiceProfile _getCompanionVoiceProfile(AICompanion companion) {
    // Use companion's voice characteristics or defaults
    final voiceData = companion.voice.isNotEmpty ? companion.voice.first : '';
    
    switch (companion.id.toLowerCase()) {
      case 'emma':
        return CompanionVoiceProfile(
          companionId: companion.id,
          name: companion.name,
          voiceName: 'en-US-AriaNeural',
          language: 'en-US',
          pitch: 1.1,
          speechRate: 0.95,
          volume: 1.0,
          style: 'friendly',
          characteristics: voiceData,
        );
      
      case 'alex':
        return CompanionVoiceProfile(
          companionId: companion.id,
          name: companion.name,
          voiceName: 'en-US-GuyNeural',
          language: 'en-US',
          pitch: 0.9,
          speechRate: 1.05,
          volume: 1.0,
          style: 'casual',
          characteristics: voiceData,
        );
      
      case 'sophia':
        return CompanionVoiceProfile(
          companionId: companion.id,
          name: companion.name,
          voiceName: 'en-GB-LibbyNeural',
          language: 'en-GB',
          pitch: 1.05,
          speechRate: 0.9,
          volume: 0.95,
          style: 'conversational',
          characteristics: voiceData,
        );
      
      default:
        return _getDefaultVoiceProfile();
    }
  }

  /// Get default voice profile
  CompanionVoiceProfile _getDefaultVoiceProfile() {
    return CompanionVoiceProfile(
      companionId: 'default',
      name: 'Default',
      voiceName: 'en-US-JennyNeural',
      language: 'en-US',
      pitch: 1.0,
      speechRate: 1.0,
      volume: 1.0,
      style: 'default',
      characteristics: '',
    );
  }

  /// Estimate audio duration based on text length and speech rate
  double _estimateAudioDuration(String text, double speechRate) {
    // Average speaking rate is ~150 words per minute
    // Adjusted for speech rate setting
    const averageWpm = 150.0;
    final words = text.split(' ').length;
    final baseMinutes = words / averageWpm;
    final adjustedMinutes = baseMinutes / speechRate;
    return adjustedMinutes * 60; // Convert to seconds
  }

  /// Check if service is available
  bool get isAvailable => _isInitialized;
  
  /// Get supported voice list for a companion
  Future<List<String>> getSupportedVoices(String companionId) async {
    // Return companion-specific voice options
    switch (companionId.toLowerCase()) {
      case 'emma':
        return ['en-US-AriaNeural', 'en-US-JennyNeural', 'en-US-NancyNeural'];
      case 'alex':
        return ['en-US-GuyNeural', 'en-US-DavisNeural', 'en-US-JasonNeural'];
      case 'sophia':
        return ['en-GB-LibbyNeural', 'en-GB-MaisieNeural', 'en-GB-SoniaNeural'];
      default:
        return ['en-US-JennyNeural'];
    }
  }
}

/// Voice synthesis result
class VoiceSynthesisResult {
  final Uint8List audioData;
  final String? audioUrl; // Supabase Storage URL
  final double duration; // Duration in seconds
  final CompanionVoiceProfile voiceProfile;
  final EmotionalContext? emotion;
  final bool success;
  final String? error;

  const VoiceSynthesisResult({
    required this.audioData,
    required this.audioUrl,
    required this.duration,
    required this.voiceProfile,
    required this.emotion,
    required this.success,
    this.error,
  });
}

/// Companion voice profile for TTS
class CompanionVoiceProfile {
  final String companionId;
  final String name;
  final String voiceName; // Azure voice name
  final String language;
  final double pitch; // 0.5 - 2.0
  final double speechRate; // 0.5 - 2.0
  final double volume; // 0.1 - 1.0
  final String style; // friendly, casual, conversational, etc.
  final String characteristics; // Voice description from companion

  const CompanionVoiceProfile({
    required this.companionId,
    required this.name,
    required this.voiceName,
    required this.language,
    required this.pitch,
    required this.speechRate,
    required this.volume,
    required this.style,
    required this.characteristics,
  });
}

/// Emotional context for voice synthesis
class EmotionalContext {
  final VoiceEmotion primaryEmotion;
  final double intensity; // 0.0 - 1.0
  final List<VoiceEmotion> secondaryEmotions;

  const EmotionalContext({
    required this.primaryEmotion,
    required this.intensity,
    this.secondaryEmotions = const [],
  });
}

/// Voice emotions
enum VoiceEmotion {
  neutral,
  happiness,
  sadness,
  excitement,
  empathy,
  curiosity,
  surprise,
  concern,
}
