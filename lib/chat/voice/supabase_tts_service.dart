import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../Companion/ai_model.dart';
import 'azure_voice_characteristics.dart';

/// Supabase-native TTS service using Azure Cognitive Services
/// Optimized for your existing tech stack and database structure
class SupabaseTTSService {
  static final SupabaseTTSService _instance = SupabaseTTSService._internal();
  factory SupabaseTTSService() => _instance;
  SupabaseTTSService._internal();

  // Azure TTS Configuration
  String? _azureApiKey;
  String? _azureRegion;
  bool _isInitialized = false;

  /// Initialize TTS service with API keys
  Future<void> initialize({
    String? azureApiKey,
    String? azureRegion,
  }) async {
    debugPrint('🔄 Initializing TTS service...');
    debugPrint('📊 Azure API Key: ${azureApiKey != null ? '[SET]' : '[MISSING]'}');
    debugPrint('📊 Azure Region: ${azureRegion ?? '[MISSING]'}');
    
    _azureApiKey = azureApiKey;
    _azureRegion = azureRegion;
    
    // Test Azure TTS availability
    if (_azureApiKey != null && _azureRegion != null) {
      try {
        debugPrint('🔍 Testing Azure TTS connection...');
        await _testAzureTTS();
        _isInitialized = true;
        debugPrint('✅ Azure TTS initialized successfully');
      } catch (e) {
        debugPrint('❌ Azure TTS initialization failed: $e');
        debugPrint('📊 Will try to initialize again on first use');
      }
    } else {
      debugPrint('❌ Azure TTS credentials missing - service disabled');
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

  /// Synthesize speech for direct playback (no storage)
  Future<VoiceSynthesisResult> synthesizeSpeech({
    required String text,
    required AICompanion companion,
    EmotionalContext? emotion,
  }) async {
    if (!_isInitialized) {
      throw Exception('TTS service not initialized. Call initialize() first.');
    }

    try {
      // Get Azure voice characteristics from companion
      final azureVoiceConfig = companion.azureVoiceConfig;
      
      if (azureVoiceConfig != null) {
        // Use companion's specific Azure voice configuration
        final ssml = azureVoiceConfig.generateSSML(text, 
          contextualEmotion: _mapEmotionToContext(emotion));
        final audioData = await _synthesizeWithAzureSSML(ssml);
        
        return VoiceSynthesisResult(
          audioData: audioData,
          duration: _estimateAudioDuration(text, azureVoiceConfig.baseSpeechRate / 100.0),
          azureVoiceConfig: azureVoiceConfig,
          emotion: emotion,
          success: true,
        );
      } else {
        // Fallback to default Azure config based on companion gender
        final defaultConfig = _getDefaultAzureConfigByGender(companion.gender);
        final ssml = defaultConfig.generateSSML(text, 
          contextualEmotion: _mapEmotionToContext(emotion));
        final audioData = await _synthesizeWithAzureSSML(ssml);
        
        return VoiceSynthesisResult(
          audioData: audioData,
          duration: _estimateAudioDuration(text, defaultConfig.baseSpeechRate / 100.0),
          azureVoiceConfig: defaultConfig,
          emotion: emotion,
          success: true,
        );
      }
      
    } catch (e) {
      debugPrint('❌ TTS synthesis failed: $e');
      return VoiceSynthesisResult(
        audioData: Uint8List(0),
        duration: 0,
        azureVoiceConfig: null,
        emotion: emotion,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Synthesize with Azure TTS using pre-generated SSML
  Future<Uint8List> _synthesizeWithAzureSSML(String ssml) async {
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

  /// Map emotion context to string for Azure voice characteristics
  String? _mapEmotionToContext(EmotionalContext? emotion) {
    if (emotion == null) return null;
    
    switch (emotion.primaryEmotion) {
      case VoiceEmotion.happiness:
        return 'happiness';
      case VoiceEmotion.sadness:
        return 'sadness';
      case VoiceEmotion.excitement:
        return 'excitement';
      case VoiceEmotion.empathy:
        return 'empathy';
      case VoiceEmotion.curiosity:
        return 'curiosity';
      case VoiceEmotion.surprise:
        return 'surprise';
      case VoiceEmotion.concern:
        return 'concern';
      default:
        return null;
    }
  }

  /// Get default Azure voice configuration based on companion gender
  AzureVoiceCharacteristics _getDefaultAzureConfigByGender(CompanionGender gender) {
    switch (gender) {
      case CompanionGender.female:
        return AzureVoiceCharacteristics(
          azureVoiceName: 'en-US-AriaNeural',
          languageCode: 'en-US',
          basePitch: 5.0,
          baseSpeechRate: 0.0,
          baseVolume: 95.0,
          voiceStyle: 'friendly',
          styleDegree: 1.1,
        );
      case CompanionGender.male:
        return AzureVoiceCharacteristics(
          azureVoiceName: 'en-US-GuyNeural',
          languageCode: 'en-US',
          basePitch: -5.0,
          baseSpeechRate: 0.0,
          baseVolume: 100.0,
          voiceStyle: 'conversational',
          styleDegree: 1.0,
        );
      case CompanionGender.other:
        return AzureVoiceCharacteristics(
          azureVoiceName: 'en-US-JennyNeural',
          languageCode: 'en-US',
          basePitch: 0.0,
          baseSpeechRate: 0.0,
          baseVolume: 95.0,
          voiceStyle: 'conversational',
          styleDegree: 1.0,
        );
    }
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
  bool get isAvailable {
    // If not initialized but we have credentials, try to initialize
    if (!_isInitialized && _azureApiKey != null && _azureRegion != null) {
      debugPrint('🔄 TTS not initialized, attempting lazy initialization...');
      // Trigger async initialization (fire and forget)
      _attemptLazyInitialization();
    }
    return _isInitialized;
  }
  
  /// Attempt lazy initialization without blocking
  void _attemptLazyInitialization() async {
    try {
      await _testAzureTTS();
      _isInitialized = true;
      debugPrint('✅ Azure TTS lazy initialization successful');
    } catch (e) {
      debugPrint('❌ Azure TTS lazy initialization failed: $e');
    }
  }
}

/// Voice synthesis result (updated for direct playback)
class VoiceSynthesisResult {
  final Uint8List audioData;
  final double duration; // Duration in seconds
  final AzureVoiceCharacteristics? azureVoiceConfig;
  final EmotionalContext? emotion;
  final bool success;
  final String? error;

  const VoiceSynthesisResult({
    required this.audioData,
    required this.duration,
    required this.azureVoiceConfig,
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
