import 'package:ai_companion/Views/Starter_Screen/onboarding_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/sign_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:ai_companion/Views/Home/home_page.dart';
import 'package:ai_companion/Views/Starter_Screen/email_verification.dart';
import 'package:ai_companion/Views/Starter_Screen/forgot_password_view.dart';
import 'package:ai_companion/Views/Starter_Screen/register_page.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/supabase_authProvider.dart';
import 'package:ai_companion/chat/chat_bloc/chat_bloc.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/themes/light_mode.dart';
import 'package:ai_companion/utilities/Loading/loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();

   _setupLogging();
  runApp(
    MultiBlocProvider(
      providers:[ 
        BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          SupabaseAuthProvider(),
        )..add(const AuthEventInitialise()),
        ),
        BlocProvider<ChatBloc>(
          create: (context) => ChatBloc(
            ChatRepository(), 
            GeminiService(),
            ChatCacheService(prefs),
          )
          ),
      ],
      child: const MainApp(),
    ),
  );
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S Chat',
      theme: lightmode,
      home: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          SupabaseAuthProvider(),
        )..add(const AuthEventInitialise()),
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) => 
            previous.isLoading != current.isLoading,
          listener: (context, state) {
            if (state.isLoading) {
              LoadingScreen().show(
                context: context,
                text: state.loadingText ?? 'Please wait a moment',
              );
            } else {
              LoadingScreen().hide();
            }
          },
          builder: (context, state) => _buildHome(context, state),
        ),
      ),
    );
  }
  
  Widget _buildHome(BuildContext context, AuthState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildHomeContent(context, state),
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthState state) {
    if (state is AuthStateRegistering) {
      return const RegisterView();
    } else if (state is AuthStateLoggedIn) {
      return state.user.isEmailVerified 
          ? const ChatScreen() 
          : const EmailVerification();
    } else if (state is AuthStateNeedsVerification) {
      return const EmailVerification();
    } else if (state is AuthStateForgotPassword) {
      return const ForgotPasswordView();
    } else if (state is AuthStateLoggedOut) {
      return _buildLoggedOutView(state.intendedView);
    } else {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _buildLoggedOutView(AuthView view) {
    switch (view) {
      case AuthView.signIn:
        return const SignInView();
      case AuthView.register:
        return const RegisterView();
      case AuthView.onboarding:
      default:
        return const OnboardingScreenView();
    }
  }
}