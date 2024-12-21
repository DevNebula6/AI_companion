
import 'dart:math';

import 'package:flutter/material.dart';

class ThreeDotsLoadingIndicator extends StatefulWidget {
  const ThreeDotsLoadingIndicator({super.key});

  @override
  State<ThreeDotsLoadingIndicator> createState() => _ThreeDotsLoadingIndicatorState();
}

class _ThreeDotsLoadingIndicatorState extends State<ThreeDotsLoadingIndicator> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(
                  sin((_controller.value * pi * 2) + (index * pi / 2)).abs(),
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}