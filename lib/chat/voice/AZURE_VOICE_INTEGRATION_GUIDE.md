# Azure Voice Characteristics Integration Guide

## Overview

This implementation adds Azure-specific voice characteristics to AI companions, enabling unique and distinct voice personalities for each companion. The system stores comprehensive Azure TTS parameters in the database and uses them for speech synthesis.

## Key Features

✅ **Unique Voice Per Companion**: Each companion can have distinct Azure voice characteristics
✅ **Database Storage**: Voice configurations stored in `azure_voice_config` JSONB column
✅ **No UI Changes Required**: Voice characteristics are internal-only for Azure TTS
✅ **Emotional Adjustments**: Dynamic voice modulation based on context
✅ **Fallback Support**: Legacy voice system as fallback for companions without Azure config
✅ **Advanced SSML**: Rich speech synthesis with Azure Neural voices

## Database Schema

```sql
-- New column added to ai_companions table
ALTER TABLE public.ai_companions 
ADD COLUMN azure_voice_config JSONB NULL;
```

## Data Structure

```json
{
  "azureVoiceName": "en-US-AriaNeural",
  "languageCode": "en-US",
  "basePitch": 10.0,
  "baseSpeechRate": -5.0,
  "baseVolume": 95.0,
  "voiceStyle": "friendly",
  "styleDegree": 1.2,
  "emotionalAdjustments": {
    "happiness": {
      "pitchAdjustment": 15.0,
      "speechRateAdjustment": 10.0,
      "volumeAdjustment": 5.0,
      "styleOverride": "cheerful"
    },
    "empathy": {
      "pitchAdjustment": -5.0,
      "speechRateAdjustment": -10.0,
      "volumeAdjustment": -5.0,
      "styleOverride": "gentle"
    }
  },
  "speechPacing": {
    "sentenceBreak": 300,
    "paragraphBreak": 600,
    "commaBreak": 150,
    "naturalPauses": true
  },
  "expressionConfig": {
    "autoEmphasis": true,
    "emphasisLevel": "moderate",
    "expressiveIntonation": true,
    "expressiveness": 1.0
  }
}
```

## Usage Examples

### 1. Setting Up Voice Configuration for a Companion

```dart
import 'package:ai_companion/chat/voice/azure_voice_characteristics.dart';
import 'package:ai_companion/chat/voice/companion_voice_config_service.dart';

// Create Azure voice characteristics for Emma
final emmaVoiceConfig = AzureVoiceCharacteristics(
  azureVoiceName: 'en-US-AriaNeural',
  languageCode: 'en-US',
  basePitch: 10.0,          // Slightly higher pitch
  baseSpeechRate: -5.0,     // Slightly slower for warmth
  baseVolume: 95.0,
  voiceStyle: 'friendly',
  styleDegree: 1.2,
  emotionalAdjustments: {
    'happiness': EmotionalVoiceAdjustment(
      pitchAdjustment: 15.0,
      speechRateAdjustment: 10.0,
      volumeAdjustment: 5.0,
      styleOverride: 'cheerful',
    ),
    'empathy': EmotionalVoiceAdjustment(
      pitchAdjustment: -5.0,
      speechRateAdjustment: -10.0,
      volumeAdjustment: -5.0,
      styleOverride: 'gentle',
    ),
  },
);

// Save to database
final voiceConfigService = CompanionVoiceConfigService();
await voiceConfigService.updateCompanionVoiceConfig(
  companionId: 'emma-uuid',
  voiceConfig: emmaVoiceConfig,
);
```

### 2. Using Presets for Quick Setup

```dart
// Use predefined voice presets
final alexVoiceConfig = AzureVoicePresets.casualMale();
final sophiaVoiceConfig = AzureVoicePresets.sophisticatedBritish();

// Apply to companions
await voiceConfigService.updateCompanionVoiceConfig(
  companionId: 'alex-uuid',
  voiceConfig: alexVoiceConfig,
);
```

