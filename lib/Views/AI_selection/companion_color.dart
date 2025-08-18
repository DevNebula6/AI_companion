import 'package:ai_companion/Companion/ai_model.dart';
import 'package:flutter/material.dart';

/// Custom color class for companion-specific styling
class CompanionColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color gradient1;
  final Color gradient2;
  final Color gradient3;
  
  CompanionColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient1,
    required this.gradient2,
    required this.gradient3,
  });

  /// Create a smooth gradient for chat backgrounds
  LinearGradient getChatGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gradient1,
        gradient2,
        gradient3,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// Create a subtle tinted gradient for app bars
  LinearGradient getAppBarGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary,
        Color.lerp(primary, secondary, 0.3)!,
      ],
    );
  }

  /// Create a lighter gradient for input fields
  LinearGradient getInputFieldGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gradient3.withOpacity(0.7),
        gradient3.withOpacity(0.9),
      ],
    );
  }
}
/// Converts companion-specific colors to a complete Material ColorScheme
ColorScheme getCompanionColorScheme(AICompanion companion) {
  final colors = getCompanionColors(companion);
  
  // Create harmonious color variants based on primary/secondary
  final Color primaryContainer = _lightenColor(colors.primary, 0.85);
  final Color secondaryContainer = _lightenColor(colors.secondary, 0.85);
  final Color tertiary = _getComplementaryColor(colors.accent);
  final Color tertiaryContainer = _lightenColor(tertiary, 0.85);
  
  // Generate surface colors with subtle tinting
  final Color surfaceColor =  Colors.white;
  
  final Color surfaceVariant =  const Color(0xFFF7F9FC); // Very light blue-gray
  
  return ColorScheme(
    brightness: Brightness.light,
    
    // Primary colors
    primary: colors.primary,
    onPrimary: _getContrastColor(colors.primary),
    primaryContainer: primaryContainer,
    onPrimaryContainer: colors.primary,
    
    // Secondary colors
    secondary: colors.secondary,
    onSecondary: _getContrastColor(colors.secondary),
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: colors.secondary,
    
    // Tertiary colors (accent)
    tertiary: tertiary,
    onTertiary: _getContrastColor(tertiary),
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: tertiary,
    
    // Background and surface colors
    background: Colors.white,
    onBackground: Colors.black87,
    surface: surfaceColor,
    onSurface: Colors.black87,
    
    // Variant surfaces for cards, dialogs, etc.
    surfaceVariant: surfaceVariant,
    onSurfaceVariant: Colors.black87.withOpacity(0.75),
    surfaceTint: colors.primary.withOpacity(0.05),
    
    // Error states
    error: const Color(0xFFE53935),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFDEDF),
    onErrorContainer: const Color(0xFFB3261E),
    
    // Outline colors
    outline: Colors.black.withOpacity(0.12),
    outlineVariant: Colors.black.withOpacity(0.06),
    
    // Shadow
    shadow: Colors.black,
    
    // Scrim overlay
    scrim: Colors.black,
    
    // Inversions for popups, tooltips, etc.
    inverseSurface: const Color(0xFF1A1A2E),
    onInverseSurface: Colors.white,
    inversePrimary: _getInverseColor(colors.primary),
  );
}

