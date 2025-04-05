import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color bubbleColor;
  final Color dotColor;
  
  const TypingIndicator({
    super.key, 
    this.bubbleColor = const Color(0xFFEEEEEE),
    this.dotColor = const Color(0xFF333333),
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _animControllers;
  late List<Animation<double>> _animations;
  
  @override
  void initState() {
    super.initState();
    
    _animControllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 200 + (index * 200)),
      )..repeat(reverse: true),
    );
    
    _animations = _animControllers.map((controller) => 
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut)
      )
    ).toList();
  }
  
  @override
  void dispose() {
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(left: 12, bottom: 8, right: 64),
      decoration: BoxDecoration(
        color: widget.bubbleColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 8 + (_animations[index].value * 4),
                width: 8 + (_animations[index].value * 4),
                decoration: BoxDecoration(
                  color: widget.dotColor.withOpacity(0.6 + (_animations[index].value * 0.4)),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}