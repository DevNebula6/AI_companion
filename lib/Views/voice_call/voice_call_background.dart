import 'package:fluid_background/fluid_background.dart';
import 'package:flutter/material.dart';
import '../../Companion/ai_model.dart';
import '../AI_selection/companion_color.dart';

/// Enhanced voice call background with companion-specific themes
/// Creates a sleek, modern dark background with dynamic companion colors
Widget buildVoiceCallBackground({
  required BuildContext context,
  required AICompanion companion,
  bool isActive = false,
  bool isUserSpeaking = false,
  bool isCompanionSpeaking = false,
}) {
  // Get companion-specific color scheme
  final companionColors = getCompanionColors(companion);
  final personalityType = getPersonalityType(companion);
  
  // Choose theme based on call state and companion personality
  final voiceTheme = _getVoiceCallFluidTheme(
    companionColors: companionColors,
    personalityType: personalityType,
    isActive: isActive,
    isUserSpeaking: isUserSpeaking,
    isCompanionSpeaking: isCompanionSpeaking,
  );
  
  return FluidBackground(
    initialColors: voiceTheme.colors,
    initialPositions: voiceTheme.positions,
    velocity: voiceTheme.velocity,
    bubblesSize: voiceTheme.bubblesSize,
    sizeChangingRange: voiceTheme.sizeRange,
    allowColorChanging: voiceTheme.allowColorChanging,
    bubbleMutationDuration: voiceTheme.mutationDuration,
    child: Container(
      decoration: BoxDecoration(
        // Dark overlay to ensure readability
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
    ),
  );
}

/// Voice call fluid theme with companion-specific colors and call state awareness
VoiceCallFluidTheme _getVoiceCallFluidTheme({
  required CompanionColors companionColors,
  required String personalityType,
  required bool isActive,
  required bool isUserSpeaking,
  required bool isCompanionSpeaking,
}) {
  // Base velocity and intensity modifiers based on call state
  double baseVelocity = isActive ? 80 : 50;
  double intensityMultiplier = 1.0;
  
  // Increase activity during speaking
  if (isUserSpeaking || isCompanionSpeaking) {
    baseVelocity += 30;
    intensityMultiplier = 1.4;
  }
  
  // Get companion-specific base colors
  final baseColors = _getCompanionVoiceColors(companionColors, personalityType);
  
  // Apply intensity modulation based on call state
  final colors = baseColors.map((color) {
    if (isCompanionSpeaking) {
      // Brighten companion colors when they're speaking
      return color.withOpacity((color.opacity * intensityMultiplier).clamp(0.4, 1.0));
    } else if (isUserSpeaking) {
      // Subtle blue tint when user is speaking
      return Color.lerp(color, Colors.blueAccent.withOpacity(0.6), 0.3)!;
    }
    return color;
  }).toList();
  
  // Personality-specific configurations
  switch (personalityType.toLowerCase()) {
    case 'warm':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity,
        bubblesSize: 460,
        sizeRange: [320, 580],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 6 : 10),
      );
      
    case 'creative':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity + 20,
        bubblesSize: 520,
        sizeRange: [380, 650],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 4 : 8),
      );
      
    case 'calm':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity - 20,
        bubblesSize: 400,
        sizeRange: [280, 480],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 8 : 15),
      );
      
    case 'energetic':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity + 40,
        bubblesSize: 580,
        sizeRange: [420, 720],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 3 : 6),
      );
      
    case 'thoughtful':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity - 15,
        bubblesSize: 380,
        sizeRange: [260, 450],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 10 : 18),
      );
      
    case 'mysterious':
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity + 10,
        bubblesSize: 440,
        sizeRange: [300, 520],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 5 : 12),
      );
      
    default:
      return VoiceCallFluidTheme(
        colors: InitialColors.custom(colors),
        positions: InitialOffsets.random(7),
        velocity: baseVelocity,
        bubblesSize: 450,
        sizeRange: [320, 550],
        allowColorChanging: true,
        mutationDuration: Duration(seconds: isActive ? 6 : 10),
      );
  }
}

/// Get companion-specific colors for voice call background
List<Color> _getCompanionVoiceColors(CompanionColors companionColors, String personalityType) {
  // Base companion colors with dark theme adjustments
  final primary = companionColors.primary;
  final secondary = companionColors.secondary;
  final accent = companionColors.accent;
  
  // Create sophisticated color palette for voice calls
  return [
    // Primary companion color - slightly desaturated for elegance
    primary.withOpacity(0.85),
    
    // Secondary color - for depth
    secondary.withOpacity(0.75),
    
    // Accent color - for highlights
    accent.withOpacity(0.70),
    
    // Darker primary variant - for sophistication
    Color.lerp(primary, Colors.black, 0.3)!.withOpacity(0.65),
    
    // Lighter primary variant - for contrast
    Color.lerp(primary, Colors.white, 0.2)!.withOpacity(0.60),
    
    // Complementary color - for visual interest
    _getComplementaryColor(primary).withOpacity(0.55),
    
    // Deep accent for modern feel
    Color.lerp(accent, Colors.black, 0.4)!.withOpacity(0.50),
  ];
}

/// Get complementary color for visual balance
Color _getComplementaryColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  final complementaryHue = (hsl.hue + 180) % 360;
  return hsl.withHue(complementaryHue).toColor();
}

/// Configuration class for voice call fluid themes
class VoiceCallFluidTheme {
  final InitialColors colors;
  final InitialOffsets positions;
  final double velocity;
  final double bubblesSize;
  final List<double> sizeRange;
  final bool allowColorChanging;
  final Duration mutationDuration;

  VoiceCallFluidTheme({
    required this.colors,
    required this.positions,
    required this.velocity,
    required this.bubblesSize,
    required this.sizeRange,
    required this.allowColorChanging,
    required this.mutationDuration,
  });
}

/// Animated background wrapper that responds to voice call states
class AnimatedVoiceCallBackground extends StatefulWidget {
  final AICompanion companion;
  final bool isActive;
  final bool isUserSpeaking;
  final bool isCompanionSpeaking;
  final Widget child;

  const AnimatedVoiceCallBackground({
    super.key,
    required this.companion,
    required this.isActive,
    required this.isUserSpeaking,
    required this.isCompanionSpeaking,
    required this.child,
  });

  @override
  State<AnimatedVoiceCallBackground> createState() => _AnimatedVoiceCallBackgroundState();
}

class _AnimatedVoiceCallBackgroundState extends State<AnimatedVoiceCallBackground>
    with TickerProviderStateMixin {
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: Stack(
        key: ValueKey('${widget.isActive}_${widget.isUserSpeaking}_${widget.isCompanionSpeaking}'),
        children: [
          // Dynamic fluid background
          buildVoiceCallBackground(
            context: context,
            companion: widget.companion,
            isActive: widget.isActive,
            isUserSpeaking: widget.isUserSpeaking,
            isCompanionSpeaking: widget.isCompanionSpeaking,
          ),
          
          // Child content
          widget.child,
        ],
      ),
    );
  }
}
