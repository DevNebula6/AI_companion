import 'dart:async';
import 'package:ai_companion/chat/voice/voice_bloc/voice_event.dart';
import 'package:ai_companion/chat/voice/voice_bloc/voice_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../voice_message_model.dart';
import '../../message_bloc/message_bloc.dart';
import '../../message_bloc/message_event.dart';
import '../../message.dart';
import '../../gemini/gemini_service.dart';
import '../../../Companion/ai_model.dart';

/// Voice BLoC for managing real-time voice chat functionality
/// Separated from MessageBloc to prevent UI interference and enable
/// single-session storage with AI-generated summaries
class VoiceBloc extends Bloc<VoiceEvent,VoiceState> {
  final MessageBloc _messageBloc;
  final GeminiService _geminiService;

  // Active session management
  String? _activeSessionId;
  VoiceSession? _activeSession;
  List<String> _realtimeFragments = [];
  
  // Session analytics
  final Map<String, DateTime> _fragmentTimestamps = {};
  final Map<String, double> _responseTimings = {};

  VoiceBloc({
    required MessageBloc messageBloc,
    required GeminiService geminiService,
  })  : _messageBloc = messageBloc,
        _geminiService = geminiService,
        super(VoiceInitial()) {
    
    on<InitializeVoiceSystemEvent>(_onInitializeVoiceSystem);
    on<StartVoiceSessionEvent>(_onStartVoiceSession);
    on<AddVoiceFragmentEvent>(_onAddVoiceFragment);
    on<UpdateTranscriptionEvent>(_onUpdateTranscription);
    on<EndVoiceSessionEvent>(_onEndVoiceSession);
    on<GenerateVoiceSessionSummaryEvent>(_onGenerateVoiceSessionSummary);
    on<VoiceErrorEvent>(_onVoiceError);
    on<RequestVoiceContextEvent>(_onRequestVoiceContext);
    on<UpdateVoiceSessionStatusEvent>(_onUpdateVoiceSessionStatus);
    on<VoiceSessionLifecycleEvent>(_onVoiceSessionLifecycle);
  }

  /// Initialize voice system
  Future<void> _onInitializeVoiceSystem(
    InitializeVoiceSystemEvent event,
    Emitter<VoiceState> emit,
  ) async {
    emit(VoiceInitializing(
      userId: event.userId,
      companion: event.companion,
    ));

    try {
      // Check permissions and capabilities
      final hasMicPermission = await _checkMicrophonePermission();
      final hasTTS = await _checkTTSAvailability();

      emit(VoiceReady(
        userId: event.userId,
        companion: event.companion,
        hasMicrophonePermission: hasMicPermission,
        hasTTSAvailable: hasTTS,
      ));

      debugPrint('✅ Voice system initialized for ${event.companion.name}');
    } catch (e) {
      emit(VoiceSessionError(
        sessionId: 'init_error',
        error: 'Failed to initialize voice system: $e',
        errorType: VoiceErrorType.microphonePermission,
        canRetry: true,
      ));
    }
  }

  /// Start voice session (no DB storage until session ends)
  Future<void> _onStartVoiceSession(
    StartVoiceSessionEvent event,
    Emitter<VoiceState> emit,
  ) async {
    try {
      // Create new voice session
      _activeSession = VoiceSession.create(
        userId: event.userId,
        companionId: event.companion.id,
      );
      _activeSessionId = _activeSession!.id;
      _realtimeFragments.clear();
      _fragmentTimestamps.clear();
      _responseTimings.clear();

      emit(VoiceSessionActive(
        sessionId: _activeSessionId!,
        companion: event.companion,
        session: _activeSession!,
        isListening: true, // Start listening immediately
        realtimeFragments: [],
      ));

      debugPrint('🎤 Voice session started: ${_activeSessionId}');
    } catch (e) {
      emit(VoiceSessionError(
        sessionId: 'session_start_error',
        error: 'Failed to start voice session: $e',
        errorType: VoiceErrorType.sessionTimeout,
        canRetry: true,
      ));
    }
  }

  /// Add conversation fragment during active session
  Future<void> _onAddVoiceFragment(
    AddVoiceFragmentEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || _activeSession == null) {
      return; // Ignore if not active session
    }

