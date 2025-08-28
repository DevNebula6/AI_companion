import 'package:flutter/foundation.dart';

/// Azure TTS specific voice characteristics for AI companions
/// This model contains all Azure-specific voice parameters and configurations
/// that are used internally for TTS generation - not shown to users
@immutable
class AzureVoiceCharacteristics {
  /// Azure Neural Voice name (e.g., 'en-US-AriaNeural', 'en-GB-LibbyNeural')
  final String azureVoiceName;
  
  /// Language code for the voice (e.g., 'en-US', 'en-GB', 'fr-FR')
  final String languageCode;
  
  /// Base pitch adjustment (-50% to +100%, default: 0%)
  final double basePitch;
  
  /// Base speaking rate (-50% to +100%, default: 0%)
  final double baseSpeechRate;
  
  /// Base volume level (0% to 100%, default: 100%)
  final double baseVolume;
  
  /// Voice style for Azure Neural voices (e.g., 'friendly', 'cheerful', 'sad', 'angry')
  final String? voiceStyle;
  
  /// Style degree for Azure Neural voices (0.01 to 2.0, default: 1.0)
  final double styleDegree;
  
  /// Voice role for Azure Neural voices (e.g., 'YoungAdultFemale', 'OlderAdultMale')
  final String? voiceRole;
  
  /// Emotional tone adjustments for different contexts
  final Map<String, EmotionalVoiceAdjustment> emotionalAdjustments;
  
  /// SSML breaks and pauses configuration
  final SpeechPacingConfig speechPacing;
  
  /// Voice emphasis and expression settings
  final VoiceExpressionConfig expressionConfig;

  const AzureVoiceCharacteristics({
    required this.azureVoiceName,
    required this.languageCode,
    this.basePitch = 0.0,
    this.baseSpeechRate = 0.0,
    this.baseVolume = 100.0,
    this.voiceStyle,
    this.styleDegree = 1.0,
    this.voiceRole,
    this.emotionalAdjustments = const {},
    this.speechPacing = const SpeechPacingConfig(),
    this.expressionConfig = const VoiceExpressionConfig(),
  });

  /// Create from JSON (from database storage)
  factory AzureVoiceCharacteristics.fromJson(Map<String, dynamic> json) {
    return AzureVoiceCharacteristics(
      azureVoiceName: json['azureVoiceName'] ?? 'en-US-JennyNeural',
      languageCode: json['languageCode'] ?? 'en-US',
      basePitch: (json['basePitch'] ?? 0.0).toDouble(),
      baseSpeechRate: (json['baseSpeechRate'] ?? 0.0).toDouble(),
      baseVolume: (json['baseVolume'] ?? 100.0).toDouble(),
      voiceStyle: json['voiceStyle'],
      styleDegree: (json['styleDegree'] ?? 1.0).toDouble(),
      voiceRole: json['voiceRole'],
      emotionalAdjustments: _parseEmotionalAdjustments(json['emotionalAdjustments']),
      speechPacing: json['speechPacing'] != null 
          ? SpeechPacingConfig.fromJson(json['speechPacing'])
          : const SpeechPacingConfig(),
      expressionConfig: json['expressionConfig'] != null
          ? VoiceExpressionConfig.fromJson(json['expressionConfig'])
          : const VoiceExpressionConfig(),
    );
  }

  /// Convert to JSON (for database storage)
  Map<String, dynamic> toJson() {
    return {
      'azureVoiceName': azureVoiceName,
      'languageCode': languageCode,
      'basePitch': basePitch,
      'baseSpeechRate': baseSpeechRate,
      'baseVolume': baseVolume,
      'voiceStyle': voiceStyle,
      'styleDegree': styleDegree,
      'voiceRole': voiceRole,
      'emotionalAdjustments': emotionalAdjustments.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'speechPacing': speechPacing.toJson(),
      'expressionConfig': expressionConfig.toJson(),
    };
  }

