/// Enhanced companion voice profiles with distinct characteristics
/// Supports multiple TTS engines and custom voice synthesis
class CompanionVoiceManager {
  static final CompanionVoiceManager _instance = CompanionVoiceManager._internal();
  factory CompanionVoiceManager() => _instance;
  CompanionVoiceManager._internal();
  
  final Map<String, EnhancedVoiceProfile> _voiceProfiles = {};
  
  /// Initialize voice profiles for all companions
  void initializeVoiceProfiles() {
    // Example companion voice profiles - customize for your companions
    _voiceProfiles['emma'] = EnhancedVoiceProfile(
      companionId: 'emma',
      name: 'Emma',
      baseVoice: 'en-US-AriaNeural', // Azure TTS voice
      characteristics: VoiceCharacteristics(
        pitch: 1.1, // Slightly higher pitch - friendly and approachable
        speechRate: 0.95, // Slightly slower - thoughtful and careful
        volume: 0.9,
        breathiness: 0.3, // Soft, warm quality
        roughness: 0.1, // Very smooth voice
        warmth: 0.8, // High warmth - caring companion
        confidence: 0.7, // Moderately confident
        playfulness: 0.6, // Some playful qualities
      ),
      emotionalRange: EmotionalVoiceRange(
        happiness: VoiceEmotion(pitchShift: 0.15, tempoShift: 0.1, volumeShift: 0.1),
        sadness: VoiceEmotion(pitchShift: -0.1, tempoShift: -0.15, volumeShift: -0.1),
        excitement: VoiceEmotion(pitchShift: 0.2, tempoShift: 0.2, volumeShift: 0.15),
        empathy: VoiceEmotion(pitchShift: -0.05, tempoShift: -0.1, volumeShift: -0.05),
        curiosity: VoiceEmotion(pitchShift: 0.1, tempoShift: 0.05, volumeShift: 0.05),
      ),
      fallbackEngine: TTSEngine.flutterTTS,
      customSSML: _getEmmaSSMLTemplate(),
    );
    
    _voiceProfiles['alex'] = EnhancedVoiceProfile(
      companionId: 'alex',
      name: 'Alex',
      baseVoice: 'en-US-GuyNeural',
      characteristics: VoiceCharacteristics(
        pitch: 0.9, // Lower pitch - more authoritative
        speechRate: 1.1, // Faster - energetic and dynamic
        volume: 1.0,
        breathiness: 0.1, // Clear, crisp voice
        roughness: 0.2, // Slight texture
        warmth: 0.6, // Moderate warmth
        confidence: 0.9, // High confidence
        playfulness: 0.8, // Very playful
      ),
      emotionalRange: EmotionalVoiceRange(
        happiness: VoiceEmotion(pitchShift: 0.1, tempoShift: 0.15, volumeShift: 0.1),
        sadness: VoiceEmotion(pitchShift: -0.15, tempoShift: -0.2, volumeShift: -0.15),
        excitement: VoiceEmotion(pitchShift: 0.25, tempoShift: 0.25, volumeShift: 0.2),
        empathy: VoiceEmotion(pitchShift: -0.1, tempoShift: -0.15, volumeShift: -0.1),
        curiosity: VoiceEmotion(pitchShift: 0.15, tempoShift: 0.1, volumeShift: 0.1),
      ),
      fallbackEngine: TTSEngine.flutterTTS,
      customSSML: _getAlexSSMLTemplate(),
    );
    
    _voiceProfiles['sophia'] = EnhancedVoiceProfile(
      companionId: 'sophia',
      name: 'Sophia',
      baseVoice: 'en-GB-LibbyNeural', // British accent
      characteristics: VoiceCharacteristics(
        pitch: 1.05, // Refined pitch
        speechRate: 0.9, // Measured, thoughtful pace
        volume: 0.95,
        breathiness: 0.2, // Slight breathiness for sophistication
        roughness: 0.05, // Very smooth
        warmth: 0.7, // Warm but professional
        confidence: 0.95, // Very confident
        playfulness: 0.3, // More serious, less playful
      ),
      emotionalRange: EmotionalVoiceRange(
        happiness: VoiceEmotion(pitchShift: 0.1, tempoShift: 0.05, volumeShift: 0.05),
        sadness: VoiceEmotion(pitchShift: -0.1, tempoShift: -0.1, volumeShift: -0.1),
        excitement: VoiceEmotion(pitchShift: 0.15, tempoShift: 0.1, volumeShift: 0.1),
        empathy: VoiceEmotion(pitchShift: -0.05, tempoShift: -0.05, volumeShift: 0.0),
        curiosity: VoiceEmotion(pitchShift: 0.08, tempoShift: 0.0, volumeShift: 0.0),
      ),
      fallbackEngine: TTSEngine.flutterTTS,
      customSSML: _getSophiaSSMLTemplate(),
    );
  }
  
  /// Get voice profile for a specific companion
  EnhancedVoiceProfile? getVoiceProfile(String companionId) {
    return _voiceProfiles[companionId];
  }
  
