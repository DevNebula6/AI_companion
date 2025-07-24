import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/Views/Home/home_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/onboarding_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/sign_page.dart';
import 'package:ai_companion/Views/AI_selection/companion_selection.dart';
import 'package:ai_companion/Views/chat_screen/chat_page.dart';
import 'package:ai_companion/Views/user_profile_screen.dart';
import 'package:ai_companion/splash_screen.dart';
import 'package:ai_companion/Companion/ai_model.dart';
import 'routes_name.dart';

class AppRoutes {
  final AuthBloc authBloc;
  late final GoRouter router;
  
  AppRoutes(this.authBloc) {
    router = GoRouter(
      initialLocation: RoutesName.splash,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: _routes,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final authState = authBloc.state;
        final currentLocation = state.matchedLocation;
        final fullPath = state.fullPath;

        if (kDebugMode) {
          print('GoRouter Redirect: $currentLocation -> ${authState.runtimeType} (fullPath: $fullPath)');
        }
        
        // During initialization, always show splash
        if (authState is AuthStateUninitialized) {
          if (currentLocation != RoutesName.splash) {
            print('GoRouter: Redirecting to splash during initialization');
            return RoutesName.splash;
          }
          return null;
        }
        
        // Handle logged out states
        if (authState is AuthStateLoggedOut) {
          final protectedRoutes = [
            RoutesName.home,
            RoutesName.userProfile,
            RoutesName.companionSelection,
            RoutesName.chat,
          ];
          if (protectedRoutes.contains(currentLocation)) {
            print('GoRouter: Redirecting unauthenticated user from protected route');
            return authState.intendedView == AuthView.signIn 
                ? RoutesName.signIn 
                : RoutesName.onboarding;
          }
          if (currentLocation == RoutesName.splash) {
            print('GoRouter: Redirecting from splash to auth screen');
            return authState.intendedView == AuthView.signIn 
                ? RoutesName.signIn 
                : RoutesName.onboarding;
          }
          return null;
        }
      
        // Handle logged in states - THE KEY FIX
        if (authState is AuthStateLoggedIn) {
          // Redirect from auth screens and splash to home
          if (currentLocation == RoutesName.signIn || 
              currentLocation == RoutesName.onboarding ||
              currentLocation == RoutesName.splash) {
            print('GoRouter: Redirecting authenticated user to home from $currentLocation');
            return RoutesName.home;
          }
          
          // If onboarding/profile/companion selection required, enforce redirect
          if (authState.intendedView == LoggedInView.userProfile && currentLocation != RoutesName.userProfile) {
            return RoutesName.userProfile;
          }
          // if (authState.intendedView == LoggedInView.companionSelection && currentLocation != RoutesName.companionSelection) {
          //   return RoutesName.companionSelection;
          // }
          // Otherwise, allow free navigation (no redirect)
          return null;
        }
        
        return null;
      },
        errorPageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Page Not Found'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Page not found', 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Route: ${state.matchedLocation}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(RoutesName.onboarding),
                  child: const Text('Go to Onboarding'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  List<RouteBase> get _routes => [
    GoRoute(
      path: RoutesName.splash,
      builder: (context, state) => const AppLoadingScreen(),
    ),
    GoRoute(
      path: RoutesName.onboarding,
      builder: (context, state) => const OnboardingScreenView(),
    ),
    GoRoute(
      path: RoutesName.signIn,
      builder: (context, state) => const SignInView(),
    ),
    GoRoute(
      path: RoutesName.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: RoutesName.userProfile,
      builder: (context, state) => const UserProfilePage(),
    ),
    GoRoute(
      path: RoutesName.companionSelection,
      builder: (context, state) => const CompanionSelectionPage(),
    ),
    GoRoute(
      path: RoutesName.chat,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) {
          // Handle missing parameters - redirect to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutesName.home);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        return ChatPage(
          conversationId: extra['conversationId'] ?? '',
          companion: extra['companion'] as AICompanion,
          navigationSource: extra['navigationSource'],
        );
      },
    ),
  ];
}

// Helper class to listen to BLoC stream changes
class GoRouterRefreshStream extends ChangeNotifier {
  final Stream<dynamic> _stream;
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(this._stream) {
    _subscription = _stream.asBroadcastStream().listen(
      (state) {
        print('GoRouter: Auth state changed to ${state.runtimeType}');
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}