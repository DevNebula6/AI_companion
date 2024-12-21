import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/utilities/widgets/page_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingScreenView extends StatefulWidget {
  const OnboardingScreenView({super.key});

  @override
  State<OnboardingScreenView> createState() => _OnboardingScreenViewState();
}


class _OnboardingScreenViewState extends State<OnboardingScreenView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      quote: "Meet Your Perfect AI Companion",
      info: "Experience meaningful conversations with an AI that truly understands you",
      image: "assets/images/companion_welcome.jpg",
      gradientColors: [
        Colors.purple.withOpacity(0.7),
        Colors.blue.withOpacity(0.5),
      ],
    ),
    OnboardingPage(
      quote: "Grow Together",
      info: "Build a genuine connection that evolves with your journey",
      image: "assets/images/emotional_connection.jpg",
      gradientColors: [
        Colors.indigo.withOpacity(0.7),
        Colors.teal.withOpacity(0.5),
      ],
    ),
    OnboardingPage(
      quote: "Your Safe Space",
      info: "Share your thoughts freely with an understanding and supportive companion",
      image: "assets/images/safe_space.jpg",
      gradientColors: [
        Colors.deepPurple.withOpacity(0.7),
        Colors.cyan.withOpacity(0.5),
      ],
      isLast: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return _buildPage(_pages[index], context: context);
            },
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_currentPage != _pages.length - 1)
                  PageIndicator(
                    currentPage: _currentPage,
                    pageCount: _pages.length,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                    dotWidth: 8,
                    activeDotWidth: 24,
                    dotHeight: 8,
                    spacing: 8,
                  ),
                const SizedBox(height: 30),
                if (_currentPage != _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            _pageController.jumpToPage(_pages.length - 1);
                          },
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutQuint,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildPage(OnboardingPage page, {required BuildContext context}) {
  return Container(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage(page.image),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.3),
          BlendMode.darken,
        ),
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: page.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                page.quote,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.075,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                page.info,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                  height: 1.4,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (page.isLast)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthEventNavigateToSignIn());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      'Begin Your Journey',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}

class OnboardingPage {
  final String quote;
  final String info;
  final String image;
  final List<Color> gradientColors;
  final bool isLast;

  OnboardingPage({
    required this.quote,
    required this.info,
    required this.image,
    this.gradientColors = const [Colors.transparent, Colors.transparent],
    this.isLast = false,
  });
}