import 'package:flutter/foundation.dart';
import 'dart:async';
import '../message_bloc/message_bloc.dart';
import '../message_bloc/message_event.dart';
import '../message.dart';
import '../gemini/gemini_service.dart';
import '../../Companion/ai_model.dart';
import 'voice_message_model.dart';

/// Enhanced Voice Chat Integration implementing user's brilliant improvements:
/// 1. Separate voice events (no UI interference during conversation)
/// 2. Single session storage (one DB row per voice call)
/// 3. AI-generated summaries for efficient context
/// 4. Smart context strategy (summary preferred, fragments fallback)
class EnhancedVoiceChatIntegration {
  static final EnhancedVoiceChatIntegration _instance = EnhancedVoiceChatIntegration._internal();
  factory EnhancedVoiceChatIntegration() => _instance;
  EnhancedVoiceChatIntegration._internal();

  final GeminiService _geminiService = GeminiService();

  // Real-time session tracking (no DB storage during conversation)
  String? _activeSessionId;
  VoiceSession? _activeSession;
  List<String> _liveConversationFragments = [];
  DateTime? _sessionStartTime;

  /// Start voice session (real-time only, no database storage yet)
  Future<String> startVoiceSession({
    required String userId,
    required AICompanion companion,
    required String conversationId,
  }) async {
    try {
      // Create voice session in memory only
      _activeSession = VoiceSession.create(
        userId: userId,
        companionId: companion.id,
      );
      _activeSessionId = _activeSession!.id;
      _liveConversationFragments.clear();
      _sessionStartTime = DateTime.now();

      debugPrint('🎤 Voice session started: ${_activeSessionId} (real-time only)');
      return _activeSessionId!;
    } catch (e) {
      debugPrint('❌ Failed to start voice session: $e');
      rethrow;
    }
  }

  /// Add conversation fragment during active session (real-time, no DB)
  void addConversationFragment({
    required String fragment,
    required bool isUserFragment,
  }) {
    if (_activeSession == null) {
      debugPrint('⚠️ No active session for fragment: $fragment');
      return;
    }

    // Add to real-time tracking
    _liveConversationFragments.add(fragment);
    _activeSession = _activeSession!.addFragment(fragment);

    debugPrint('💬 Fragment added (real-time): $fragment');
    debugPrint('📊 Session progress: ${_liveConversationFragments.length} fragments');
  }

  /// End voice session and create SINGLE database message with summary
  Future<String?> endVoiceSession({
    required MessageBloc messageBloc,
    required AICompanion companion,
    bool generateSummary = true,
  }) async {
    if (_activeSession == null) {
      debugPrint('⚠️ No active session to end');
      return null;
    }

    try {
      debugPrint('🔄 Ending voice session with ${_liveConversationFragments.length} fragments');

      // Generate AI summary for efficient future context
      String? conversationSummary;
      if (generateSummary && _liveConversationFragments.isNotEmpty) {
        debugPrint('🤖 Generating AI summary for efficient context...');
        conversationSummary = await _generateAISummary(
          fragments: _liveConversationFragments,
          companion: companion,
        );
      }

      // Create single message for entire voice session
      final completedSession = _activeSession!.endSession();
      final messageData = completedSession.toMessageJson();

      // Add AI summary to metadata for efficient context usage
      if (conversationSummary != null) {
        messageData['metadata'] = {
          ...messageData['metadata'] ?? {},
          'conversation_summary': conversationSummary,
          'summary_generated_at': DateTime.now().toIso8601String(),
          'token_efficiency': _calculateTokenEfficiency(
            _liveConversationFragments, 
            conversationSummary,
          ),
        };
      }

      // Add session statistics
      messageData['metadata'] = {
        ...messageData['metadata'] ?? {},
        'session_stats': {
          'duration_seconds': completedSession.duration.inSeconds,
          'total_exchanges': _liveConversationFragments.length,
          'user_fragments': _countUserFragments(_liveConversationFragments),
          'ai_fragments': _countAIFragments(_liveConversationFragments),
          'session_type': 'voice_conversation',
        },
      };

      // Create message and store in database
      final message = Message.fromJson(messageData);
      messageBloc.add(SendMessageEvent(message: message));

      final messageId = message.id;
      
      // Clean up session
      _cleanup();

      debugPrint('💾 Voice session saved as single message with ${conversationSummary != null ? 'AI summary' : 'fragments only'}');
      debugPrint('🎯 Message ID: $messageId');
      
      return messageId;
    } catch (e) {
      debugPrint('❌ Failed to end voice session: $e');
      rethrow;
    }
  }

