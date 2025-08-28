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
    // **ENHANCED: Load session metadata on startup**
    Future.microtask(() => _loadSessionMetadata());
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
  static const int _sessionMaxMessages = 200;                
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

  /// **ENHANCED: Load session metadata on startup with validation**
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
        
        _log.info('✅ Loaded session metadata for ${sessionData.length} sessions');
        
        // Validate loaded metadata against current time
        final now = DateTime.now();
        final keysToRemove = <String>[];
        
        _sessionLastUsed.forEach((key, lastUsed) {
          if (now.difference(lastUsed) > _sessionMaxAge) {
            keysToRemove.add(key);
          }
        });
        
        // Clean up expired metadata
        for (final key in keysToRemove) {
          _sessionLastUsed.remove(key);
          _sessionMessageCount.remove(key);
        }
        
        if (keysToRemove.isNotEmpty) {
          _log.info('🧹 Cleaned ${keysToRemove.length} expired session metadata entries');
          unawaited(_saveSessionMetadata()); // Save cleaned metadata
        }
      }
    } catch (e) {
      _log.warning('Failed to load session metadata: $e');
    }
  }

  /// **NEW: Update session metadata after clearing a user's data**
  Future<void> _updateSessionMetadataAfterUserClear(String userId) async {
    if (!_prefsInitialized) return;
    
    try {
      // Filter out sessions for the cleared user from persistent metadata
      final sessionDataString = _prefs.getString('session_metadata');
      if (sessionDataString != null) {
        final sessionData = jsonDecode(sessionDataString) as Map<String, dynamic>;
        final updatedSessionData = <String, dynamic>{};
        
        // Keep only sessions that don't belong to the cleared user
        sessionData.forEach((key, data) {
          if (!key.startsWith('${userId}_')) {
            updatedSessionData[key] = data;
          }
        });
        
        // Save the filtered metadata
        await _prefs.setString('session_metadata', jsonEncode(updatedSessionData));
        _log.info('🧹 Updated session metadata: removed sessions for user $userId');
      }
    } catch (e) {
      _log.warning('Failed to update session metadata after user clear: $e');
    }
  }

  /// **NEW: Update session metadata after clearing a specific companion**
  Future<void> _updateSessionMetadataAfterCompanionClear(String sessionKey) async {
    if (!_prefsInitialized) return;
    
    try {
      // Remove specific session from persistent metadata
      final sessionDataString = _prefs.getString('session_metadata');
      if (sessionDataString != null) {
        final sessionData = jsonDecode(sessionDataString) as Map<String, dynamic>;
        
        // Remove the specific session
        sessionData.remove(sessionKey);
        
        // Save the updated metadata
        await _prefs.setString('session_metadata', jsonEncode(sessionData));
        _log.info('🧹 Updated session metadata: removed session $sessionKey');
      }
    } catch (e) {
      _log.warning('Failed to update session metadata after companion clear: $e');
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
  String _getOrCacheSystemPrompt(AICompanion companion, {bool isVoiceMode = false}) {
    // Use different cache keys for voice vs text mode
    final cacheKey = isVoiceMode ? '${companion.id}_voice' : companion.id;
    
    if (_cachedSystemPrompts.containsKey(cacheKey)) {
      return _cachedSystemPrompts[cacheKey]!;
    }
    
    String prompt = buildCompanionIntroduction(companion);
    
    // Add voice-specific instructions for voice mode
    if (isVoiceMode) {
      // Import voice instructions from VoiceEnhancedGeminiService
      final voiceInstructions = getVoiceSystemInstructions(companion);
      prompt += '\n\n$voiceInstructions';
    }
    
    _cachedSystemPrompts[cacheKey] = prompt;
    return prompt;
  }



  List<Content> _buildOptimizedSessionHistory(CompanionState state) {
    final history = <Content>[];

    // Safe companion access with fallback
    if (!state.hasCompanion) {
      _log.severe('Cannot build session history: companion not loaded for ${state.companionId}');
      throw StateError('Companion not loaded in state');
    }

    // **ENHANCED: Check if companion introduction already exists in state history**
    final hasCompanionIntro = state.history.any((content) => 
      content.parts.any((part) => 
        part is TextPart && 
        (part.text.contains('CHARACTER ASSIGNMENT') || 
         part.text.contains('EMBODIMENT INSTRUCTIONS') ||
         part.text.contains('VOICE CONVERSATION GUIDELINES') ||
         part.text.contains('VOICE DELIVERY INSTRUCTIONS'))
      )
    );
    
    if (!hasCompanionIntro) {
      // **ENHANCED: Use cached system prompt**
      final intro = _getOrCacheSystemPrompt(state.companion);
      state.history.insert(0, Content.text(intro));
      _log.info('Added companion introduction to persistent state');
    }
    
    if (state.history.isNotEmpty) {
      final recentHistory = state.history.length > 100 
          ? state.history.skip(state.history.length - 100).toList()
          : state.history;
      history.addAll(recentHistory);
      _log.info('Added ${recentHistory.length} history items to session');
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

  /// State loading with reduced overhead**
  Future<CompanionState> _getOrLoadCompanionStateOptimized({
    required String userId,
    required String companionId,
    required AICompanion companion,
    required MessageBloc messageBloc,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final key = _getCompanionStateKey(userId, companionId);

    // Quick memory check first**
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

  /// **ENHANCED: Initialize context from existing messages with fragmentation support**
  Future<void> _initializeContextFromMessages(
    CompanionState state,
    String? userName,
    Map<String, dynamic>? userProfile,
    MessageBloc messageBloc,
  ) async {
    try {
      _log.info('🔄 Initializing context from MessageBloc for ${state.companion.name}');

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
        // **CRITICAL FIX: Check if we already have an introduction in either state or messages**
        final hasIntroInState = state.history.any((content) => 
          content.parts.any((part) => 
            part is TextPart && 
            (part.text.contains('CHARACTER ASSIGNMENT') || 
             part.text.contains('EMBODIMENT INSTRUCTIONS'))
          )
        );
        
        final hasIntroInMessages = messages.any((msg) => 
          msg.isBot && msg.message.contains("CHARACTER ASSIGNMENT: You are now embodying ${state.companion.name}"));
        
        if (!hasIntroInState && !hasIntroInMessages) {
          // Add introduction only if not present anywhere
          final intro = _getOrCacheSystemPrompt(state.companion);
          state.addHistory(Content.text(intro));
          _log.info('✅ Added companion introduction to state history');
        }

        // **ENHANCED: Process messages with fragmentation awareness**
        final processedMessages = <String, Message>{};

        // Group messages by base ID to handle fragments vs complete messages
        for (final message in messages) {
          // **FRAGMENTATION FIX: Use proper base message ID extraction**
          final baseId = message.metadata['base_message_id']?.toString() ?? 
                        message.id?.replaceAll(RegExp(r'_fragment_\d+'), '') ?? 
                        message.id;
          
          if (baseId != null) {
            // **CRITICAL: Prefer complete messages over fragments, but handle both**
            final existing = processedMessages[baseId];
            if (existing == null) {
              processedMessages[baseId] = message;
            } else {
              // If we have a fragment and the new message is complete, prefer complete
              if (existing.isFragment && !message.isFragment) {
                processedMessages[baseId] = message;
              }
              // If both are fragments, prefer the one with more content
              else if (existing.isFragment && message.isFragment) {
                if (message.messageFragments.length > existing.messageFragments.length) {
                  processedMessages[baseId] = message;
                }
              }
            }
          }
        }
        
        // **ENHANCED: Sort by timestamp and convert to AI history**
        final sortedMessages = processedMessages.values.toList()
          ..sort((a, b) => a.created_at.compareTo(b.created_at));
        
        // **CRITICAL: Build conversation history with proper content handling**
        for (final message in sortedMessages) {
          // **FRAGMENTATION SUPPORT: Handle both fragmented and complete messages**
          String messageText;
          if (message.hasFragments && message.messageFragments.isNotEmpty) {
            messageText = message.messageFragments.join(' ').trim();
          } else if (message.messageFragments.isNotEmpty) {
            messageText = message.messageFragments.first.trim();
          } else {
            messageText = message.message.trim();
          }
          
          // Only add non-empty messages
          if (messageText.isNotEmpty) {
            if (message.isBot) {
              state.addHistory(Content.model([TextPart(messageText)]));
            } else {
              state.addHistory(Content.text(messageText));
            }
          }
        }
        
        // **ENHANCED: Update metadata with accurate counts**
        final botMessages = sortedMessages.where((m) => m.isBot).length;
        final userMessages = sortedMessages.where((m) => !m.isBot).length;
        
        state.updateMetadata('total_interactions', botMessages + userMessages);
        state.updateMetadata('bot_messages', botMessages);
        state.updateMetadata('user_messages', userMessages);
        state.updateMetadata('last_context_sync', DateTime.now().toIso8601String());
        
        _log.info('✅ Initialized state with ${sortedMessages.length} processed messages ($userMessages user, $botMessages bot)');
      } else {
        _log.info('ℹ️ No existing messages found - conversation will start fresh');
      }
      
    } catch (e, stackTrace) {
      _log.severe('❌ Error initializing state from MessageBloc: $e', e, stackTrace);
      // Don't rethrow - allow initialization to continue with empty history
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
      await _getOrLoadCompanionStateOptimized(
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

  /// **ENHANCED: Robust persistent session management with intelligent reuse**
  Future<ChatSession> _getOrCreatePersistentSession(CompanionState state, {bool isVoiceMode = false}) async {
    await _getOptimizedModel();
    
    final sessionKey = '${state.userId}_${state.companionId}';
    _log.info('🔍 Session management for key: $sessionKey');

    // **CRITICAL FIX: Check if this is after a reset or conversation clear**
    final lastReset = state.conversationMetadata['last_reset'];
    final lastClear = state.conversationMetadata['last_conversation_clear'];
    
    if ((lastReset != null || lastClear != null) && _sessionLastUsed.containsKey(sessionKey)) {
      final resetTime = lastReset != null ? DateTime.parse(lastReset) : null;
      final clearTime = lastClear != null ? DateTime.parse(lastClear) : null;
      final sessionTime = _sessionLastUsed[sessionKey]!;
      
      final shouldReset = (resetTime != null && resetTime.isAfter(sessionTime)) ||
                         (clearTime != null && clearTime.isAfter(sessionTime));
      
      if (shouldReset) {
        // Session is older than last reset/clear - force recreation
        _persistentSessions.remove(sessionKey);
        _sessionLastUsed.remove(sessionKey);
        _sessionMessageCount.remove(sessionKey);
        _log.info('🔄 Forced session recreation due to conversation reset/clear');
      }
    }
    
    // **ENHANCED: Intelligent session reuse with metadata validation**
    if (await canReuseExistingSession(userId: state.userId, companionId: state.companionId)) {
      _log.info('🎯 Attempting intelligent session reuse');
      
      // Try to reuse in-memory session
      if (_persistentSessions.containsKey(sessionKey)) {
        final lastUsed = _sessionLastUsed[sessionKey] ?? DateTime.now();
        final messageCount = _sessionMessageCount[sessionKey] ?? 0;
        
        final isRecent = DateTime.now().difference(lastUsed) < _sessionMaxAge;
        final isFresh = messageCount < _sessionMaxMessages;
        
        if (isRecent && isFresh) {
          _sessionLastUsed[sessionKey] = DateTime.now();
          _log.info('✅ Reusing existing in-memory session (age: ${DateTime.now().difference(lastUsed).inMinutes}min, messages: $messageCount)');
          return _persistentSessions[sessionKey]!;
        }
      }
      
      // **NEW: Smart session reconstruction with minimal context**
      _log.info('🔄 Reconstructing session with minimal context for efficiency');
      final minimalHistory = _buildMinimalSessionHistory(state);
      
      final session = _baseModel!.startChat(history: minimalHistory);
      _persistentSessions[sessionKey] = session;
      _sessionLastUsed[sessionKey] = DateTime.now();
      _sessionMessageCount[sessionKey] = minimalHistory.length;
      
      _log.info('⚡ Reconstructed session with ${minimalHistory.length} minimal context messages (${state.history.length} total available)');
      return session;
    }

    // **ENHANCED: Create new session with comprehensive history validation**
    _log.info('🆕 Creating new session for ${state.companion.name}');

    final sessionHistory = _buildOptimizedSessionHistory(state);
    
    // **CRITICAL: Validate history before creating session**
    if (sessionHistory.isEmpty) {
      _log.warning('⚠️ Empty session history - adding companion introduction');
      final intro = _getOrCacheSystemPrompt(state.companion, isVoiceMode: isVoiceMode);
      sessionHistory.add(Content.text(intro));
      // Also add to state so it persists
      if (state.history.isEmpty || !state.history.any((c) => 
          c.parts.any((p) => p is TextPart && p.text.contains('CHARACTER ASSIGNMENT')))) {
        state.addHistory(Content.text(intro));
        _debouncedSave(state); // Save updated state
      }
    }
    
    final session = _baseModel!.startChat(history: sessionHistory);
    _persistentSessions[sessionKey] = session;
    _sessionLastUsed[sessionKey] = DateTime.now();
    _sessionMessageCount[sessionKey] = sessionHistory.length;
    
    // **CRITICAL: Save session metadata immediately**
    unawaited(_saveSessionMetadata());
    
    _log.info('✅ Created new persistent session for ${state.companion.name} with ${sessionHistory.length} history messages');
    return session;
  }

  /// **NEW: Build minimal context for efficient session reconstruction**
  List<Content> _buildMinimalSessionHistory(CompanionState state) {
    final history = <Content>[];

    // **ESSENTIAL: Always include companion introduction**
    if (state.hasCompanion) {
      final intro = _getOrCacheSystemPrompt(state.companion);
      history.add(Content.text(intro));
    }

    // **OPTIMIZED: Use only last 3 exchanges (6 messages) for true minimal context**
    const maxContextMessages = 6; // Last 3 exchanges for optimal token efficiency
    
    if (state.history.length > 1) {
      // Check if history already contains introduction
      final hasIntroInHistory = state.history.any((c) => 
        c.parts.any((p) => p is TextPart && p.text.contains('CHARACTER ASSIGNMENT')));
      
      final actualHistory = hasIntroInHistory ? state.history.skip(1).toList() : state.history;
      
      if (actualHistory.length > maxContextMessages) {
        // Take only the most recent exchanges
        final recentHistory = actualHistory.skip(actualHistory.length - maxContextMessages).toList();
        history.addAll(recentHistory);
        _log.info('📝 Built minimal session history: ${history.length} messages (from ${state.history.length} total) - Using last $maxContextMessages messages for optimal token efficiency');
      } else {
        // Use all available history
        history.addAll(actualHistory);
        _log.info('📝 Built minimal session history: ${history.length} messages (using all ${actualHistory.length} conversation messages)');
      }
    }

    return history;
  }


  /// **ENHANCED: Response generation with comprehensive session validation and context preservation**
  Future<String> generateResponse(String userMessage, {bool isVoiceMode = false}) async {
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
      
      // **CRITICAL FIX: Ensure companion is properly loaded**
      if (!state.hasCompanion) {
        throw StateError('Companion not loaded in state - reinitialize required');
      }
      
      // **ENHANCED: Get or create session with robust validation**
      final chatSession = await _getOrCreatePersistentSession(state, isVoiceMode: isVoiceMode);
      
      // **CRITICAL: Validate session before use**
      final sessionKey = '${state.userId}_${state.companionId}';
      if (!_persistentSessions.containsKey(sessionKey)) {
        throw StateError('Session creation failed - key not found in persistent sessions');
      }

      // **ENHANCED: Send message to persistent session with context validation**
      final userContent = Content.text(userMessage);
      
      _log.info('🚀 Sending message to session for ${state.companion.name}');
      
      final response = await chatSession.sendMessage(userContent)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Response generation timed out');
      });

      stopwatch.stop();
      _log.info('✅ Response received in ${stopwatch.elapsedMilliseconds}ms');

      final aiText = response.text;
      if (aiText == null || aiText.trim().isEmpty) {
        if (response.promptFeedback?.blockReason != null) {
          throw Exception('Response blocked: ${response.promptFeedback!.blockReason}');
        }
        throw Exception('Empty response received from AI');
      }

      // **ENHANCED: Update state efficiently with comprehensive tracking**
      _updateStateEfficiently(state, userMessage, aiText, stopwatch.elapsedMilliseconds);
      
      // **CRITICAL: Update session tracking with validation**
      if (_sessionMessageCount.containsKey(sessionKey) && _sessionLastUsed.containsKey(sessionKey)) {
        _sessionMessageCount[sessionKey] = (_sessionMessageCount[sessionKey] ?? 0) + 2;
        _sessionLastUsed[sessionKey] = DateTime.now();
        
        // **ENHANCED: Validate session health**
        final currentCount = _sessionMessageCount[sessionKey]!;
        if (currentCount > _sessionMaxMessages) {
          _log.warning('⚠️ Session approaching message limit ($currentCount/$_sessionMaxMessages)');
        }
      } else {
        _log.warning('⚠️ Session tracking lost - reinitializing counters');
        _sessionMessageCount[sessionKey] = 2;
        _sessionLastUsed[sessionKey] = DateTime.now();
      }

      // **ENHANCED: Async save with validation**
      _debouncedSave(state);
      
      // **NEW: Periodic session metadata backup**
      if (_sessionMessageCount[sessionKey]! % 10 == 0) {
        unawaited(_saveSessionMetadata());
      }

      _log.info('🎯 Response generated successfully: "${aiText.length > 50 ? "${aiText.substring(0, 50)}..." : aiText}"');
      return aiText;
    } catch (e, stackTrace) {
      _log.severe('❌ Response generation failed: $e', e, stackTrace);
      rethrow;
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

  /// **ENHANCED: Resets conversation with comprehensive session cleanup**
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
      _log.info('🔄 Resetting conversation for: ${state.companion.name}');

      // **CRITICAL FIX 1: Clear the persistent session completely**
      final sessionKey = '${state.userId}_${state.companionId}';
      if (_persistentSessions.containsKey(sessionKey)) {
        _persistentSessions.remove(sessionKey);
        _sessionLastUsed.remove(sessionKey);
        _sessionMessageCount.remove(sessionKey);
        _log.info('✅ Cleared persistent session for reset');
      }

      // **ENHANCED: Clear any cached system prompts**
      if (state.hasCompanion) {
        _cachedSystemPrompts.remove(state.companion.id);
        _log.info('✅ Cleared cached system prompts');
      }

      // Cache core information before reset
      final userName = state.userMemory['userName'];
      final userProfile = state.userMemory['userProfile'];

      // **CRITICAL FIX 2: Complete state reset with conversation clear tracking**
      state.history.clear();
      state.userMemory.clear();
      state.userMemory['userName'] = userName;
      if (userProfile != null) {
        state.userMemory['userProfile'] = userProfile;
      }

      state.relationshipLevel = 1;
      state.dominantEmotion = 'neutral';
      state.conversationMetadata.clear();
      state.conversationMetadata['total_interactions'] = 0;
      state.conversationMetadata['reset_count'] = (state.conversationMetadata['reset_count'] ?? 0) + 1;
      state.conversationMetadata['last_reset'] = DateTime.now().toIso8601String();
      state.conversationMetadata['last_conversation_clear'] = DateTime.now().toIso8601String();

      // **ENHANCED: Re-add companion introduction properly with validation**
      if (state.hasCompanion) {
        final intro = _getOrCacheSystemPrompt(state.companion);
        state.addHistory(Content.text(intro));
        _log.info('✅ Added fresh companion introduction after reset');
      } else {
        _log.warning('⚠️ Companion not loaded during reset - introduction will be added later');
      }

      // **CRITICAL FIX 3: Force save the reset state immediately**
      await _saveCompanionState(key, state);
      _log.info('✅ Saved reset state to persistent storage');

      // **ENHANCED: Update session metadata to reflect reset**
      unawaited(_saveSessionMetadata());

      _log.info('🎯 Conversation reset completed successfully for ${state.hasCompanion ? state.companion.name : 'companion'}');
    } catch (e, stackTrace) {
      _log.severe('❌ Error during conversation reset: $e', e, stackTrace);
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

  /// **NEW: Force session recreation for debugging/recovery**
  Future<void> forceRecreateSession({required String userId, required String companionId}) async {
    final sessionKey = '${userId}_$companionId';
    
    _log.info('🔧 Force recreating session for key: $sessionKey');
    
    // Remove existing session completely
    _persistentSessions.remove(sessionKey);
    _sessionLastUsed.remove(sessionKey);
    _sessionMessageCount.remove(sessionKey);
    
    // Clear cached system prompt
    _cachedSystemPrompts.remove(companionId);
    
    // Save updated metadata
    unawaited(_saveSessionMetadata());
    
    _log.info('✅ Session forcefully recreated - next message will create fresh session');
  }

  /// **NEW: Validate and repair session integrity**
  Future<bool> validateSessionIntegrity({required String userId, required String companionId}) async {
    final sessionKey = '${userId}_$companionId';
    final stateKey = _getCompanionStateKey(userId, companionId);
    
    _log.info('🔍 Validating session integrity for: $sessionKey');
    
    // Check if we have a session
    final hasSession = _persistentSessions.containsKey(sessionKey);
    final hasState = _companionStates.containsKey(stateKey);
    final hasMetadata = _sessionLastUsed.containsKey(sessionKey);
    
    _log.info('Session exists: $hasSession, State exists: $hasState, Metadata exists: $hasMetadata');
    
    if (hasSession && hasState) {
      final state = _companionStates[stateKey]!;
      final sessionHistory = _sessionMessageCount[sessionKey] ?? 0;
      final stateHistory = state.history.length;
      
      _log.info('Session history: $sessionHistory, State history: $stateHistory');
      
      // Consider valid if within reasonable range
      if ((stateHistory - sessionHistory).abs() <= 10) {
        _log.info('✅ Session integrity validated');
        return true;
      }
    }
    
    _log.warning('❌ Session integrity failed - will recreate on next use');
    return false;
  }

  /// **NEW: Comprehensive session debugging method**
  void debugSessionState({required String userId, required String companionId}) {
    final sessionKey = '${userId}_$companionId';
    final stateKey = _getCompanionStateKey(userId, companionId);
    
    print('=== SESSION DEBUG FOR $sessionKey ===');
    print('Session exists: ${_persistentSessions.containsKey(sessionKey)}');
    print('State exists: ${_companionStates.containsKey(stateKey)}');
    print('Last used: ${_sessionLastUsed[sessionKey]}');
    print('Message count: ${_sessionMessageCount[sessionKey]}');
    
    if (_companionStates.containsKey(stateKey)) {
      final state = _companionStates[stateKey]!;
      print('State history length: ${state.history.length}');
      print('Has companion: ${state.hasCompanion}');
      print('Last reset: ${state.conversationMetadata['last_reset']}');
      print('Last clear: ${state.conversationMetadata['last_conversation_clear']}');
    }
    
    print('All session keys: ${_persistentSessions.keys.toList()}');
    print('=== END DEBUG ===');
  }

  /// **CRITICAL: Advanced session diagnostics with fragment analysis**
  Map<String, dynamic> getSessionDiagnostics() {
    final sessionKey = _activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!) 
        ? '${_companionStates[_activeCompanionKey!]!.userId}_${_companionStates[_activeCompanionKey!]!.companionId}'
        : null;
    
    return {
      'service_initialized': _isModelInitialized,
      'active_companion_key': _activeCompanionKey,
      'current_session_key': sessionKey,
      'total_sessions': _persistentSessions.length,
      'session_exists': sessionKey != null ? _persistentSessions.containsKey(sessionKey) : false,
      'session_last_used': sessionKey != null ? _sessionLastUsed[sessionKey]?.toIso8601String() : null,
      'session_message_count': sessionKey != null ? _sessionMessageCount[sessionKey] : null,
      'cached_states': _companionStates.length,
      'cached_prompts': _cachedSystemPrompts.length,
      'active_companion_has_history': _activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!) 
          ? _companionStates[_activeCompanionKey!]!.history.length : 0,
      'last_cleanup': _lastStateCleanup.toIso8601String(),
      'all_session_keys': _persistentSessions.keys.toList(),
      'metadata_entries': _sessionLastUsed.length,
      'session_age_hours': sessionKey != null && _sessionLastUsed.containsKey(sessionKey) 
          ? DateTime.now().difference(_sessionLastUsed[sessionKey]!).inHours : null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// **NEW: Optimize session reuse by pre-validating existing sessions**
  Future<bool> canReuseExistingSession({required String userId, required String companionId}) async {
    final sessionKey = '${userId}_$companionId';
    
    // Check if we have metadata for this session
    if (!_sessionLastUsed.containsKey(sessionKey)) {
      return false;
    }
    
    final lastUsed = _sessionLastUsed[sessionKey]!;
    final messageCount = _sessionMessageCount[sessionKey] ?? 0;
    
    // Validate age and message count
    final isRecent = DateTime.now().difference(lastUsed) < _sessionMaxAge;
    final isFresh = messageCount < _sessionMaxMessages;
    
    // Additional validation: check if we have corresponding state
    final stateKey = _getCompanionStateKey(userId, companionId);
    final hasState = _companionStates.containsKey(stateKey);
    
    final canReuse = isRecent && isFresh && hasState;
    
    _log.info('🔍 Session reuse check for $sessionKey: recent=$isRecent, fresh=$isFresh, hasState=$hasState → canReuse=$canReuse');
    
    return canReuse;
  }

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

  /// **NEW: Comprehensive optimization metrics for performance monitoring**
  Map<String, dynamic> getOptimizationMetrics() {
    final metrics = <String, dynamic>{};
    
    // Session efficiency metrics
    final sessionMetrics = <String, dynamic>{
      'total_sessions': _persistentSessions.length,
      'active_sessions': _persistentSessions.entries.where((e) => 
        DateTime.now().difference(_sessionLastUsed[e.key] ?? DateTime.now()) < Duration(hours: 1)
      ).length,
      'average_session_age_hours': _sessionLastUsed.values.isNotEmpty 
        ? _sessionLastUsed.values.map((t) => DateTime.now().difference(t).inHours).reduce((a, b) => a + b) / _sessionLastUsed.length
        : 0,
      'session_reuse_rate': _calculateSessionReuseRate(),
    };
    
    // Context optimization metrics
    final contextMetrics = <String, dynamic>{
      'average_context_size': _calculateAverageContextSize(),
      'cached_system_prompts': _cachedSystemPrompts.length,
      'memory_cache_efficiency': _companionStates.isNotEmpty ? (_stateAccessTimes.length / _companionStates.length) : 0,
    };
    
    // Performance metrics
    final performanceMetrics = <String, dynamic>{
      'pending_saves': _pendingSaves.length,
      'model_initialized': _isModelInitialized,
      'preferences_initialized': _prefsInitialized,
      'last_cleanup_hours_ago': DateTime.now().difference(_lastStateCleanup).inHours,
    };
    
    // Token optimization estimation
    final tokenMetrics = <String, dynamic>{
      'estimated_token_savings_percent': _estimateTokenSavings(),
      'optimal_context_usage': _isUsingOptimalContext(),
      'session_reconstruction_efficiency': _calculateReconstructionEfficiency(),
    };
    
    metrics['session_management'] = sessionMetrics;
    metrics['context_optimization'] = contextMetrics;
    metrics['performance'] = performanceMetrics;
    metrics['token_efficiency'] = tokenMetrics;
    metrics['optimization_score'] = _calculateOverallOptimizationScore(sessionMetrics, contextMetrics, tokenMetrics);
    
    return metrics;
  }

  /// Calculate session reuse efficiency
  double _calculateSessionReuseRate() {
    if (_sessionLastUsed.isEmpty) return 0.0;
    
    final recentSessions = _sessionLastUsed.values.where((t) => 
      DateTime.now().difference(t) < Duration(hours: 24)
    ).length;
    
    return recentSessions / _sessionLastUsed.length;
  }

  /// Calculate average context size for optimization monitoring
  double _calculateAverageContextSize() {
    if (_companionStates.isEmpty) return 0.0;
    
    final totalMessages = _companionStates.values
        .map((state) => state.history.length)
        .fold(0, (sum, length) => sum + length);
    
    return totalMessages / _companionStates.length;
  }

  /// Estimate token savings from current optimization
  double _estimateTokenSavings() {
    if (_companionStates.isEmpty) return 0.0;
    
    // Estimate based on minimal context usage vs full history
    final averageHistorySize = _calculateAverageContextSize();
    const optimalContextSize = 5.0; // System prompt + 4 messages
    
    if (averageHistorySize <= optimalContextSize) {
      return 95.0; // Excellent optimization
    } else {
      final efficiency = (1.0 - (optimalContextSize / averageHistorySize)) * 100;
      return efficiency.clamp(0.0, 95.0);
    }
  }

  /// Check if using optimal context size
  bool _isUsingOptimalContext() {
    const optimalContextSize = 5.0;
    return _calculateAverageContextSize() <= optimalContextSize;
  }

  /// Calculate session reconstruction efficiency
  double _calculateReconstructionEfficiency() {
    if (_persistentSessions.isEmpty) return 0.0;
    
    // Higher efficiency = more session reuse, less reconstruction
    final reuseRate = _calculateSessionReuseRate();
    return reuseRate * 100;
  }

  /// Calculate overall optimization score (0-100)
  double _calculateOverallOptimizationScore(
    Map<String, dynamic> sessionMetrics,
    Map<String, dynamic> contextMetrics,
    Map<String, dynamic> tokenMetrics,
  ) {
    final sessionScore = (sessionMetrics['session_reuse_rate'] as double) * 100;
    final contextScore = _isUsingOptimalContext() ? 100.0 : 50.0;
    final tokenScore = tokenMetrics['estimated_token_savings_percent'] as double;
    
    return (sessionScore + contextScore + tokenScore) / 3;
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

      // CRITICAL FIX: Update session metadata to remove this user's sessions
      await _updateSessionMetadataAfterUserClear(userId);

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
      
      // Clear cached system prompt
      _cachedSystemPrompts.remove(companionId);
      
      // CRITICAL FIX: Update session metadata to remove this companion's session
      await _updateSessionMetadataAfterCompanionClear(sessionKey);

      // Remove from storage
      await _prefs.remove('$_prefsKeyPrefix$key');
      
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