  /// Parse emotional adjustments from JSON
  static Map<String, EmotionalVoiceAdjustment> _parseEmotionalAdjustments(dynamic json) {
    if (json == null) return {};
    
    final Map<String, dynamic> data = Map<String, dynamic>.from(json);
    return data.map(
      (key, value) => MapEntry(
        key, 
        EmotionalVoiceAdjustment.fromJson(Map<String, dynamic>.from(value)),
      ),
    );
  }

  /// Generate SSML for Azure TTS with all voice characteristics applied
  String generateSSML(String text, {String? contextualEmotion}) {
    // Escape XML special characters
    final escapedText = _escapeXML(text);
    
    // Apply contextual emotional adjustments
    final adjustedCharacteristics = _applyEmotionalContext(contextualEmotion);
    
    // Build SSML with all characteristics
    final ssmlBuffer = StringBuffer();
    
    ssmlBuffer.writeln('<speak version="1.0" xml:lang="$languageCode">');
    ssmlBuffer.write('  <voice name="$azureVoiceName"');
    
    // Add voice style if supported
    if (voiceStyle != null) {
      ssmlBuffer.write(' style="$voiceStyle" styledegree="$styleDegree"');
    }
    
    // Add voice role if supported
    if (voiceRole != null) {
      ssmlBuffer.write(' role="$voiceRole"');
    }
    
    ssmlBuffer.writeln('>');
    
    // Apply prosody with adjusted characteristics
    ssmlBuffer.write('    <prosody');
    ssmlBuffer.write(' pitch="${_formatProsodyValue(adjustedCharacteristics.pitch)}"');
    ssmlBuffer.write(' rate="${_formatProsodyValue(adjustedCharacteristics.speechRate)}"');
    ssmlBuffer.write(' volume="${adjustedCharacteristics.volume.round()}%"');
    ssmlBuffer.writeln('>');
    
    // Apply expression and pacing
    final processedText = _applyExpressionAndPacing(escapedText);
    ssmlBuffer.writeln('      $processedText');
    
    ssmlBuffer.writeln('    </prosody>');
    ssmlBuffer.writeln('  </voice>');
    ssmlBuffer.writeln('</speak>');
    
    return ssmlBuffer.toString();
  }

  /// Apply emotional context adjustments
  _AdjustedCharacteristics _applyEmotionalContext(String? emotion) {
    if (emotion == null || !emotionalAdjustments.containsKey(emotion)) {
      return _AdjustedCharacteristics(
        pitch: basePitch,
        speechRate: baseSpeechRate,
        volume: baseVolume,
      );
    }
    
    final adjustment = emotionalAdjustments[emotion]!;
    return _AdjustedCharacteristics(
      pitch: (basePitch + adjustment.pitchAdjustment).clamp(-50.0, 100.0),
      speechRate: (baseSpeechRate + adjustment.speechRateAdjustment).clamp(-50.0, 100.0),
      volume: (baseVolume + adjustment.volumeAdjustment).clamp(0.0, 100.0),
    );
  }

  /// Apply expression and pacing to text
  String _applyExpressionAndPacing(String text) {
    var processedText = text;
    
    // Apply breaks for pacing
    if (speechPacing.sentenceBreak > 0) {
      processedText = processedText.replaceAllMapped(
        RegExp(r'[.!?]\s+'),
        (match) => '${match.group(0)}<break time="${speechPacing.sentenceBreak}ms"/>',
      );
    }
    
    // Apply emphasis based on expression config
    if (expressionConfig.autoEmphasis) {
      // Add emphasis to exclamatory phrases
      processedText = processedText.replaceAllMapped(
        RegExp(r'[!]+'),
        (match) => '<emphasis level="${expressionConfig.emphasisLevel}">${match.group(0)}</emphasis>',
      );
    }
    
    return processedText;
  }

