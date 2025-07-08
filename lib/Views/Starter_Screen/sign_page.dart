import 'dart:ui';

import 'package:ai_companion/ErrorHandling/error_translator.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/utilities/Dialogs/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> with TickerProviderStateMixin {
  late AnimationController _formController;
  late AnimationController _animationController;
  bool _isLoading = false;
  final Random _random = Random();
  static const int particleCount = 6;
  final List<ParticleModel> _particles = [];
  final double blur = 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeParticles();
    });
    _setupAnimations();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _animationController.addListener(_updateParticles);
  }

  void _setupAnimations() {
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  void _initializeParticles() {
    final size = MediaQuery.of(context).size;
    final baseParticleSize = size.width * 0.0045; // Responsive sizing

    _particles.clear();
    for (int i = 0; i < particleCount; i++) {
      _particles.add(ParticleModel(
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        velocity: Offset(
          (_random.nextDouble()) * 5,
          (_random.nextDouble()) * 5,
        ),
        scale: baseParticleSize + _random.nextDouble() * 1,
        maxSpeed: 2 + _random.nextDouble(),
        rotationSpeed: (_random.nextBool() ? 1 : -1) * _random.nextDouble() * 0.05,
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;

    setState(() {
      for (var particle in _particles) {
        particle.update(size);
      }
    });
  }

  @override
  void dispose() {
    _formController.dispose();
    _animationController.dispose();
    _particles.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String message = '';
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthStateLoggedOut && state.exception != null) {
          setState(() {
            _isLoading = false; // Reset loading state on any state change
          });
          message = ErrorTranslator.translate(state.exception!);
        }
        if (message.isNotEmpty) {
          showMessage(
            message: message,
            context: context,
            icon: Icons.error,
            backgroundColor: Colors.red.withOpacity(0.8),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildParticles(),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: RepaintBoundary(child: _buildGlassCard()),
            ),
            _buildAppLogo(),

            // Add back button at the top left
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: _buildBackButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8F0),
            Color(0xFFFFE4D6),
          ],
        ),
      ),
    );
  }

  Widget _buildParticles() {
    return RepaintBoundary(
      child: Stack(
        children: _particles.map((particle) => AnimatedPositioned(
              duration: const Duration(milliseconds: 20),
              left: particle.position.dx,
              top: particle.position.dy,
              child: Transform.rotate(
                angle: particle.rotation,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: particle.opacity,
                  child: Transform.scale(
                    scale: particle.scale,
                    child: Lottie.asset(
                      'assets/animation/blue gradient.json',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )).toList(),
      ),
    );
  }

  Widget _buildAppLogo() {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: MediaQuery.of(context).padding.top + size.height * 0.1,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9D6C).withOpacity(0.3),
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
    );
  }

  Widget _buildGlassCard() {
    final size = MediaQuery.of(context).size;

    return Align(
      alignment: const Alignment(0, 0.95), // Moves card lower
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.95),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _formController,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: _formController,
            child: Container(
              width: size.width * 0.85,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.black,
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildSocialButtons(),
                  const SizedBox(height: 24),
                  _buildFooterText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          "Welcome back",
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your AI companion awaits you",
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _buildSocialButton(
          'Continue with Google',
          'assets/icons/google.svg',
          Colors.white,
          () => _handleSocialSignIn(const AuthEventGoogleSignIn()),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSocialButton(
    String text,
    String iconPath,
    Color backgroundColor,
    VoidCallback onPressed,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: _isLoading ? 0.95 : 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: backgroundColor == Colors.white
                    ? Colors.black87
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.only(left: 18, right: 18),
                elevation: 1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    iconPath,
                    height: 26,
                    width: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterText() {
    return Text(
      'By continuing, you agree to our Terms & Privacy Policy',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: Colors.white.withOpacity(0.7),
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.black.withOpacity(0.0),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          // Navigate back to onboarding screen
          context.pop();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _handleSocialSignIn(AuthEvents event) {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(event);
  }
}

class ParticleModel {
  Offset position;
  Offset velocity;
  double scale;
  double opacity;
  double maxSpeed;
  double rotation;
  double rotationSpeed;

  ParticleModel({
    required this.position,
    required this.velocity,
    this.scale = 2.0,
    this.opacity = 1,
    this.maxSpeed = 2.0,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
  });
  void update(Size bounds) {
    position += velocity;

    // Update rotation
    rotation += rotationSpeed;

    // Boundary collision handling
    if (position.dx <= 0 || position.dx >= bounds.width) {
      velocity = Offset(-velocity.dx * 0.8, velocity.dy);
      position = Offset(
        position.dx <= 0 ? 0 : bounds.width,
        position.dy,
      );
    }

    if (position.dy <= 0 || position.dy >= bounds.height) {
      velocity = Offset(velocity.dx, -velocity.dy * 0.8);
      position = Offset(
        position.dx,
        position.dy <= 0 ? 0 : bounds.height,
      );
    }

    // Maintain consistent speed
    double speed = velocity.distance;
    if (speed > maxSpeed) {
      velocity = (velocity / speed) * maxSpeed;
    }
  }
}