/// Updates the companion color sets with more sophisticated modern palette
CompanionColors getCompanionColors(AICompanion companion) {
  // Enhanced modern color palette by personality type with gradient support
  final Map<String, List<Map<String, Color>>> colorSets = {
    'Calm': [
      // Female palette - Ocean blue flow (darker to lighter)
      {
        'primary': const Color(0xFF2E86C1),
        'secondary': const Color(0xFF1B4F72),
        'gradient1': const Color(0xFF1E3A8A), // Deep ocean blue (app bar - darkest)
        'gradient2': const Color(0xFF3B82F6), // Bright blue (middle)
        'gradient3': const Color(0xFF60A5FA), // Light blue (input area - lightest)
      },
      // Male palette - Forest to mint green flow
      {
        'primary': const Color(0xFF1B4F72),
        'secondary': const Color(0xFF2E86C1),
        'gradient1': const Color(0xFF064E3B), // Deep forest (app bar - darkest)
        'gradient2': const Color(0xFF10B981), // Emerald green (middle)
        'gradient3': const Color(0xFF6EE7B7), // Mint green (input area - lightest)
      },
    ],
    'Creative': [
      // Female palette - Rich vibrant purple to pink (darker to lighter flow)
      {
        'primary': const Color(0xFF8E44AD),
        'secondary': const Color(0xFFE91E63),
        'gradient1': const Color(0xFF581C87), // Deep purple (app bar - darkest)
        'gradient2': const Color(0xFF9333EA), // Vibrant purple (middle)
        'gradient3': const Color(0xFFEC4899), // Bright pink (input area - lightest)
      },
      // Male palette - Electric blue to cyan flow
      {
        'primary': const Color(0xFF3498DB),
        'secondary': const Color(0xFF8E44AD),
        'gradient1': const Color(0xFF1E40AF), // Deep blue (app bar - darkest)
        'gradient2': const Color(0xFF3B82F6), // Electric blue (middle)
        'gradient3': const Color(0xFF06B6D4), // Bright cyan (input area - lightest)
      },
    ],
    'Warm': [
      // Female palette - Rich vibrant sunset (darker to lighter flow)
      {
        'primary': const Color(0xFFE74C3C),
        'secondary': const Color(0xFFF39C12),
        'gradient1': const Color(0xFFD97706), // Deep orange (app bar - darkest)
        'gradient2': const Color(0xFFF39C12), // Rich orange-amber (middle)
        'gradient3': const Color(0xFFFBBF24), // Golden amber (input area - lightest)
      },
      // Male palette - Rich amber to golden flow
      {
        'primary': const Color(0xFFD68910),
        'secondary': const Color(0xFFB7472A),
        'gradient1': const Color(0xFF92400E), // Deep brown-orange (app bar - darkest)
        'gradient2': const Color(0xFFD97706), // Rich orange (middle)
        'gradient3': const Color(0xFFF59E0B), // Golden yellow (input area - lightest)
      },
    ],
    'Thoughtful': [
      // Female palette - Deep indigo to soft purple (darker to lighter flow)
      {
        'primary': const Color(0xFF5B2C87),
        'secondary': const Color(0xFF7D3C98),
        'gradient1': const Color(0xFF3730A3), // Deep indigo (app bar - darkest)
        'gradient2': const Color(0xFF7C3AED), // Rich purple (middle)
        'gradient3': const Color(0xFFC4B5FD), // Soft lavender (input area - lightest)
      },
      // Male palette - Forest to sage green flow (darker to lighter)
      {
        'primary': const Color(0xFF186A3B),
        'secondary': const Color(0xFF52BE80),
        'gradient1': const Color(0xFF14532D), // Deep forest (app bar - darkest)
        'gradient2': const Color(0xFF16A34A), // Rich green (middle)
        'gradient3': const Color(0xFF86EFAC), // Sage green (input area - lightest)
      },
    ],
    'Energetic': [
      // Female palette - Electric pink to bright yellow (darker to lighter flow)
      {
        'primary': const Color(0xFF1ABC9C),
        'secondary': const Color(0xFF3498DB),
        'gradient1': const Color(0xFFBE185D), // Deep pink (app bar - darkest)
        'gradient2': const Color(0xFFEC4899), // Vibrant pink (middle)
        'gradient3': const Color(0xFFFDE047), // Bright yellow (input area - lightest)
      },
      // Male palette - Electric orange to bright lime flow
      {
        'primary': const Color(0xFFFF6B35),
        'secondary': const Color(0xFF3742FA),
        'gradient1': const Color(0xFF9A3412), // Deep orange (app bar - darkest)
        'gradient2': const Color(0xFFEA580C), // Electric orange (middle)
        'gradient3': const Color(0xFF84CC16), // Bright lime (input area - lightest)
      },
    ],
    'Mysterious': [
      // Female palette - Deep purple to lavender (darker to lighter flow)
      {
        'primary': const Color(0xFF4A148C),
        'secondary': const Color(0xFF1A237E),
        'gradient1': const Color(0xFF4C1D95), // Deep violet (app bar - darkest)
        'gradient2': const Color(0xFF7C3AED), // Rich purple (middle)
        'gradient3': const Color(0xFFA78BFA), // Light lavender (input area - lightest)
      },
      // Male palette - Charcoal to steel blue flow
      {
        'primary': const Color(0xFF263238),
        'secondary': const Color(0xFF37474F),
        'gradient1': const Color(0xFF0F172A), // Deep charcoal (app bar - darkest)
        'gradient2': const Color(0xFF334155), // Dark slate (middle)
        'gradient3': const Color(0xFF64748B), // Steel blue (input area - lightest)
      },
    ],
  };
  
  // Determine personality type
  String personalityType = getPersonalityType(companion);
  
  // Get color set based on personality and gender
  List<Map<String, Color>> options = colorSets[personalityType] ?? colorSets['Thoughtful']!;
  int index = companion.gender == CompanionGender.female ? 0 : 1;
  Map<String, Color> colorMap = options[index % options.length];
  
  // Generate accent color more intelligently
  Color accent;
  if (personalityType == 'Creative' || personalityType == 'Warm' || personalityType == 'Energetic') {
    // Use analogous color for more vibrant personalities
    accent = _getAnalogousColor(colorMap['primary']!);
  } else {
    // Use gentle intermediate shade for calmer personalities
    accent = Color.lerp(colorMap['primary']!, colorMap['secondary']!, 0.3)!;
  }
  
  return CompanionColors(
    primary: colorMap['primary']!,
    secondary: colorMap['secondary']!,
    accent: accent,
    gradient1: colorMap['gradient1']!,
    gradient2: colorMap['gradient2']!,
    gradient3: colorMap['gradient3']!,
  );
}

