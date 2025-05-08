import 'package:flutter/material.dart';
import 'dart:math' as math;

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFAFAFA), Color(0xFFF0F0F0)],
                ),
              ),
              child: Stack(
                children: [
                  // Geometric background shapes
                  ...List.generate(12, (index) {
                    final random = math.Random(index);
                    final size = 20.0 + random.nextDouble() * 150;

                    // Create different geometric shapes
                    Widget shape;
                    final shapeType = index % 4;

                    if (shapeType == 0) {
                      // Rectangle
                      shape = Container(
                        width: size,
                        height: size * 0.6,
                        decoration: BoxDecoration(
                          color: Color(0xFF6E7FF3).withOpacity(0.05 + (random.nextDouble() * 0.05)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    } else if (shapeType == 1) {
                      // Circle
                      shape = Container(
                        width: size * 0.8,
                        height: size * 0.8,
                        decoration: BoxDecoration(
                          color: Color(0xFFB4D4FF).withOpacity(0.07 + (random.nextDouble() * 0.05)),
                          shape: BoxShape.circle,
                        ),
                      );
                    } else if (shapeType == 2) {
                      // Rounded rectangle
                      shape = Container(
                        width: size * 1.2,
                        height: size * 0.4,
                        decoration: BoxDecoration(
                          color: Color(0xFF90A9FC).withOpacity(0.05 + (random.nextDouble() * 0.05)),
                          borderRadius: BorderRadius.circular(size * 0.2),
                        ),
                      );
                    } else {
                      // Triangle - using CustomPaint
                      shape = SizedBox(
                        width: size * 0.7,
                        height: size * 0.7,
                        child: CustomPaint(
                          painter: TrianglePainter(
                            color: Color(0xFF758BFD).withOpacity(0.05 + (random.nextDouble() * 0.05)),
                          ),
                        ),
                      );
                    }

                    return Positioned(
                      left: random.nextDouble() * MediaQuery.of(context).size.width,
                      top: random.nextDouble() * MediaQuery.of(context).size.height,
                      child: Transform.rotate(
                        angle: random.nextDouble() * math.pi * 2,
                        child: AnimatedOpacity(
                          opacity: _fadeAnimation.value * (0.4 + random.nextDouble() * 0.6),
                          duration: Duration(milliseconds: 300 + (random.nextInt(700))),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.95, end: 1.05),
                            duration: Duration(milliseconds: 2000 + random.nextInt(3000)),
                            curve: Curves.easeInOutSine,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: shape,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),

                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo container with elegant shadow
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF6E7FF3), Color(0xFF758BFD)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6E7FF3).withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF6E7FF3).withOpacity(0.1),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo4.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // App name with refined typography
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            'AI Companion',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                              color: Color(0xFF454655),
                              height: 1.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Tagline with delicate fade-in
                        FadeTransition(
                          opacity: Animation.fromValueListenable(
                            _controller,
                            transformer: (value) => value < 0.6 ? 0.0 : (value - 0.6) * 2.5,
                          ),
                          child: const Text(
                            'Your intelligent companion',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF7A7A8C),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Elegant loading indicator
                        FadeTransition(
                          opacity: Animation.fromValueListenable(
                            _controller,
                            transformer: (value) => value < 0.7 ? 0.0 : (value - 0.7) * 3.3,
                          ),
                          child: _buildElegantLoadingIndicator(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildElegantLoadingIndicator() {
    return SizedBox(
      width: 48,
      height: 48,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOutCirc,
        builder: (context, value, child) {
          return CustomPaint(
            painter: ElegantLoadingPainter(
              progress: value,
              animation: _controller.value,
              color: const Color(0xFF6E7FF3),
            ),
          );
        },
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ElegantLoadingPainter extends CustomPainter {
  final double progress;
  final double animation;
  final Color color;

  ElegantLoadingPainter({
    required this.progress,
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Animated arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Draw main arc that grows with progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arcPaint,
    );

    // Draw smaller moving highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (animation * math.pi * 4),
      math.pi / 8,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}