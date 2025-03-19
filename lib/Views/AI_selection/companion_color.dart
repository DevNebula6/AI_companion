import 'dart:ui';

import 'package:ai_companion/Companion/ai_model.dart';
import 'package:flutter/material.dart';

/// Custom color class for companion-specific styling
class CompanionColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  
  CompanionColors({
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

CompanionColors getCompanionColors(AICompanion companion) {
  // Base color sets for different personality types
  final Map<String, List<List<Color>>> colorSets = {
    'Calm': [
      [const Color(0xFF3A6073), const Color(0xFF16213E)], // Blue
      [const Color(0xFF606C88), const Color(0xFF3F4C6B)], // Navy
    ],
    'Creative': [
      [const Color(0xFF834D9B), const Color(0xFFD04ED6)], // Purple
      [const Color(0xFFCB356B), const Color(0xFFBD3F32)], // Red
    ],
    'Warm': [
      [const Color(0xFFFF8008), const Color(0xFFFFC837)], // Orange
      [const Color(0xFFEB3349), const Color(0xFFF45C43)], // Red-orange
    ],
    'Thoughtful': [
      [const Color(0xFF4776E6), const Color(0xFF8E54E9)], // Purple-blue
      [const Color(0xFF067D68), const Color(0xFF0E9577)], // Teal
    ],
  };
  
  // Determine personality type
  String personalityType = _getPersonalityType(companion);
  
  // Get color set based on personality and gender
  List<List<Color>> options = colorSets[personalityType] ?? colorSets['Thoughtful']!;
  int index = companion.gender == CompanionGender.female ? 0 : 1;
  List<Color> colors = options[index % options.length];
  
  return CompanionColors(
    primary: colors[0],
    secondary: colors[1],
    accent: Color.lerp(colors[0], colors[1], 0.5)!,
  );
}

String _getPersonalityType(AICompanion companion) {
  final traits = companion.personality.primaryTraits;
  
  if (traits.any((t) => ['Calm', 'Peaceful', 'Serene', 'Composed'].contains(t))) {
    return 'Calm';
  } else if (traits.any((t) => ['Creative', 'Artistic', 'Innovative', 'Imaginative'].contains(t))) {
    return 'Creative';
  } else if (traits.any((t) => ['Warm', 'Nurturing', 'Cheerful', 'Friendly', 'Optimistic'].contains(t))) {
    return 'Warm';
  } else {
    return 'Thoughtful';
  }
}

IconData getPersonalityIcon(AICompanion companion) {
  String type = _getPersonalityType(companion);
  
  switch (type) {
    case 'Calm': return Icons.water_drop_outlined;
    case 'Creative': return Icons.palette_outlined;
    case 'Warm': return Icons.local_fire_department_outlined;
    case 'Thoughtful': return Icons.psychology_outlined;
    default: return Icons.star_outline;
  }
}

String getPersonalityLabel(AICompanion companion) {
  return _getPersonalityType(companion);
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