  /// Apply voice profile with emotional context
  VoiceSettings getVoiceSettings(String companionId, {EmotionalContext? emotion, String? text}) {
    final profile = _voiceProfiles[companionId];
    if (profile == null) return VoiceSettings.defaultSettings();
    
    // Base settings from profile
    var settings = VoiceSettings(
      voice: profile.baseVoice,
      pitch: profile.characteristics.pitch,
      speechRate: profile.characteristics.speechRate,
      volume: profile.characteristics.volume,
      language: profile.language,
      engine: profile.fallbackEngine,
    );
    
    // Apply emotional modifications
    if (emotion != null) {
      settings = _applyEmotionalModulation(settings, profile, emotion);
    }
    
    // Apply text-based contextual adjustments
    if (text != null) {
      settings = _applyContextualAdjustments(settings, profile, text);
    }
    
    return settings;
  }
  
  /// Apply emotional modulation to voice settings
  VoiceSettings _applyEmotionalModulation(
    VoiceSettings baseSettings, 
    EnhancedVoiceProfile profile, 
    EmotionalContext emotion
  ) {
    VoiceEmotion? emotionMod;
    
    switch (emotion.primaryEmotion) {
      case Emotion.happiness:
        emotionMod = profile.emotionalRange.happiness;
        break;
      case Emotion.sadness:
        emotionMod = profile.emotionalRange.sadness;
        break;
      case Emotion.excitement:
        emotionMod = profile.emotionalRange.excitement;
        break;
      case Emotion.empathy:
        emotionMod = profile.emotionalRange.empathy;
        break;
      case Emotion.curiosity:
        emotionMod = profile.emotionalRange.curiosity;
        break;
      default:
        return baseSettings;
    }
    
    if (emotionMod == null) return baseSettings;
    
    // Apply modulation with intensity scaling
    final intensity = emotion.intensity.clamp(0.0, 1.0);
    
    return baseSettings.copyWith(
      pitch: (baseSettings.pitch + (emotionMod.pitchShift * intensity)).clamp(0.5, 2.0),
      speechRate: (baseSettings.speechRate + (emotionMod.tempoShift * intensity)).clamp(0.5, 2.0),
      volume: (baseSettings.volume + (emotionMod.volumeShift * intensity)).clamp(0.1, 1.0),
    );
  }
  
  /// Apply contextual adjustments based on text content
  VoiceSettings _applyContextualAdjustments(
    VoiceSettings baseSettings,
    EnhancedVoiceProfile profile,
    String text
  ) {
    var adjustedSettings = baseSettings;
    
    // Question detection - slight pitch rise
    if (text.contains('?')) {
      adjustedSettings = adjustedSettings.copyWith(
        pitch: (adjustedSettings.pitch * 1.05).clamp(0.5, 2.0),
      );
    }
    
    // Excitement detection - punctuation analysis
    if (text.contains('!')) {
      final exclamationCount = '!'.allMatches(text).length;
      final excitement = (exclamationCount * 0.1).clamp(0.0, 0.3);
      
      adjustedSettings = adjustedSettings.copyWith(
        pitch: (adjustedSettings.pitch + excitement).clamp(0.5, 2.0),
        speechRate: (adjustedSettings.speechRate + excitement).clamp(0.5, 2.0),
      );
    }
    
    // Length-based pacing
    if (text.length > 200) {
      // Longer text - slightly slower for clarity
      adjustedSettings = adjustedSettings.copyWith(
        speechRate: (adjustedSettings.speechRate * 0.95).clamp(0.5, 2.0),
      );
    }
    
    return adjustedSettings;
  }
  
  /// Generate SSML for advanced voice synthesis
  String generateSSML(String text, String companionId, {EmotionalContext? emotion}) {
    final profile = _voiceProfiles[companionId];
    if (profile == null) return text;
    
    final settings = getVoiceSettings(companionId, emotion: emotion, text: text);
    
    // Use custom SSML template if available
    if (profile.customSSML.isNotEmpty) {
      return profile.customSSML
          .replaceAll('{TEXT}', _escapeSSML(text))
          .replaceAll('{PITCH}', '${(settings.pitch * 100 - 100).round()}%')
          .replaceAll('{RATE}', '${(settings.speechRate * 100).round()}%')
          .replaceAll('{VOLUME}', '${(settings.volume * 100).round()}%');
    }
    
    // Generate basic SSML
    return '''
<speak version="1.0" xml:lang="${settings.language}">
  <voice name="${settings.voice}">
    <prosody 
      pitch="${(settings.pitch * 100 - 100).round()}%" 
      rate="${(settings.speechRate * 100).round()}%"
      volume="${(settings.volume * 100).round()}%">
      ${_escapeSSML(text)}
    </prosody>
  </voice>
</speak>
    '''.trim();
  }
  
