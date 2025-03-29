import 'package:flutter/material.dart';

/// A comprehensive typography system for the AI Companion app.
/// 
/// This class implements a dual-font strategy:
/// - Space Grotesk: Used for headings and display text, providing a modern tech aesthetic
/// - Plus Jakarta Sans: Used for body text and UI elements, offering excellent readability
/// 
/// Using predefined styles ensures visual consistency while improving performance
/// by preventing style recreation during scrolling and animations.
class AppTextStyles {
  // DISPLAY & HEADINGS (Space Grotesk)
  
  /// Used for main screen titles and the largest headers
  /// Examples: Welcome screen title, Onboarding page headers
  static const displayLarge = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: Colors.black87,
  );
  
  /// Used for section titles and medium-sized headers
  /// Examples: "Choose Your Companion", profile section titles
  static const displayMedium = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
    color: Colors.black87,
  );
  
  /// Used for card titles and smaller headers
  /// Examples: Card titles, dialog headers
  static const displaySmall = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
    color: Colors.black87,
  );
  
  /// Used for section headers within cards or content areas
  /// Examples: "Personality Traits", "Your Interests"
  static const sectionHeader = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
    color: Colors.black87,
  );
  
  // BODY TEXT (Plus Jakarta Sans)
  
  /// Primary body text style for most content
  /// Examples: Profile descriptions, longer text sections
  static const bodyLarge = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Colors.black87,
  );
  
  /// Secondary body text style for medium prominence content
  /// Examples: Companion descriptions, details text
  static const bodyMedium = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Colors.black87,
  );
  
  /// Smaller body text for less important content
  /// Examples: Captions, hints, secondary information
  static const bodySmall = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Colors.black54,
  );
  
  // LABELS & CAPTIONS (Plus Jakarta Sans)
  
  /// Used for form field labels and section headings
  /// Examples: Input field labels, settings headers
  static const labelLarge = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: Colors.black54,
  );
  
  /// Used for smaller labels and secondary information
  /// Examples: Form field hints, metadata
  static const labelMedium = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: Colors.black54,
  );
  
  /// Used for the smallest text elements
  /// Examples: Timestamps, version info, metadata
  static const labelSmall = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: Colors.black54,
  );
  
  // BUTTONS & INTERACTIVE ELEMENTS (Plus Jakarta Sans)
  
  /// Used for primary buttons and CTAs
  /// Examples: "Save Profile", "Start Conversation"
  static const buttonLarge = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.4,
    color: Colors.white,
  );
  
  /// Used for secondary buttons and smaller CTAs
  /// Examples: Secondary actions, smaller buttons
  static const buttonMedium = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: Colors.white,
  );
  
  /// Used for small button labels and menu items
  /// Examples: Dropdown menu items, chips, badges
  static const buttonSmall = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: Colors.white,
  );
  
  // SPECIAL STYLES
  
  /// Used for companion names in selection cards
  /// Example: Companion name in profile card
  static const companionName = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
    color: Colors.white,
  );
  
  /// Used for companion names with Popins font
  /// Example: Companion name and age in profile cards
  static const companionNamePopins = TextStyle(
    fontFamily: 'Popins',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing:0.5,
    height: 1.4,
    color: Colors.white,
  );
  
  /// Used for companion descriptions and bios
  /// Example: The brief description of companion personalities
  static const companionDescription = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Colors.white70,
  );
  
  /// Used for displaying traits/interests as chips
  /// Examples: Personality traits, interests
  static const chipLabel = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: Colors.black54,
  );
  
  /// Used for quotes or highlighted text
  /// Examples: Companion quotes, testimonials
  static const quoteText = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.6,
    color: Colors.black87,
  );
  
  /// Used for stats and metrics
  /// Examples: Interest category counts, completion percentages
  static const statsNumber = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Colors.black87,
  );
  
  /// Used for profile attribute labels in companion details
  /// Examples: "Native Language:", "Expertise Level:"
  static const attributeLabel = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14, 
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: Colors.black54,
  );
  
  /// Used for profile attribute values in companion details
  /// Examples: The answers to attribute labels
  static const attributeValue = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Colors.black87,
  );
  
  /// Used for appbar titles
  /// Examples: "Profile", "Settings", "Conversations"
  static const appBarTitle = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: Colors.black87,
  );
  
  // FALLBACK LEGACY STYLES (for backward compatibility)
  
  /// Legacy style - migrate to labelMedium
  static const labelStyle = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 13,
    color: Colors.black54,
  );
  
  /// Legacy style - migrate to sectionHeader
  static const headerStyle = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  // HELPER METHODS
  
  /// Returns a copy of the style with specified color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
  
  /// Returns a copy of the style with bold weight
  static TextStyle withBold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w700);
  }
  
  /// Returns a copy of the style with medium weight
  static TextStyle withMedium(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w500);
  }
  
  /// Returns a copy of the style with italic style
  static TextStyle withItalic(TextStyle style) {
    return style.copyWith(fontStyle: FontStyle.italic);
  }
  
  /// Returns a light theme variant of the style (for light backgrounds)
  static TextStyle forLightTheme(TextStyle style) {
    return style.copyWith(
      color: style.color?.withOpacity(0.87) ?? Colors.black87,
    );
  }
  
  /// Returns a dark theme variant of the style (for dark backgrounds)
  static TextStyle forDarkTheme(TextStyle style) {
    // Adjust color for dark theme
    Color textColor;
    if (style.color == Colors.black87) {
      textColor = Colors.white;
    } else if (style.color == Colors.black54) {
      textColor = Colors.white70;
    } else {
      textColor = style.color ?? Colors.white;
    }
    
    return style.copyWith(color: textColor);
  }
}