/// Utility method to get a proper contrasting text color
Color _getContrastColor(Color backgroundColor) {
  // Calculate relative luminance using standard formula
  double luminance = (0.299 * backgroundColor.red + 
                     0.587 * backgroundColor.green + 
                     0.114 * backgroundColor.blue) / 255;
  
  // Use white text on dark backgrounds, black on light
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}

/// Create a complementary color (opposite on color wheel)
Color _getComplementaryColor(Color color) {
  // Convert to HSL for easier manipulation
  HSLColor hsl = HSLColor.fromColor(color);
  
  // Rotate hue by 180 degrees for complementary color
  return hsl.withHue((hsl.hue + 180) % 360).toColor();
}

/// Create an analogous color (adjacent on color wheel)
Color _getAnalogousColor(Color color) {
  // Convert to HSL for easier manipulation
  HSLColor hsl = HSLColor.fromColor(color);
  
  // Shift hue by 30 degrees for analogous color
  return hsl.withHue((hsl.hue + 30) % 360).toColor();
}

/// Lighten a color to create container variants
Color _lightenColor(Color color, double factor) {
  // Convert to HSL for easier manipulation
  HSLColor hsl = HSLColor.fromColor(color);
  
  // Create lighter version with same hue
  return hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * factor).clamp(0.0, 1.0)).toColor();
}

/// Darken a color to create shadow or disabled variants
Color _darkenColor(Color color, double factor) {
  HSLColor hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * (1 - factor)).clamp(0.0, 1.0)).toColor();
}

/// Get inverse color for contrast situations
Color _getInverseColor(Color color) {
  HSLColor hsl = HSLColor.fromColor(color);
  
  // Create inverted hue with adjusted saturation
  return hsl.withHue((hsl.hue + 180) % 360)
            .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
            .withLightness((1 - hsl.lightness).clamp(0.3, 0.8))
            .toColor();
}

