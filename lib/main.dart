import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/voice/azure_test_helper.dart';
import 'package:ai_companion/chat/voice/voice_bloc/voice_bloc.dart';
import 'package:ai_companion/chat/voice/voice_enhanced_gemini_service.dart';
import 'package:ai_companion/chat/voice/supabase_tts_service.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:ai_companion/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/supabase_authProvider.dart';
import 'package:ai_companion/chat/message_bloc/message_bloc.dart';
import 'package:ai_companion/chat/chat_cache_manager.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:ai_companion/themes/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_companion/services/connectivity_service.dart';

import 'navigation/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  final testResult = await AzureTestHelper.testAzureSTTConfiguration();
  print('Azure Setup Status: $testResult');

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
              final conversationBloc = context.read<ConversationBloc>();

              final messageBloc = MessageBloc(repo, cache,conversationBloc);
      
              return messageBloc;
            },
            lazy: false,
          ),
          BlocProvider<VoiceBloc>(
            create: (context) {
              final messageBloc = context.read<MessageBloc>();
              
              // Initialize TTS service with Azure credentials
              final ttsService = SupabaseTTSService();
              
              // Initialize TTS service asynchronously (fire and forget)
              ttsService.initialize(
                azureApiKey: dotenv.env['AZURE_SPEECH_KEY'],
                azureRegion: dotenv.env['AZURE_SPEECH_REGION'] ?? 'centralindia',
              ).then((_) {
                print('✅ TTS service initialized successfully');
              }).catchError((e) {
                print('❌ TTS service initialization failed: $e');
              });
              
              return VoiceBloc(
                messageBloc: messageBloc,
                voiceGeminiService: VoiceEnhancedGeminiService(),
                ttsService: ttsService,
              );
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
    final defaultColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.light,
    );

    final authBloc = context.read<AuthBloc>();
    final appRoutes = AppRoutes(authBloc);
    
    return MaterialApp.router(
      title: 'Ai_Companion',
      debugShowCheckedModeBanner: false,
      theme: createAppTheme(defaultColorScheme),
      routerConfig: appRoutes.router,
    );
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