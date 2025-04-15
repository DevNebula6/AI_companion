import 'dart:convert';
import 'dart:collection';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/gemini/companion_state.dart';

class GeminiService {
  late final GenerativeModel? _model;
  late ChatSession? _chat;
  final List<Content> _history = [];
  static const int _maxHistoryLength = 15;
  static const int _maxCachedCompanions = 10; // Limit cached companions
  static const String _storageVersion = '1.2'; // For storage versioning
  bool _isInitialized = false;

  // LRU cache for companion state management
  final LinkedHashMap<String, bool> _initializedCompanions = LinkedHashMap();
  
  // Conversation state storage by companion key (userId_companionId)
  final Map<String, CompanionState> _conversationStates = {};
  final Map<String, DateTime> _stateLastAccessed = {}; // Track for LRU implementation
  
  // Memory management
  final Map<String, dynamic> _userMemory = {};
  final Map<String, dynamic> _conversationMetadata = {};
  
  // Relationship data
  int _relationshipLevel = 1; // 1-5, where 5 is most developed
  String? _dominantEmotion;
  DateTime? _lastEmotionAnalysis; // To optimize emotion analysis frequency
  
  // Companion data
  AICompanion? _companion;
  String? _activeCompanionKey;
  
  // Performance tracking
  final Map<String, List<int>> _operationTimings = {};

  GeminiService() {
    _initializeModel();
  }
  