String getPersonalityType(AICompanion companion) {
  final traits = companion.personality.primaryTraits;
  
  if (traits.any((t) => ['Calm', 'Peaceful', 'Serene', 'Composed', 'Tranquil', 'Meditative'].contains(t))) {
    return 'Calm';
  } else if (traits.any((t) => ['Creative', 'Artistic', 'Innovative', 'Imaginative', 'Expressive', 'Visionary'].contains(t))) {
    return 'Creative';
  } else if (traits.any((t) => ['Warm', 'Nurturing', 'Cheerful', 'Friendly', 'Optimistic', 'Caring', 'Affectionate'].contains(t))) {
    return 'Warm';
  } else if (traits.any((t) => ['Energetic', 'Dynamic', 'Vibrant', 'Enthusiastic', 'Lively', 'Spirited', 'Active'].contains(t))) {
    return 'Energetic';
  } else if (traits.any((t) => ['Mysterious', 'Enigmatic', 'Secretive', 'Intriguing', 'Complex', 'Deep', 'Intense'].contains(t))) {
    return 'Mysterious';
  } else {
    return 'Thoughtful';
  }
}

  // Helper method to get skill icon
  IconData getSkillIcon(String skill) {
    final String lowercaseSkill = skill.toLowerCase();
    
    if (lowercaseSkill.contains('design') || lowercaseSkill.contains('art')) {
      return Icons.design_services;
    } else if (lowercaseSkill.contains('cook') || lowercaseSkill.contains('bak')) {
      return Icons.restaurant;
    } else if (lowercaseSkill.contains('music') || lowercaseSkill.contains('sing') || lowercaseSkill.contains('play')) {
      return Icons.music_note;
    } else if (lowercaseSkill.contains('language') || lowercaseSkill.contains('speak') || lowercaseSkill.contains('fluency')) {
      return Icons.translate;
    } else if (lowercaseSkill.contains('write') || lowercaseSkill.contains('story') || lowercaseSkill.contains('poetry')) {
      return Icons.edit_note;
    } else if (lowercaseSkill.contains('tech') || lowercaseSkill.contains('code') || lowercaseSkill.contains('program')) {
      return Icons.code;
    } else if (lowercaseSkill.contains('social') || lowercaseSkill.contains('people') || lowercaseSkill.contains('communication')) {
      return Icons.people;
    } else if (lowercaseSkill.contains('strategy') || lowercaseSkill.contains('chess')) {
      return Icons.psychology;
    } else if (lowercaseSkill.contains('photo')) {
      return Icons.camera_alt;
    }
    
    return Icons.star;
  }

  // Helper method to get voice icon
  IconData getVoiceIcon(String attribute, int index) {
    if (attribute.contains('accent') || attribute.contains('phrases')) {
      return Icons.language;
    } else if (attribute.contains('enthusiastic') || attribute.contains('animated') || attribute.contains('expressive')) {
      return Icons.sentiment_very_satisfied;
    } else if (attribute.contains('calm') || attribute.contains('soothing') || attribute.contains('measured')) {
      return Icons.waves;
    } else if (attribute.contains('laugh') || attribute.contains('humor')) {
      return Icons.mood;
    } else if (attribute.contains('pauses') || attribute.contains('thoughtful')) {
      return Icons.motion_photos_pause;
    } else if (attribute.contains('storytelling') || attribute.contains('descriptive')) {
      return Icons.auto_stories;
    }
    
    // Alternate between different voice-related icons
    final List<IconData> voiceIcons = [
      Icons.record_voice_over,
      Icons.graphic_eq,
      Icons.mic,
      Icons.volume_up,
    ];
    
    return voiceIcons[index % voiceIcons.length];
  }

  // Helper method to get conversation icon
  IconData getConversationIcon(String topic) {
    // Reuse interest icon logic since topics are derived from interests
    return getInterestIcon(topic);
  }

  // Helper method to generate conversation prompts
  String getConversationPrompt(String topic) {
    final String lowercaseTopic = topic.toLowerCase();
    
    if (lowercaseTopic.contains('art') || lowercaseTopic.contains('design')) {
      return "Discuss favorite art movements and creative influences";
    } else if (lowercaseTopic.contains('music')) {
      return "Share thoughts about musical styles and memorable performances";
    } else if (lowercaseTopic.contains('food') || lowercaseTopic.contains('cook')) {
      return "Exchange favorite recipes and culinary experiences";
    } else if (lowercaseTopic.contains('book') || lowercaseTopic.contains('read')) {
      return "Talk about inspiring books and favorite authors";
    } else if (lowercaseTopic.contains('travel')) {
      return "Share memorable journeys and dream destinations";
    } else if (lowercaseTopic.contains('tech')) {
      return "Discuss technological innovations and digital trends";
    } else if (lowercaseTopic.contains('nature') || lowercaseTopic.contains('outdoor')) {
      return "Explore favorite natural places and outdoor activities";
    } else if (lowercaseTopic.contains('culture') || lowercaseTopic.contains('history')) {
      return "Discover fascinating historical periods and cultural practices";
    } else if (lowercaseTopic.contains('wine') || lowercaseTopic.contains('tea')) {
      return "Compare preferences and tasting experiences";
    }
    
    return "Have a meaningful conversation about $topic";
  }
