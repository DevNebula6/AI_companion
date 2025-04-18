import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/chat_repository.dart'; // Assuming ChatRepositoryFactory is here for getCompanion
import 'package:ai_companion/chat/gemini/companion_state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

/// Service for interacting with the Gemini API and managing companion state.
/// Implemented as a singleton.
class GeminiService {
  // --- Singleton Setup ---
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    _log.info('GeminiService singleton created.');
    // Initialize SharedPreferences lazily or here if needed immediately
    _initPrefs();
  }

  // --- Dependencies & Configuration ---
  final _log = Logger('GeminiService');
  late final SharedPreferences _prefs;
  bool _prefsInitialized = false;
  GenerativeModel? _model; // Lazy loaded model
  bool _isModelInitializing = false;
  bool _isModelInitialized = false;

  // --- Constants ---
  static const String _prefsKeyPrefix = 'gemini_companion_state_v2_'; // Updated prefix for new structure
  static const int _maxMemoryCacheSize = 10; // Max states to keep in memory LRU cache
  static const int _maxActiveHistoryLength = 50; // Max history items for active session
  // Default system instruction (can be overridden in model config if needed)
  static const String _defaultSystemInstruction = "You are a helpful AI companion.";
  // Storage version - increment this if CompanionState.toJson/fromJson changes significantly
  static const String storageVersion = '2.0';

  // --- State Management ---
  // LRU Cache for companion states (Key: userId_companionId)
  final LinkedHashMap<String, CompanionState> _companionStates = LinkedHashMap();
  String? _activeCompanionKey; // Key of the currently active companion

  // --- Initialization ---

  Future<void> _initPrefs() async {
    if (!_prefsInitialized) {
      try {
        _prefs = await SharedPreferences.getInstance();
        _prefsInitialized = true;
        _log.info('SharedPreferences initialized.');
      } catch (e, stackTrace) {
        _log.severe('Failed to initialize SharedPreferences: $e', e, stackTrace);
        // Handle failure - app might not function correctly without prefs
      }
    }
  }

  /// Lazily initializes and returns the GenerativeModel instance.
  Future<GenerativeModel> _getModel() async {
    // Return immediately if already initialized
    if (_model != null && _isModelInitialized) return _model!;

    // Prevent concurrent initialization
    if (_isModelInitializing) {
      _log.fine('Model initialization already in progress, waiting...');
      // Wait for initialization to complete
      while (_isModelInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Return the initialized model or throw if it failed
      if (_model != null && _isModelInitialized) return _model!;
      throw Exception('Model initialization failed after waiting.');
    }

    _isModelInitializing = true;
    _log.info('Initializing Gemini Model...');

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        _log.severe('GEMINI_API_KEY not found or empty in .env file.');
        throw Exception('API Key configuration error.');
      }

      // Define safety settings (adjust thresholds as needed)
      final safetySettings = [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.low),
      ];

      // Define generation config (optional)
      final generationConfig = GenerationConfig(
        temperature: 0.8, // Adjust creativity vs. coherence
        // topK: 40,
        // topP: 0.95,
        maxOutputTokens: 2048, // Limit response length
        // stopSequences: [...] // Optional stop sequences
      );

      // Initialize the model ONCE
      _model = GenerativeModel(
        // Consider making model name configurable
        model: 'gemini-2.0-flash', // Use appropriate model name
        apiKey: apiKey,
        safetySettings: safetySettings,
        generationConfig: generationConfig,
        // System instruction provides overall context for the MODEL, not specific chats
        systemInstruction: Content.system(_defaultSystemInstruction),
      );

      _log.info('Gemini Model initialized successfully.');
      _isModelInitialized = true;
      return _model!;
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize Gemini Model: $e', e, stackTrace);
      _isModelInitialized = false; // Ensure state reflects failure
      rethrow; // Propagate the error
    } finally {
      _isModelInitializing = false; // Allow future attempts if needed
    }
  }

  /// Public getter for external checks (e.g., UI elements)
  bool get isInitialized => _isModelInitialized;

  // --- State Key Helper ---
  String _getCompanionStateKey(String userId, String companionId) {
    return '${userId}_$companionId';
  }

  // --- Persistence (using CompanionState.toJson/fromJson) ---

  /// Saves the given CompanionState to SharedPreferences.
  Future<void> _saveCompanionState(String key, CompanionState state) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) {
      _log.severe('Cannot save state for key $key: SharedPreferences not available.');
      return;
    }

    try {
      final jsonString = jsonEncode(state.toJson());
      await _prefs.setString('$_prefsKeyPrefix$key', jsonString);
      _log.fine('Saved state for key: $key');
    } catch (e, stackTrace) {
      _log.warning('Failed to save state for key $key: $e', e, stackTrace);
      // Consider adding more robust error handling, e.g., retry logic or user notification
    }
  }

  /// Loads CompanionState from SharedPreferences. Returns null if not found or error occurs.
  Future<CompanionState?> _loadCompanionState(String key) async {
    if (!_prefsInitialized) await _initPrefs();
    if (!_prefsInitialized) {
      _log.severe('Cannot load state for key $key: SharedPreferences not available.');
      return null;
    }

    try {
      final jsonString = _prefs.getString('$_prefsKeyPrefix$key');
      if (jsonString != null) {
        final state = CompanionState.fromJson(jsonDecode(jsonString));
        // Basic version check
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
      // Optionally clear corrupted data
      // await _prefs.remove('$_prefsKeyPrefix$key');
    }
    return null;
  }

  // --- Core State Logic & LRU Cache Management ---

  /// Gets state from memory cache, loads from storage, or creates a new one.
  /// Manages the LRU cache eviction.
  Future<CompanionState> _getOrLoadCompanionState({
    required String userId,
    required String companionId,
    required AICompanion companion, // Pass the full companion object for context/creation
    String? userName, // Needed for creating initial context
    Map<String, dynamic>? userProfile, // Needed for creating initial context
  }) async {
    final key = _getCompanionStateKey(userId, companionId);

    // 1. Check memory cache (LRU update)
    if (_companionStates.containsKey(key)) {
      _log.fine('State cache hit for key: $key');
      // Move to end to mark as recently used
      final state = _companionStates.remove(key)!;
      _companionStates[key] = state;
      // Ensure transient fields are populated if needed (companion might be updated)
      state.companion = companion;
      // Recreate chat session if it's null (e.g., after loading from storage)
      if (state.chatSession == null) {
         await _recreateChatSession(state);
      }
      return state;
    }

    _log.fine('State cache miss for key: $key. Attempting to load from storage...');

    // 2. Try loading from SharedPreferences
    CompanionState? state = await _loadCompanionState(key);

    if (state != null) {
      _log.info('Loaded state from storage for key: $key');
      // Populate transient fields
      state.companion = companion;
      await _recreateChatSession(state); // Recreate ChatSession from loaded history
    } else {
      _log.info('No state found in storage. Creating new state for key: $key');
      // 3. Create new state if not found
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
        // chatSession will be created by _recreateChatSession
      );
      // Add initial context messages to history *before* creating session
      _addInitialContextToHistory(state, userName, userProfile);
      await _recreateChatSession(state); // Create the initial ChatSession

      // Save the newly created state immediately
      await _saveCompanionState(key, state);
    }

    // 4. Add to memory cache and manage size (LRU eviction)
    _companionStates[key] = state;
    await _evictLRUStateIfNecessary(); // Check and evict oldest if cache exceeds limit

    return state;
  }

  /// Recreates the ChatSession for a given state, using its history.
  Future<void> _recreateChatSession(CompanionState state) async {
     try {
       final model = await _getModel(); // Ensure model is initialized
       // Trim history *before* starting chat if it exceeds active limit
       _trimHistory(state.history, _maxActiveHistoryLength);
       state.chatSession = model.startChat(history: state.history.isNotEmpty ? state.history : null);
       _log.fine('Recreated chat session for key: ${_getCompanionStateKey(state.userId, state.companionId)} with ${state.history.length} history items.');
     } catch (e, stackTrace) {
       _log.severe('Failed to recreate chat session for key ${_getCompanionStateKey(state.userId, state.companionId)}: $e', e, stackTrace);
       state.chatSession = null; // Ensure session is null on failure
     }
  }

  /// Adds companion and user context as initial messages to the state's history.
  void _addInitialContextToHistory(CompanionState state, String? userName, Map<String, dynamic>? userProfile) {
     if (state.history.isEmpty) { // Only add if history is truly empty
        final companionContext = _buildCompanionContext(state.companion!, state.relationshipLevel, state.dominantEmotion);
        final userContext = _buildUserContext(userName, userProfile, state.relationshipLevel, state.userMemory);

        // Add context as 'user' role messages to guide the 'model'
        // The actual system prompt is set on the model itself.
        state.addHistory(Content('user', [TextPart("Companion Context:\n$companionContext")]));
        state.addHistory(Content('user', [TextPart("User Context:\n$userContext")]));
        _log.fine('Added initial context to history for key: ${_getCompanionStateKey(state.userId, state.companionId)}');
     }
  }


  /// Checks cache size and evicts the least recently used state if necessary.
  Future<void> _evictLRUStateIfNecessary() async {
    if (_companionStates.length > _maxMemoryCacheSize) {
      // Get the key of the least recently used item (first in LinkedHashMap)
      final oldestKey = _companionStates.keys.first;
      _log.info('Cache limit ($_maxMemoryCacheSize) reached. Evicting state for key: $oldestKey');
      final evictedState = _companionStates.remove(oldestKey);

      // Save the evicted state to persistent storage before removing from memory
      if (evictedState != null) {
        // Clear the transient chat session before saving to avoid issues
        evictedState.chatSession = null;
        await _saveCompanionState(oldestKey, evictedState);
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

    // Save state of the previously active companion *before* switching
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
         _log.warning('Chat session is null after loading state for $key. Attempting to recreate.');
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

  /// Generates a response from the currently active companion.
  Future<String> generateResponse(String userMessage) async {
    final stopwatch = Stopwatch()..start();
    if (_activeCompanionKey == null) {
      _log.severe('generateResponse called but no active companion key set.');
      throw Exception('GeminiService: No active companion.');
    }
    if (!_isModelInitialized || _model == null) {
       _log.severe('generateResponse called before model is initialized.');
       throw Exception('Gemini Model not initialized.');
    }

    // Get the active state from the LRU cache
    final state = _companionStates[_activeCompanionKey!];
    if (state == null) {
      // This indicates a potential logic error - state should be in cache if active
      _log.severe('Active companion state not found in cache for key: $_activeCompanionKey. This should not happen.');
      // Attempt recovery (optional, might be better to throw)
      // final recoveredState = await _loadCompanionState(_activeCompanionKey!);
      // if (recoveredState != null) { state = recoveredState; ... } else { throw ... }
      throw Exception('Internal state error: Active companion state missing.');
    }

    // Ensure chat session exists
    if (state.chatSession == null) {
       _log.warning('Chat session is null for active companion $state.companionId. Recreating...');
       await _recreateChatSession(state);
       if (state.chatSession == null) {
          throw Exception('Failed to create chat session for active companion.');
       }
    }

    _log.fine('Generating response for: "$userMessage" (Companion: ${state.companionId})');

    try {
      final userContent = Content.text(userMessage);
      // Add user message to the state's history
      state.addHistory(userContent);
      _trimHistory(state.history, _maxActiveHistoryLength); // Trim active history

      // Send message using the state's chat session
      final response = await state.chatSession!.sendMessage(userContent);
      stopwatch.stop();
      _log.info('Gemini response received in ${stopwatch.elapsedMilliseconds}ms.');

      final aiText = response.text; // Use extension method
      if (aiText == null) {
        _log.warning('Received null or empty response from Gemini. Feedback: ${response.promptFeedback}');
        // Consider checking response.promptFeedback?.blockReason
        throw Exception('Gemini returned an empty or blocked response.');
      }

      // Add AI response to the state's history
      state.addHistory(Content.model([TextPart(aiText)]));
      _trimHistory(state.history, _maxActiveHistoryLength); // Trim again after adding AI response

      // --- Update State (Memory, Relationship, Metadata) ---
      _extractMemoryItems(state, userMessage, aiText);
      _updateRelationshipMetrics(state, userMessage, aiText);
      state.updateMetadata('last_interaction', DateTime.now().toIso8601String());
      state.updateMetadata('total_interactions', (state.conversationMetadata['total_interactions'] ?? 0) + 1);
      // --- End Update State ---

      // Save state asynchronously after successful response (don't wait)
      _saveCompanionState(_activeCompanionKey!, state).ignore();

      return aiText;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _log.severe('Error generating response for key $_activeCompanionKey: $e', e, stackTrace);
      // Optionally remove the user message from history if generation failed
      // if (state.history.isNotEmpty && state.history.last.role == 'user') {
      //   state.history.removeLast();
      // }
      throw Exception('Failed to get response from AI: $e'); // Rethrow cleaned-up exception
    }
  }

  /// Trims the history list to the specified maximum length, removing older items.
  void _trimHistory(List<Content> history, int maxLength) {
    if (history.length > maxLength) {
      // Remove items from the beginning, preserving initial context if possible
      int removeCount = history.length - maxLength;
      int startIndex = 0;
      // Protect initial context messages if they exist (assuming first 2 are context)
      if (history.length > 2 && history[0].role == 'user' && history[1].role == 'user') {
         startIndex = 2;
         if (removeCount > history.length - 2) {
            removeCount = history.length - 2; // Don't remove context
         }
      }
       if (removeCount > 0) {
          history.removeRange(startIndex, startIndex + removeCount);
          _log.finest('Trimmed history to ${history.length} items.');
       }
    }
  }


  /// Saves the currently active companion's state to persistent storage.
  Future<void> saveState() async {
    if (_activeCompanionKey != null && _companionStates.containsKey(_activeCompanionKey!)) {
      _log.info('Explicitly saving state for active key: $_activeCompanionKey');
      final state = _companionStates[_activeCompanionKey!]!;
      // Clear transient session before saving
      state.chatSession = null;
      await _saveCompanionState(_activeCompanionKey!, state);
    } else {
      _log.warning('saveState called but no active or valid companion state found.');
    }
  }

  /// Clears state from memory and storage for a specific user-companion pair.
  Future<void> clearCompanionState(String userId, String companionId) async {
    final key = _getCompanionStateKey(userId, companionId);
    _log.info('Clearing state for key: $key');

    // Remove from memory cache
    _companionStates.remove(key);

    // If this was the active companion, clear the active key
    if (_activeCompanionKey == key) {
      _activeCompanionKey = null;
      _log.info('Cleared active companion key.');
    }

    // Remove from persistent storage
    if (!_prefsInitialized) await _initPrefs();
    if (_prefsInitialized) {
      try {
        await _prefs.remove('$_prefsKeyPrefix$key');
        _log.fine('Removed state from storage for key: $key');
      } catch (e, stackTrace) {
        _log.warning('Failed to remove state from storage for key $key: $e', e, stackTrace);
      }
    } else {
       _log.warning('Cannot remove state from storage for key $key: SharedPreferences not available.');
    }
  }

  /// Resets the conversation history and related metrics for the currently active companion.
  Future<void> resetConversation() async {
     if (_activeCompanionKey == null || !_companionStates.containsKey(_activeCompanionKey!)) {
       _log.warning('resetConversation called but no active companion state found.');
       return;
     }
     final key = _activeCompanionKey!;
     final state = _companionStates[key]!;
     _log.info('Resetting conversation state for key: $key');

     // Clear history
     state.history.clear();

     // Reset memory and metrics (optional, decide based on desired behavior)
     state.userMemory.clear();
     state.relationshipLevel = 1;
     state.dominantEmotion = 'neutral';
     state.conversationMetadata['total_interactions'] = 0;
     // Keep user_id, companion_id, created_at in metadata

     // Add initial context back to history
     final user = state.userMemory['userName']; // Assuming userName is stored
     final profile = state.userMemory['userProfile'];
     _addInitialContextToHistory(state, user, profile);

     // Recreate chat session with cleared & context-added history
     await _recreateChatSession(state);

     // Save the reset state
     await _saveCompanionState(key, state);

     _log.info('Conversation reset complete for key: $key');
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
    _log.fine('Updated memory item "$memoryKey" for key: $_activeCompanionKey');
    // Optionally trigger save here or rely on periodic/event-based saving
    _saveCompanionState(_activeCompanionKey!, state).ignore(); // Save updated memory async
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
     // Check if it's the active key AND present in the cache
     return _activeCompanionKey == key && _companionStates.containsKey(key);
   }

  // --- Internal Helper Methods ---

  /// Builds the companion context string for initial history messages.
  String _buildCompanionContext(AICompanion companion, int relationshipLevel, String? dominantEmotion) {
     // This builds the detailed character sheet based on the companion model
     // Similar to the previous implementation's _buildCompanionContext
     final personality = companion.personality;
     return '''
# Companion Character Sheet: ${companion.name}
## Core Identity
- Gender: ${companion.gender.toString().split('.').last}
- Personality Type: ${personality.primaryTraits.join(', ')}
## Physical Attributes
- Age: ${companion.physical.age}, Height: ${companion.physical.height}, Style: ${companion.physical.style}
## Personality Profile
- Primary Traits: ${personality.primaryTraits.join(', ')}
- Interests: ${personality.interests.join(', ')}
## Background & Skills
- Background: ${companion.background.join('. ')}
- Skills: ${companion.skills.join(', ')}
## Voice & Communication
- Style: ${companion.voice.join(', ')}
## Current Relationship Dynamics
- Relationship Level: $relationshipLevel (1-5)
- Emotional Tone: ${dominantEmotion ?? 'Neutral'}
''';
  }

   /// Builds the user context string for initial history messages.
   String _buildUserContext(String? userName, Map<String, dynamic>? userProfile, int relationshipLevel, Map<String, dynamic> userMemory) {
      return '''
# User Information
- Name: ${userName ?? 'User'}
${userProfile != null ? _formatUserProfile(userProfile) : ''}
- Current Relationship Level with Companion: $relationshipLevel (1-5)
${userMemory.isNotEmpty ? '- Known User Memory: ${jsonEncode(userMemory)}' : ''}
''';
   }

  /// Formats user profile map into a string.
  String _formatUserProfile(Map<String, dynamic> profile) {
    return profile.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
  }

  /// Extracts relevant information from messages to update companion state memory.
  void _extractMemoryItems(CompanionState state, String userMessage, String aiResponse) {
      // Simplified example: Look for preferences or important facts
      final lowerUserMsg = userMessage.toLowerCase();
      if (lowerUserMsg.contains('my favorite') || lowerUserMsg.contains('i like') || lowerUserMsg.contains('i love')) {
         state.updateMemory('preferences', [...(state.userMemory['preferences'] ?? []), userMessage]);
      }
      if (lowerUserMsg.contains('i live in') || lowerUserMsg.contains('i\'m from')) {
         state.updateMemory('location', userMessage);
      }
      // Add more sophisticated extraction logic here based on patterns or keywords
  }

  /// Updates relationship level and dominant emotion based on interaction.
  void _updateRelationshipMetrics(CompanionState state, String userMessage, String aiResponse) {
      // Simplified example: Increment level based on interaction count and message length
      final interactions = state.conversationMetadata['total_interactions'] ?? 0;
      if (interactions > state.relationshipLevel * 10 && userMessage.length > 30 && state.relationshipLevel < 5) {
         state.relationshipLevel++;
         _log.info('Relationship level increased to ${state.relationshipLevel} for key: ${_getCompanionStateKey(state.userId, state.companionId)}');
      }

      // Basic emotion update based on keywords (replace with more robust analysis if needed)
      final lowerResponse = aiResponse.toLowerCase();
      if (lowerResponse.contains('happy') || lowerResponse.contains('glad')) {
         state.dominantEmotion = 'happy';
      } else if (lowerResponse.contains('sorry') || lowerResponse.contains('sad')) {
         state.dominantEmotion = 'sad';
      } else if (lowerResponse.contains('curious') || lowerResponse.contains('wonder')) {
         state.dominantEmotion = 'curious';
      } else {
         // Decay towards neutral if no strong indicators
         if (state.dominantEmotion != 'neutral' && interactions % 5 == 0) {
             state.dominantEmotion = 'neutral';
         }
      }
  }


  // --- Performance & Debugging ---

  /// Provides a basic report on the current state of the service.
  Map<String, dynamic> getPerformanceReport() {
    return {
      'isModelInitialized': _isModelInitialized,
      'activeCompanionKey': _activeCompanionKey,
      'memoryCacheSize': _companionStates.length,
      'memoryCacheKeys': _companionStates.keys.toList(),
      // Add more metrics if needed
    };
  }

  // --- Cleanup ---
  /// Call this potentially on app shutdown or when service is no longer needed.
  Future<void> dispose() async {
    _log.info('Disposing GeminiService...');
    // Save the currently active state one last time
    await saveState();
    // Clear in-memory cache
    _companionStates.clear();
    _activeCompanionKey = null;
    _model = null; // Allow GC
    _isModelInitialized = false;
    _log.info('GeminiService disposed.');
  }
}

// Extension to easily get text from GenerateContentResponse
extension ResponseText on GenerateContentResponse {
  String? get text {
    try {
      return candidates.firstOrNull?.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join('');
     } catch (e) {
       print("Error extracting text from response: $e");
       return null;
     }
  }
}