import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/gemini/companion_state.dart';
import 'package:ai_companion/chat/gemini/system_prompt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

/// Service for interacting with the Gemini API and managing companion state.
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

  // Model management
  GenerativeModel? _baseModel;
  final Map<String, GenerativeModel> _companionModels = {};
  final Map<String, String> _cachedSystemPrompts = {};
  bool _isModelInitializing = false;
  bool _isModelInitialized = false;

  // Improved thread safety with better mutex tracking
  final _modelInitMutex = Mutex();
  final _stateOperationMutex = Mutex();

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

        // Schedule periodic cleanup
        _schedulePeriodicCleanup();
      } catch (e, stackTrace) {
        _log.severe('Failed to initialize SharedPreferences: $e', e, stackTrace);
      }
    }
  }

  // Initialize base model once for efficiency
  Future<void> _initializeBaseModel() async {
    await _modelInitMutex.acquire();
    try {
      if (_baseModel != null && _isModelInitialized) {
        _modelInitMutex.release();
        return;
      }

      if (_isModelInitializing) {
        _log.info('Model already initializing, waiting...');
        _modelInitMutex.release();
        return;
      }

      _isModelInitializing = true;
      _log.info('Initializing base Gemini Model...');

      // Get API key with validation
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found or empty in .env file.');
      }

      // Create the base model with generic system instruction
      _baseModel = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        safetySettings: _safetySettings,
        generationConfig: _generationConfig,
        systemInstruction: Content.system("You are an AI companion assistant."),
      );

      _isModelInitialized = true;
      _isModelInitializing = false;
      _log.info('Base Gemini Model initialized successfully.');
    } catch (e, stackTrace) {
      _isModelInitializing = false;
      _isModelInitialized = false;
      _log.severe('Failed to initialize Gemini Model: $e', e, stackTrace);
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

  /// Ensures the base model is initialized and returns it
  Future<GenerativeModel> _getBaseModel() async {
    if (_baseModel != null && _isModelInitialized) {
      return _baseModel!;
    }

    await _initializeBaseModel();

    if (_baseModel == null || !_isModelInitialized) {
      throw Exception('Failed to initialize Gemini model after retry');
    }

    return _baseModel!;
  }

  /// Gets or creates a companion-specific model with the right system prompt
  Future<GenerativeModel> _getCompanionModel(AICompanion companion) async {
    final companionId = companion.id;

    // Return cached model if available
    if (_companionModels.containsKey(companionId)) {
      return _companionModels[companionId]!;
    }

    // Make sure base model is initialized
    await _getBaseModel();

    // Get API key
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found or empty');
    }

    // Check for cached system prompt or generate new one
    String systemPrompt;
    if (_cachedSystemPrompts.containsKey(companionId)) {
      systemPrompt = _cachedSystemPrompts[companionId]!;
    } else {
      systemPrompt = buildSystemPrompt(companion);
      _cachedSystemPrompts[companionId] = systemPrompt; // Cache for future use
    }

    // Create companion-specific model
    final companionModel = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      safetySettings: _safetySettings,
      generationConfig: _generationConfig,
      systemInstruction: Content.system(systemPrompt),
    );

    // Cache the model for future use
    _companionModels[companionId] = companionModel;

    return companionModel;
  }

  /// Public getter for external checks (e.g., UI elements)
  bool get isInitialized => _isModelInitialized;

  // --- State Key Helper ---
  String _getCompanionStateKey(String userId, String companionId) {
    return '${userId}_$companionId';
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

  // --- Core State Logic & LRU Cache Management ---

  /// Gets state from memory cache, loads from storage, or creates a new one.
  Future<CompanionState> _getOrLoadCompanionState({
    required String userId,
    required String companionId,
    required AICompanion companion,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final key = _getCompanionStateKey(userId, companionId);

    // Use improved mutex with auto-release
    await _stateOperationMutex.acquire();

    try {
      // Check memory cache first (LRU update)
      if (_companionStates.containsKey(key)) {
        _log.fine('State cache hit for key: $key');
        // Update access time
        _stateAccessTimes[key] = DateTime.now();
        // Move to end to mark as recently used
        final state = _companionStates.remove(key)!;
        _companionStates[key] = state;
        // Ensure transient fields are populated if needed
        state.companion = companion;
        // Recreate chat session if it's null
        if (state.chatSession == null) {
          await _recreateChatSession(state);
        }
        return state;
      }

      _log.fine('State cache miss for key: $key. Loading from storage...');

      // Try loading from SharedPreferences
      CompanionState? state = await _loadCompanionState(key);

      if (state != null) {
        _log.info('Loaded state from storage for key: $key');
        // Populate transient fields
        state.companion = companion;
        await _recreateChatSession(state); // Recreate ChatSession from loaded history
      } else {
        _log.info('No state found in storage. Creating new state for key: $key');
        // Create new state if not found
        state = CompanionState(
          userId: userId,
          companionId: companionId,
          history: [], // Start with empty history
          userMemory: { // Initialize basic memory
            'userName': userName ?? 'User',
            if (userProfile != null) 'userProfile': userProfile,
          },
          conversationMetadata: {
            'created_at': DateTime.now().toIso8601String(),
            'total_interactions': 0,
          },
          relationshipLevel: 1,
          dominantEmotion: 'neutral',
          companion: companion, // Attach the full companion object
        );

        // Add initial context as first message
        await _initializeCompanionContext(state, userName, userProfile);

        // Save the newly created state immediately
        await _saveCompanionState(key, state);
      }

      // Add to memory cache and manage size (LRU eviction)
      _companionStates[key] = state;
      _stateAccessTimes[key] = DateTime.now();
      await _evictLRUStateIfNecessary(); // Check and evict oldest if cache exceeds limit

      return state;
    } catch (e) {
      _log.severe('Error in _getOrLoadCompanionState: $e');
      rethrow;
    } finally {
      _stateOperationMutex.release();
    }
  }

  /// Initializes companion context by creating a ChatSession with the appropriate system prompt
  Future<void> _initializeCompanionContext(
    CompanionState state,
    String? userName,
    Map<String, dynamic>? userProfile
  ) async {
    try {
      // Get companion-specific model - cached or new
      final companionModel = await _getCompanionModel(state.companion!);

      // Create initial session with the companion-specific model
      state.chatSession = companionModel.startChat();

      // Add minimal context for the conversation
      final userContext = _buildMinimalUserContext(userName, userProfile);
      if (userContext.isNotEmpty) {
        state.addHistory(Content.text("Tell me about yourself: $userContext"));

        // Add dummy model response to initialize the conversation
        state.addHistory(Content.model([TextPart("Nice to meet you! I'm ${state.companion!.name}. What would you like to talk about?")]));
      }

      _log.fine('Initialized context and chat session for ${state.companion!.name}');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize companion context: $e', e, stackTrace);
      throw Exception('Failed to setup companion: ${e.toString().split('\n').first}');
    }
  }

  /// Creates a minimal user context string with essential info
  String _buildMinimalUserContext(String? userName, Map<String, dynamic>? userProfile) {
    final buffer = StringBuffer();

    if (userName != null && userName.isNotEmpty) {
      buffer.write("My name is $userName");
    }

    if (userProfile != null) {
      if (userProfile['age'] != null) {
        buffer.write(buffer.isEmpty ? "I'm " : ", I'm ");
        buffer.write("${userProfile['age']} years old");
      }

      if (userProfile['gender'] != null && userProfile['gender'].toString().isNotEmpty) {
        buffer.write(buffer.isEmpty ? "I'm " : ", I'm ");
        buffer.write("${userProfile['gender']}");
      }

      if (userProfile['interests'] is List && (userProfile['interests'] as List).isNotEmpty) {
        buffer.write(buffer.isEmpty ? "I like " : ", and I like ");
        buffer.write((userProfile['interests'] as List).join(', '));
      }
    }

    return buffer.toString();
  }

  /// Recreates the ChatSession for a given state, using its history and companion-specific model.
  Future<void> _recreateChatSession(CompanionState state) async {
    try {
      // Trim history before starting chat if too long
      if (state.history.length > _maxActiveHistoryLength) {
        _trimHistory(state.history, _maxActiveHistoryLength);
      }

      // Get the companion-specific model - reuses cached model when available
      final companionModel = await _getCompanionModel(state.companion!);

      // Initialize chat with history
      state.chatSession = companionModel.startChat(
        history: state.history.isNotEmpty ? state.history : null,
      );

      _log.fine('Recreated chat session for ${state.companion!.name} with ${state.history.length} history items');
    } catch (e, stackTrace) {
      _log.severe('Failed to recreate chat session: $e', e, stackTrace);
      state.chatSession = null; // Ensure session is null on failure
      throw Exception('Failed to initialize companion: ${e.toString().split('\n').first}');
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

  /// Initializes or loads the state for a specific companion interaction, making it active.
  Future<void> initializeCompanion({
    required AICompanion companion,
    required String userId,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final key = _getCompanionStateKey(userId, companion.id);
    _log.info('Initializing companion: ${companion.name} (key: $key)');

    // Ensure base model is initialized in background
    unawaited(_getBaseModel());

    // Save state of the previously active companion before switching
    if (_activeCompanionKey != null && _activeCompanionKey != key) {
      await saveState(); // Saves the currently active state
    }

    try {
      // Get/Load the state. This also adds it to the memory cache (LRU).
      final state = await _getOrLoadCompanionState(
        userId: userId,
        companionId: companion.id,
        companion: companion,
        userName: userName,
        userProfile: userProfile,
      );

      // Set the new active key
      _activeCompanionKey = key;

      // Ensure the chat session is valid
      if (state.chatSession == null) {
        _log.warning('Chat session is null after loading state. Recreating...');
        await _recreateChatSession(state);
        if (state.chatSession == null) {
          throw Exception('Failed to create chat session after loading state.');
        }
      }

      _log.info('Companion ${companion.name} initialized and active.');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize companion ${companion.name}: $e', e, stackTrace);
      _activeCompanionKey = null; // Ensure no active key on failure
      rethrow; // Propagate the error
    }
  }

  /// Generates a response from the currently active companion with enhanced error handling.
  Future<String> generateResponse(String userMessage) async {
    final stopwatch = Stopwatch()..start();
    // Validation checks
    if (_activeCompanionKey == null) {
      _log.severe('generateResponse called but no active companion key set.');
      throw Exception('No active companion. Please initialize a companion first.');
    }

    // Acquire mutex with timeout - prevent deadlocks
    if (!await _stateOperationMutex.acquireWithTimeout(_stateOperationTimeout)) {
      throw TimeoutException('Operation timed out waiting for mutex');
    }

    try {
      // Get the active state from cache
      final state = _companionStates[_activeCompanionKey!];
      if (state == null) {
        throw Exception('Active companion state not found. Please reinitialize.');
      }

      // Ensure chat session exists
      if (state.chatSession == null) {
        _log.warning('Chat session is null for active companion. Recreating...');
        await _recreateChatSession(state);
        if (state.chatSession == null) {
          throw Exception('Failed to create chat session for companion.');
        }
      }

      _log.fine('Generating response for: "$userMessage" (Companion: ${state.companionId})');

      // Prepare user message
      final userContent = Content.text(userMessage);

      // Add to history
      state.addHistory(userContent);

      // Ensure history isn't too long
      if (state.history.length > _maxActiveHistoryLength) {
        _trimHistory(state.history, _maxActiveHistoryLength);
      }

      // Send message with timeout
      final response = await state.chatSession!.sendMessage(userContent)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Response generation timed out');
      });

      stopwatch.stop();
      _log.info('Response received in ${stopwatch.elapsedMilliseconds}ms');

      // Process response
      final aiText = response.text;
      if (aiText == null || aiText.trim().isEmpty) {
        if (response.promptFeedback?.blockReason != null) {
          throw Exception('Response blocked: ${response.promptFeedback!.blockReason}');
        }
        throw Exception('Empty response received from AI');
      }

      // Add AI response to history
      state.addHistory(Content.model([TextPart(aiText)]));

      // Update state metadata for analytics and relationship metrics
      _updateStateMetadata(state, userMessage, aiText, stopwatch.elapsedMilliseconds);

      // Save state asynchronously (don't wait)
      unawaited(_saveCompanionState(_activeCompanionKey!, state));

      return aiText;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _log.severe('Error generating response: $e', e, stackTrace);

      // Attempt recovery on timeout
      if (e is TimeoutException) {
        try {
          // On timeout, try to recreate the session
          final state = _companionStates[_activeCompanionKey!];
          if (state != null) {
            state.chatSession = null; // Force recreation on next attempt
            _log.info('Clearing chat session after timeout');
          }
        } catch (recoveryError) {
          _log.warning('Error during timeout recovery: $recoveryError');
        }
      }

      // Return user-friendly error message
      if (e is TimeoutException) {
        throw Exception('I need a moment to collect my thoughts. Please try again.');
      } else {
        throw Exception('I\'m having trouble responding right now. Let\'s try something else.');
      }
    } finally {
      _stateOperationMutex.release();
    }
  }

  /// Update state metadata with analytics and relationship data
  void _updateStateMetadata(CompanionState state, String userMessage, String aiResponse, int responseTimeMs) {
    try {
      // Update basic interaction metrics
      final interactions = (state.conversationMetadata['total_interactions'] ?? 0) + 1;
      state.updateMetadata('total_interactions', interactions);
      state.updateMetadata('last_interaction', DateTime.now().toIso8601String());
      state.updateMetadata('last_response_time_ms', responseTimeMs);

      // Update memory items (every message)
      _extractMemoryItems(state, userMessage, aiResponse);

      // Update relationship metrics (every 5 messages for performance)
      if (interactions % 5 == 0) {
        _updateRelationshipMetrics(state, userMessage, aiResponse);
      }
    } catch (e) {
      _log.warning('Error updating metadata: $e');
    }
  }

  /// Trims the history list to the specified maximum length, removing older items.
  void _trimHistory(List<Content> history, int maxLength) {
    if (history.length > maxLength) {
      // Calculate how many items to remove (preserve first context item)
      int removeCount = history.length - maxLength;

      // Always keep the first item (context setup)
      if (history.length > 2 && removeCount >= history.length - 1) {
        removeCount = history.length - 2;
      }

      if (removeCount > 0) {
        // Remove from index 1 (after context) to preserve the setup
        history.removeRange(1, 1 + removeCount);
        _log.info('Trimmed history from ${history.length + removeCount} to ${history.length} items');
      }
    }
  }

  /// Saves the currently active companion's state to persistent storage.
  Future<void> saveState() async {
    if (_activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)) {
      _log.info('Saving state for active companion: $_activeCompanionKey');
      final state = _companionStates[_activeCompanionKey!]!;

      // Create a copy of state before modifying it to avoid affecting memory version
      final stateForStorage = CompanionState(
        userId: state.userId,
        companionId: state.companionId,
        history: state.history,
        userMemory: Map.from(state.userMemory),
        conversationMetadata: Map.from(state.conversationMetadata),
        relationshipLevel: state.relationshipLevel,
        dominantEmotion: state.dominantEmotion,
        companion: state.companion,
      );

      // Clear transient session before saving
      stateForStorage.chatSession = null;
      await _saveCompanionState(_activeCompanionKey!, stateForStorage);
    } else {
      _log.warning('saveState called but no active companion state found.');
    }
  }

  /// Resets the conversation history and related metrics for the currently active companion.
  Future<void> resetConversation() async {
    if (_activeCompanionKey == null || !_companionStates.containsKey(_activeCompanionKey!)) {
      _log.warning('resetConversation called but no active companion state found.');
      return;
    }

    // Use mutex for thread safety
    await _stateOperationMutex.acquire();

    try {
      final key = _activeCompanionKey!;
      final state = _companionStates[key]!;
      _log.info('Resetting conversation state for: ${state.companion?.name ?? key}');

      // Cache core information before reset
      final companion = state.companion;
      final userName = state.userMemory['userName'];
      final userProfile = state.userMemory['userProfile'];

      // Reset state
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

      // Reinitialize context and session
      await _initializeCompanionContext(state, userName, userProfile);

      // Save the reset state
      await _saveCompanionState(key, state);

      _log.info('Conversation reset complete');
    } catch (e) {
      _log.severe('Error during conversation reset: $e');
      rethrow;
    } finally {
      _stateOperationMutex.release();
    }
  }

  // --- Memory & Relationship ---

  /// Adds or updates an item in the user-specific memory for the active companion.
  void addMemoryItem(String memoryKey, dynamic value) {
    if (_activeCompanionKey == null || !_companionStates.containsKey(_activeCompanionKey!)) {
      _log.warning('addMemoryItem called but no active companion state found.');
      return;
    }

    final state = _companionStates[_activeCompanionKey!]!;
    state.updateMemory(memoryKey, value);
    _log.fine('Updated memory item "$memoryKey" for companion: ${state.companion?.name ?? state.companionId}');

    // Save updated memory async
    unawaited(_saveCompanionState(_activeCompanionKey!, state));
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

  // --- Improved Relationship & Memory Management ---

  /// Enhanced memory item extraction with pattern recognition
  void _extractMemoryItems(CompanionState state, String userMessage, String aiResponse) {
    try {
      final lowerUserMsg = userMessage.toLowerCase();

      // Extract relationship-related information
      if (lowerUserMsg.contains('my name is') || lowerUserMsg.contains('i\'m called')) {
        final namePattern = RegExp(r'''(?:my name is|i\'m called|i am called) ([A-Za-z]+)''');
        final match = namePattern.firstMatch(userMessage);
        if (match != null && match.group(1) != null) {
          state.updateMemory('user_preferred_name', match.group(1));
        }
      }

      // Extract preferences
      if (lowerUserMsg.contains('favorite') || lowerUserMsg.contains(' like ') ||
          lowerUserMsg.contains(' love ') || lowerUserMsg.contains(' enjoy ')) {
        final preferences = state.userMemory['preferences'] ?? <String>[];
        if (preferences is List) {
          if (preferences.length >= 10) preferences.removeAt(0); // Keep list manageable
          preferences.add(userMessage);
          state.updateMemory('preferences', preferences);
        }
      }

      // Extract important facts
      if (lowerUserMsg.contains('i am ') || lowerUserMsg.contains('i\'m ') ||
          lowerUserMsg.startsWith('i have ') || lowerUserMsg.contains('my ')) {
        final facts = state.userMemory['important_facts'] ?? <String>[];
        if (facts is List && facts.length < 15 && userMessage.length > 10) {
          facts.add(userMessage);
          state.updateMemory('important_facts', facts);
        }
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

    await _stateOperationMutex.acquire();
    try {
      // Clear from memory cache
      final keysToRemove = _companionStates.keys
          .where((key) => key.startsWith('${userId}_'))
          .toList();
      
      for (final key in keysToRemove) {
        _companionStates.remove(key);
        _stateAccessTimes.remove(key);
      }

      // Clear from persistent storage
      final allKeys = _prefs.getKeys()
          .where((key) => key.startsWith('${_prefsKeyPrefix}${userId}_'))
          .toList();

      for (final key in allKeys) {
        await _prefs.remove(key);
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

    await _stateOperationMutex.acquire();
    try {
      final key = _getCompanionStateKey(userId, companionId);
      
      // Remove from memory
      _companionStates.remove(key);
      _stateAccessTimes.remove(key);
      
      // Remove from storage
      await _prefs.remove('$_prefsKeyPrefix$key');
      
      _log.info('Cleared companion state for $companionId');
    } catch (e) {
      _log.severe('Error clearing companion state: $e');
    } finally {
      _stateOperationMutex.release();
    }
  }
  /// Call this on app shutdown or when service is no longer needed.
  Future<void> dispose() async {
    _log.info('Disposing GeminiService...');

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
      await _completer!.future.timeout(
        timeout,
        onTimeout: () {},
      );
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
  // Intentionally left empty
}