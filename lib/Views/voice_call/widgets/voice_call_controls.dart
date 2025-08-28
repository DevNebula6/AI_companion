import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Voice call control buttons with modern design
class VoiceCallControls extends StatefulWidget {
  final bool isCallActive;
  final bool isMuted;
  final ColorScheme companionColors;
  final VoidCallback onStartCall;
  final VoidCallback onEndCall;
  final VoidCallback onToggleMute;

  const VoiceCallControls({
    super.key,
    required this.isCallActive,
    required this.isMuted,
    required this.companionColors,
    required this.onStartCall,
    required this.onEndCall,
    required this.onToggleMute,
  });

  @override
  State<VoiceCallControls> createState() => _VoiceCallControlsState();
}

class _VoiceCallControlsState extends State<VoiceCallControls>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceCallControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCallActive && !oldWidget.isCallActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCallActive && oldWidget.isCallActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button (only visible during call)
        if (widget.isCallActive)
          _buildControlButton(
            icon: widget.isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: widget.isMuted 
                ? Colors.red.withOpacity(0.2)
                : Colors.white.withOpacity(0.2),
            iconColor: widget.isMuted ? Colors.red : Colors.white,
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onToggleMute();
            },
            size: 60,
          ).animate().fadeIn(duration: 300.ms),
        
        // Main call button
        _buildMainCallButton(),
        
        // Speaker button (only visible during call)
        if (widget.isCallActive)
          _buildControlButton(
            icon: Icons.volume_up,
            backgroundColor: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onPressed: () {
              HapticFeedback.selectionClick();
              // TODO: Toggle speaker
            },
            size: 60,
          ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }
  
  Widget _buildMainCallButton() {
    if (widget.isCallActive) {
      // End call button
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: _buildControlButton(
              icon: Icons.call_end,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              onPressed: () {
                HapticFeedback.heavyImpact();
                widget.onEndCall();
              },
              size: 80,
            ),
          );
        },
      );
    } else {
      // Start call button
      return _buildControlButton(
        icon: Icons.call,
        backgroundColor: widget.companionColors.primary,
        iconColor: Colors.white,
        onPressed: () {
          HapticFeedback.heavyImpact();
          widget.onStartCall();
        },
        size: 80,
        showGlow: true,
      ).animate().scale(
        duration: 600.ms,
        curve: Curves.elasticOut,
      );
    }
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onPressed,
    required double size,
    bool showGlow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick action buttons for additional controls
class VoiceCallQuickActions extends StatelessWidget {
  final bool isCallActive;
  final ColorScheme companionColors;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onShowKeypad;
  final VoidCallback? onAddCall;

  const VoiceCallQuickActions({
    super.key,
    required this.isCallActive,
    required this.companionColors,
    this.onToggleVideo,
    this.onShowKeypad,
    this.onAddCall,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCallActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.videocam_off,
            label: 'Video',
            onPressed: onToggleVideo,
          ),
          _buildQuickActionButton(
            icon: Icons.dialpad,
            label: 'Keypad',
            onPressed: onShowKeypad,
          ),
          _buildQuickActionButton(
            icon: Icons.person_add,
            label: 'Add',
            onPressed: onAddCall,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed != null
                  ? () {
                      HapticFeedback.lightImpact();
                      onPressed();
                    }
                  : null,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: onPressed != null
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null
                ? Colors.white.withOpacity(0.8)
                : Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
