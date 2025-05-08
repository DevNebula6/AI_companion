import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

class OnboardingScreenView extends StatefulWidget {
  const OnboardingScreenView({super.key});

  @override
  State<OnboardingScreenView> createState() => _OnboardingScreenViewState();
}

class _OnboardingScreenViewState extends State<OnboardingScreenView> with TickerProviderStateMixin {
  int _currentPage = 0;
  late LiquidController _liquidController;

  final double _imageSize = 280.0;
  late ValueNotifier<double> _swipeProgress;
  // ignore: unused_field
  bool _isAnimatingFromSwipe = false;

  final List<Color> _pageColors = [
    const Color(0xFF5E35B1),  // Deep purple for first page
    const Color(0xFF0277BD),  // Deep blue for second page
    const Color(0xFF038C7F),  // Adjusted teal for third page - creates smoother transition
    const Color(0xFFD81B60),  // Deep pink for final page
  ];

  final List<Color> _secondaryColors = [
    const Color(0xFF9575CD),  // Light purple for first page
    const Color(0xFF4FC3F7),  // Light blue for second page
    const Color(0xFF4EAEB7),  // Adjusted teal-blue for third page - bridges the transition
    const Color(0xFFF06292),  // Light pink for final page
  ];

  final List<Color> _accentColors = [
    const Color(0xFF42A5F5),  // First page accent
    const Color(0xFF26A69A),  // Second page accent
    const Color(0xFFFF9E80),  // Warm peach accent for third page - bridges warm & cool tones
    const Color(0xFFFFB74D),  // Last page accent
  ];

  final List<Map<String, dynamic>> _pageContent = [
    {
      "title": "Connect with diverse personas",
      "subtitle": "Build meaningful relationships with different personas that understand you",
      "image": "assets/images/companion_welcome.jpg",
      "decoration": "conversation",
    },
    {
      "title": "Grow Together",
      "subtitle": "Practice conversations, build social skills, and watch your relationships evolve in meaningful ways over time",
      "image": "assets/images/emotional_connection.jpg",
      "decoration": "connection",
    },
    {
      "title": "Explore",
      "subtitle": "Discover diverse cultures and perspectives in a private, judgment-free space where you can truly be yourself",
      "image": "assets/images/e4.png",
      "decoration": "exploration",  
    },
    {
      "title": "Your Safe Space",
      "subtitle": "Express yourself freely in a judgment-free environment with complete privacy",
      "image": "assets/images/safe_space.jpg",
      "decoration": "comfort",
    },
  ];

  @override
  void initState() {
    super.initState();
    _liquidController = LiquidController();
    _swipeProgress = ValueNotifier<double>(0.0);
  }

  @override
  void dispose() {
    _swipeProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: _buildPages(),
            liquidController: _liquidController,
            enableSideReveal: true,
            slideIconWidget: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            enableLoop: false,
            fullTransitionValue: 600,
            waveType: WaveType.liquidReveal,
            onPageChangeCallback: (page) {
              setState(() {
                _currentPage = page;
              });

              _isAnimatingFromSwipe = false;
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildNavigationControls(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: _currentPage < _pageContent.length - 1
                ? _buildSkipButton()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPages() {
    return List.generate(_pageContent.length, (index) {
      return _buildPage(
        index: index,
        mainColor: _pageColors[index],
        secondaryColor: _secondaryColors[index],
        title: _pageContent[index]["title"]!,
        subtitle: _pageContent[index]["subtitle"]!,
        imagePath: _pageContent[index]["image"]!,
        isLastPage: index == _pageContent.length - 1,
      );
    });
  }

  Widget _buildPage({
    required int index,
    required Color mainColor,
    required Color secondaryColor,
    required String title,
    required String subtitle,
    required String imagePath,
    required bool isLastPage,
  }) {
    final Color accentColor = _accentColors[index];
    final String decorationType = _pageContent[index]["decoration"];
    final Size screenSize = MediaQuery.of(context).size;

    final double centerY = screenSize.height * 0.33;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mainColor,
            secondaryColor,
          ],
          stops: const [0.3, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.5,
            child: _buildBackgroundElements(decorationType, accentColor),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: centerY - _imageSize / 2 - 16),
                  Center(
                    child: _buildCircularImage(
                      imagePath: imagePath,
                      mainColor: mainColor,
                      accentColor: accentColor,
                      index: index,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTitle(title),
                  const SizedBox(height: 16),
                  _buildSubtitle(subtitle),
                  if (isLastPage)
                    Padding(

                      padding: const EdgeInsets.only(top: 40),
                      child: _buildButton(mainColor),
                    ),
                  SizedBox(height: isLastPage ? 20 : 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundElements(String decorationType, Color accentColor) {
    return const SizedBox.shrink();
  }

  Widget _buildCircularImage({
    required String imagePath,
    required Color mainColor,
    required Color accentColor,
    required int index,
  }) {
    return Container(
      width: _imageSize,
      height: _imageSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(0.3),
                    mainColor,
                  ],
                  center: Alignment.center,
                  radius: 0.8,
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print(error);
                  return Container(
                    color: mainColor,
                    child: Center(
                      child: Icon(
                        _getPageIcon(index),
                        size: 80,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 38,  // Slightly increased for impact
        fontWeight: FontWeight.w700, // Bolder weight
        fontStyle: FontStyle.normal,
        letterSpacing: 0, // Tighter letter spacing for headlines
        height: 1.15,  // Slightly tighter line height
        shadows: [
          Shadow(
            offset: Offset(0, 2),
            blurRadius: 6, // Increased blur for softer shadow
            color: Color(0x70000000),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(String subtitle) {
    return Text(
      subtitle,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white.withOpacity(0.92),
        fontSize: 18, // Slightly increased for readability
        fontWeight: FontWeight.w400, // Lighter weight for contrast with title
        letterSpacing: 0.15, // Slightly increased letter spacing for readability
        height: 1.6, // Increased line height for better reading flow
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 3, // Slightly increased blur
            color: Colors.black.withOpacity(0.25),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(Color mainColor) {
    return SizedBox(

      width: MediaQuery.of(context).size.width * 0.8,
      height: 58, // Slightly taller for better tap target
      child: ElevatedButton(
        onPressed: () {
          context.read<AuthBloc>().add(const AuthEventNavigateToSignIn());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: mainColor,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Begin Your Journey',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3, // Increased for better presence
          ),
        ),
      ),
    );
  }

  IconData _getPageIcon(int page) {
    switch (page) {
      case 0:
        return Icons.chat_bubble_outline_rounded;
      case 1:
        return Icons.timeline_outlined;
      case 2:
        return Icons.travel_explore;  // New icon for exploration page
      case 3:
        return Icons.shield_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  Widget _buildNavigationControls() {
    if (_currentPage == _pageContent.length - 1) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(_pageContent.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _isAnimatingFromSwipe = true;

            _liquidController.animateToPage(
              page: _currentPage + 1,
              duration: 600,
            );
          },
          child: const Icon(
            Icons.arrow_forward,
            color: Colors.black87,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          _liquidController.jumpToPage(page: _pageContent.length - 1);
        },
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
          ),
          child: const Text(
            'Skip',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}