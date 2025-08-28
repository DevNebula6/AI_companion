import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

/// Real-time audio visualizer that responds to voice activity
class AudioVisualizer extends StatefulWidget {
  final bool isUserSpeaking;
  final bool isCompanionSpeaking;
  final ColorScheme companionColors;
  final double height;
  final int barCount;

  const AudioVisualizer({
    super.key,
    required this.isUserSpeaking,
    required this.isCompanionSpeaking,
    required this.companionColors,
    this.height = 60,
    this.barCount = 40,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _barControllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(
          milliseconds: 300 + (math.Random().nextInt(200)),
        ),
        vsync: this,
      ),
    );
    
    _barAnimations = _barControllers.map((controller) {
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();
  }
  
  @override
  void dispose() {
    for (final controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isUserSpeaking || widget.isCompanionSpeaking) {
      _startVisualization();
    } else {
      _stopVisualization();
    }
  }
  
  void _startVisualization() {
    for (int i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 20), () {
        if (mounted && _barControllers[i].status != AnimationStatus.forward) {
          _barControllers[i].repeat(reverse: true);
        }
      });
    }
  }
  
  void _stopVisualization() {
    for (final controller in _barControllers) {
      controller.stop();
      controller.reset();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _barAnimations[index],
            builder: (context, child) {
              final barHeight = widget.height * _barAnimations[index].value;
              final color = _getBarColor(index);
              
              return Container(
                width: 3,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    if (widget.isUserSpeaking || widget.isCompanionSpeaking)
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Color _getBarColor(int index) {
    if (widget.isCompanionSpeaking) {
      // Use companion's primary color with gradient effect
      final progress = index / widget.barCount;
      return Color.lerp(
        widget.companionColors.primary,
        widget.companionColors.secondary,
        progress,
      )!.withOpacity(0.8);
    } else if (widget.isUserSpeaking) {
      // Use blue tones for user speaking
      final progress = index / widget.barCount;
      return Color.lerp(
        Colors.blueAccent,
        Colors.lightBlueAccent,
        progress,
      )!.withOpacity(0.8);
    } else {
      // Inactive state - subtle white
      return Colors.white.withOpacity(0.2);
    }
  }
}

/// Circular audio visualizer for compact spaces
class CircularAudioVisualizer extends StatefulWidget {
  final bool isActive;
  final bool isSpeaking;
  final Color primaryColor;
  final double size;
  final int segments;

  const CircularAudioVisualizer({
    super.key,
    required this.isActive,
    required this.isSpeaking,
    required this.primaryColor,
    this.size = 120,
    this.segments = 20,
  });

  @override
  State<CircularAudioVisualizer> createState() => _CircularAudioVisualizerState();
}

class _CircularAudioVisualizerState extends State<CircularAudioVisualizer>
    with TickerProviderStateMixin {
  
  late List<AnimationController> _segmentControllers;
  
  @override
  void initState() {
    super.initState();
    _initializeSegmentAnimations();
  }
  
  void _initializeSegmentAnimations() {
    _segmentControllers = List.generate(
      widget.segments,
      (index) => AnimationController(
        duration: Duration(
          milliseconds: 400 + (math.Random().nextInt(300)),
        ),
        vsync: this,
      ),
    );
  }
  
  @override
  void dispose() {
    for (final controller in _segmentControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void didUpdateWidget(CircularAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSpeaking && widget.isActive) {
      _startCircularVisualization();
    } else {
      _stopCircularVisualization();
    }
  }
  
  void _startCircularVisualization() {
    for (int i = 0; i < _segmentControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _segmentControllers[i].repeat(reverse: true);
        }
      });
    }
  }
  
  void _stopCircularVisualization() {
    for (final controller in _segmentControllers) {
      controller.stop();
      controller.reset();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: CircularVisualizerPainter(
          segmentControllers: _segmentControllers,
          primaryColor: widget.primaryColor,
          isActive: widget.isActive && widget.isSpeaking,
        ),
      ),
    );
  }
}

/// Custom painter for circular audio visualization
class CircularVisualizerPainter extends CustomPainter {
  final List<AnimationController> segmentControllers;
  final Color primaryColor;
  final bool isActive;

  CircularVisualizerPainter({
    required this.segmentControllers,
    required this.primaryColor,
    required this.isActive,
  }) : super(repaint: Listenable.merge(segmentControllers));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    for (int i = 0; i < segmentControllers.length; i++) {
      final angle = (2 * math.pi / segmentControllers.length) * i;
      final animationValue = segmentControllers[i].value;
      
      // Calculate segment properties
      final startRadius = radius * 0.7;
      final endRadius = startRadius + (radius * 0.3 * animationValue);
      
      final startPoint = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      
      final endPoint = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );
      
      // Paint segment
      final paint = Paint()
        ..color = primaryColor.withOpacity(isActive ? 0.8 : 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(CircularVisualizerPainter oldDelegate) {
    return oldDelegate.isActive != isActive ||
           oldDelegate.primaryColor != primaryColor;
  }
}