  /// Get voice context for AI (smart strategy: summary preferred, fragments fallback)
  Future<String> getVoiceContextForAI({
    required String userId,
    required String companionId,
    required MessageBloc messageBloc,
    int maxSessions = 3,
  }) async {
    try {
      // Get recent voice messages
      final recentVoiceMessages = messageBloc.currentMessages
          .where((msg) => 
              msg.isVoiceMessage && 
              msg.companionId == companionId &&
              msg.userId == userId)
          .take(maxSessions)
          .toList();

      if (recentVoiceMessages.isEmpty) {
        return 'No previous voice conversations';
      }

      final contextParts = <String>[];
      int efficientContextCount = 0;

      for (final message in recentVoiceMessages) {
        // SMART STRATEGY: Prefer summary for efficiency
        final summary = message.metadata['conversation_summary']?.toString();
        
        if (summary != null && summary.isNotEmpty) {
          // Use efficient AI-generated summary
          contextParts.add('Previous conversation summary: $summary');
          efficientContextCount++;
        } else {
          // Fallback to conversation fragments (limited for token efficiency)
          final fragments = message.voiceData?['conversationFragments'] as List<String>?;
          if (fragments != null && fragments.isNotEmpty) {
            final limitedFragments = fragments.take(6).join('\n'); // Limit for tokens
            contextParts.add('Previous conversation: $limitedFragments');
          }
        }
      }

      final context = contextParts.join('\n\n');
      
      debugPrint('🧠 Voice context built: $efficientContextCount/${recentVoiceMessages.length} using efficient summaries');
      debugPrint('📊 Context length: ${context.length} characters');
      
      return context;
    } catch (e) {
      debugPrint('❌ Failed to build voice context: $e');
      return 'Error loading conversation history';
    }
  }

  /// Generate AI summary for conversation fragments
  Future<String> _generateAISummary({
    required List<String> fragments,
    required AICompanion companion,
  }) async {
    if (fragments.isEmpty) return 'Empty conversation';

    final conversationText = fragments.join('\n');
    
    final summaryPrompt = '''
Create a concise summary of this voice conversation between a user and ${companion.name}.
This summary will be used for future conversation context, so include:

- Key topics discussed
- Important user preferences or information shared
- ${companion.name}'s personality traits that emerged
- Any decisions, plans, or commitments made
- Emotional tone and relationship dynamics

Keep the summary under 150 words but preserve all essential context for future conversations.

Voice Conversation:
$conversationText

Context Summary:''';

    try {
      final summary = await _geminiService.generateResponse(summaryPrompt);
      debugPrint('✅ AI summary generated: ${summary.length} characters');
      return summary;
    } catch (e) {
      debugPrint('❌ AI summary generation failed: $e');
      // Fallback to basic summary
      return _generateFallbackSummary(fragments, companion);
    }
  }

  /// Generate fallback summary if AI generation fails
  String _generateFallbackSummary(List<String> fragments, AICompanion companion) {
    final userFragments = _countUserFragments(fragments);
    final aiFragments = _countAIFragments(fragments);
    final duration = DateTime.now().difference(_sessionStartTime ?? DateTime.now());
    
    return 'Voice conversation with ${companion.name}: $userFragments user messages, $aiFragments AI responses. Duration: ${duration.inMinutes} minutes.';
  }

  /// Calculate token efficiency of summary vs fragments
  double _calculateTokenEfficiency(List<String> fragments, String summary) {
    final fragmentsLength = fragments.join(' ').length;
    final summaryLength = summary.length;
    
    if (fragmentsLength == 0) return 1.0;
    
    final efficiency = summaryLength / fragmentsLength;
    debugPrint('📈 Token efficiency: ${(efficiency * 100).toStringAsFixed(1)}% (${summaryLength}/${fragmentsLength} chars)');
    
    return efficiency;
  }