### 3. Auto-Configuration Based on Personality

```dart
// Automatically set voice config based on companion traits
await voiceConfigService.setDefaultVoiceConfigForCompanion(companion);
```

### 4. Voice Synthesis with Azure Characteristics

```dart
import 'package:ai_companion/chat/voice/supabase_tts_service.dart';

final ttsService = SupabaseTTSService();

// Example: Sophia Martinez (Vibrant Interior Designer)
final result = await ttsService.synthesizeSpeech(
  text: "¡Qué maravilloso! I can already envision the perfect color palette for your space!",
  companion: sophiaCompanion, // Uses her energetic, animated voice characteristics
  emotion: EmotionalContext(
    primaryEmotion: VoiceEmotion.excitement,
    intensity: 0.9,
  ),
);

// Example: Akiko Nakamura (Elegant Architect)
final result2 = await ttsService.synthesizeSpeech(
  text: "Let us consider the flow of natural light and how it shapes the space throughout the day.",
  companion: akikoCompanion, // Uses her calm, measured voice characteristics
  emotion: EmotionalContext(
    primaryEmotion: VoiceEmotion.thoughtful,
    intensity: 0.7,
  ),
);

// Example: Claire Montgomery (Former Diplomat)
final result3 = await ttsService.synthesizeSpeech(
  text: "In my experience, the most elegant solutions often emerge from understanding cultural nuances.",
  companion: claireCompanion, // Uses her sophisticated British voice
  emotion: EmotionalContext(
    primaryEmotion: VoiceEmotion.confidence,
    intensity: 0.8,
  ),
);

if (result.success) {
  // Audio generated with companion's unique voice characteristics
  final audioData = result.audioData;
  final duration = result.duration;
}
```

### 5. Real Companion Examples

```dart
// Sophia Martinez - Vibrant Interior Designer
final sophiaVoiceConfig = AzureVoiceCharacteristics(
  azureVoiceName: 'en-US-AriaNeural',
  languageCode: 'en-US',
  basePitch: 15.0,        // Higher pitch for energy
  baseSpeechRate: 5.0,    // Faster for animation
  baseVolume: 98.0,       // Confident volume
  voiceStyle: 'cheerful',
  styleDegree: 1.3,       // High expressiveness
  emotionalAdjustments: {
    'excitement': EmotionalVoiceAdjustment(
      pitchAdjustment: 25.0,
      speechRateAdjustment: 20.0,
      volumeAdjustment: 10.0,
      styleOverride: 'excited',
    ),
  },
);

// Akiko Nakamura - Elegant Architect  
final akikoVoiceConfig = AzureVoiceCharacteristics(
  azureVoiceName: 'en-US-JennyNeural',
  languageCode: 'en-US',
  basePitch: -8.0,        // Lower pitch for calm
  baseSpeechRate: -15.0,  // Slower for thoughtfulness
  baseVolume: 88.0,       // Soft-spoken
  voiceStyle: 'calm',
  styleDegree: 1.1,       // Subtle expressiveness
  emotionalAdjustments: {
    'thoughtful': EmotionalVoiceAdjustment(
      pitchAdjustment: -5.0,
      speechRateAdjustment: -10.0,
      volumeAdjustment: -5.0,
      styleOverride: 'calm',
    ),
  },
);

// Claire Montgomery - Former Diplomat
final claireVoiceConfig = AzureVoiceCharacteristics(
  azureVoiceName: 'en-GB-LibbyNeural',  // British accent
  languageCode: 'en-GB',
  basePitch: -3.0,        // Authoritative
  baseSpeechRate: -8.0,   // Measured pace
  baseVolume: 92.0,       // Professional
  voiceStyle: 'conversational',
  styleDegree: 1.0,       // Diplomatic restraint
);
```

## Voice Configuration Management

### Get Current Configuration

