import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:ai_companion/Views/Starter_Screen/onboarding_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/sign_page.dart';
import 'package:ai_companion/Views/AI_selection/companion_selection.dart';
import 'package:ai_companion/Views/user_profile_screen.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:ai_companion/Views/Home/home_page.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/supabase_authProvider.dart';
import 'package:ai_companion/chat/message_bloc/message_bloc.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:ai_companion/themes/theme.dart';
import 'package:ai_companion/utilities/Loading/loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  
  try {
    // Initialize Hive
    await HiveService.initHive();
    await HiveService.getCompanionsBox();
  } catch (e) {
    print('Error initializing Hive: $e');
  }

  _setupLogging();
  
  runApp(
    MultiBlocProvider(
      providers:[ 
        BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          SupabaseAuthProvider(),
        )..add(const AuthEventInitialise()),
        ),
        BlocProvider<CompanionBloc>(
          create: (context) {
            // Get the initialized Supabase client from AuthBloc
            final supabase = SupabaseClientManager().client;
            final companionRepository = AICompanionRepository(supabase);
            return CompanionBloc(companionRepository)
            ..add(LoadCompanions());
          },
        ),
        BlocProvider<MessageBloc>(
          create: (context) => MessageBloc(
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
    //Default color scheme
    final defaultColorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6FA5),  // Modern blue as base
        brightness: Brightness.light,
      );
    return MaterialApp(
      title: 'Ai_Companion',
      debugShowCheckedModeBanner: false,
      theme: createAppTheme(defaultColorScheme),
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
    if (state is AuthStateLoggedIn) {
      if (state is AuthStateUserProfile || !state.user.hasCompletedProfile) {
        return const UserProfilePage() ;
      } else {
        return const ChatScreen();
      }
    } else if (state is AuthStateLoggedOut) {
      return _buildLoggedOutView(state.intendedView);
    } else if (state is AuthStateUserProfile) {
      return const UserProfilePage();
    } else if (state is AuthStateSelectCompanion) {
      return const CompanionSelectionPage();
    } else {
      return Scaffold(
        body: Center(child: Text("$state")),
      );
    }
  }

  Widget _buildLoggedOutView(AuthView view) {
    switch (view) {
      case AuthView.signIn:
        return const SignInView();
      case AuthView.onboarding:
      default:
        return const OnboardingScreenView();
    }
  }
}