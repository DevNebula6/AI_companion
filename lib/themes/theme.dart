import 'package:flutter/material.dart';

/// Creates a modern, visually striking app theme with a minimalist feel
ThemeData createAppTheme(ColorScheme colorScheme) {
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    
    // Typography with system fonts instead of Google Fonts
    textTheme: ThemeData(brightness: colorScheme.brightness).textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Poppins',  // You can replace with your bundled font
        fontWeight: FontWeight.w300,
        fontSize: 57,
        letterSpacing: -0.5,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w300,
        fontSize: 46,
      ),
      displaySmall: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 36,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 28,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.25,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: 16,
        letterSpacing: 0.1,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 16,
        letterSpacing: 0.5,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 14,
        letterSpacing: 0.25,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
    
    // Card theme with subtle shadows and rounded corners
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
    ),
    
    // Stylish buttons with subtle animations
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 1,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Clean, minimal outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Modern text buttons with subtle hover effects
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        foregroundColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Input fields with clean lines
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.brightness == Brightness.dark 
          ? colorScheme.surfaceVariant.withOpacity(0.4)
          : colorScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    
    // Dialogs with clean, modern appearance
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 6,
      backgroundColor: colorScheme.surface,
    ),
    
    // App bar with subtle elevation
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
    ),
    
    // Bottom sheet with curved corners
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
    ),
    
    // Tabs with custom indicator
    tabBarTheme: TabBarTheme(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.label,
      dividerHeight: 0,
    ),
    
    // Slick, modern sliders
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.primary.withOpacity(0.2),
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withOpacity(0.12),
    ),
    
    // Checkbox with modern styling
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.surfaceVariant;
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    
    // Chips with modern styling
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceVariant,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    
    // Floating Action Button with gradient option
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Scaffold background
    scaffoldBackgroundColor: colorScheme.background,
    
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.surfaceVariant;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colorScheme.primary.withOpacity(0.5);
        }
        return colorScheme.onSurface.withOpacity(0.1);
      }),
    ),
  );
}

/// Creates a modern color scheme with vibrant yet sophisticated colors
ColorScheme createModernColorScheme({
  bool isDark = false,
  String? baseColor,
}) {
  // Modern, visually striking color palette
  // Base colors - can be customized per app section or companion
  final Color primaryColor = _hexToColor(baseColor ?? (isDark ? '#7358FF' : '#7358FF'));
  final Color secondaryColor = isDark ? const Color(0xFF41C2FF) : const Color(0xFF41C2FF);
  final Color tertiaryColor = isDark ? const Color(0xFFFF6D91) : const Color(0xFFFF6D91);
  
  // Background colors
  final Color backgroundColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF7F9FC);
  final Color surfaceColor = isDark ? const Color(0xFF16213E) : Colors.white;
  final Color surfaceVariantColor = isDark ? const Color(0xFF242851) : const Color(0xFFF0F3FA);
  
  return ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    
    // Primary colors
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: _lightenColor(primaryColor, isDark ? 0.3 : 0.85),
    onPrimaryContainer: isDark ? Colors.white : primaryColor,
    
    // Secondary colors
    secondary: secondaryColor,
    onSecondary: Colors.white,
    secondaryContainer: _lightenColor(secondaryColor, isDark ? 0.3 : 0.85),
    onSecondaryContainer: isDark ? Colors.white : secondaryColor,
    
    // Tertiary colors
    tertiary: tertiaryColor,
    onTertiary: Colors.white,
    tertiaryContainer: _lightenColor(tertiaryColor, isDark ? 0.3 : 0.85),
    onTertiaryContainer: isDark ? Colors.white : tertiaryColor,
    
    // Error colors
    error: const Color(0xFFE53935),
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF5C1313) : const Color(0xFFFFDEDF),
    onErrorContainer: isDark ? Colors.white : const Color(0xFFB3261E),
    
    // Background colors
    background: backgroundColor,
    onBackground: isDark ? Colors.white : Colors.black87,
    surface: surfaceColor,
    onSurface: isDark ? Colors.white : Colors.black87,
    
    // Variant surfaces
    surfaceVariant: surfaceVariantColor,
    onSurfaceVariant: isDark ? Colors.white70 : Colors.black54,
    
    // Outline colors
    outline: isDark ? Colors.white30 : Colors.black12,
    outlineVariant: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
    
    // Shadow
    shadow: Colors.black,
    
    // Surface tint (used for elevation tints in Material 3)
    surfaceTint: primaryColor.withOpacity(0.05),
    
    // Scrim color (used for modals)
    scrim: Colors.black54,
    
    // Inverse colors (for tooltips, etc)
    inverseSurface: isDark ? Colors.white : const Color(0xFF1A1A2E),
    onInverseSurface: isDark ? Colors.black : Colors.white,
    inversePrimary: isDark ? primaryColor.withOpacity(0.8) : primaryColor,
  );
}

/// Helper to convert hex string to color
Color _hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// Helper to lighten a color
Color _lightenColor(Color color, double factor) {
  return Color.fromARGB(
    color.alpha,
    color.red + ((255 - color.red) * factor).round(),
    color.green + ((255 - color.green) * factor).round(),
    color.blue + ((255 - color.blue) * factor).round(),
  );
}