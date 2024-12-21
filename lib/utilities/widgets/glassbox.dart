import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Gradient? gradient;
  final bool enableHover;
  final double? width;
  final double? height;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.2,
    this.borderRadius = 30,
    this.gradient,
    this.enableHover = true,
    this.width,
    this.height,
  });

  @override
  _GlassmorphicContainerState createState() => _GlassmorphicContainerState();
}

class _GlassmorphicContainerState extends State<GlassmorphicContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blur + (_isHovered && widget.enableHover ? 2 : 0),
              sigmaY: widget.blur + (_isHovered && widget.enableHover ? 2 : 0),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(widget.opacity),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                gradient: widget.gradient,
                boxShadow: [
                  if (_isHovered && widget.enableHover)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