IconData getPersonalityIcon(AICompanion companion) {
  String type = getPersonalityType(companion);
  
  switch (type) {
    case 'Calm': return Icons.water_drop_outlined;
    case 'Creative': return Icons.palette_outlined;
    case 'Warm': return Icons.local_fire_department_outlined;
    case 'Thoughtful': return Icons.psychology_outlined;
    default: return Icons.star_outline;
  }
}

String getPersonalityLabel(AICompanion companion) {
  return getPersonalityType(companion);
}

/// Get an icon that best represents a given interest
IconData getInterestIcon(String interest) {
  // Convert to lowercase for case-insensitive matching
  final String lowercaseInterest = interest.toLowerCase();
  
  // Art & Design
  if (lowercaseInterest.contains('design') || 
      lowercaseInterest.contains('interior')) {
    return Icons.design_services;
  }
  if (lowercaseInterest.contains('art') || 
      lowercaseInterest.contains('exhibition') || 
      lowercaseInterest.contains('gallery')) {
    return Icons.palette;
  }
  if (lowercaseInterest.contains('architecture') || 
      lowercaseInterest.contains('building')) {
    return Icons.architecture;
  }
  
  // Reading & Writing
  if (lowercaseInterest.contains('book') || 
      lowercaseInterest.contains('fiction') || 
      lowercaseInterest.contains('reading')) {
    return Icons.auto_stories;
  }
  if (lowercaseInterest.contains('poetry') || 
      lowercaseInterest.contains('writing')) {
    return Icons.edit_note;
  }
  
  // Food & Drink
  if (lowercaseInterest.contains('baking') || 
      lowercaseInterest.contains('cook')) {
    return Icons.bakery_dining;
  }
  if (lowercaseInterest.contains('farmers') || 
      lowercaseInterest.contains('market')) {
    return Icons.store;
  }
  if (lowercaseInterest.contains('dining') || 
      lowercaseInterest.contains('restaurant')) {
    return Icons.restaurant;
  }
  if (lowercaseInterest.contains('tea')) {
    return Icons.emoji_food_beverage;
  }
  if (lowercaseInterest.contains('wine') || 
      lowercaseInterest.contains('cocktail')) {
    return Icons.wine_bar;
  }
  
  // Music & Entertainment
  if (lowercaseInterest.contains('music') || 
      lowercaseInterest.contains('classical')) {
    return Icons.music_note;
  }
  if (lowercaseInterest.contains('movie') || 
      lowercaseInterest.contains('film')) {
    return Icons.movie;
  }
  if (lowercaseInterest.contains('theater') || 
      lowercaseInterest.contains('drama')) {
    return Icons.theater_comedy;
  }
  
  // Nature & Mindfulness
  if (lowercaseInterest.contains('garden') || 
      lowercaseInterest.contains('plant')) {
    return Icons.nature;
  }
  if (lowercaseInterest.contains('mindful') || 
      lowercaseInterest.contains('meditation')) {
    return Icons.self_improvement;
  }
  if (lowercaseInterest.contains('yoga') || 
      lowercaseInterest.contains('fitness')) {
    return Icons.fitness_center;
  }
  if (lowercaseInterest.contains('rain') || 
      lowercaseInterest.contains('weather')) {
    return Icons.water_drop;
  }
  
  // Travel & Culture
  if (lowercaseInterest.contains('travel') || 
      lowercaseInterest.contains('adventure')) {
    return Icons.travel_explore;
  }
  if (lowercaseInterest.contains('international') || 
      lowercaseInterest.contains('global') || 
      lowercaseInterest.contains('affair')) {
    return Icons.public;
  }
  if (lowercaseInterest.contains('ceremony') || 
      lowercaseInterest.contains('japanese') || 
      lowercaseInterest.contains('ikebana')) {
    return Icons.spa;
  }
  if (lowercaseInterest.contains('history')) {
    return Icons.history_edu;
  }
  
  // Hobbies & Collections
  if (lowercaseInterest.contains('vintage') || 
      lowercaseInterest.contains('antique')) {
    return Icons.watch;
  }
  if (lowercaseInterest.contains('textile') || 
      lowercaseInterest.contains('fabric')) {
    return Icons.texture;
  }
  if (lowercaseInterest.contains('mystery') || 
      lowercaseInterest.contains('detective')) {
    return Icons.search;
  }
  if (lowercaseInterest.contains('chess') || 
      lowercaseInterest.contains('game')) {
    return Icons.casino;
  }
  if (lowercaseInterest.contains('photo')) {
    return Icons.photo_camera;
  }
  // Default fallback
  return Icons.interests;
}

