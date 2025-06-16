import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
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
import 'package:ai_companion/themes/theme.dart';
import 'package:ai_companion/utilities/Loading/loading_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_companion/services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const AppLoadingScreen());
  await _initializeCoreServices();
}

Future<void> _initializeCoreServices() async {
  try {
    _setupLogging();

    // Initialize Supabase client
    final supabaseManager = SupabaseClientManager();
    await supabaseManager.initialize();

    final prefs = await SharedPreferences.getInstance();

    // Initialize connectivity service early for app-wide usage
    final connectivityService = ConnectivityService();

    // Initialize Hive in parallel
    final hiveInitFuture = HiveService.initHive()
        .then((_) => HiveService.getCompanionsBox())
        .catchError((e) {
      throw HiveError('Hive initialization error: $e');
    });

    // Wait for Hive to complete
    await hiveInitFuture;

    // Initialize repository (factory handles initialization)
    final chatRepository = await ChatRepositoryFactory.getInstance();

    // Create ChatCacheService instance
    final chatCacheService = ChatCacheService(prefs);

    runApp(
      MultiProvider(
        providers: [
          // Provide ConnectivityService as singleton
          Provider<ConnectivityService>.value(value: connectivityService),
          
          // Provide ChatRepository instance
          Provider<ChatRepository>.value(value: chatRepository),
          
          // Provide ChatCacheService
          Provider<ChatCacheService>.value(value: chatCacheService),
          
          // --- BLoC Providers ---
          BlocProvider<AuthBloc>(
            create: (context) {
              final authProvider = SupabaseAuthProvider();
              authProvider.initialize();
              return AuthBloc(
                authProvider,
                isInitialized: true,
              )..add(const AuthEventInitialise());
            },
          ),
          BlocProvider<CompanionBloc>(
            create: (context) {
              final supabase = SupabaseClientManager().client;
              final companionRepository = AICompanionRepository(supabase);
              // Load companions immediately after creation
              return CompanionBloc(companionRepository)..add(LoadCompanions());
            },
          ),
          BlocProvider<ConversationBloc>(
            create: (context) {
              final repo = context.read<ChatRepository>();
              final cacheService = context.read<ChatCacheService>();
              // Ensure dependencies are set if needed
              repo.setCompanionBloc(context.read<CompanionBloc>());
              return ConversationBloc(repo, cacheService);
            },
          ),
          BlocProvider<MessageBloc>(
            create: (context) {
              final repo = context.read<ChatRepository>();
              final cache = context.read<ChatCacheService>();
              // MessageBloc accesses GeminiService singleton directly
              return MessageBloc(repo, cache);
            },
          ),
        ],
        child: const MainApp(),
      ),
    );
  } catch (e, stackTrace) {
    print("Error during initialization: $e\n$stackTrace");
    runApp(AppErrorScreen(error: e.toString()));
  }
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.loggerName}: ${rec.message}');
    if (rec.error != null) {
      print('ERROR: ${rec.error}');
    }
    if (rec.stackTrace != null) {
      print('STACKTRACE: ${rec.stackTrace}');
    }
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    //Default color scheme
    final defaultColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6), // Modern minimalist blue - clean and trustworthy
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
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildHomeContent(context, state),
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthState state) {
    if (state is AuthStateUninitialized) {
      return AppLoadingScreen(key: const ValueKey('Uninitialized'));
    } else if (state is AuthStateLoggedIn) {
      return HomeScreen();
    } else if (state is AuthStateLoggedOut) {
      return _buildLoggedOutView(state.intendedView,
          key: ValueKey('LoggedOut_${state.intendedView}'));
    } else if (state is AuthStateUserProfile) {
      return UserProfilePage(key: ValueKey('UserProfile_${state.user.id}'));
    } else if (state is AuthStateSelectCompanion) {
      return CompanionSelectionPage(
          key: ValueKey('SelectCompanion_${state.user.id}'));
    } else if (state is AuthStateChatPage) {
      return ChatPage(
        key: ValueKey('ChatPage_${state.conversationId}'),
        conversationId: state.conversationId,
        companion: state.companion,
        navigationSource: state.navigationSource,
      );
    } else {
      return Scaffold(
        key: const ValueKey('ErrorState'),
        body: Center(child: Text("Unknown Auth State: $state")),
      );
    }
  }

  Widget _buildLoggedOutView(AuthView view, {Key? key}) {
    switch (view) {
      case AuthView.signIn:
        return SignInView(key: key);
      case AuthView.onboarding:
      default:
        return OnboardingScreenView(key: key);
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