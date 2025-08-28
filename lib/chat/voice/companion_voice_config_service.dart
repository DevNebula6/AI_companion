import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Companion/ai_model.dart';
import 'azure_voice_characteristics.dart';

/// Service for managing companion Azure voice configurations
/// Handles CRUD operations for voice characteristics in the database
class CompanionVoiceConfigService {
  static final CompanionVoiceConfigService _instance = CompanionVoiceConfigService._internal();
  factory CompanionVoiceConfigService() => _instance;
  CompanionVoiceConfigService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Update a companion's Azure voice configuration
  Future<void> updateCompanionVoiceConfig({
    required String companionId,
    required AzureVoiceCharacteristics voiceConfig,
  }) async {
    try {
      await _supabase
          .from('ai_companions')
          .update({
            'azure_voice_config': voiceConfig.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', companionId);

      debugPrint('✅ Updated Azure voice config for companion: $companionId');
    } catch (e) {
      debugPrint('❌ Failed to update voice config: $e');
      rethrow;
    }
  }

  /// Get a companion's Azure voice configuration
  Future<AzureVoiceCharacteristics?> getCompanionVoiceConfig(String companionId) async {
    try {
      final response = await _supabase
          .from('ai_companions')
          .select('azure_voice_config')
          .eq('id', companionId)
          .single();

      if (response['azure_voice_config'] != null) {
        return AzureVoiceCharacteristics.fromJson(
          Map<String, dynamic>.from(response['azure_voice_config']),
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get voice config: $e');
      return null;
    }
  }

  /// Set default Azure voice configuration for a companion based on their characteristics
  Future<void> setDefaultVoiceConfigForCompanion(AICompanion companion) async {
    try {
      AzureVoiceCharacteristics defaultConfig;

      // Determine default voice config based on companion characteristics
      if (companion.gender == CompanionGender.female) {
        if (_hasPersonalityTrait(companion, 'friendly') || 
            _hasPersonalityTrait(companion, 'supportive')) {
          defaultConfig = AzureVoicePresets.friendlyFemale();
        } else if (_hasPersonalityTrait(companion, 'sophisticated') ||
                   _hasPersonalityTrait(companion, 'intelligent')) {
          defaultConfig = AzureVoicePresets.sophisticatedBritish();
        } else {
          defaultConfig = AzureVoicePresets.friendlyFemale();
        }
      } else if (companion.gender == CompanionGender.male) {
        defaultConfig = AzureVoicePresets.casualMale();
      } else {
        // Default to friendly female for non-binary/other
        defaultConfig = AzureVoicePresets.friendlyFemale();
      }

      // Customize based on specific personality traits
      defaultConfig = _customizeForPersonality(defaultConfig, companion);

      await updateCompanionVoiceConfig(
        companionId: companion.id,
        voiceConfig: defaultConfig,
      );

      debugPrint('✅ Set default voice config for ${companion.name}');
    } catch (e) {
      debugPrint('❌ Failed to set default voice config: $e');
      rethrow;
    }
  }

  /// Check if companion has a specific personality trait
  bool _hasPersonalityTrait(AICompanion companion, String trait) {
    return companion.personality.primaryTraits.any(
      (t) => t.toLowerCase().contains(trait.toLowerCase()),
    ) || companion.personality.secondaryTraits.any(
      (t) => t.toLowerCase().contains(trait.toLowerCase()),
    );
  }

  /// Customize voice config based on companion's personality
  AzureVoiceCharacteristics _customizeForPersonality(
    AzureVoiceCharacteristics baseConfig,
    AICompanion companion,
  ) {
    var customConfig = baseConfig;

    // Adjust based on personality traits
    if (_hasPersonalityTrait(companion, 'energetic') || 
        _hasPersonalityTrait(companion, 'playful')) {
      customConfig = customConfig.copyWith(
        baseSpeechRate: baseConfig.baseSpeechRate + 5.0,
        basePitch: baseConfig.basePitch + 5.0,
      );
    }

    if (_hasPersonalityTrait(companion, 'calm') || 
        _hasPersonalityTrait(companion, 'peaceful')) {
      customConfig = customConfig.copyWith(
        baseSpeechRate: baseConfig.baseSpeechRate - 5.0,
        speechPacing: const SpeechPacingConfig(
          sentenceBreak: 400,
          commaBreak: 200,
          naturalPauses: true,
        ),
      );
    }

    if (_hasPersonalityTrait(companion, 'confident') || 
        _hasPersonalityTrait(companion, 'assertive')) {
      customConfig = customConfig.copyWith(
        baseVolume: (baseConfig.baseVolume + 5.0).clamp(0.0, 100.0),
        basePitch: baseConfig.basePitch - 3.0,
      );
    }

    if (_hasPersonalityTrait(companion, 'gentle') || 
        _hasPersonalityTrait(companion, 'soft-spoken')) {
      customConfig = customConfig.copyWith(
        baseVolume: (baseConfig.baseVolume - 5.0).clamp(0.0, 100.0),
        voiceStyle: 'gentle',
      );
    }

    return customConfig;
  }

  /// Bulk update voice configurations for multiple companions
  Future<void> bulkUpdateVoiceConfigs(
    Map<String, AzureVoiceCharacteristics> companionConfigs,
  ) async {
    try {
      for (final entry in companionConfigs.entries) {
        await updateCompanionVoiceConfig(
          companionId: entry.key,
          voiceConfig: entry.value,
        );
      }
      debugPrint('✅ Bulk updated ${companionConfigs.length} voice configs');
    } catch (e) {
      debugPrint('❌ Bulk update failed: $e');
      rethrow;
    }
  }

  /// Remove Azure voice configuration for a companion (fallback to legacy)
  Future<void> removeCompanionVoiceConfig(String companionId) async {
    try {
      await _supabase
          .from('ai_companions')
          .update({
            'azure_voice_config': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', companionId);

      debugPrint('✅ Removed Azure voice config for companion: $companionId');
    } catch (e) {
      debugPrint('❌ Failed to remove voice config: $e');
      rethrow;
    }
  }

  /// Get all companions with Azure voice configurations
  Future<List<String>> getCompanionsWithVoiceConfig() async {
    try {
      final response = await _supabase
          .from('ai_companions')
          .select('id')
          .not('azure_voice_config', 'is', null);

      return response.map<String>((row) => row['id'] as String).toList();
    } catch (e) {
      debugPrint('❌ Failed to get companions with voice config: $e');
      return [];
    }
  }

  /// Validate Azure voice configuration
  bool validateVoiceConfig(AzureVoiceCharacteristics config) {
    // Basic validation checks
    if (config.azureVoiceName.isEmpty) return false;
    if (config.languageCode.isEmpty) return false;
    if (config.basePitch < -50.0 || config.basePitch > 100.0) return false;
    if (config.baseSpeechRate < -50.0 || config.baseSpeechRate > 100.0) return false;
    if (config.baseVolume < 0.0 || config.baseVolume > 100.0) return false;
    if (config.styleDegree < 0.01 || config.styleDegree > 2.0) return false;

    return true;
  }
}