  /// Escape XML special characters
  String _escapeXML(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Format prosody values for SSML
  String _formatProsodyValue(double value) {
    if (value == 0.0) return 'default';
    if (value > 0) return '+${value.round()}%';
    return '${value.round()}%';
  }

  /// Create a copy with different values
  AzureVoiceCharacteristics copyWith({
    String? azureVoiceName,
    String? languageCode,
    double? basePitch,
    double? baseSpeechRate,
    double? baseVolume,
    String? voiceStyle,
    double? styleDegree,
    String? voiceRole,
    Map<String, EmotionalVoiceAdjustment>? emotionalAdjustments,
    SpeechPacingConfig? speechPacing,
    VoiceExpressionConfig? expressionConfig,
  }) {
    return AzureVoiceCharacteristics(
      azureVoiceName: azureVoiceName ?? this.azureVoiceName,
      languageCode: languageCode ?? this.languageCode,
      basePitch: basePitch ?? this.basePitch,
      baseSpeechRate: baseSpeechRate ?? this.baseSpeechRate,
      baseVolume: baseVolume ?? this.baseVolume,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      styleDegree: styleDegree ?? this.styleDegree,
      voiceRole: voiceRole ?? this.voiceRole,
      emotionalAdjustments: emotionalAdjustments ?? this.emotionalAdjustments,
      speechPacing: speechPacing ?? this.speechPacing,
      expressionConfig: expressionConfig ?? this.expressionConfig,
    );
  }
}

/// Emotional voice adjustment for specific contexts
@immutable
class EmotionalVoiceAdjustment {
  final double pitchAdjustment; // -50% to +100%
  final double speechRateAdjustment; // -50% to +100%
  final double volumeAdjustment; // -50% to +50%
  final String? styleOverride; // Override voice style for this emotion

  const EmotionalVoiceAdjustment({
    this.pitchAdjustment = 0.0,
    this.speechRateAdjustment = 0.0,
    this.volumeAdjustment = 0.0,
    this.styleOverride,
  });

  factory EmotionalVoiceAdjustment.fromJson(Map<String, dynamic> json) {
    return EmotionalVoiceAdjustment(
      pitchAdjustment: (json['pitchAdjustment'] ?? 0.0).toDouble(),
      speechRateAdjustment: (json['speechRateAdjustment'] ?? 0.0).toDouble(),
      volumeAdjustment: (json['volumeAdjustment'] ?? 0.0).toDouble(),
      styleOverride: json['styleOverride'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pitchAdjustment': pitchAdjustment,
      'speechRateAdjustment': speechRateAdjustment,
      'volumeAdjustment': volumeAdjustment,
      'styleOverride': styleOverride,
    };
  }
}

/// Speech pacing configuration
@immutable
class SpeechPacingConfig {
  final int sentenceBreak; // Milliseconds break after sentences
  final int paragraphBreak; // Milliseconds break after paragraphs
  final int commaBreak; // Milliseconds break after commas
  final bool naturalPauses; // Add natural pauses for thinking

  const SpeechPacingConfig({
    this.sentenceBreak = 300,
    this.paragraphBreak = 600,
    this.commaBreak = 150,
    this.naturalPauses = true,
  });

  factory SpeechPacingConfig.fromJson(Map<String, dynamic> json) {
    return SpeechPacingConfig(
      sentenceBreak: json['sentenceBreak'] ?? 300,
      paragraphBreak: json['paragraphBreak'] ?? 600,
      commaBreak: json['commaBreak'] ?? 150,
      naturalPauses: json['naturalPauses'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sentenceBreak': sentenceBreak,
      'paragraphBreak': paragraphBreak,
      'commaBreak': commaBreak,
      'naturalPauses': naturalPauses,
    };
  }
}

/// Voice expression configuration
@immutable
class VoiceExpressionConfig {
  final bool autoEmphasis; // Automatically add emphasis to exclamations
  final String emphasisLevel; // 'strong', 'moderate', 'reduced'
  final bool expressiveIntonation; // Use expressive intonation patterns
  final double expressiveness; // 0.0 to 2.0, controls overall expressiveness

