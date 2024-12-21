
import 'package:flutter/material.dart';

enum AnimationDirection {
  left,
  top,
  right,
  bottom,
}

class AnimatedWidgetSlide extends StatefulWidget {
  final Widget child;
  final AnimationDirection direction;
  final Duration duration;
  final Curve curve;

  const AnimatedWidgetSlide({
    super.key,
    required this.child,
    required this.direction,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
  });
  
  @override
  State<StatefulWidget> createState() => _AnimatedWidgetSlideState();

}

class _AnimatedWidgetSlideState extends State<AnimatedWidgetSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getOffset(AnimationDirection direction, double offset) {
    switch (direction) {
      case AnimationDirection.left:
        return Offset(-offset, 0);
      case AnimationDirection.top:
        return Offset(0, -offset);
      case AnimationDirection.right:
        return Offset(offset, 0);
      case AnimationDirection.bottom:
        return Offset(0, offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double offset = 100 * (1 - _animation.value);
        return Transform.translate(
          offset: _getOffset(widget.direction, offset),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}