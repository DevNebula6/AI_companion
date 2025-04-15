import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:ai_companion/Views/Home/home_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/onboarding_screen.dart';
import 'package:ai_companion/Views/Starter_Screen/sign_page.dart';
import 'package:ai_companion/Views/AI_selection/companion_selection.dart';
import 'package:ai_companion/Views/chat_screen/chat_page.dart';
import 'package:ai_companion/Views/user_profile_screen.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:ai_companion/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  runApp(const AppLoadingScreen());

  // Initialize core services asynchronously
  await _initializeCoreServices();
  
}

Future<void> _initializeCoreServices() async {

  try {

  // Set up logging
  _setupLogging();

  // Initialize Supabase client
  final supabaseManager = SupabaseClientManager();
  await supabaseManager.initialize();

  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Hive in parallel
  final hiveInitFuture = HiveService.initHive()
    .then((_) => HiveService.getCompanionsBox())
    .catchError((e) { 
      throw HiveError('Hive initialization error: $e');
      });
  
  // Create essential services
  final geminiService = GeminiService();
  
  // Wait for all parallel operations to complete
  await hiveInitFuture;
  
  // Initialize repository with a delay to prevent UI freezing
  final chatRepository = await ChatRepositoryFactory.getInstance();

  
  runApp(
    MultiProvider(
      providers: [
        // Provide base services
        Provider<GeminiService>.value(value: geminiService),
        Provider<ChatRepository>.value(value: chatRepository),

        // Create other providers as needed
        BlocProvider<AuthBloc>(
          create: (context) {
            // Make sure you're using the already-initialized SupabaseAuthProvider
            final authProvider = SupabaseAuthProvider();
            // Initialize it right away
            authProvider.initialize();
            return AuthBloc(
              authProvider,
              isInitialized: true,
          )..add(const AuthEventInitialise());
          },
        ),

        
        BlocProvider<CompanionBloc>(
          create: (context) {
            // Get the initialized Supabase client from AuthBloc
            final supabase = SupabaseClientManager().client;
            final companionRepository = AICompanionRepository(supabase);
            return CompanionBloc(companionRepository);
          },
        ),
        BlocProvider<ConversationBloc>(
          create: (context) {
            final companionBloc = context.read<CompanionBloc>();
            final geminiService = context.read<GeminiService>();
            // Use setters instead of direct field access
            chatRepository.setCompanionBloc(companionBloc);
            chatRepository.setGeminiService(geminiService);
    
            return ConversationBloc(chatRepository);
          },
        ),
        BlocProvider<MessageBloc>(
          create: (context) {
            final geminiService = context.read<GeminiService>();
            
            // Ensure GeminiService is set
            chatRepository.setGeminiService(geminiService);
            
            return MessageBloc(
              chatRepository,
              geminiService,
              ChatCacheService(prefs),
            );
          },
        ),
      ],
      child: const MainApp(),
    ),
  );
  } catch (e) {
    print("Error during initialization: $e");
    // Show error screen
    runApp(AppErrorScreen(error: e.toString()));
  }
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('Log -${rec.level.name}: ${rec.time}: ${rec.message}');
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
      home: BlocConsumer<AuthBloc, AuthState>(
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
    );
  }
  
  Widget _buildHome(BuildContext context, AuthState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildHomeContent(context, state),
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthState state) {
    if (state is AuthStateUninitialized) {
      return AppLoadingScreen();
    } else if (state is AuthStateLoggedIn) {
      return HomeScreen();
    } else if (state is AuthStateLoggedOut) {
      return _buildLoggedOutView(state.intendedView);
    } else if (state is AuthStateUserProfile) {
      return const UserProfilePage();
    } else if (state is AuthStateSelectCompanion) {
      return const CompanionSelectionPage();
    } else if (state is AuthStateChatPage) {
      return ChatPage(
        conversationId: state.conversationId,
        companion: state.companion,
      );
    }  else {
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

// Error screen for initialization failures
class AppErrorScreen extends StatelessWidget {
  final String error;
  
  const AppErrorScreen({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart app
                    _initializeCoreServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}