  const VoiceExpressionConfig({
    this.autoEmphasis = true,
    this.emphasisLevel = 'moderate',
    this.expressiveIntonation = true,
    this.expressiveness = 1.0,
  });

  factory VoiceExpressionConfig.fromJson(Map<String, dynamic> json) {
    return VoiceExpressionConfig(
      autoEmphasis: json['autoEmphasis'] ?? true,
      emphasisLevel: json['emphasisLevel'] ?? 'moderate',
      expressiveIntonation: json['expressiveIntonation'] ?? true,
      expressiveness: (json['expressiveness'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoEmphasis': autoEmphasis,
      'emphasisLevel': emphasisLevel,
      'expressiveIntonation': expressiveIntonation,
      'expressiveness': expressiveness,
    };
  }
}

/// Internal class for adjusted characteristics
class _AdjustedCharacteristics {
  final double pitch;
  final double speechRate;
  final double volume;

  const _AdjustedCharacteristics({
    required this.pitch,
    required this.speechRate,
    required this.volume,
  });
}

/// Predefined Azure voice characteristics for common companion types
class AzureVoicePresets {
  /// Warm, friendly female voice
  static AzureVoiceCharacteristics friendlyFemale() {
    return AzureVoiceCharacteristics(
      azureVoiceName: 'en-US-AriaNeural',
      languageCode: 'en-US',
      basePitch: 10.0,
      baseSpeechRate: -5.0,
      baseVolume: 95.0,
      voiceStyle: 'friendly',
      styleDegree: 1.2,
      emotionalAdjustments: {
        'happiness': const EmotionalVoiceAdjustment(
          pitchAdjustment: 15.0,
          speechRateAdjustment: 10.0,
          volumeAdjustment: 5.0,
          styleOverride: 'cheerful',
        ),
        'empathy': const EmotionalVoiceAdjustment(
          pitchAdjustment: -5.0,
          speechRateAdjustment: -10.0,
          volumeAdjustment: -5.0,
          styleOverride: 'gentle',
        ),
      },
    );
  }

  /// Confident, casual male voice
  static AzureVoiceCharacteristics casualMale() {
    return AzureVoiceCharacteristics(
      azureVoiceName: 'en-US-GuyNeural',
      languageCode: 'en-US',
      basePitch: -5.0,
      baseSpeechRate: 5.0,
      baseVolume: 100.0,
      voiceStyle: 'casual',
      styleDegree: 1.1,
      emotionalAdjustments: {
        'excitement': const EmotionalVoiceAdjustment(
          pitchAdjustment: 20.0,
          speechRateAdjustment: 15.0,
          volumeAdjustment: 10.0,
        ),
        'confidence': const EmotionalVoiceAdjustment(
          pitchAdjustment: -10.0,
          speechRateAdjustment: 0.0,
          volumeAdjustment: 5.0,
        ),
      },
    );
  }

  /// Sophisticated British female voice
  static AzureVoiceCharacteristics sophisticatedBritish() {
    return AzureVoiceCharacteristics(
      azureVoiceName: 'en-GB-LibbyNeural',
      languageCode: 'en-GB',
      basePitch: 5.0,
      baseSpeechRate: -10.0,
      baseVolume: 90.0,
      voiceStyle: 'conversational',
      styleDegree: 1.3,
      speechPacing: const SpeechPacingConfig(
        sentenceBreak: 400,
        commaBreak: 200,
        naturalPauses: true,
      ),
      emotionalAdjustments: {
        'curiosity': const EmotionalVoiceAdjustment(
          pitchAdjustment: 8.0,
          speechRateAdjustment: -5.0,
        ),
        'thoughtful': const EmotionalVoiceAdjustment(
          pitchAdjustment: -3.0,
          speechRateAdjustment: -15.0,
        ),
      },
    );
  }
}
