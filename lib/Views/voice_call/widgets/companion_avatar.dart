import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../Companion/ai_model.dart';
import '../../AI_selection/companion_color.dart';

/// Voice call companion avatar with speaking animations
class VoiceCallCompanionAvatar extends StatefulWidget {
  final AICompanion companion;
  final bool isActive;
  final bool isSpeaking;
  final double size;

  const VoiceCallCompanionAvatar({
    super.key,
    required this.companion,
    required this.isActive,
    required this.isSpeaking,
    required this.size,
  });

  @override
  State<VoiceCallCompanionAvatar> createState() => _VoiceCallCompanionAvatarState();
}

class _VoiceCallCompanionAvatarState extends State<VoiceCallCompanionAvatar>
    with TickerProviderStateMixin {
  
  late AnimationController _breathingController;
  late AnimationController _speakingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _speakingAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _speakingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    _speakingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _speakingController,
      curve: Curves.elasticOut,
    ));
    
    // Start subtle breathing animation
    _breathingController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _breathingController.dispose();
    _speakingController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceCallCompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _speakingController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _speakingController.stop();
      _speakingController.reset();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final companionColors = getCompanionColorScheme(widget.companion);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingAnimation, _speakingAnimation]),
      builder: (context, child) {
        final scale = _breathingAnimation.value * 
                     (widget.isSpeaking ? _speakingAnimation.value : 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  companionColors.primary.withOpacity(0.1),
                  companionColors.primary.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                if (widget.isActive)
                  BoxShadow(
                    color: companionColors.primary.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatarContent(companionColors),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAvatarContent(ColorScheme companionColors) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                companionColors.primary.withOpacity(0.8),
                companionColors.secondary.withOpacity(0.6),
              ],
            ),
          ),
        ),
        
        // Avatar image or placeholder
        if (widget.companion.avatarUrl.isNotEmpty)
          Image.network(
            widget.companion.avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildAvatarPlaceholder(companionColors);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildAvatarPlaceholder(companionColors);
            },
          )
        else
          _buildAvatarPlaceholder(companionColors),
        
        // Speaking overlay effect
        if (widget.isSpeaking)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                  companionColors.primary.withOpacity(0.2),
                ],
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.3)),
        
        // Border ring
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isActive
                  ? companionColors.primary.withOpacity(0.6)
                  : Colors.white.withOpacity(0.3),
              width: 4,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAvatarPlaceholder(ColorScheme companionColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            companionColors.primary,
            companionColors.secondary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.companion.name.isNotEmpty
              ? widget.companion.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Compact companion avatar for smaller spaces
class CompactVoiceAvatar extends StatefulWidget {
  final AICompanion companion;
  final bool isActive;
  final double size;

  const CompactVoiceAvatar({
    super.key,
    required this.companion,
    required this.isActive,
    this.size = 60,
  });

  @override
  State<CompactVoiceAvatar> createState() => _CompactVoiceAvatarState();
}

class _CompactVoiceAvatarState extends State<CompactVoiceAvatar>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(CompactVoiceAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _glowController.stop();
      _glowController.reset();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final companionColors = getCompanionColorScheme(widget.companion);
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: companionColors.primary.withOpacity(_glowAnimation.value),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ]
                : [],
          ),
          child: ClipOval(
            child: _buildCompactContent(companionColors),
          ),
        );
      },
    );
  }
  
  Widget _buildCompactContent(ColorScheme companionColors) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                companionColors.primary,
                companionColors.secondary,
              ],
            ),
          ),
        ),
        
        // Avatar image or initial
        if (widget.companion.avatarUrl.isNotEmpty)
          Image.network(
            widget.companion.avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildCompactPlaceholder();
            },
          )
        else
          _buildCompactPlaceholder(),
        
        // Active indicator
        if (widget.isActive)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildCompactPlaceholder() {
    return Center(
      child: Text(
        widget.companion.name.isNotEmpty
            ? widget.companion.name[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: widget.size * 0.35,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