/// Get an icon that represents a personality trait
IconData getTraitIcon(String trait) {
  final String lowercaseTrait = trait.toLowerCase();
  
  // Creative & Artistic traits
  if (lowercaseTrait.contains('creative') || 
      lowercaseTrait.contains('artistic') ||
      lowercaseTrait.contains('innovative') ||
      lowercaseTrait.contains('visual thinker')) {
    return Icons.lightbulb_outline;
  }
  
  // Passionate & Expressive traits
  if (lowercaseTrait.contains('passionate') || 
      lowercaseTrait.contains('expressive') ||
      lowercaseTrait.contains('animated') ||
      lowercaseTrait.contains('enthusiastic')) {
    return Icons.local_fire_department_outlined;
  }
  
  // Thoughtful & Perceptive traits
  if (lowercaseTrait.contains('thoughtful') || 
      lowercaseTrait.contains('perceptive') ||
      lowercaseTrait.contains('observant') ||
      lowercaseTrait.contains('insightful')) {
    return Icons.psychology_outlined;
  }
  
  // Calm & Composed traits
  if (lowercaseTrait.contains('calm') || 
      lowercaseTrait.contains('composed') ||
      lowercaseTrait.contains('serene') ||
      lowercaseTrait.contains('peaceful') ||
      lowercaseTrait.contains('appreciates silence')) {
    return Icons.spa_outlined;
  }
  
  // Strategic & Analytical traits
  if (lowercaseTrait.contains('strategic') || 
      lowercaseTrait.contains('analytical') ||
      lowercaseTrait.contains('logical') ||
      lowercaseTrait.contains('precise') ||
      lowercaseTrait.contains('chess player')) {
    return Icons.analytics_outlined;
  }
  
  // Social & Diplomatic traits
  if (lowercaseTrait.contains('diplomatic') || 
      lowercaseTrait.contains('social') ||
      lowercaseTrait.contains('charismatic') ||
      lowercaseTrait.contains('friendly')) {
    return Icons.handshake_outlined;
  }
  
  // Intelligent & Curious traits
  if (lowercaseTrait.contains('intelligent') || 
      lowercaseTrait.contains('curious') ||
      lowercaseTrait.contains('witty') ||
      lowercaseTrait.contains('intellectual') ||
      lowercaseTrait.contains('quotes books')) {
    return Icons.school_outlined;
  }
  
  // Warm & Nurturing traits
  if (lowercaseTrait.contains('warm') || 
      lowercaseTrait.contains('nurturing') ||
      lowercaseTrait.contains('caring') ||
      lowercaseTrait.contains('supportive')) {
    return Icons.favorite_outline;
  }
  
  // Cheerful & Optimistic traits
  if (lowercaseTrait.contains('cheerful') || 
      lowercaseTrait.contains('optimistic') ||
      lowercaseTrait.contains('happy') ||
      lowercaseTrait.contains('positive') ||
      lowercaseTrait.contains('sweet tooth') ||
      lowercaseTrait.contains('hums while working')) {
    return Icons.mood;
  }
  
  // Patient & Authentic traits
  if (lowercaseTrait.contains('patient') || 
      lowercaseTrait.contains('authentic') ||
      lowercaseTrait.contains('genuine') ||
      lowercaseTrait.contains('sincere')) {
    return Icons.watch_later_outlined;
  }
  
  // Adaptable & Flexible traits
  if (lowercaseTrait.contains('adaptable') || 
      lowercaseTrait.contains('flexible') ||
      lowercaseTrait.contains('versatile')) {
    return Icons.sync_alt;
  }
  
  // Detail-oriented & Perfectionist traits
  if (lowercaseTrait.contains('detail') || 
      lowercaseTrait.contains('perfectionist') ||
      lowercaseTrait.contains('meticulous') ||
      lowercaseTrait.contains('values punctuality')) {
    return Icons.tune;
  }
  
  // Private & Independent traits
  if (lowercaseTrait.contains('private') || 
      lowercaseTrait.contains('independent') ||
      lowercaseTrait.contains('reserved') ||
      lowercaseTrait.contains('introspective')) {
    return Icons.lock_outline;
  }
  
  // Collector & Appreciation traits
  if (lowercaseTrait.contains('collector') || 
      lowercaseTrait.contains('appreciation') ||
      lowercaseTrait.contains('connoisseur')) {
    return Icons.collections_outlined;
  }
  
  // Time preference traits
  if (lowercaseTrait.contains('night owl')) {
    return Icons.nightlight_outlined;
  }
  if (lowercaseTrait.contains('morning person')) {
    return Icons.wb_sunny_outlined;
  }
  
  // Home/Space traits
  if (lowercaseTrait.contains('rearranging furniture') || 
      lowercaseTrait.contains('home')) {
    return Icons.chair_outlined;
  }
  
  // Beverage preferences
  if (lowercaseTrait.contains('tea')) {
    return Icons.emoji_food_beverage;
  }
  if (lowercaseTrait.contains('wine')) {
    return Icons.wine_bar_outlined;
  }
  
  // Default fallback
  return Icons.stars_outlined;
}

