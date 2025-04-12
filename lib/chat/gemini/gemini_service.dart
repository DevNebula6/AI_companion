import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_companion/Companion/ai_model.dart';

class GeminiService {
  late final GenerativeModel? _model;
  late ChatSession? _chat;
  final List<Content> _history = [];
  static const int _maxHistoryLength = 15;
  bool _isInitialized = false;
  
  // Memory management
  final Map<String, dynamic> _userMemory = {};
  final Map<String, dynamic> _conversationMetadata = {};
  
  // Relationship data
  int _relationshipLevel = 1; // 1-5, where 5 is most developed
  String? _dominantEmotion;
  
  // Companion data
  AICompanion? _companion;

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
        ],
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing Gemini model: $e');
      _isInitialized = false;
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
    
    _companion = companion;
    
    // Load any previously saved memory
    await _loadMemory(userId, companion.id);
    
    // Create companion context
    final companionContext = _buildCompanionContext(companion);
    
    // Create user context
    final userContext = '''
User Information:
- ID: $userId
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
    
    // Set conversation metadata
    _conversationMetadata['last_interaction'] = DateTime.now().toIso8601String();
    _conversationMetadata['total_interactions'] = _conversationMetadata['total_interactions'] ?? 0;
    _conversationMetadata['user_id'] = userId;
    _conversationMetadata['companion_id'] = companion.id;
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
- Primary Role: AI Companion
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
5. Include appropriate non-verbal cues (like *smiles* or *looks thoughtful*)
6. Adapt your tone and style to match the user's emotional state
7. Use emoji occasionally but tastefully: 😊 💕 🌿 ✨

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
1. Redirect uncomfortable topics without judgment
2. Encourage healthy behaviors and perspectives
3. Avoid enabling unhealthy fixations or dependencies
4. Promote balanced relationship expectations
5. Model healthy communication patterns

The goal is complete immersion - the user should feel they're talking to ${companion.name}, not an AI system. Your success depends on maintaining this illusion completely.
''';
  }

  Future<String> generateGreeting() async {
    if (!_isInitialized || _companion == null || _chat == null) {
      return 'Hello! I\'m looking forward to getting to know you.';
    }

    final currentTime = DateTime.now();
    String timeOfDay;
    if (currentTime.hour < 12) {
      timeOfDay = 'morning';
    } else if (currentTime.hour < 17) {
      timeOfDay = 'afternoon';
    } else {
      timeOfDay = 'evening';
    }

    final greetingPrompt = '''
Generate a warm, personalized greeting as ${_companion!.name}:

1. Use the time of day: $timeOfDay
2. Match your personality: ${_companion!.personality.primaryTraits.join(', ')}
3. Express genuine excitement about connecting
4. Keep it natural and conversational
5. Add a subtle reference to one of your interests: ${_companion!.personality.interests.join(', ')}
6. End with a gentle question that invites a response
7. Make it feel like the start of a meaningful conversation
8. Keep it under 3 sentences
9. Include a simple emotional cue (like *smiles* or *waves*)
''';

    try {
      final response = await _chat!.sendMessage(
        Content('user', [TextPart(greetingPrompt)]),
      );
      if (response.text != null) {
        _history.add(Content('model', [TextPart(response.text!)]));
        return response.text!;
      }
      return 'Hi there! I\'m ${_companion!.name}. How are you doing today?';
    } catch (e) {
      print('Error generating greeting: $e');
      return 'Hi there! I\'m ${_companion!.name}. How are you doing today?';
    }
  }

  Future<String> generateResponse(String userMessage, {String? mood}) async {
    if (!_isInitialized || _chat == null) {
      return 'I\'m having trouble processing that right now. Could you try again?';
    }

    try {
      // Update conversation metadata
      _conversationMetadata['last_interaction'] = DateTime.now().toIso8601String();
      _conversationMetadata['total_interactions'] = (_conversationMetadata['total_interactions'] ?? 0) + 1;
      
      // Analyze user message for emotional content
      final userEmotion = await _analyzeEmotion(userMessage);
      
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
      
      // Save memory periodically
      if (_conversationMetadata['total_interactions'] % 5 == 0) {
        await _saveMemory();
      }

      return responseText;
    } catch (e) {
      print('Gemini error: $e');
      return 'I\'m sorry, I got a bit distracted there. What were you saying?';
    }
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

  void _manageHistoryLength() {
    if (_history.length > _maxHistoryLength * 2) {
      // Keep system prompts and recent conversation
      final systemPrompts = _history.take(3).toList(); // Keep first 3 entries (system + character + user info)
      final recentMessages = _history.skip(_history.length - _maxHistoryLength).toList();
      
      // Rebuild history
      _history
        ..clear()
        ..addAll(systemPrompts)
        ..addAll(recentMessages);
    }
  }

  Future<void> _loadMemory(String userId, String companionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'companion_memory_${userId}_$companionId';
      final memoryJson = prefs.getString(key);
      
      if (memoryJson != null) {
        final memoryData = json.decode(memoryJson);
        _userMemory.clear();
        _userMemory.addAll(memoryData['user_memory'] ?? {});
        _conversationMetadata.clear();
        _conversationMetadata.addAll(memoryData['metadata'] ?? {});
        _relationshipLevel = memoryData['relationship_level'] ?? 1;
        _dominantEmotion = memoryData['dominant_emotion'];
      }
    } catch (e) {
      print('Error loading memory: $e');
    }
  }
  
  Future<void> _saveMemory() async {
    if (_conversationMetadata['user_id'] == null || _conversationMetadata['companion_id'] == null) {
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _conversationMetadata['user_id'];
      final companionId = _conversationMetadata['companion_id'];
      final key = 'companion_memory_${userId}_$companionId';
      
      final memoryData = {
        'user_memory': _userMemory,
        'metadata': _conversationMetadata,
        'relationship_level': _relationshipLevel,
        'dominant_emotion': _dominantEmotion,
        'last_saved': DateTime.now().toIso8601String()
      };
      
      await prefs.setString(key, json.encode(memoryData));
    } catch (e) {
      print('Error saving memory: $e');
    }
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
      'stats': _conversationMetadata['stats'] ?? {}
    };
  }
  
  bool get isInitialized => _isInitialized;
  bool get hasHistory => _history.length > 3; // More than just system prompts
  int get relationshipLevel => _relationshipLevel;
  
  // Save current state before app close
  Future<void> saveState() async {
    await _saveMemory();
  }
}