  /// Count user fragments
  int _countUserFragments(List<String> fragments) {
    return fragments.where((f) => f.startsWith('User:')).length;
  }

  /// Count AI fragments  
  int _countAIFragments(List<String> fragments) {
    return fragments.where((f) => !f.startsWith('User:')).length;
  }

  /// Clean up session data
  void _cleanup() {
    _activeSessionId = null;
    _activeSession = null;
    _liveConversationFragments.clear();
    _sessionStartTime = null;
  }

  /// Check if there's an active voice session
  bool get hasActiveSession => _activeSessionId != null;

  /// Get current session info
  Map<String, dynamic> getCurrentSessionInfo() {
    if (!hasActiveSession) return {};
    
    return {
      'sessionId': _activeSessionId,
      'fragmentsCount': _liveConversationFragments.length,
      'duration': _sessionStartTime != null 
          ? DateTime.now().difference(_sessionStartTime!).inSeconds 
          : 0,
      'isActive': true,
    };
  }

  /// Get live conversation fragments (for real-time display)
  List<String> get liveFragments => List.from(_liveConversationFragments);

  /// Check if a message is a voice session message
  static bool isVoiceSessionMessage(Message message) {
    return message.isVoiceMessage && 
           message.voiceData?['voice_session'] == true;
  }

  /// Extract conversation summary from voice message (for context)
  static String? getConversationSummary(Message voiceMessage) {
    if (!isVoiceSessionMessage(voiceMessage)) return null;
    return voiceMessage.metadata['conversation_summary']?.toString();
  }

  /// Get conversation fragments from voice message (fallback for context)
  static List<String>? getConversationFragments(Message voiceMessage) {
    if (!isVoiceSessionMessage(voiceMessage)) return null;
    return voiceMessage.voiceData?['conversationFragments'] as List<String>?;
  }

  /// Build efficient context from voice message (smart strategy)
  static String buildContextFromVoiceMessage(Message voiceMessage) {
    final summary = getConversationSummary(voiceMessage);
    
    if (summary != null && summary.isNotEmpty) {
      // Preferred: Use efficient summary
      return 'Previous conversation summary: $summary';
    } else {
      // Fallback: Use fragments (limited for token efficiency)
      final fragments = getConversationFragments(voiceMessage);
      if (fragments != null && fragments.isNotEmpty) {
        final limitedFragments = fragments.take(5).join('\n');
        return 'Previous conversation: $limitedFragments';
      }
    }
    
    return 'Previous voice conversation (details unavailable)';
  }
}

/// Voice session statistics for analytics
class VoiceSessionStats {
  final Duration totalDuration;
  final int totalFragments;
  final int userFragments;
  final int aiFragments;
  final bool hasSummary;
  final double? tokenEfficiency;

  const VoiceSessionStats({
    required this.totalDuration,
    required this.totalFragments,
    required this.userFragments,
    required this.aiFragments,
    required this.hasSummary,
    this.tokenEfficiency,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalDuration': totalDuration.inSeconds,
      'totalFragments': totalFragments,
      'userFragments': userFragments,
      'aiFragments': aiFragments,
      'hasSummary': hasSummary,
      'tokenEfficiency': tokenEfficiency,
    };
  }

  factory VoiceSessionStats.fromMessage(Message voiceMessage) {
    final stats = voiceMessage.metadata['session_stats'] as Map<String, dynamic>?;
    if (stats == null) {
      return VoiceSessionStats(
        totalDuration: Duration.zero,
        totalFragments: 0,
        userFragments: 0,
        aiFragments: 0,
        hasSummary: false,
      );
    }

    return VoiceSessionStats(
      totalDuration: Duration(seconds: stats['duration_seconds'] ?? 0),
      totalFragments: stats['total_exchanges'] ?? 0,
      userFragments: stats['user_fragments'] ?? 0,
      aiFragments: stats['ai_fragments'] ?? 0,
      hasSummary: voiceMessage.metadata['conversation_summary'] != null,
      tokenEfficiency: voiceMessage.metadata['token_efficiency']?.toDouble(),
    );
  }
}