/// Get a color that represents a personality trait
Color getTraitColor(String trait, BuildContext context) {
  // Convert to lowercase for case-insensitive matching
  final String lowercaseTrait = trait.toLowerCase();
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  
  // Creative & Passionate traits (purples & reds)
  if (lowercaseTrait.contains('creative') || 
      lowercaseTrait.contains('artistic') ||
      lowercaseTrait.contains('passionate') ||
      lowercaseTrait.contains('expressive')) {
    return const Color(0xFF9C27B0);  // Purple
  }
  
  // Thoughtful & Calm traits (blues & teals)
  if (lowercaseTrait.contains('thoughtful') || 
      lowercaseTrait.contains('calm') ||
      lowercaseTrait.contains('composed') ||
      lowercaseTrait.contains('precise') ||
      lowercaseTrait.contains('perceptive')) {
    return const Color(0xFF0288D1);  // Blue
  }
  
  // Cheerful & Warm traits (oranges & yellows)
  if (lowercaseTrait.contains('cheerful') || 
      lowercaseTrait.contains('optimistic') ||
      lowercaseTrait.contains('warm') ||
      lowercaseTrait.contains('nurturing') ||
      lowercaseTrait.contains('sweet')) {
    return const Color(0xFFFF9800);  // Orange
  }
  
  // Intelligent & Strategic traits (deep blues & indigos)
  if (lowercaseTrait.contains('intelligent') || 
      lowercaseTrait.contains('strategic') ||
      lowercaseTrait.contains('witty') ||
      lowercaseTrait.contains('analytical') ||
      lowercaseTrait.contains('chess')) {
    return const Color(0xFF3F51B5);  // Indigo
  }
  
  // Patient & Authentic traits (greens)
  if (lowercaseTrait.contains('patient') || 
      lowercaseTrait.contains('authentic') ||
      lowercaseTrait.contains('adaptable') ||
      lowercaseTrait.contains('diplomatic')) {
    return const Color(0xFF4CAF50);  // Green
  }
  
  // Detail & Private traits (grays & silvers)
  if (lowercaseTrait.contains('detail') || 
      lowercaseTrait.contains('private') ||
      lowercaseTrait.contains('silence')) {
    return const Color(0xFF607D8B);  // Blue Grey
  }

  // Night vs Morning
  if (lowercaseTrait.contains('night')) {
    return const Color(0xFF5E35B1);  // Deep Purple
  }
  if (lowercaseTrait.contains('morning')) {
    return const Color(0xFFFFB74D);  // Amber
  }
  
  // Default fallback - use primary color
  return colorScheme.primary;
}

