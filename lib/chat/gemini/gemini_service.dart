import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/gemini/companion_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../message.dart';
import '../message_bloc/message_bloc.dart';
import '../message_bloc/message_state.dart';
import 'system_prompt.dart';

/// Optimized service for interacting with the Gemini API and managing companion state.
/// Implemented as a singleton for application-wide state management.
class GeminiService {
  // --- Singleton Setup ---
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    _log.info('GeminiService singleton created.');
    _initPrefs();
    // Initialize model in background
    Future.microtask(() => _initializeBaseModel());
  }

  // --- Dependencies & Configuration ---
  final _log = Logger('GeminiService');
  late final SharedPreferences _prefs;
  bool _prefsInitialized = false;

  // **OPTIMIZED: Single base model instead of multiple companion-specific models**
  GenerativeModel? _baseModel;
  final Map<String, String> _cachedSystemPrompts = {};
  bool _isModelInitializing = false;
  bool _isModelInitialized = false;
  final Map<String, ChatSession> _persistentSessions = {};
  final Map<String, DateTime> _sessionLastUsed = {};
  static const Duration _sessionMaxAge = Duration(days: 90);  // 30 days!
  static const int _sessionMaxMessages = 1000;                // 500 messages!
  final Map<String, int> _sessionMessageCount = {};
  
  // **OPTIMIZED: Enhanced thread safety with better mutex tracking**
  final _modelInitMutex = Mutex();
  final _stateOperationMutex = Mutex();

  // **OPTIMIZED: Debounced saving mechanism**
  Timer? _saveDebounceTimer;
  final Set<String> _pendingSaves = {};
  static const Duration _saveDebounceDelay = Duration(milliseconds: 500);

  // **OPTIMIZED: Cached regex patterns for memory extraction**
  Map<String, RegExp>? _cachedPatterns;

  // --- Constants ---
  static const String _prefsKeyPrefix = 'gemini_companion_state_v2_';
  static const int _maxMemoryCacheSize = 30;
  static const int _maxActiveHistoryLength = 50;
  static const Duration _modelInitTimeout = Duration(seconds: 10);
  static const Duration _stateOperationTimeout = Duration(seconds: 5);
  static const String storageVersion = '2.0';

  // AI model configuration constants
  static const String _modelName = 'gemini-2.0-flash';
  final List<SafetySetting> _safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.low),
  ];
  final GenerationConfig _generationConfig = GenerationConfig(
    temperature: 0.9,
    topK: 40,
    topP: 0.95,
    maxOutputTokens: 300,
  );

  // Last cleanup timestamp
  DateTime _lastStateCleanup = DateTime.now();

  // --- State Management ---
  final LinkedHashMap<String, CompanionState> _companionStates = LinkedHashMap();
  final Map<String, DateTime> _stateAccessTimes = {};
  String? _activeCompanionKey;

  // --- Initialization ---
  Future<void> _initPrefs() async {
    if (!_prefsInitialized) {
      try {
        _prefs = await SharedPreferences.getInstance();
        _prefsInitialized = true;
        _log.info('SharedPreferences initialized.');
        await _loadSessionMetadata();

        // Schedule periodic cleanup
        _schedulePeriodicCleanup();
      } catch (e, stackTrace) {
        _log.severe('Failed to initialize SharedPreferences: $e', e, stackTrace);
      }
    }
  }

  Future<void> _saveSessionMetadata() async {
    if (!_prefsInitialized) return;
    
    try {
      final sessionData = <String, dynamic>{};
      
      _sessionLastUsed.forEach((key, lastUsed) {
        sessionData[key] = {
          'lastUsed': lastUsed.toIso8601String(),
          'messageCount': _sessionMessageCount[key] ?? 0,
        };
      });
      
      await _prefs.setString('session_metadata', jsonEncode(sessionData));
      _log.info('Saved session metadata for ${sessionData.length} sessions');
    } catch (e) {
      _log.warning('Failed to save session metadata: $e');
    }
  }

  /// Load session metadata on startup
  Future<void> _loadSessionMetadata() async {
    if (!_prefsInitialized) return;
    
    try {
      final sessionDataString = _prefs.getString('session_metadata');
      if (sessionDataString != null) {
        final sessionData = jsonDecode(sessionDataString) as Map<String, dynamic>;
        
        sessionData.forEach((key, data) {
          if (data is Map<String, dynamic>) {
            _sessionLastUsed[key] = DateTime.parse(data['lastUsed']);
            _sessionMessageCount[key] = data['messageCount'] ?? 0;
          }
        });
        
        _log.info('Loaded session metadata for ${sessionData.length} sessions');
      }
    } catch (e) {
      _log.warning('Failed to load session metadata: $e');
    }
  }

  // **OPTIMIZED: Single base model initialization**
  Future<void> _initializeBaseModel() async {
    if (!await _modelInitMutex.acquireWithTimeout(_modelInitTimeout)) {
      throw TimeoutException('Model initialization timed out');
    }

    try {
      if (_baseModel != null && _isModelInitialized) {
        return;
      }

      if (_isModelInitializing) {
        _log.info('Model already initializing, waiting...');
        return;
      }

      _isModelInitializing = true;
      _log.info('Initializing optimized base Gemini Model...');

      // Get API key with validation
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found or empty in .env file.');
      }

      // **OPTIMIZED: Create single base model with minimal system instruction**
      _baseModel = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        safetySettings: _safetySettings,
        generationConfig: _generationConfig,
        systemInstruction: Content.system(buildFoundationalSystemPrompt()),
      );

      _isModelInitialized = true;
      _isModelInitializing = false;
      _log.info('Optimized base Gemini Model initialized successfully.');
    } catch (e, stackTrace) {
      _isModelInitializing = false;
      _isModelInitialized = false;
      _log.severe('Failed to initialize Gemini Model: $e', e, stackTrace);
      rethrow;
    } finally {
      _modelInitMutex.release();
    }
  }

  // Schedule periodic cleanup of stale states
  void _schedulePeriodicCleanup() {
    Future.delayed(const Duration(hours: 12), () async {
      await _cleanupStaleStates();
      _schedulePeriodicCleanup(); // Reschedule
    });
  }

  // Cleanup stale states that haven't been accessed in 30 days
  Future<void> _cleanupStaleStates() async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) return;

    try {
      final now = DateTime.now();
      _lastStateCleanup = now;

      // Find potential stale state keys
      final keys = _prefs.getKeys()
          .where((key) => key.startsWith(_prefsKeyPrefix))
          .toList();

      int removed = 0;
      for (final key in keys) {
        try {
          final jsonString = _prefs.getString(key);
          if (jsonString != null) {
            final json = jsonDecode(jsonString);
            final lastAccessed = json['last_accessed'];

            if (lastAccessed != null) {
              final lastAccessTime = DateTime.parse(lastAccessed);
              if (now.difference(lastAccessTime).inDays > 30) {
                await _prefs.remove(key);
                removed++;
              }
            }
          }
        } catch (e) {
          _log.warning('Error processing key $key during cleanup: $e');
        }
      }

      _log.info('Cleanup complete. Removed $removed stale states.');
    } catch (e) {
      _log.warning('Error during state cleanup: $e');
    }
  }

  /// **OPTIMIZED: Ensures the base model is initialized and returns it**
  Future<GenerativeModel> _getOptimizedModel() async {
    if (_baseModel != null && _isModelInitialized) {
      return _baseModel!;
    }

    await _initializeBaseModel();

    if (_baseModel == null || !_isModelInitialized) {
      throw Exception('Failed to initialize Gemini model after retry');
    }

    return _baseModel!;
  }

  /// **OPTIMIZED: Cache system prompts to avoid regeneration**
  String _getOrCacheSystemPrompt(AICompanion companion) {
    if (_cachedSystemPrompts.containsKey(companion.id)) {
      return _cachedSystemPrompts[companion.id]!;
    }
    
    final prompt = buildCompanionIntroduction(companion);
    _cachedSystemPrompts[companion.id] = prompt;
    return prompt;
  }


  List<Content> _buildOptimizedSessionHistory(CompanionState state) {
    final history = <Content>[];

    // ✅ FIXED: Safe companion access with fallback
    if (!state.hasCompanion) {
      _log.severe('Cannot build session history: companion not loaded for ${state.companionId}');
      throw StateError('Companion not loaded in state');
    }

    // **FIXED: Check if companion introduction already exists in state history**
    final hasCompanionIntro = state.history.any((content) => 
      content.parts.any((part) => 
        part is TextPart && 
        (part.text.contains('CHARACTER ASSIGNMENT') || 
         part.text.contains('EMBODIMENT INSTRUCTIONS'))
      )
    );
    
    if (!hasCompanionIntro) {
      // **FIXED: Add intro to state history so it persists**
      final intro = buildCompanionIntroduction(state.companion);
      state.history.insert(0, Content.text(intro));
      _log.info('Added companion introduction to persistent state');
    }
    
    if (state.history.isNotEmpty) {
      final recentHistory = state.history.length > 100 
          ? state.history.skip(state.history.length - 100).toList()
          : state.history;
      history.addAll(recentHistory);
    }
    
    _log.info('Built session with ${history.length} messages');
    return history;
  }

  /// Public getter for external checks (e.g., UI elements)
  bool get isInitialized => _isModelInitialized;

  // --- State Key Helper ---
  String _getCompanionStateKey(String userId, String companionId) {
    return '${userId}_$companionId';
  }

  // --- **OPTIMIZED: Debounced State Saving** ---

  /// **OPTIMIZED: Debounced save to prevent excessive disk I/O**
  void _debouncedSave(CompanionState state) {
    final key = _getCompanionStateKey(state.userId, state.companionId);
    
    // Mark this state as needing save
    _pendingSaves.add(key);
    
    // Cancel existing timer and create new one
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDelay, () async {
      await _processPendingSaves();
    });
  }

  /// **OPTIMIZED: Process all pending saves in batch**
  Future<void> _processPendingSaves() async {
    if (_pendingSaves.isEmpty) return;
    
    final keysToSave = Set<String>.from(_pendingSaves);
    _pendingSaves.clear();
    
    _log.info('Processing ${keysToSave.length} pending saves');
    
    for (final key in keysToSave) {
      if (_companionStates.containsKey(key)) {
        final state = _companionStates[key]!;
        
        // Create lightweight copy for saving
        final stateForStorage = CompanionState(
          userId: state.userId,
          companionId: state.companionId,
          history: List.from(state.history), // Shallow copy
          userMemory: Map.from(state.userMemory),
          conversationMetadata: Map.from(state.conversationMetadata),
          relationshipLevel: state.relationshipLevel,
          dominantEmotion: state.dominantEmotion,
        );
        
        await _saveCompanionState(key, stateForStorage);
      }
    }
  }

  // --- Persistence (using CompanionState.toJson/fromJson) ---

  /// Saves the given CompanionState to SharedPreferences with error handling.
  Future<void> _saveCompanionState(String key, CompanionState state) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) {
      _log.severe('Cannot save state for key $key: SharedPreferences not available.');
      return;
    }

    try {
      // Add last accessed timestamp to metadata for cleanup purposes
      state.updateMetadata('last_accessed', DateTime.now().toIso8601String());

      final jsonString = jsonEncode(state.toJson());
      await _prefs.setString('$_prefsKeyPrefix$key', jsonString);
      _log.fine('Saved state for key: $key');
    } catch (e, stackTrace) {
      _log.warning('Failed to save state for key $key: $e', e, stackTrace);
    }
  }

  /// Loads CompanionState from SharedPreferences with improved validation.
  Future<CompanionState?> _loadCompanionState(String key) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) {
      _log.severe('Cannot load state for key $key: SharedPreferences not available.');
      return null;
    }

    try {
      final jsonString = _prefs.getString('$_prefsKeyPrefix$key');
      if (jsonString != null) {
        // Track access time for this key
        _stateAccessTimes[key] = DateTime.now();

        final state = CompanionState.fromJson(jsonDecode(jsonString));
        // Validate state has required fields
        if (state.userId.isNotEmpty && state.companionId.isNotEmpty) {
          _log.fine('Loaded state for key: $key (Version: ${jsonDecode(jsonString)['version'] ?? 'N/A'})');
          return state;
        } else {
          _log.warning('Loaded state for key $key is invalid (missing IDs). Discarding.');
          await _prefs.remove('$_prefsKeyPrefix$key'); // Remove invalid data
        }
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to load or parse state for key $key: $e', e, stackTrace);
      // On JSON parse error, remove corrupted data
      try {
        await _prefs.remove('$_prefsKeyPrefix$key');
        _log.info('Removed corrupted state data for key: $key');
      } catch (cleanupError) {
        _log.warning('Failed to remove corrupted state: $cleanupError');
      }
    }
    return null;
  }

  // --- **OPTIMIZED: Core State Logic & LRU Cache Management** ---

  /// **OPTIMIZED: State loading with reduced overhead**
  Future<CompanionState> _getOrLoadCompanionStateOptimized({
    required String userId,
    required String companionId,
    required AICompanion companion,
    required MessageBloc messageBloc,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final key = _getCompanionStateKey(userId, companionId);

    // **OPTIMIZED: Quick memory check first**
    if (_companionStates.containsKey(key)) {
      _log.fine('State cache hit for key: $key');
      _stateAccessTimes[key] = DateTime.now();
      final state = _companionStates.remove(key)!;
      _companionStates[key] = state; // Move to end (LRU)
      state.companion = companion;
      return state;
    }

    // **OPTIMIZED: Load with timeout to prevent hanging**
    CompanionState? state = await _loadCompanionState(key)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      _log.warning('State loading timed out for key: $key. Creating new state.');
      return null;
    });

    if (state != null) {
      _log.info('Loaded state from storage for key: $key');
      state.companion = companion;
    } else {
      _log.info('Creating new optimized state for key: $key');
      state = CompanionState(
        userId: userId,
        companionId: companionId,
        history: [],
        userMemory: {
          'userName': userName ?? 'User',
          if (userProfile != null) 'userProfile': userProfile,
        },
        conversationMetadata: {
          'created_at': DateTime.now().toIso8601String(),
          'total_interactions': 0,
        },
        relationshipLevel: 1,
        dominantEmotion: 'neutral',
      );

      await state.loadCompanion(companion);
      await _initializeContextFromMessages(state, userName, userProfile, messageBloc);
    }

    // Add to cache and manage size
    _companionStates[key] = state;
    _stateAccessTimes[key] = DateTime.now();
    unawaited(_evictLRUStateIfNecessary());

    return state;
  }

  /// **OPTIMIZED: Initialize context from existing messages**
  Future<void> _initializeContextFromMessages(
    CompanionState state,
    String? userName,
    Map<String, dynamic>? userProfile,
    MessageBloc messageBloc,
  ) async {
    try {

      if (!state.hasCompanion) {
      _log.severe('Cannot initialize context: companion not loaded');
      return;
      }

      List<Message> messages = [];

      final messageBlocState = messageBloc.state;
      if (messageBlocState is MessageLoaded) {
        messages = messageBlocState.messages;
      } else {
        messages = messageBloc.currentMessages;
      }

      if (messages.isNotEmpty) {
        // **FIXED: Check if we already have an introduction**
        final hasIntro = messages.any((msg) => 
          msg.isBot && msg.message.contains("CHARACTER ASSIGNMENT: You are now embodying ${state.companion.name}"));
        
        if (!hasIntro) {
          // Add introduction only if not present in database
          final intro = buildCompanionIntroduction(state.companion);
          state.addHistory(Content.text(intro));
        }
        
        // Convert existing messages to AI history
        for (final message in messages) {
          if (message.isBot) {
            state.addHistory(Content.model([TextPart(message.message)]));
          } else {
            state.addHistory(Content.text(message.message));
          }
        }
        
        state.updateMetadata('total_interactions', messages.length ~/ 2);
        _log.info('Initialized state with ${messages.length} messages from MessageBloc');
      }
      // If no messages, introduction will be added when session is created
      
    } catch (e) {
      _log.severe('Error initializing state from MessageBloc: $e');
    }
  }

  /// Checks cache size and evicts the least recently used state if necessary.
  Future<void> _evictLRUStateIfNecessary() async {
    if (_companionStates.length > _maxMemoryCacheSize) {
      // Find oldest accessed state by sorting access times
      final entries = _stateAccessTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      if (entries.isNotEmpty) {
        final oldestKey = entries.first.key;
        _log.info('Cache limit ($_maxMemoryCacheSize) reached. Evicting state for key: $oldestKey');

        final evictedState = _companionStates.remove(oldestKey);
        _stateAccessTimes.remove(oldestKey);

        // Save the evicted state to persistent storage before removing from memory
        if (evictedState != null) {
          // Clear the transient chat session before saving
          evictedState.chatSession = null;
          await _saveCompanionState(oldestKey, evictedState);
        }
      }
    }
  }

  /// **OPTIMIZED: Parallel initialization processes**
  Future<void> initializeCompanion({
    required AICompanion companion,
    required String userId,
    required MessageBloc messageBloc,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final key = _getCompanionStateKey(userId, companion.id);
    _log.info('Initializing companion: ${companion.name} (key: $key)');

    // **OPTIMIZED: Parallel initialization**
    final futures = <Future>[
      _getOptimizedModel(), // Ensure base model is ready
      if (_activeCompanionKey != null && _activeCompanionKey != key) 
        _quickSaveActiveState(), // Quick save current state
    ];
    
    await Future.wait(futures);

    try {
      // **OPTIMIZED: Load state with minimal blocking**
      final state = await _getOrLoadCompanionStateOptimized(
        userId: userId,
        companionId: companion.id,
        companion: companion,
        userName: userName,
        userProfile: userProfile,
        messageBloc: messageBloc,
      );

      // Set as active immediately
      _activeCompanionKey = key;

      _log.info('Companion ${companion.name} initialized efficiently.');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize companion ${companion.name}: $e', e, stackTrace);
      _activeCompanionKey = null;
      rethrow;
    }
  }

  /// **OPTIMIZED: Quick save without full serialization**
  Future<void> _quickSaveActiveState() async {
    if (_activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)) {
      final state = _companionStates[_activeCompanionKey!]!;
      // Use debounced save instead of immediate save
      _debouncedSave(state);
    }
  }

  // TODO: Implement optimized session history building
  Future<ChatSession> _getOrCreatePersistentSession(CompanionState state) async {
    await _getOptimizedModel();
    
    final sessionKey = '${state.userId}_${state.companionId}';

    // **VALIDATION: Check if this is after a reset**
    final lastReset = state.conversationMetadata['last_reset'];
    if (lastReset != null && _sessionLastUsed.containsKey(sessionKey)) {
      final resetTime = DateTime.parse(lastReset);
      final sessionTime = _sessionLastUsed[sessionKey]!;
      
      if (resetTime.isAfter(sessionTime)) {
        // Session is older than last reset - force recreation
        _persistentSessions.remove(sessionKey);
        _sessionLastUsed.remove(sessionKey);
        _sessionMessageCount.remove(sessionKey);
        _log.info('Forced session recreation due to conversation reset');
      }
    }
    
    if (_persistentSessions.containsKey(sessionKey)) {
      final lastUsed = _sessionLastUsed[sessionKey] ?? DateTime.now();
      final messageCount = _sessionMessageCount[sessionKey] ?? 0;
      
      final isRecent = DateTime.now().difference(lastUsed) < _sessionMaxAge;
      final isFresh = messageCount < _sessionMaxMessages;
      
      if (isRecent && isFresh) {
        _sessionLastUsed[sessionKey] = DateTime.now();
        _log.info('Reusing existing session for ${state.companion.name}');
        return _persistentSessions[sessionKey]!;
      } else {
        _log.info('Session expired: age=${DateTime.now().difference(lastUsed).inDays}d, messages=$messageCount');
        _persistentSessions.remove(sessionKey);
        _sessionLastUsed.remove(sessionKey);
        _sessionMessageCount.remove(sessionKey);
      }
    }

    // Create new session with optimized history
    _log.info('Creating new session for ${state.companion.name}');

    final sessionHistory = _buildOptimizedSessionHistory(state);
    
    final session = _baseModel!.startChat(history: sessionHistory);
    _persistentSessions[sessionKey] = session;
    _sessionLastUsed[sessionKey] = DateTime.now();
    _sessionMessageCount[sessionKey] = sessionHistory.length;
    
    _log.info('Created new 90-day session for ${state.companion.name}');
    return session;
  }


  /// TODO: Response generation with full context
  Future<String> generateResponse(String userMessage) async {
    final stopwatch = Stopwatch()..start();
    
    if (_activeCompanionKey == null) {
      throw Exception('No active companion. Please initialize a companion first.');
    }

    if (!await _stateOperationMutex.acquireWithTimeout(_stateOperationTimeout)) {
      throw TimeoutException('Operation timed out waiting for mutex');
    }

    try {
      final state = _companionStates[_activeCompanionKey!];
      if (state == null) {
        throw Exception('Active companion state not found. Please reinitialize.');
      }
      
      final chatSession = await _getOrCreatePersistentSession(state);

      //  Send message to persistent session (maintains context!)
      final userContent = Content.text(userMessage);
      
      final response = await chatSession.sendMessage(userContent)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Response generation timed out');
      });

      stopwatch.stop();
      _log.info('Response received in ${stopwatch.elapsedMilliseconds}ms');

      final aiText = response.text;
      if (aiText == null || aiText.trim().isEmpty) {
        if (response.promptFeedback?.blockReason != null) {
          throw Exception('Response blocked: ${response.promptFeedback!.blockReason}');
        }
        throw Exception('Empty response received from AI');
      }

      //  Update state efficiently
      _updateStateEfficiently(state, userMessage, aiText, stopwatch.elapsedMilliseconds);
      
      // Update session message count
      final sessionKey = '${state.userId}_${state.companionId}';
      _sessionMessageCount[sessionKey] = (_sessionMessageCount[sessionKey] ?? 0) + 2;
      _sessionLastUsed[sessionKey] = DateTime.now();

      // Async save with debouncing**
      _debouncedSave(state);

      return aiText;
    } finally {
      _stateOperationMutex.release();
    }
  }

  /// **TODO: Batch state updates**
  void _updateStateEfficiently(CompanionState state, String userMessage, String aiResponse, int responseTimeMs) {
    // Add messages to history
    state.addHistory(Content.text(userMessage));
    state.addHistory(Content.model([TextPart(aiResponse)]));
    
    // Trim if necessary
    if (state.history.length > _maxActiveHistoryLength) {
      // trim history while preserving system messages
      _trimHistoryOptimized(state.history, _maxActiveHistoryLength);
      // trim companion state history to keep it manageable
      final keepCount = 40;
      state.history.removeRange(0, state.history.length - keepCount);
    }
    
    // **OPTIMIZED: Batch metadata updates**
    final updates = <String, dynamic>{
      'total_interactions': (state.conversationMetadata['total_interactions'] ?? 0) + 1,
      'last_interaction': DateTime.now().toIso8601String(),
      'last_response_time_ms': responseTimeMs,
    };
    
    updates.forEach((key, value) => state.updateMetadata(key, value));
    
    // **OPTIMIZED: Conditional relationship updates**
    final interactions = updates['total_interactions'] as int;
    if (interactions % 5 == 0) {
      _updateRelationshipMetrics(state, userMessage, aiResponse);
    }
    
    // **OPTIMIZED: Conditional memory updates**
    if (interactions % 3 == 0) {
      _extractMemoryItemsOptimized(state, userMessage, aiResponse);
    }
  }

  /// **OPTIMIZED: History trimming with conversation context preservation**
  void _trimHistoryOptimized(List<Content> history, int maxLength) {
    if (history.length <= maxLength) return;
    
    final systemMessages = <Content>[];
    final conversationHistory = <Content>[];
    
    // Separate system messages from conversation
    for (final content in history) {
      if (content.role == 'system' || content.role == 'model' && 
          content.parts.any((part) => part is TextPart && 
          (part.text.contains('You are') || part.text.length > 500))) {
        systemMessages.add(content);
      } else {
        conversationHistory.add(content);
      }
    }
    
    // Trim conversation history but keep system messages
    if (conversationHistory.length > maxLength - systemMessages.length) {
      final keepCount = maxLength - systemMessages.length;
      final removeCount = conversationHistory.length - keepCount;
      
      // **OPTIMIZED: Keep recent conversations and some context**
      if (removeCount > 0) {
        // Keep first few messages for context (25%) and recent messages (75%)
        final contextKeep = (keepCount * 0.25).round();
        final recentKeep = keepCount - contextKeep;
        
        final contextMessages = conversationHistory.take(contextKeep).toList();
        final recentMessages = conversationHistory.skip(conversationHistory.length - recentKeep).toList();
        
        conversationHistory.clear();
        conversationHistory.addAll(contextMessages);
        conversationHistory.addAll(recentMessages);
      }
    }
    
    // Rebuild history
    history.clear();
    history.addAll(systemMessages);
    history.addAll(conversationHistory);
    
    _log.info('Optimized history trimming: ${history.length} messages retained');
  }

  // Quick check if companion is active without full initialization
  bool isCompanionActive(String userId, String companionId) {
    final key = _getCompanionStateKey(userId, companionId);
    return _activeCompanionKey == key;
  }

  // Get active companion info for debugging
  Map<String, String?> getActiveCompanionInfo() {
    return {
      'activeKey': _activeCompanionKey,
      'companionId': _activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)
          ? _companionStates[_activeCompanionKey!]!.companionId
          : null,
      'companionName': _activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)
          ? _companionStates[_activeCompanionKey!]!.companion.name
          : null,
    };
  }
  // Saves the currently active companion's state to persistent storage.
  Future<void> saveState() async {
    if (_activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)) {
      _log.info('Saving state for active companion: $_activeCompanionKey');
      final state = _companionStates[_activeCompanionKey!]!;
      _debouncedSave(state);
    } else {
      // Only log warning if we actually expect an active companion
      if (_activeCompanionKey != null) {
        _log.warning('saveState called but active companion state $_activeCompanionKey not found in memory.');
      } else {
        _log.fine('saveState called but no active companion is currently set.');
      }
    }
  }

  /// Resets the conversation history and related metrics for the currently active companion.
  Future<void> resetConversation({required MessageBloc messageBloc}) async {
    if (_activeCompanionKey == null || !_companionStates.containsKey(_activeCompanionKey!)) {
      _log.warning('resetConversation called but no active companion state found.');
      return;
    }

    if (!await _stateOperationMutex.acquireWithTimeout(_stateOperationTimeout)) {
      throw TimeoutException('Reset conversation operation timed out');
    }

    try {
      final key = _activeCompanionKey!;
      final state = _companionStates[key]!;
      _log.info('Resetting conversation for: ${state.companion.name}');

      // **CRITICAL FIX 1: Clear the persistent session**
      final sessionKey = '${state.userId}_${state.companionId}';
      if (_persistentSessions.containsKey(sessionKey)) {
        _persistentSessions.remove(sessionKey);
        _sessionLastUsed.remove(sessionKey);
        _sessionMessageCount.remove(sessionKey);
        _log.info('Cleared persistent session for reset');
      }

      // Cache core information before reset
      final userName = state.userMemory['userName'];
      final userProfile = state.userMemory['userProfile'];
      final companion = state.companion; // Store companion reference

      // **CRITICAL FIX 2: Complete state reset**
      state.history.clear();
      state.userMemory.clear();
      state.userMemory['userName'] = userName;
      if (userProfile != null) {
        state.userMemory['userProfile'] = userProfile;
      }

      state.relationshipLevel = 1;
      state.dominantEmotion = 'neutral';
      state.conversationMetadata['total_interactions'] = 0;
      state.conversationMetadata['reset_count'] = (state.conversationMetadata['reset_count'] ?? 0) + 1;
      state.conversationMetadata['last_reset'] = DateTime.now().toIso8601String();

      // Re-add companion introduction properly
      if (state.hasCompanion) {
        final intro = buildCompanionIntroduction(state.companion);
        state.addHistory(Content.text(intro));
        _log.info('Added fresh companion introduction after reset');
      }

      //: Save the completely reset state**
      _debouncedSave(state);

      _log.info('Conversation reset complete - session and state cleared');
    } catch (e) {
      _log.severe('Error during conversation reset: $e');
      rethrow;
    } finally {
      _stateOperationMutex.release();
    }
  }

  // --- **OPTIMIZED: Memory & Relationship Management** ---

  void cleanupStaleSessions() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _sessionLastUsed.forEach((key, lastUsed) {
      // **GENEROUS: Only remove sessions older than 45 days**
      if (now.difference(lastUsed).inDays > 45) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _persistentSessions.remove(key);
      _sessionLastUsed.remove(key);
      _sessionMessageCount.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      _log.info('Cleaned up ${keysToRemove.length} sessions older than 45 days');
    }
  }

  /// Adds or updates an item in the user-specific memory for the active companion.
  void addMemoryItem(String memoryKey, dynamic value) {
    if (_activeCompanionKey == null || !_companionStates.containsKey(_activeCompanionKey!)) {
      _log.warning('addMemoryItem called but no active companion state found.');
      return;
    }

    final state = _companionStates[_activeCompanionKey!]!;
    state.updateMemory(memoryKey, value);
    _log.fine('Updated memory item "$memoryKey" for companion: ${state.companion.name}');

    // Save updated memory with debouncing
    _debouncedSave(state);
  }

  /// Retrieves relationship metrics for the active companion.
  Map<String, dynamic> getRelationshipMetrics() {
    if (_activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)) {
      final state = _companionStates[_activeCompanionKey!]!;
      return {
        'level': state.relationshipLevel,
        'dominant_emotion': state.dominantEmotion ?? 'neutral',
        'total_interactions': state.conversationMetadata['total_interactions'] ?? 0,
        'last_interaction': state.conversationMetadata['last_interaction'],
      };
    }

    // Return default values if no active state
    _log.warning('getRelationshipMetrics called but no active companion state found.');
    return {
      'level': 1,
      'dominant_emotion': 'neutral',
      'total_interactions': 0,
    };
  }

  /// Checks if a specific companion is the currently active and initialized one in memory.
  bool isCompanionInitialized(String userId, String companionId) {
    final key = _getCompanionStateKey(userId, companionId);
    return _activeCompanionKey == key && _companionStates.containsKey(key);
  }

  // --- **OPTIMIZED: Memory Management** ---

  /// **OPTIMIZED: Cache regex patterns for reuse**
  Map<String, RegExp> _getCachedPatterns() {
    return _cachedPatterns ??= {
      'name': RegExp(r'(?:my name is|i am called|i am called|call me)\s+([A-Za-z]+)', caseSensitive: false),
      'age': RegExp(r'i am (\d+) years old|i am (\d+)', caseSensitive: false),
    };
  }

  /// **OPTIMIZED: Helper to check multiple keywords efficiently**
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// **OPTIMIZED: Helper to determine if a message contains important facts**
  bool _isImportantFact(String message) {
    final lower = message.toLowerCase();
    final factIndicators = ['i am', 'i\'m', 'i have', 'my', 'i work', 'i live'];
    return _containsAny(lower, factIndicators) && 
           message.length > 10 && 
           message.length < 200;
  }

  /// **OPTIMIZED: Helper to add items to memory lists efficiently**
  void _addToMemoryList(CompanionState state, String key, String value, {int maxSize = 10}) {
    final list = state.userMemory[key] as List<dynamic>? ?? <String>[];
    
    // Avoid duplicates
    if (!list.contains(value)) {
      if (list.length >= maxSize) {
        list.removeAt(0); // Remove oldest
      }
      list.add(value);
      state.updateMemory(key, list);
    }
  }

  /// **OPTIMIZED: Memory extraction with pattern caching**
  void _extractMemoryItemsOptimized(CompanionState state, String userMessage, String aiResponse) {
    try {
      final lowerUserMsg = userMessage.toLowerCase();
      
      // **OPTIMIZED: Use cached regex patterns**
      final patterns = _getCachedPatterns();
      
      // Extract name with better pattern
      final nameMatch = patterns['name']!.firstMatch(userMessage);
      if (nameMatch != null && nameMatch.group(1) != null) {
        state.updateMemory('user_preferred_name', nameMatch.group(1)!.trim());
      }

      // **OPTIMIZED: Batch preference extraction**
      if (_containsAny(lowerUserMsg, ['favorite', 'like', 'love', 'enjoy', 'prefer'])) {
        _addToMemoryList(state, 'preferences', userMessage, maxSize: 8);
      }

      // **OPTIMIZED: Extract facts more selectively**
      if (_isImportantFact(userMessage)) {
        _addToMemoryList(state, 'important_facts', userMessage, maxSize: 10);
      }
    } catch (e) {
      _log.warning('Error extracting memory items: $e');
    }
  }

  /// Enhanced relationship metrics update with emotion detection
  void _updateRelationshipMetrics(CompanionState state, String userMessage, String aiResponse) {
    try {
      final interactions = state.conversationMetadata['total_interactions'] ?? 0;

      // Relationship level logic - grow relationships more naturally
      if (interactions > 10 && state.relationshipLevel == 1) {
        state.relationshipLevel = 2; // After 10 interactions -> level 2
      } else if (interactions > 30 && state.relationshipLevel == 2) {
        state.relationshipLevel = 3; // After 30 interactions -> level 3
      } else if (interactions > 60 && state.relationshipLevel == 3) {
        state.relationshipLevel = 4; // After 60 interactions -> level 4
      } else if (interactions > 100 && state.relationshipLevel == 4) {
        state.relationshipLevel = 5; // After 100 interactions -> level 5
      }

      // Emotion detection - more nuanced approach
      final lowerResponse = aiResponse.toLowerCase();
      final lowerUserMsg = userMessage.toLowerCase();

      // Basic emotion mapping from content keywords
      Map<String, List<String>> emotionKeywords = {
        'happy': ['happy', 'glad', 'excited', 'wonderful', 'delighted', 'pleased'],
        'sad': ['sad', 'sorry', 'unfortunate', 'upset', 'disappointed'],
        'curious': ['curious', 'wonder', 'interesting', 'fascinating', 'tell me more'],
        'concerned': ['worried', 'concerned', 'careful', 'cautious'],
        'amused': ['funny', 'amusing', 'laugh', 'hilarious', 'haha'],
        'affectionate': ['care', 'love', 'close', 'fond', 'miss you'],
      };

      String? dominantEmotion;
      int maxMatches = 0;

      // Find emotion with most keyword matches
      emotionKeywords.forEach((emotion, keywords) {
        int matches = keywords.where((keyword) =>
            lowerResponse.contains(keyword) || lowerUserMsg.contains(keyword)).length;
        if (matches > maxMatches) {
          maxMatches = matches;
          dominantEmotion = emotion;
        }
      });

      // Only update if we found matches or need to normalize
      if (maxMatches > 0) {
        state.dominantEmotion = dominantEmotion;
      } else if (interactions % 10 == 0 && state.dominantEmotion != 'neutral') {
        // Occasionally reset to neutral if no strong signals
        state.dominantEmotion = 'neutral';
      }
    } catch (e) {
      _log.warning('Error updating relationship metrics: $e');
    }
  }

  // --- Performance & Debugging ---

  /// Provides a detailed report on the current state of the service.
  Map<String, dynamic> getPerformanceReport() {
    return {
      'isModelInitialized': _isModelInitialized,
      'activeCompanionKey': _activeCompanionKey,
      'memoryCacheSize': _companionStates.length,
      'memoryCacheKeys': _companionStates.keys.toList(),
      'lastStateCleanup': _lastStateCleanup.toIso8601String(),
      'stateAccessTimes': _stateAccessTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
      'pendingSaves': _pendingSaves.length,
      'cachedSystemPrompts': _cachedSystemPrompts.length,
      'activeCompanionDetails': _activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)
          ? {
              'companionId': _companionStates[_activeCompanionKey!]!.companionId,
              'historyLength': _companionStates[_activeCompanionKey!]!.history.length,
              'relationshipLevel': _companionStates[_activeCompanionKey!]!.relationshipLevel,
              'dominantEmotion': _companionStates[_activeCompanionKey!]!.dominantEmotion,
            }
          : null,
    };
  }

  // --- Cleanup ---
  /// Clear all companion states for a specific user (for logout)
  Future<void> clearAllUserStates(String userId) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) return;

    if (!await _stateOperationMutex.acquireWithTimeout(_stateOperationTimeout)) {
      throw TimeoutException('Clear user states operation timed out');
    }

    try {
      // Clear from memory cache
      final keysToRemove = _companionStates.keys
          .where((key) => key.startsWith('${userId}_'))
          .toList();
      
      for (final key in keysToRemove) {
        _companionStates.remove(key);
        _stateAccessTimes.remove(key);
      }

      // Clear sessions
      final sessionKeysToRemove = _persistentSessions.keys
          .where((key) => key.startsWith('${userId}_'))
          .toList();
          
      for (final key in sessionKeysToRemove) {
        _persistentSessions.remove(key);
        _sessionLastUsed.remove(key);
        _sessionMessageCount.remove(key);
      }

      // Clear from persistent storage
      final allKeys = _prefs.getKeys()
          .where((key) => key.startsWith('$_prefsKeyPrefix${userId}_'))
          .toList();

      for (final key in allKeys) {
        await _prefs.remove(key);
      }

      // Clear cached system prompts for this user's companions
      final userCompanionPrompts = _cachedSystemPrompts.keys
          .where((key) => key.startsWith(userId))
          .toList();
      
      for (final key in userCompanionPrompts) {
        _cachedSystemPrompts.remove(key);
      }

      _log.info('Cleared all companion states for user $userId (${allKeys.length} keys removed)');
    } catch (e) {
      _log.severe('Error clearing user companion states: $e');
    } finally {
      _stateOperationMutex.release();
    }
  }

  /// Clear state for a specific companion
  Future<void> clearCompanionState(String userId, String companionId) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) return;

    if (!await _stateOperationMutex.acquireWithTimeout(_stateOperationTimeout)) {
      throw TimeoutException('Clear companion state operation timed out');
    }

    try {
      final key = _getCompanionStateKey(userId, companionId);
      final sessionKey = '${userId}_$companionId';

      // Remove from memory
      _companionStates.remove(key);
      _stateAccessTimes.remove(key);
      
      // Remove session
      _persistentSessions.remove(sessionKey);
      _sessionLastUsed.remove(sessionKey);
      _sessionMessageCount.remove(sessionKey);
      

      // Remove from storage
      await _prefs.remove('$_prefsKeyPrefix$key');
      
      // Clear cached system prompt
      _cachedSystemPrompts.remove(companionId);
      
      _log.info('Cleared companion state for $companionId');
    } catch (e) {
      _log.severe('Error clearing companion state: $e');
    } finally {
      _stateOperationMutex.release();
    }
  }

  /// **OPTIMIZED: Call this on app shutdown or when service is no longer needed.**
  Future<void> dispose() async {
    _log.info('Disposing GeminiService...');
    await _saveSessionMetadata();

    // Cancel any pending save operations
    _saveDebounceTimer?.cancel();
    
    // Process any remaining pending saves
    if (_pendingSaves.isNotEmpty) {
      await _processPendingSaves();
    }

    // Save all active states
    await saveState();

    // Save other states in cache
    for (final key in _companionStates.keys.where((k) => k != _activeCompanionKey)) {
      final state = _companionStates[key];
      if (state != null) {
        state.chatSession = null;
        await _saveCompanionState(key, state);
      }
    }

    // Clear in-memory cache
    _companionStates.clear();
    _stateAccessTimes.clear();
    _cachedSystemPrompts.clear();
    _cachedPatterns = null;
    _activeCompanionKey = null;
    _baseModel = null; // Allow GC
    _isModelInitialized = false;

    _log.info('GeminiService disposed successfully.');
  }
}

/// Improved mutex implementation with timeouts and auto-release capabilities
class Mutex {
  Completer<void>? _completer;

  bool get isLocked => _completer != null;

  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
  }

  Future<bool> acquireWithTimeout(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (_completer != null) {
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      try {
        await _completer!.future.timeout(
          Duration(milliseconds: 100),
          onTimeout: () {},
        );
      } catch (e) {
        // Continue waiting
      }
    }
    _completer = Completer<void>();
    return true;
  }

  void release() {
    if (_completer != null && !_completer!.isCompleted) {
      final completer = _completer;
      _completer = null;
      completer!.complete();
    } else {
      _completer = null;
    }
  }
}

/// Helper for non-blocking operations
void unawaited(Future<void> future) {
  // Intentionally left empty - allows fire-and-forget operations
}