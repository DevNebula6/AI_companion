import 'package:fluid_background/fluid_background.dart';
import 'package:flutter/material.dart';

Widget buildFluidBackground(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  
  // Choose theme based on time of day for dynamic experience
  final fluidTheme = _getEnhancedFluidTheme(colorScheme);
  
  return FluidBackground(
    initialColors: fluidTheme.colors,
    initialPositions: fluidTheme.positions,
    velocity: fluidTheme.velocity,
    bubblesSize: fluidTheme.bubblesSize,
    sizeChangingRange: fluidTheme.sizeRange,
    allowColorChanging: fluidTheme.allowColorChanging,
    bubbleMutationDuration: fluidTheme.mutationDuration,
    child: Container(),
  );
}

/// Enhanced fluid theme with vibrant, modern colors optimized for readability
FluidTheme _getEnhancedFluidTheme(ColorScheme colorScheme) {
  final hour = DateTime.now().hour;
  
  if (hour >= 6 && hour < 12) {
    // Morning theme - Fresh and energetic with vibrant cool tones
    return FluidTheme(
      colors: InitialColors.custom([
        const Color(0xFF00E5FF).withOpacity(0.85), // Electric cyan - vibrant and fresh
        const Color(0xFF1DE9B6).withOpacity(0.80), // Mint green - modern and crisp
        const Color(0xFF40C4FF).withOpacity(0.90), // Sky blue - bright and airy
        const Color(0xFF18FFFF).withOpacity(0.75), // Aqua - refreshing accent
        const Color(0xFF69F0AE).withOpacity(0.70), // Light green - soft complement
        const Color(0xFFE91E63).withOpacity(0.65), // Vibrant pink - energetic contrast
      ]),
      positions: InitialOffsets.random(6),
      velocity: 65, // Smooth movement
      bubblesSize: 420,
      sizeRange: [300, 520],
      allowColorChanging: true,
      mutationDuration: const Duration(seconds: 8),
    );
  } else if (hour >= 12 && hour < 18) {
    // Afternoon theme - Professional vibrant blues with modern accents
    return FluidTheme(
      colors: InitialColors.custom([
        const Color(0xFF2196F3).withOpacity(0.90), // Material blue - professional and vibrant
        const Color(0xFF00BCD4).withOpacity(0.85), // Cyan - modern and fresh
        const Color(0xFF03DAC6).withOpacity(0.80), // Teal - balanced and elegant
        const Color(0xFF40C4FF).withOpacity(0.88), // Light blue - airy complement
        const Color(0xFF1DE9B6).withOpacity(0.75), // Mint - fresh accent
        const Color(0xFF9C27B0).withOpacity(0.70), // Purple - creative contrast
      ]),
      positions: InitialOffsets.random(6),
      velocity: 55, // Moderate for focus
      bubblesSize: 380,
      sizeRange: [280, 450],
      allowColorChanging: true,
      mutationDuration: const Duration(seconds: 10),
    );
  } else if (hour >= 18 && hour < 22) {
    // Evening theme - Sophisticated purples with electric accents
    return FluidTheme(
      colors: InitialColors.custom([
        const Color(0xFF7C4DFF).withOpacity(0.95), // Electric purple - vibrant and modern
        const Color(0xFF536DFE).withOpacity(0.90), // Indigo - sophisticated
        const Color(0xFF3F51B5).withOpacity(0.85), // Deep blue - elegant base
        const Color(0xFF9C27B0).withOpacity(0.80), // Purple - creative accent
        const Color(0xFF00E5FF).withOpacity(0.75), // Cyan - cool contrast
        const Color(0xFFE91E63).withOpacity(0.70), // Hot pink - dramatic accent
      ]),
      positions: InitialOffsets.random(6),
      velocity: 50, // Relaxed but dynamic
      bubblesSize: 360,
      sizeRange: [260, 420],
      allowColorChanging: true,
      mutationDuration: const Duration(seconds: 12),
    );
  } else {
    // Night theme - Deep blues with electric accents for a premium feel
    return FluidTheme(
      colors: InitialColors.custom([
        const Color(0xFF1A237E).withOpacity(0.92), // Deep navy - sophisticated base
        const Color(0xFF283593).withOpacity(0.88), // Rich indigo - elegant depth
        const Color(0xFF3949AB).withOpacity(0.85), // Purple-blue - modern accent
        const Color(0xFF5C6BC0).withOpacity(0.80), // Soft indigo - gentle complement
        const Color(0xFF00E5FF).withOpacity(0.75), // Electric cyan - vibrant accent
        const Color(0xFF7C4DFF).withOpacity(0.70), // Electric purple - mysterious glow
      ]),
      positions: InitialOffsets.random(6),
      velocity: 40, // Slower for nighttime relaxation
      bubblesSize: 340,
      sizeRange: [240, 400],
      allowColorChanging: true,
      mutationDuration: const Duration(seconds: 15),
    );
  }
}

/// Configuration class for fluid themes
class FluidTheme {
  final InitialColors colors;
  final InitialOffsets positions;
  final double velocity;
  final double bubblesSize;
  final List<double> sizeRange;
  final bool allowColorChanging;
  final Duration mutationDuration;

  FluidTheme({
    required this.colors,
    required this.positions,
    required this.velocity,
    required this.bubblesSize,
    required this.sizeRange,
    required this.allowColorChanging,
    required this.mutationDuration,
  });
}