    try {
      // Add fragment to real-time list
      _realtimeFragments.add(event.fragment);
      _fragmentTimestamps[event.fragment] = DateTime.now();

      // Update session with fragment
      _activeSession = _activeSession!.addFragment(event.fragment);

      // Calculate response timing if this is an AI response
      if (!event.isUserFragment && _realtimeFragments.length >= 2) {
        final userFragment = _realtimeFragments[_realtimeFragments.length - 2];
        final userTime = _fragmentTimestamps[userFragment];
        if (userTime != null) {
          final responseTime = DateTime.now().difference(userTime).inMilliseconds / 1000.0;
          _responseTimings[event.fragment] = responseTime;
        }
      }

      // Emit updated state
      if (state is VoiceSessionActive) {
        final currentState = state as VoiceSessionActive;
        emit(currentState.copyWith(
          session: _activeSession,
          realtimeFragments: List.from(_realtimeFragments),
          isProcessing: false, // Done processing this fragment
        ));
      }

      debugPrint('💬 Fragment added: ${event.fragment}');
    } catch (e) {
      add(VoiceErrorEvent(
        sessionId: event.sessionId,
        error: 'Failed to add voice fragment: $e',
        errorType: VoiceErrorType.aiResponseFailed,
      ));
    }
  }

  /// Update real-time transcription
  Future<void> _onUpdateTranscription(
    UpdateTranscriptionEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId) return;

    if (state is VoiceSessionActive) {
      final currentState = state as VoiceSessionActive;
      emit(currentState.copyWith(
        currentTranscription: event.transcription,
        isListening: !event.isFinal, // Stop listening when transcription is final
        isProcessing: event.isFinal,  // Start processing when transcription is final
      ));
    }
  }

  /// End voice session and create single database message with summary
  Future<void> _onEndVoiceSession(
    EndVoiceSessionEvent event,
    Emitter<VoiceState> emit,
  ) async {
    try {
      emit(VoiceSessionEnding(
        sessionId: event.sessionId,
        companion: event.voiceSession.companionId == _activeSession?.companionId 
            ? _getCompanionFromSession(event.voiceSession) 
            : AICompanion(id: event.voiceSession.companionId, name: 'Unknown', 
                gender: CompanionGender.other, artStyle: CompanionArtStyle.realistic,
                avatarUrl: '', description: '', physical: PhysicalAttributes.fromJson({}),
                personality: PersonalityTraits.fromJson({}), background: [], skills: [], voice: []),
        session: event.voiceSession,
        isGeneratingSummary: event.shouldGenerateSummary,
      ));

      String? conversationSummary;
      
      // Generate AI summary if requested and session has conversation
      if (event.shouldGenerateSummary && event.voiceSession.conversationFragments.isNotEmpty) {
        emit(VoiceSessionEnding(
          sessionId: event.sessionId,
          companion: _getCompanionFromSession(event.voiceSession),
          session: event.voiceSession,
          isGeneratingSummary: true,
          summaryProgress: 'Analyzing conversation...',
        ));

        conversationSummary = await _generateSessionSummary(
          event.voiceSession.conversationFragments,
          _getCompanionFromSession(event.voiceSession),
        );
      }

      // Create message for database storage
      final messageData = event.voiceSession.endSession().toMessageJson();
      
      // ENHANCED: Add comprehensive session metadata with token efficiency tracking
      if (conversationSummary != null) {
        final tokenEfficiency = _calculateTokenEfficiency(
          event.voiceSession.conversationFragments, 
          conversationSummary,
        );
        
        messageData['metadata'] = {
          ...messageData['metadata'] ?? {},
          'conversation_summary': conversationSummary,
          'summary_generated_at': DateTime.now().toIso8601String(),
          'token_efficiency': tokenEfficiency,
          'original_length': event.voiceSession.conversationFragments.join(' ').length,
          'summary_length': conversationSummary.length,
          'compression_ratio': tokenEfficiency,
        };
        
        debugPrint('📊 Token efficiency: ${(tokenEfficiency * 100).toStringAsFixed(1)}% compression');
      }

      // Add session statistics
      final stats = _calculateSessionStats(event.voiceSession);
      messageData['metadata'] = {
        ...messageData['metadata'] ?? {},
        'session_stats': stats.toJson(),
      };

      final message = Message.fromJson(messageData);

      // Store in database via MessageBloc
      _messageBloc.add(SendMessageEvent(message: message));

      // ENHANCED: Clean up active session using dedicated method
      _cleanup();

      emit(VoiceSessionCompleted(
        sessionId: event.sessionId,
        companion: _getCompanionFromSession(event.voiceSession),
        completedSession: event.voiceSession.endSession(),
        conversationSummary: conversationSummary,
        messageId: message.id ?? 'unknown',
        stats: stats,
      ));

      debugPrint('💾 Voice session saved with ${conversationSummary != null ? 'summary' : 'fragments only'}');
    } catch (e) {
      emit(VoiceSessionError(
        sessionId: event.sessionId,
        error: 'Failed to end voice session: $e',
        errorType: VoiceErrorType.storageError,
        canRetry: false,
        partialSession: event.voiceSession,
      ));
    }
  }

  /// Generate AI summary for voice session
  Future<void> _onGenerateVoiceSessionSummary(
    GenerateVoiceSessionSummaryEvent event,
    Emitter<VoiceState> emit,
  ) async {
    try {
      final summary = await _generateSessionSummary(
        event.conversationFragments,
        event.companion,
      );

      final keyTopics = _extractKeyTopics(event.conversationFragments);

      emit(VoiceSessionSummaryGenerated(
        sessionId: event.sessionId,
        summary: summary,
        keyTopics: keyTopics,
        summaryMetadata: {
          'original_fragments': event.conversationFragments.length,
          'summary_length': summary.length,
          'compression_ratio': event.conversationFragments.join(' ').length / summary.length,
          'generated_at': DateTime.now().toIso8601String(),
        },
      ));
    } catch (e) {
      add(VoiceErrorEvent(
        sessionId: event.sessionId,
        error: 'Failed to generate summary: $e',
        errorType: VoiceErrorType.summaryGenerationFailed,
      ));
    }
  }

  /// Handle voice errors
  Future<void> _onVoiceError(
    VoiceErrorEvent event,
    Emitter<VoiceState> emit,
  ) async {
    emit(VoiceSessionError(
      sessionId: event.sessionId,
      error: event.error,
      errorType: event.errorType,
      canRetry: _canRetryError(event.errorType),
      partialSession: _activeSession,
    ));

    debugPrint('❌ Voice error: ${event.error}');
  }

  /// Request voice context for AI generation with smart context strategy
  Future<void> _onRequestVoiceContext(
    RequestVoiceContextEvent event,
    Emitter<VoiceState> emit,
  ) async {
    try {
      // Get recent voice messages from MessageBloc
      final recentVoiceMessages = _messageBloc.currentMessages
          .where((msg) => msg.isVoiceMessage && 
                         msg.companionId == event.companionId &&
                         msg.userId == event.userId)
          .take(event.maxMessages)
          .toList();

      // Build context sessions with SMART CONTEXT STRATEGY (summary preferred, fragments fallback)
      final contexts = recentVoiceMessages.map((msg) {
        final summary = msg.metadata['conversation_summary']?.toString();
        final fragments = msg.voiceData?['conversationFragments'] as List<String>?;
        final statsData = msg.metadata['session_stats'] as Map<String, dynamic>?;
        final stats = statsData != null 
            ? SessionStats.fromJson(statsData) 
            : SessionStats(
                totalDuration: Duration.zero,
                totalExchanges: 0,
                userFragments: 0,
                aiFragments: 0,
                averageResponseTime: 0.0,
                summaryGenerated: false,
              );

        return VoiceSessionContext(
          sessionId: msg.id ?? 'unknown',
          timestamp: msg.created_at,
          summary: summary,
          fragments: fragments,
          stats: stats,
        );
      }).toList();

      // ENHANCED: Create efficient combined context using smart strategy
      final contextSummary = _buildSmartContextSummary(contexts);

      emit(VoiceContextLoaded(
        userId: event.userId,
        companionId: event.companionId,
        recentSessions: contexts,
        contextSummary: contextSummary,
      ));

      debugPrint('📊 Voice context loaded: ${contexts.length} sessions, using smart context strategy');
    } catch (e) {
      add(VoiceErrorEvent(
        sessionId: 'context_error',
        error: 'Failed to load voice context: $e',
        errorType: VoiceErrorType.storageError,
      ));
    }
  }

  /// Update voice session status
  Future<void> _onUpdateVoiceSessionStatus(
    UpdateVoiceSessionStatusEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (state is VoiceSessionActive && _activeSessionId == event.sessionId) {
      final currentState = state as VoiceSessionActive;
      
      // Update session status
      _activeSession = _activeSession?.copyWith(
        status: event.status,
        sessionMetadata: {
          ..._activeSession?.sessionMetadata ?? {},
          ...event.additionalData ?? {},
        },
      );

      emit(currentState.copyWith(session: _activeSession));
    }
  }

  /// Handle voice session lifecycle events
  Future<void> _onVoiceSessionLifecycle(
    VoiceSessionLifecycleEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (state is VoiceSessionActive && _activeSessionId == event.sessionId) {
      final currentState = state as VoiceSessionActive;
      
      switch (event.action) {
        case VoiceLifecycleAction.userSpeaking:
          emit(currentState.copyWith(isListening: true, isSpeaking: false));
          break;
        case VoiceLifecycleAction.userStoppedSpeaking:
          emit(currentState.copyWith(isListening: false, isProcessing: true));
          break;
        case VoiceLifecycleAction.aiResponding:
          emit(currentState.copyWith(isProcessing: false, isSpeaking: true));
          break;
        case VoiceLifecycleAction.aiResponseComplete:
          emit(currentState.copyWith(isSpeaking: false, isListening: true));
          break;
        case VoiceLifecycleAction.sessionPaused:
          emit(currentState.copyWith(isListening: false, isSpeaking: false, isProcessing: false));
          break;
        case VoiceLifecycleAction.sessionResumed:
          emit(currentState.copyWith(isListening: true));
          break;
        default:
          break;
      }
    }
  }

  /// Generate AI summary for conversation fragments
  Future<String> _generateSessionSummary(
    List<String> fragments,
    AICompanion companion,
  ) async {
    if (fragments.isEmpty) return 'Empty conversation';

    final conversationText = fragments.join('\n');
    
    final summaryPrompt = '''
Summarize this voice conversation between a user and ${companion.name} concisely for future context. 
Focus on:
- Key topics discussed
- Important user preferences or information shared
- ${companion.name}'s personality traits that emerged
- Any decisions or plans made
- Emotional tone of the conversation

Keep the summary under 150 words but include all important context for future conversations.

Conversation:
$conversationText

Summary:''';

    try {
      return await _geminiService.generateResponse(summaryPrompt);
    } catch (e) {
      debugPrint('Failed to generate AI summary: $e');
      // Fallback to simple summary
      return _generateFallbackSummary(fragments, companion);
    }
  }

  /// Generate fallback summary if AI generation fails
  String _generateFallbackSummary(List<String> fragments, AICompanion companion) {
    final userFragments = fragments.where((f) => f.startsWith('User:')).length;
    final aiFragments = fragments.where((f) => f.startsWith('${companion.name}:')).length;
    final topics = _extractKeyTopics(fragments);
    
    return 'Voice conversation with ${companion.name}: $userFragments user messages, $aiFragments AI responses. Topics: ${topics.take(3).join(', ')}.';
  }

  /// Extract key topics from conversation fragments
  List<String> _extractKeyTopics(List<String> fragments) {
    // Simple keyword extraction - could be enhanced with NLP
    final keywords = <String>[];
    final conversationText = fragments.join(' ').toLowerCase();
    
    // Common topic keywords
    final topicPatterns = [
      'work', 'family', 'music', 'movies', 'travel', 'food', 'health',
      'hobbies', 'sports', 'books', 'technology', 'feelings', 'plans'
    ];
    
    for (final pattern in topicPatterns) {
      if (conversationText.contains(pattern)) {
        keywords.add(pattern);
      }
    }
    
    return keywords.take(5).toList();
  }

  /// Calculate session statistics
  SessionStats _calculateSessionStats(VoiceSession session) {
    final duration = session.endTime?.difference(session.startTime) ?? Duration.zero;
    final totalExchanges = session.conversationFragments.length;
    final userFragments = session.conversationFragments
        .where((f) => f.startsWith('User:')).length;
    final aiFragments = totalExchanges - userFragments;
    
    final averageResponseTime = _responseTimings.values.isNotEmpty
        ? _responseTimings.values.reduce((a, b) => a + b) / _responseTimings.length
        : 0.0;

    return SessionStats(
      totalDuration: duration,
      totalExchanges: totalExchanges,
      userFragments: userFragments,
      aiFragments: aiFragments,
      averageResponseTime: averageResponseTime,
      summaryGenerated: true, // Will be set appropriately
    );
  }

  /// Calculate token efficiency of using summary vs fragments
  double _calculateTokenEfficiency(List<String> fragments, String summary) {
    final fragmentsLength = fragments.join(' ').length;
    final summaryLength = summary.length;
    return fragmentsLength > 0 ? summaryLength / fragmentsLength : 1.0;
  }

  /// ENHANCED: Build smart context summary using summary-preferred strategy with fragments fallback
  String _buildSmartContextSummary(List<VoiceSessionContext> contexts) {
    if (contexts.isEmpty) return 'No previous voice conversations';
    
    final contextParts = <String>[];
    int totalTokensSaved = 0;
    
    for (final context in contexts) {
      if (context.summary != null && context.summary!.isNotEmpty) {
        // PREFER SUMMARY for token efficiency
        contextParts.add('Session ${context.sessionId}: ${context.summary}');
        
        // Calculate token savings
        final fragmentsLength = context.fragments?.join(' ').length ?? 0;
        final summaryLength = context.summary!.length;
        if (fragmentsLength > 0) {
          totalTokensSaved += (fragmentsLength - summaryLength);
        }
      } else if (context.fragments != null && context.fragments!.isNotEmpty) {
        // FALLBACK to fragments if no summary available
        final fragmentText = context.fragments!.take(3).join('; '); // Limit fragments
        contextParts.add('Session ${context.sessionId}: ${fragmentText}...');
      }
    }
    
    if (contextParts.isEmpty) {
      return 'Previous voice conversations: ${contexts.length} sessions';
    }
    
    final combinedContext = contextParts.take(3).join('\n\n'); // Limit context size
    debugPrint('📊 Smart context strategy saved ~$totalTokensSaved tokens');
    
    return combinedContext;
  }

  /// Get companion from session
  AICompanion _getCompanionFromSession(VoiceSession session) {
    // This would typically fetch from a companion service
    // For now, return a basic companion
    return AICompanion(
      id: session.companionId,
      name: session.companionId,
      gender: CompanionGender.other,
      artStyle: CompanionArtStyle.realistic,
      avatarUrl: '',
      description: '',
      physical: PhysicalAttributes.fromJson({}),
      personality: PersonalityTraits.fromJson({}),
      background: [],
      skills: [],
      voice: [],
    );
  }

  /// Check microphone permission
  Future<bool> _checkMicrophonePermission() async {
    // Implementation would check actual permissions
    return true; // Placeholder
  }

  /// Check TTS availability
  Future<bool> _checkTTSAvailability() async {
    // Implementation would check TTS engine availability
    return true; // Placeholder
  }

  /// Check if error type can be retried
  bool _canRetryError(VoiceErrorType errorType) {
    switch (errorType) {
      case VoiceErrorType.networkError:
      case VoiceErrorType.speechRecognitionFailed:
      case VoiceErrorType.ttsGenerationFailed:
      case VoiceErrorType.aiResponseFailed:
        return true;
      case VoiceErrorType.microphonePermission:
      case VoiceErrorType.sessionTimeout:
      case VoiceErrorType.summaryGenerationFailed:
      case VoiceErrorType.storageError:
        return false;
    }
  }

  /// ENHANCED: Clean up session data (from enhanced version)
  void _cleanup() {
    _activeSessionId = null;
    _activeSession = null;
    _realtimeFragments.clear();
    _fragmentTimestamps.clear();
    _responseTimings.clear();
    debugPrint('🧹 Voice session cleaned up');
  }

  /// Get current active session ID
  String? get activeSessionId => _activeSessionId;

  /// Check if there's an active voice session
  bool get hasActiveSession => _activeSessionId != null && _activeSession != null;

  /// Get real-time fragments for current session
  List<String> get currentSessionFragments => List.from(_realtimeFragments);
}