  String _escapeSSML(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
  
  // SSML templates for different companions
  static String _getEmmaSSMLTemplate() {
    return '''
<speak version="1.0" xml:lang="en-US">
  <voice name="en-US-AriaNeural">
    <prosody pitch="{PITCH}" rate="{RATE}" volume="{VOLUME}">
      <emphasis level="moderate">{TEXT}</emphasis>
    </prosody>
  </voice>
</speak>
    ''';
  }
  
  static String _getAlexSSMLTemplate() {
    return '''
<speak version="1.0" xml:lang="en-US">
  <voice name="en-US-GuyNeural">
    <prosody pitch="{PITCH}" rate="{RATE}" volume="{VOLUME}">
      <emphasis level="strong">{TEXT}</emphasis>
    </prosody>
  </voice>
</speak>
    ''';
  }
  
  static String _getSophiaSSMLTemplate() {
    return '''
<speak version="1.0" xml:lang="en-GB">
  <voice name="en-GB-LibbyNeural">
    <prosody pitch="{PITCH}" rate="{RATE}" volume="{VOLUME}">
      {TEXT}
    </prosody>
  </voice>
</speak>
    ''';
  }
}

/// Enhanced voice profile with personality characteristics
class EnhancedVoiceProfile {
  final String companionId;
  final String name;
  final String baseVoice;
  final String language;
  final VoiceCharacteristics characteristics;
  final EmotionalVoiceRange emotionalRange;
  final TTSEngine fallbackEngine;
  final String customSSML;
  
  const EnhancedVoiceProfile({
    required this.companionId,
    required this.name,
    required this.baseVoice,
    this.language = 'en-US',
    required this.characteristics,
    required this.emotionalRange,
    this.fallbackEngine = TTSEngine.flutterTTS,
    this.customSSML = '',
  });
}

/// Voice characteristics defining personality traits
class VoiceCharacteristics {
  final double pitch; // 0.5 - 2.0
  final double speechRate; // 0.5 - 2.0
  final double volume; // 0.1 - 1.0
  final double breathiness; // 0.0 - 1.0
  final double roughness; // 0.0 - 1.0
  final double warmth; // 0.0 - 1.0
  final double confidence; // 0.0 - 1.0
  final double playfulness; // 0.0 - 1.0
  
  const VoiceCharacteristics({
    this.pitch = 1.0,
    this.speechRate = 1.0,
    this.volume = 1.0,
    this.breathiness = 0.0,
    this.roughness = 0.0,
    this.warmth = 0.5,
    this.confidence = 0.5,
    this.playfulness = 0.5,
  });
}

/// Emotional voice range for different emotions
class EmotionalVoiceRange {
  final VoiceEmotion? happiness;
  final VoiceEmotion? sadness;
  final VoiceEmotion? excitement;
  final VoiceEmotion? empathy;
  final VoiceEmotion? curiosity;
  final VoiceEmotion? anger;
  final VoiceEmotion? surprise;
  
  const EmotionalVoiceRange({
    this.happiness,
    this.sadness,
    this.excitement,
    this.empathy,
    this.curiosity,
    this.anger,
    this.surprise,
  });
}

/// Voice emotion modulation parameters
class VoiceEmotion {
  final double pitchShift; // -0.5 to +0.5
  final double tempoShift; // -0.5 to +0.5
  final double volumeShift; // -0.3 to +0.3
  final double breathinessShift; // -0.3 to +0.3
  
  const VoiceEmotion({
    this.pitchShift = 0.0,
    this.tempoShift = 0.0,
    this.volumeShift = 0.0,
    this.breathinessShift = 0.0,
  });
}

/// Voice settings for TTS engines
class VoiceSettings {
  final String voice;
  final double pitch;
  final double speechRate;
  final double volume;
  final String language;
  final TTSEngine engine;
  
  const VoiceSettings({
    required this.voice,
    this.pitch = 1.0,
    this.speechRate = 1.0,
    this.volume = 1.0,
    this.language = 'en-US',
    this.engine = TTSEngine.flutterTTS,
  });
  
  factory VoiceSettings.defaultSettings() {
    return const VoiceSettings(
      voice: 'default',
      language: 'en-US',
    );
  }
  
  VoiceSettings copyWith({
    String? voice,
    double? pitch,
    double? speechRate,
    double? volume,
    String? language,
    TTSEngine? engine,
  }) {
    return VoiceSettings(
      voice: voice ?? this.voice,
      pitch: pitch ?? this.pitch,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      language: language ?? this.language,
      engine: engine ?? this.engine,
    );
  }
}

/// Emotional context for voice modulation
class EmotionalContext {
  final Emotion primaryEmotion;
  final double intensity; // 0.0 - 1.0
  final List<Emotion> secondaryEmotions;
  
  const EmotionalContext({
    required this.primaryEmotion,
    this.intensity = 1.0,
    this.secondaryEmotions = const [],
  });
}

/// Available TTS engines
enum TTSEngine {
  flutterTTS,
  azureTTS,
  googleTTS,
  customAPI,
}

/// Emotion types
enum Emotion {
  neutral,
  happiness,
  sadness,
  excitement,
  empathy,
  curiosity,
  anger,
  surprise,
  fear,
  disgust,
}