```dart
final config = await voiceConfigService.getCompanionVoiceConfig('companion-id');
if (config != null) {
  print('Voice: ${config.azureVoiceName}');
  print('Language: ${config.languageCode}');
  print('Style: ${config.voiceStyle}');
}
```

### Bulk Configuration Updates

```dart
final configs = {
  'emma-uuid': AzureVoicePresets.friendlyFemale(),
  'alex-uuid': AzureVoicePresets.casualMale(),
  'sophia-uuid': AzureVoicePresets.sophisticatedBritish(),
};

await voiceConfigService.bulkUpdateVoiceConfigs(configs);
```

### Remove Configuration (Fallback to Legacy)

```dart
await voiceConfigService.removeCompanionVoiceConfig('companion-id');
```

## Available Azure Neural Voices

### English (US)
- `en-US-AriaNeural` - Friendly female (recommended for supportive companions)
- `en-US-JennyNeural` - Professional female
- `en-US-GuyNeural` - Casual male (recommended for confident companions)
- `en-US-DavisNeural` - Deep male voice

### English (UK)
- `en-GB-LibbyNeural` - Sophisticated British female
- `en-GB-MaisieNeural` - Young British female
- `en-GB-RyanNeural` - British male

### Voice Styles
- `friendly` - Warm and approachable
- `cheerful` - Upbeat and positive
- `sad` - Melancholic tone
- `angry` - Firm and assertive
- `fearful` - Cautious and worried
- `conversational` - Natural dialogue style
- `newscast` - Professional news reading style

## Emotional Adjustments

Configure how voice changes for different emotional contexts:

```dart
emotionalAdjustments: {
  'happiness': EmotionalVoiceAdjustment(
    pitchAdjustment: 15.0,      // +15% pitch when happy
    speechRateAdjustment: 10.0,  // +10% faster when excited
    volumeAdjustment: 5.0,       // +5% louder when joyful
    styleOverride: 'cheerful',   // Switch to cheerful style
  ),
  'sadness': EmotionalVoiceAdjustment(
    pitchAdjustment: -10.0,      // -10% pitch when sad
    speechRateAdjustment: -15.0, // -15% slower when melancholy
    volumeAdjustment: -5.0,      // -5% quieter when sad
    styleOverride: 'sad',        // Switch to sad style
  ),
}
```

## Migration Guide

### For Existing Companions

1. **Add Azure Voice Configuration Column**:
   ```sql
   ALTER TABLE public.ai_companions ADD COLUMN azure_voice_config JSONB NULL;
   ```

2. **Set Default Configurations**:
   ```dart
   final companions = await getExistingCompanions();
   for (final companion in companions) {
     await voiceConfigService.setDefaultVoiceConfigForCompanion(companion);
   }
   ```

3. **Test Voice Generation**:
   ```dart
   // Existing companions will automatically use new Azure characteristics
   // Fallback to legacy system if no Azure config is present
   ```

## Performance Benefits

- **Unique Voices**: Each companion has distinct voice characteristics
- **Dynamic Emotional Expression**: Voice adapts to emotional context
- **Advanced SSML**: Rich speech synthesis with Azure Neural voices
- **Database Efficiency**: Voice configurations stored as JSONB
- **Backward Compatibility**: Fallback to legacy system if needed
- **No UI Changes**: Internal voice system enhancement only

## Error Handling

The system includes comprehensive error handling:

- **Validation**: Voice configurations are validated before saving
- **Fallback**: Legacy voice system used if Azure config unavailable
- **Logging**: Detailed logging for debugging voice synthesis issues
- **Recovery**: Graceful degradation if Azure TTS service unavailable

## Future Enhancements

- **Voice Cloning**: Support for custom voice models
- **Multi-language**: Support for multiple languages per companion
- **Voice Learning**: Adaptive voice characteristics based on user preferences
- **Advanced Emotions**: More granular emotional voice adjustments