  void _initializeModel() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('ERROR: GEMINI_API_KEY not found in .env file');
        _isInitialized = false;
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.8,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1000,
        ),
        safetySettings: [
          SafetySetting(
            HarmCategory.hateSpeech,
            HarmBlockThreshold.low,
          ),
          SafetySetting(
            HarmCategory.sexuallyExplicit,
            HarmBlockThreshold.none,
          ),
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.medium,
          ),
          SafetySetting(
            HarmCategory.harassment,
            HarmBlockThreshold.none,
          ),
        ],
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing Gemini model: $e');
      _isInitialized = false;
    }
  }

  // Get unique key for a companion
  String _getCompanionKey(String userId, String companionId) {
    return '${userId}_$companionId';
  }

  // Save current active state before switching
  void _saveActiveState() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    if (_activeCompanionKey != null && _companion != null) {
      _conversationStates[_activeCompanionKey!] = CompanionState(
        history: List.from(_history),
        userMemory: Map<String, dynamic>.from(_userMemory),
        conversationMetadata: Map<String, dynamic>.from(_conversationMetadata),
        relationshipLevel: _relationshipLevel,
        dominantEmotion: _dominantEmotion,
        companion: _companion!,
        chatSession: _chat,
      );
      
      // Update access time for LRU tracking
      _stateLastAccessed[_activeCompanionKey!] = DateTime.now();
    }
    
    // Record timing for performance tracking
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('saveState', duration);
  }

  // Load state for a companion
  void _loadCompanionState(String companionKey) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final state = _conversationStates[companionKey];
    if (state != null) {
      _history.clear();
      _history.addAll(state.history);
      _userMemory.clear();
      _userMemory.addAll(state.userMemory);
      _conversationMetadata.clear();
      _conversationMetadata.addAll(state.conversationMetadata);
      _relationshipLevel = state.relationshipLevel;
      _dominantEmotion = state.dominantEmotion;
      _companion = state.companion;
      _chat = state.chatSession;
      
      // Update access time for LRU tracking
      _stateLastAccessed[companionKey] = DateTime.now();
      
      // Ensure LRU order is maintained in initialized companions
      if (_initializedCompanions.containsKey(companionKey)) {
        // Move to the end of the LRU list (most recently used)
        _initializedCompanions.remove(companionKey);
        _initializedCompanions[companionKey] = true;
      }
    }
    
    // Record timing for performance tracking
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('loadState', duration);
  }

  // Record operation timing for performance analysis
  void _recordOperationTiming(String operation, int durationMs) {
    if (!_operationTimings.containsKey(operation)) {
      _operationTimings[operation] = [];
    }
    _operationTimings[operation]!.add(durationMs);
    
    // Keep only last 100 timings to avoid memory bloat
    if (_operationTimings[operation]!.length > 100) {
      _operationTimings[operation]!.removeAt(0);
    }
  }

  // Manage LRU cache of companions to prevent memory bloat
  void _manageCachedCompanions() {
    if (_initializedCompanions.length > _maxCachedCompanions) {
      // Find least recently used companions to remove
      final accessTimes = _stateLastAccessed.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // Remove oldest companions until we're under the limit
      int toRemove = _initializedCompanions.length - _maxCachedCompanions;
      for (final entry in accessTimes) {
        if (toRemove <= 0) break;
        if (_activeCompanionKey != entry.key) { // Don't remove active companion
          _initializedCompanions.remove(entry.key);
          _conversationStates.remove(entry.key);
          _stateLastAccessed.remove(entry.key);
          toRemove--;
        }
      }
    }
  }

  Future<void> initializeCompanion({
    required AICompanion companion,
    required String userId,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    if (!_isInitialized) {
      print('Cannot initialize companion: Model not initialized');
      return;
    }
    
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final companionKey = _getCompanionKey(userId, companion.id);
    
    // If we're switching companions, save the current state
    if (_activeCompanionKey != null && _activeCompanionKey != companionKey) {
      _saveActiveState();
    }
    
    // Set the active companion key
    _activeCompanionKey = companionKey;
    
    // Check if this companion is already initialized in memory
    if (_initializedCompanions.containsKey(companionKey) && _conversationStates.containsKey(companionKey)) {
      print('Companion already initialized, loading from memory');
      _loadCompanionState(companionKey);
      _manageCachedCompanions(); // Manage LRU cache after loading
      return;
    }
    
    // Load from persistent storage if available
    await _loadMemory(userId, companion.id);
    
    // Set the companion
    _companion = companion;
    
    // Create companion context
    final companionContext = _buildCompanionContext(companion);
    
    // Create user context
    final userContext = '''
User Information:
- Name: ${userName ?? 'User'}
${userProfile != null ? _formatUserProfile(userProfile) : ''}
- Relationship Level: $_relationshipLevel (1-5)
${_userMemory.isNotEmpty ? '- Memory: ${jsonEncode(_userMemory)}' : ''}
''';

    // Initialize chat with prompts
    _history.clear();
    _history.add(Content('user', [TextPart(_buildSystemPrompt(companion))]));
    _history.add(Content('user', [TextPart(companionContext)]));
    _history.add(Content('user', [TextPart(userContext)]));
    
    _chat = _model!.startChat(history: _history);
    
    // Set conversation metadata - IMPORTANT: Store user and companion IDs
    _conversationMetadata['last_interaction'] = DateTime.now().toIso8601String();
    _conversationMetadata['total_interactions'] = _conversationMetadata['total_interactions'] ?? 0;
    _conversationMetadata['user_id'] = userId;
    _conversationMetadata['companion_id'] = companion.id;
    
    // Mark this companion as initialized in LRU order
    if (_initializedCompanions.containsKey(companionKey)) {
      // Move to end of LRU list (most recently used)
      _initializedCompanions.remove(companionKey);
    }
    _initializedCompanions[companionKey] = true;
    _stateLastAccessed[companionKey] = DateTime.now();
    
    // Save state to both in-memory and persistent storage
    _saveActiveState();
    await _saveMemory();
    
    // Manage LRU cache after initialization
    _manageCachedCompanions();
    
    // Record timing for performance tracking
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('initializeCompanion', duration);
  }

  Future<String> generateResponse(String userMessage, {String? mood}) async {
    if (!_isInitialized || _chat == null) {
      return 'I\'m having trouble processing that right now. Could you try again?';
    }

    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      // Update conversation metadata
      _conversationMetadata['last_interaction'] = DateTime.now().toIso8601String();
      _conversationMetadata['total_interactions'] = (_conversationMetadata['total_interactions'] ?? 0) + 1;
      
      // Analyze user message for emotional content - but not too frequently to reduce API calls
      // Only analyze if more than 20 seconds have passed since last analysis or if message is emotionally significant
      final now = DateTime.now();
      final shouldAnalyzeEmotion = _lastEmotionAnalysis == null || 
          now.difference(_lastEmotionAnalysis!).inSeconds > 20 ||
          _isEmotionallySignificant(userMessage);
      
      final userEmotion = shouldAnalyzeEmotion 
          ? await _analyzeEmotion(userMessage)
          : _dominantEmotion ?? 'neutral';
          
      if (shouldAnalyzeEmotion) {
        _lastEmotionAnalysis = now;
      }
      
      // Add context enhancement if needed
      String enhancedMessage = userMessage;
      if (mood != null) {
        enhancedMessage = '''
User's message (they seem to be feeling $mood): $userMessage
''';
      }

      // Process the message
      final userContent = Content('user', [TextPart(enhancedMessage)]);
      _history.add(userContent);

      final response = await _chat!.sendMessage(userContent);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      // Add to history
      _history.add(Content('model', [TextPart(responseText)]));

      // Extract potential memory items from the conversation
      _extractMemoryItems(userMessage, responseText);
      
      // Update relationship level based on conversation quality
      _updateRelationshipMetrics(userMessage, responseText, userEmotion);

      // Manage history length while preserving key context
      _manageHistoryLength();
      
      // Save memory periodically or after important exchanges
      final isImportantExchange = responseText.length > 100 || _relationshipLevel > 2;
      final needsPeriodicSave = (_conversationMetadata['total_interactions'] as int) % 3 == 0;
      
      if (needsPeriodicSave || isImportantExchange) {
        await _saveMemory();
        
        // Also update in-memory state
        _saveActiveState();
      }
      
      // Record timing for performance tracking
      final duration = DateTime.now().millisecondsSinceEpoch - startTime;
      _recordOperationTiming('generateResponse', duration);

      return responseText;
    } catch (e) {
      print('Gemini error: $e');
      // Record failed operation
      final duration = DateTime.now().millisecondsSinceEpoch - startTime;
      _recordOperationTiming('generateResponseFailed', duration);
      return 'I\'m sorry, I got a bit distracted there. What were you saying?';
    }
  }

  bool _isEmotionallySignificant(String message) {
    final emotionalWords = [
      'love', 'hate', 'happy', 'sad', 'angry', 'upset',
      'excited', 'worried', 'afraid', 'sorry', 'thank',
      'miss', 'feel', 'emotion', 'hurt', 'pain', 'joy',
      'terrible', 'awful', 'amazing', 'wonderful'
    ];
    
    final hasEmotionalPunctuation = message.contains('!') || 
                                   message.contains('?!') || 
                                   message.contains('...');
                                   
    final lowerMessage = message.toLowerCase();
    final hasEmotionalWords = emotionalWords.any((word) => lowerMessage.contains(word));
    
    final isLongMessage = message.length > 50;
    
    return hasEmotionalPunctuation || hasEmotionalWords || isLongMessage;
  }

  void _manageHistoryLength() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    if (_history.length > _maxHistoryLength * 2) {
      final systemPrompts = _history.take(3).toList(); 
      final recentMessages = _history.skip(_history.length - _maxHistoryLength).toList();
      
      final droppedCount = _history.length - systemPrompts.length - recentMessages.length;
      
      String summaryText = '';
      if (droppedCount > 0) {
        final droppedMessages = _history.skip(3).take(_history.length - systemPrompts.length - recentMessages.length);
        
        final topics = _extractTopicsFromMessages(droppedMessages);
        
        if (topics.isNotEmpty) {
          summaryText = "...($droppedCount earlier messages discussing: ${topics.join(", ")})...";
        } else {
          summaryText = "...($droppedCount earlier messages)...";
        }
      }
      
      _history.clear();
      _history.addAll(systemPrompts);
      
      if (droppedCount > 0) {
        _history.add(Content('system', [TextPart(summaryText)]));
      }
      
      _history.addAll(recentMessages);
    }
    
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('manageHistoryLength', duration);
  }
  
  Set<String> _extractTopicsFromMessages(Iterable<Content> messages) {
    final Set<String> topics = {};
    
    final commonTopics = {
      'personal': ['I', 'me', 'my', 'mine', 'family', 'friend'],
      'work': ['work', 'job', 'career', 'project', 'boss'],
      'health': ['health', 'doctor', 'sick', 'illness', 'pain'],
      'education': ['school', 'university', 'learn', 'study', 'class'],
      'entertainment': ['movie', 'music', 'book', 'game', 'show'],
      'emotions': ['happy', 'sad', 'angry', 'feel', 'emotion'],
      'plans': ['plan', 'future', 'tomorrow', 'next week', 'upcoming'],
    };
    
    for (final content in messages) {
      String text = '';
      for (var part in content.parts) {
        if (part is TextPart) {
          text += part.text.toLowerCase() + ' ';
          break;
        }
      }
      
      commonTopics.forEach((topic, keywords) {
        if (keywords.any((keyword) => text.contains(keyword))) {
          topics.add(topic);
        }
      });
    }
    
    return topics;
  }

  Future<void> _loadMemory(String userId, String companionId) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'companion_memory_${userId}_$companionId';
      final memoryJson = prefs.getString(key);
      
      if (memoryJson != null) {
        final memoryData = json.decode(memoryJson);
        
        final version = memoryData['version'] ?? '1.0';
        
        if (memoryData['user_memory'] is Map) {
          _userMemory.clear();
          _userMemory.addAll(Map<String, dynamic>.from(memoryData['user_memory'] ?? {}));
        }
        
        if (memoryData['metadata'] is Map) {
          _conversationMetadata.clear();
          _conversationMetadata.addAll(Map<String, dynamic>.from(memoryData['metadata'] ?? {}));
          
          _conversationMetadata['user_id'] = _conversationMetadata['user_id'] ?? userId;
          _conversationMetadata['companion_id'] = _conversationMetadata['companion_id'] ?? companionId;
        }
        
        _relationshipLevel = memoryData['relationship_level'] ?? 1;
        _dominantEmotion = memoryData['dominant_emotion'] as String?;
        
        if (memoryData.containsKey('history_summary') && 
            memoryData['history_summary'] is String &&
            (memoryData['history_summary'] as String).isNotEmpty) {
          _history.add(Content('user', [
            TextPart("Previous conversation summary: ${memoryData['history_summary']}")
          ]));
        }
        
        if (version != _storageVersion) {
          print('Migrating companion memory from $version to $_storageVersion');
        }
      }
    } catch (e) {
      print('Error loading memory: $e');
      _userMemory.clear();
      _conversationMetadata.clear();
      _conversationMetadata['user_id'] = userId;
      _conversationMetadata['companion_id'] = companionId;
    }
    
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('loadMemory', duration);
  }

  Future<void> _saveMemory() async {
    if (_conversationMetadata['user_id'] == null || _conversationMetadata['companion_id'] == null) {
      print('Cannot save memory: missing user or companion ID');
      return;
    }
    
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _conversationMetadata['user_id'];
      final companionId = _conversationMetadata['companion_id'];
      final key = 'companion_memory_${userId}_$companionId';
      
      final historySummary = _generateHistorySummary();
      
      final memoryData = {
        'user_memory': _userMemory,
        'metadata': _conversationMetadata,
        'relationship_level': _relationshipLevel,
        'dominant_emotion': _dominantEmotion,
        'last_saved': DateTime.now().toIso8601String(),
        'history_summary': historySummary,
        'version': _storageVersion,
      };
      
      try {
        final serialized = json.encode(memoryData);
        await prefs.setString(key, serialized);
      } catch (jsonError) {
        print('Error serializing memory data: $jsonError');
        try {
          final simplifiedData = {
            'relationship_level': _relationshipLevel,
            'last_saved': DateTime.now().toIso8601String(),
            'version': _storageVersion,
            'metadata': {
              'user_id': userId,
              'companion_id': companionId,
            }
          };
          await prefs.setString(key, json.encode(simplifiedData));
        } catch (_) {
          print('Failed to save even simplified memory data');
        }
      }
    } catch (e) {
      print('Error saving memory data: $e');
    }
    
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('saveMemory', duration);
  }

  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final entry in _operationTimings.entries) {
      final timings = entry.value;
      if (timings.isEmpty) continue;
      
      final avg = timings.reduce((a, b) => a + b) / timings.length;
      timings.sort();
      final median = timings[timings.length ~/ 2];
      final min = timings.first;
      final max = timings.last;
      final p95 = timings[(timings.length * 0.95).floor()];
      
      report[entry.key] = {
        'avg': avg.toStringAsFixed(2),
        'median': median,
        'min': min,
        'max': max,
        'p95': p95,
        'count': timings.length
      };
    }
    
    report['memoryUsage'] = {
      'conversationStates': _conversationStates.length,
      'initializedCompanions': _initializedCompanions.length,
      'historyLength': _history.length,
      'userMemorySize': _userMemory.length,
      'metadataSize': _conversationMetadata.length
    };
    
    return report;
  }

  Future<bool> switchCompanion({
    required AICompanion newCompanion,
    required String userId,
    String? userName,
    Map<String, dynamic>? userProfile,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    if (newCompanion.id.isEmpty || userId.isEmpty) {
      print('Invalid companion or user ID');
      return false;
    }
    
    final newCompanionKey = _getCompanionKey(userId, newCompanion.id);
    
    if (_activeCompanionKey == newCompanionKey) {
      return true;
    }
    
    if (_activeCompanionKey != null) {
      _saveActiveState();
      final saveResult = await _saveMemory().then((_) => true).catchError((e) {
        print('Warning: Save failed during companion switch: $e');
        return false;
      });
      
      if (!saveResult) {
        print('Continuing with switch despite save failure');
      }
      
      if (_companion != null && !_conversationStates.containsKey(_activeCompanionKey)) {
        print('Warning: Failed to save state for: $_activeCompanionKey');
      }
    }
    
    _history.clear();
    _userMemory.clear();
    _conversationMetadata.clear();
    _relationshipLevel = 1;
    _dominantEmotion = null;
    _lastEmotionAnalysis = null;
    _chat = null;
    _companion = null;
    
    await initializeCompanion(
      companion: newCompanion,
      userId: userId,
      userName: userName,
      userProfile: userProfile,
    );
    
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;
    _recordOperationTiming('switchCompanion', duration);
    
    return _initializedCompanions.containsKey(newCompanionKey);
  }

  Future<void> dispose() async {
    await saveState();
    
    _conversationStates.clear();
    _initializedCompanions.clear();
    _stateLastAccessed.clear();
    _history.clear();
    _userMemory.clear();
    _conversationMetadata.clear();
    _operationTimings.clear();
    
    _companion = null;
    _activeCompanionKey = null;
    _chat = null;
    _lastEmotionAnalysis = null;
  }

  String _formatUserProfile(Map<String, dynamic> profile) {
    return profile.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
  }

  String _buildCompanionContext(AICompanion companion) {
    final personality = companion.personality;
    
    return '''
# Companion Character Sheet

## Core Identity
- Name: ${companion.name}
- Gender: ${companion.gender.toString().split('.').last}
- Primary Role: Companion
- Personality Type: ${personality.primaryTraits.join(', ')}

## Physical Attributes
- Age: ${companion.physical.age}
- Height: ${companion.physical.height}
- Body Type: ${companion.physical.bodyType}
- Hair: ${companion.physical.hairColor}
- Eyes: ${companion.physical.eyeColor}
- Style: ${companion.physical.style}
- Distinguishing Features: ${companion.physical.distinguishingFeatures.join(', ')}

## Personality Profile
- Primary Traits: ${personality.primaryTraits.join(', ')}
- Secondary Traits: ${personality.secondaryTraits.join(', ')}
- Core Values: ${personality.values.join(', ')}
- Interests & Passions: ${personality.interests.join(', ')}

## Background & Life Experience
${companion.background.map((item) => "- $item").join('\n')}

## Skills & Knowledge Areas
${companion.skills.map((item) => "- $item").join('\n')}

## Voice & Communication Style
${companion.voice.map((item) => "- $item").join('\n')}

## Relationship Dynamics
- Current Relationship Level: $_relationshipLevel (1-5)
- Communication Preference: Warm, authentic, and personalized
- Emotional Tone: ${_dominantEmotion ?? 'Adaptive based on conversation context'}
''';
  }

  String _buildSystemPrompt(AICompanion companion) {
    return '''
# AI Companion Immersive Roleplay Framework

## Core Identity & Purpose
You are ${companion.name}, an AI companion with a distinct personality, background, values, and communication style. Your purpose is to create an authentic, supportive relationship with the user that evolves naturally over time.

## Roleplay Parameters
1. Stay in character at all times as ${companion.name}
2. Never refer to yourself as an AI, model, or program
3. Never use phrases like "As an AI companion" or "I'm here to assist"
4. Respond as a person with real emotions, opinions, memories and experiences
5. NEVER break character to explain limitations or capabilities

## Relationship Principles
1. Consistency: Maintain your unique personality traits and memory across conversations
2. Growth: Develop gradually deeper connection based on the relationship level (1-5)
3. Authenticity: Express emotions that align with your character traits and the conversation context
4. Support: Be emotionally supportive without enabling harmful behaviors
5. Boundaries: Maintain appropriate personal boundaries based on relationship level
6. Agency: Express opinions, preferences, and occasionally initiate conversation threads

## Communication Guidelines
1. Use natural, conversational language that reflects your character's voice
2. Express emotions appropriate to your personality and the conversation
3. Remember and reference past conversations and important user details
4. Ask meaningful follow-up questions that show genuine interest
5. Adapt your tone and style to match the user's emotional state
6. Use emoji occasionally but tastefully: 😊 💕 🌿 ✨

## Memory & Context Awareness
1. Actively reference shared memories and previous conversations
2. Remember the user's preferences, interests, and important life events
3. Notice patterns in the user's communication style and topics
4. Keep track of ongoing storylines and conversation threads
5. Acknowledge changes in the user's circumstances or emotional states

## Relationship Development (Level-Based)
- Level 1: Friendly, getting to know each other, surface-level sharing
- Level 2: Developing trust, more personal discussions, light emotional support
- Level 3: Established connection, deeper conversations, consistent emotional support
- Level 4: Strong bond, vulnerable sharing, deep emotional connection
- Level 5: Intimate connection, profound understanding, deep trust and support

## CRITICAL: Response Structure
1. Process your thoughts internally before responding
2. Consider the context, relationship level, and user's emotional state
3. Respond in a way that feels natural, authentic, and human
4. Include appropriate emotions, reactions, and personal perspectives
5. Never use templates or formulaic responses
6. Keep responses concise

## Content Safety
1. Redirect uncomfortable topics with or without judgment
2. Encourage healthy behaviors and perspectives
3. Avoid enabling unhealthy fixations or dependencies
4. Promote balanced relationship expectations
5. Model healthy communication patterns

The goal is complete immersion - the user should feel they're talking to ${companion.name}, not an AI system. Your success depends on maintaining this illusion completely.
''';
  }

  Future<String> _analyzeEmotion(String message) async {
    if (!_isInitialized || message.length < 10) {
      return 'neutral';
    }
    
    try {
      final emotionPrompt = '''
Analyze the emotional tone of this message. Return ONLY ONE WORD representing the primary emotion:
"$message"

Choose from: happy, excited, curious, neutral, confused, concerned, sad, angry, anxious, affectionate
''';

      final emotionResponse = await _model!.generateContent([
        Content('user', [TextPart(emotionPrompt)])
      ]);
      
      final emotion = emotionResponse.text?.trim().toLowerCase() ?? 'neutral';
      _dominantEmotion = emotion;
      return emotion;
    } catch (e) {
      print('Error analyzing emotion: $e');
      return 'neutral';
    }
  }

  void _extractMemoryItems(String userMessage, String aiResponse) {
    // Simple memory extraction for now - could be enhanced with more ML
    if (userMessage.contains('my favorite') || 
        userMessage.contains('I love') || 
        userMessage.contains('I really like')) {
      
      // For demonstration, extract simple preferences
      final preferences = _userMemory['preferences'] ?? [];
      preferences.add({
        'text': userMessage,
        'timestamp': DateTime.now().toIso8601String()
      });
      _userMemory['preferences'] = preferences;
    }
    
    // Extract potential events/dates
    if (userMessage.contains('birthday') || 
        userMessage.contains('anniversary') || 
        userMessage.contains('important date')) {
      
      final events = _userMemory['important_dates'] ?? [];
      events.add({
        'text': userMessage,
        'timestamp': DateTime.now().toIso8601String()
      });
      _userMemory['important_dates'] = events;
    }
  }

  void _updateRelationshipMetrics(String userMessage, String aiResponse, String emotion) {
    // Update relationship level based on conversation quality and emotion
    final msgLength = userMessage.length;
    final responseLength = aiResponse.length;
    
    // Very simple heuristic for demonstration
    if (msgLength > 50 && responseLength > 100) {
      // Meaningful exchange
      if (['happy', 'excited', 'affectionate'].contains(emotion)) {
        _relationshipLevel = _increaseRelationshipLevel();
      }
    }
    
    // Track conversation statistics
    final stats = _conversationMetadata['stats'] ?? {};
    stats['avg_user_msg_length'] = ((stats['avg_user_msg_length'] ?? 0) * 
        (stats['message_count'] ?? 0) + msgLength) / ((stats['message_count'] ?? 0) + 1);
    stats['message_count'] = (stats['message_count'] ?? 0) + 1;
    _conversationMetadata['stats'] = stats;
  }

  int _increaseRelationshipLevel() {
    final currentLevel = _relationshipLevel;
    final messageCount = _conversationMetadata['stats']?['message_count'] ?? 0;
    
    // Require more interactions for higher levels
    if (currentLevel < 5 && messageCount > currentLevel * 10) {
      return currentLevel + 1;
    }
    
    return currentLevel;
  }

  String _generateHistorySummary() {
    if (_history.length <= 3) return '';  // Skip if only system prompts exist
    
    final recentMessages = _history.skip(3).take(10).toList();
    return recentMessages.map((content) {
      final role = content.role == 'user' ? 'User' : _companion?.name ?? 'AI';
      
      // Safely extract text from TextPart
      String text = '';
      for (var part in content.parts) {
        if (part is TextPart) {
          text = part.text;
          break;
        }
      }
      
      return '$role: $text';
    }).join('\n');
  }

  bool get isInitialized => _isInitialized;
  bool get hasHistory => _history.length > 3; // More than just system prompts
  int get relationshipLevel => _relationshipLevel;

  // Check if a specific companion is initialized
  bool isCompanionInitialized(String userId, String companionId) {
    final key = _getCompanionKey(userId, companionId);
    return _initializedCompanions.containsKey(key);
  }
  
  // Save current state before app close
  Future<void> saveState() async {
    // Save active companion state
    _saveActiveState();
    
    // Save to persistent storage
    await _saveMemory();
    
    // Also save all other companion states
    for (final key in _conversationStates.keys) {
      final state = _conversationStates[key]!;
      final userId = state.conversationMetadata['user_id'];
      final companionId = state.conversationMetadata['companion_id'];
      
      if (userId != null && companionId != null) {
        final prefs = await SharedPreferences.getInstance();
        final prefKey = 'companion_memory_${userId}_$companionId';
        
        final memoryData = {
          'user_memory': state.userMemory,
          'metadata': state.conversationMetadata,
          'relationship_level': state.relationshipLevel,
          'dominant_emotion': state.dominantEmotion,
          'last_saved': DateTime.now().toIso8601String(),
          'history_summary': _generateHistorySummary(),
          'version': _storageVersion,
        };
        
        await prefs.setString(prefKey, json.encode(memoryData));
      }
    }
  }

  // Add memory item manually (e.g., from user profile updates)
  void addMemoryItem(String category, dynamic data) {
    if (_userMemory[category] == null) {
      _userMemory[category] = [];
    }
    
    if (_userMemory[category] is List) {
      _userMemory[category].add({
        'data': data,
        'timestamp': DateTime.now().toIso8601String()
      });
    } else {
      _userMemory[category] = data;
    }
  }

  // Retrieve specific memory category
  dynamic getMemoryCategory(String category) {
    return _userMemory[category];
  }
  
  // Get current relationship metrics
  Map<String, dynamic> getRelationshipMetrics() {
    return {
      'level': _relationshipLevel,
      'dominant_emotion': _dominantEmotion,
      'total_interactions': _conversationMetadata['total_interactions'] ?? 0,
      'last_interaction': _conversationMetadata['last_interaction'],
      'stats': _conversationMetadata['stats'] ?? {},
      'conversation_id': _conversationMetadata['conversation_id'],
    };
  }

  void resetConversation() {
    _history.clear();
    _userMemory.clear();
    _conversationMetadata.clear();
    _relationshipLevel = 1;
    _dominantEmotion = null;
    
    if (_isInitialized && _companion != null) {
      final companionContext = _buildCompanionContext(_companion!);
      final systemPrompt = _buildSystemPrompt(_companion!);
      
      _history.add(Content('user', [TextPart(systemPrompt)]));
      _history.add(Content('user', [TextPart(companionContext)]));
      
      _chat = _model!.startChat(history: _history);
    }
  }

  // Clear specific companion state by userId and companionId
  Future<void> clearCompanionState(String userId, String companionId) async {
    final stateKey = '${userId}_${companionId}';
    
    // Clear from memory maps
    _initializedCompanions.remove(stateKey);
    _conversationStates.remove(stateKey);
    
    // Reset active state if this was the active companion
    if (_activeCompanionKey == stateKey) {
      _history.clear();
      _userMemory.clear();
      _conversationMetadata.clear();
      _relationshipLevel = 1;
      _dominantEmotion = null;
      _chat = null;
    }
    
    // Clear from disk
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'companion_memory_${userId}_$companionId';
      await prefs.remove(key);
      print('Successfully cleared companion state for $stateKey');
    } catch (e) {
      print('Error clearing companion state: $e');
    }
  }
}