/// Create a dynamic gradient with smooth color transitions (messenger-style)
LinearGradient createDynamicGradient(AICompanion companion, {
  GradientType type = GradientType.chat,
  double opacity = 1.0,
}) {
  final colors = getCompanionColors(companion);
  
  switch (type) {
    case GradientType.chat:
      // Seamless messenger-style gradient from dark to complementary colors
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.gradient1.withOpacity(opacity), // App bar color (darkest)
          colors.gradient2.withOpacity(opacity), // Middle transition
          colors.gradient3.withOpacity(opacity), // Input area (complementary)
        ],
        stops: const [0.0, 0.7, 1.0], // More gradual transition
      );
    case GradientType.appBar:
      // Rich app bar gradient
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.gradient1.withOpacity(opacity),
          Color.lerp(colors.gradient1, colors.gradient2, 0.3)!.withOpacity(opacity),
        ],
      );
    case GradientType.inputField:
      // Subtle input field gradient that blends with background
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.gradient3.withOpacity(opacity),
          colors.gradient3.withOpacity(opacity),
        ],
      );
    case GradientType.bubble:
      // Frosted glass bubble gradients with subtle transparency
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.gradient2.withOpacity(0.15 * opacity), // Very subtle top color
          colors.gradient3.withOpacity(0.25 * opacity), // Slightly more visible bottom
          colors.gradient2.withOpacity(0.12 * opacity), // Even more subtle at bottom
        ],
        stops: const [0.0, 0.5, 1.0],
      );
    case GradientType.userBubble:
      // User message bubbles with slightly different frosted effect
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.gradient1.withOpacity(0.20 * opacity), // Slightly more visible for user messages
          colors.gradient2.withOpacity(0.30 * opacity),
          colors.gradient1.withOpacity(0.15 * opacity),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
  }
}

/// Gradient types for different UI components
enum GradientType {
  chat,
  appBar,
  inputField,
  bubble,
  userBubble,
}

/// Create a subtle shadow color based on the companion's primary color
Color getCompanionShadowColor(AICompanion companion) {
  final colors = getCompanionColors(companion);
  return _darkenColor(colors.primary, 0.3).withOpacity(0.2);
}

/// Get a tinted surface color that harmonizes with companion colors
Color getCompanionSurfaceColor(AICompanion companion, {double tintStrength = 0.02}) {
  final colors = getCompanionColors(companion);
  return Color.lerp(Colors.white, colors.gradient2, tintStrength)!;
}

/// Create a radial gradient for special effects
RadialGradient createRadialGradient(AICompanion companion, {
  AlignmentGeometry center = Alignment.center,
  double radius = 1.0,
}) {
  final colors = getCompanionColors(companion);
  return RadialGradient(
    center: center,
    radius: radius,
    colors: [
      colors.gradient1.withOpacity(0.3),
      colors.gradient2.withOpacity(0.1),
      Colors.transparent,
    ],
    stops: const [0.0, 0.6, 1.0],
  );
}