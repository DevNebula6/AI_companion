import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:flutter/material.dart';

class MessageBubbleTheme {
  final Color userBubbleColor;
  final Color botBubbleColor;
  final Color userTextColor;
  final Color botTextColor;
  final Color timestampColor;
  final Color pendingIndicatorColor;
  final Color avatarBorderColor;
  final Color avatarBackgroundColor;
  final BoxShadow bubbleShadow;
  final String? avatarUrl;

  const MessageBubbleTheme({
    required this.userBubbleColor,
    required this.botBubbleColor,
    required this.userTextColor,
    required this.botTextColor,
    required this.timestampColor,
    required this.pendingIndicatorColor,
    required this.avatarBorderColor,
    required this.avatarBackgroundColor,
    required this.bubbleShadow,
    this.avatarUrl,
  });

  factory MessageBubbleTheme.fromCompanion(AICompanion companion) {
    final colorScheme = getCompanionColorScheme(companion);
    final companionColors = getCompanionColors(companion);
    
    return MessageBubbleTheme(
      userBubbleColor: colorScheme.primary,
      botBubbleColor: colorScheme.surfaceVariant,
      userTextColor: colorScheme.onPrimary,
      botTextColor: colorScheme.onSurfaceVariant,
      timestampColor: colorScheme.onSurfaceVariant.withOpacity(0.6),
      pendingIndicatorColor: colorScheme.onPrimary.withOpacity(0.6),
      avatarBorderColor: companionColors.primary.withOpacity(0.3),
      avatarBackgroundColor: companionColors.primary.withOpacity(0.1),
      bubbleShadow: BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      avatarUrl: companion.avatarUrl,
    );
  }
}