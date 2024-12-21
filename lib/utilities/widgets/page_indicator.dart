
import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final Color activeColor;
  final Color inactiveColor;
  final double dotWidth;
  final double activeDotWidth;
  final double dotHeight;
  final double spacing;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
    this.activeColor = Colors.white,
    this.inactiveColor = Colors.white54,
    this.dotWidth = 13.0,
    this.activeDotWidth = 21.0,
    this.dotHeight = 6.0,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => _buildIndicator(index == currentPage),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(horizontal: spacing / 2),
      height: dotHeight,
      width: isActive ? activeDotWidth : dotWidth,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.all(Radius.circular(dotHeight / 2)),
      ),
    );
  }
}