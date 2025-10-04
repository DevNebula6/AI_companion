import 'dart:async';
import 'package:ai_companion/chat/voice/voice_bloc/voice_event.dart';
import 'package:ai_companion/chat/voice/voice_bloc/voice_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../voice_message_model.dart';
import '../supabase_tts_service.dart';
import '../voice_enhanced_gemini_service.dart';
import '../continuous_voice_chat_service_v2.dart';
import '../azure_speech_config.dart';
import '../audio_player_service.dart';
import '../companion_voice_config_service.dart';
import '../../message_bloc/message_bloc.dart';
import '../../message_bloc/message_event.dart';
import '../../message.dart';
import '../../../Companion/ai_model.dart';

/// Voice BLoC for managing real-time voice chat functionality
/// Separated from MessageBloc to prevent UI interference and enable
/// single-session storage with AI-generated summaries
class VoiceBloc extends Bloc<VoiceEvent,VoiceState> {
  final MessageBloc _messageBloc;
  final VoiceEnhancedGeminiService _voiceGeminiService;
  final SupabaseTTSService _ttsService;
  final ContinuousVoiceChatServiceV2 _continuousVoiceService;
  final AudioPlayerService _audioPlayerService;

  // Active session management
  String? _activeSessionId;
  VoiceSession? _activeSession;
  AICompanion? _currentCompanion; // Cache companion directly
  final List<String> _realtimeFragments = [];
  
  // Session analytics
  final Map<String, DateTime> _fragmentTimestamps = {};
  final Map<String, double> _responseTimings = {};

  VoiceBloc({
    required MessageBloc messageBloc,
    required VoiceEnhancedGeminiService voiceGeminiService,
    required SupabaseTTSService ttsService,
  })  : _messageBloc = messageBloc,
        _voiceGeminiService = voiceGeminiService,
        _ttsService = ttsService,
        _continuousVoiceService = ContinuousVoiceChatServiceV2(),
        _audioPlayerService = AudioPlayerService(),
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
    
    // Add new STT event handlers
    on<StartListeningEvent>(_onStartListening);
    on<StopListeningEvent>(_onStopListening);
    on<SpeechResultEvent>(_onSpeechResult);
    on<VoiceActivityEvent>(_onVoiceActivity);
    on<STTErrorEvent>(_onSTTError);
    
    // Add new TTS event handlers
    on<PlayTTSAudioEvent>(_onPlayTTSAudio);
    on<TTSPlaybackStatusEvent>(_onTTSPlaybackStatus);
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
      // ENHANCED: Refresh companion data with voice config from database
      debugPrint('🔄 Refreshing companion data with voice config...');
      final refreshedCompanion = await _refreshCompanionWithVoiceConfig(event.companion);
      
      // Cache the refreshed companion with voice config
      _currentCompanion = refreshedCompanion;
      debugPrint('📊 Companion cached with voice config: ${refreshedCompanion.azureVoiceConfig != null}');

      // Check permissions and capabilities
      final hasMicPermission = await _checkMicrophonePermission();
      final hasTTS = await _checkTTSAvailability();

      emit(VoiceReady(
        userId: event.userId,
        companion: refreshedCompanion, // Use refreshed companion
        hasMicrophonePermission: hasMicPermission,
        hasTTSAvailable: hasTTS,
      ));

      debugPrint('✅ Voice system initialized for ${refreshedCompanion.name} with voice config: ${refreshedCompanion.azureVoiceConfig != null}');
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
        conversationId: event.conversationId,
      );
      _activeSessionId = _activeSession!.id;
      _realtimeFragments.clear();
      _fragmentTimestamps.clear();
      _responseTimings.clear();

      emit(VoiceSessionActive(
        sessionId: _activeSessionId!,
        companion: event.companion,
        session: _activeSession!,
        isListening: false, // Will be set to true when STT starts
        realtimeFragments: [],
      ));

      // Automatically start STT listening
      add(StartListeningEvent(sessionId: _activeSessionId!));

      debugPrint('🎤 Voice session started: $_activeSessionId');
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

      // ENHANCED: Process voice message if this is a user fragment
      if (event.isUserFragment) {
        await _processVoiceMessage(event.fragment, emit);
      }

      // Emit updated state
      if (state is VoiceSessionActive) {
        final currentState = state as VoiceSessionActive;
        emit(currentState.copyWith(
          session: _activeSession,
          realtimeFragments: List.from(_realtimeFragments),
          isProcessing: event.isUserFragment, // Show processing for user messages
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

  /// Process voice message using VoiceEnhancedGeminiService
  Future<void> _processVoiceMessage(String userMessage, Emitter<VoiceState> emit) async {
    if (_activeSession == null) return;

    try {
      // OPTIMIZED: Get companion directly from cache - no async needed!
      final companion = _getCompanionFromSession(_activeSession!);
      
      // Generate AI response using voice-enhanced service
      final aiResponse = await _voiceGeminiService.generateVoiceResponse(
        userMessage: userMessage,
        companion: companion,
        companionId: companion.id,
      );

      // Add AI response as a new fragment
      add(AddVoiceFragmentEvent(
        sessionId: _activeSession!.id,
        fragment: aiResponse,
        isUserFragment: false,
      ));

      // ENHANCED: Play TTS audio if available
      debugPrint('🔊 Checking TTS availability...');
      debugPrint('📊 TTS Service available: ${_ttsService.isAvailable}');
      debugPrint('📊 Companion voice config: ${companion.azureVoiceConfig != null ? 'Available' : 'Missing'}');
      
      if (companion.azureVoiceConfig != null) {
        debugPrint('🎤 Voice config details: ${companion.azureVoiceConfig.toString()}');
      }
      
      if (_ttsService.isAvailable && companion.azureVoiceConfig != null) {
        // Play TTS audio through AudioPlayerService
        add(PlayTTSAudioEvent(
          sessionId: _activeSession!.id,
          text: aiResponse,
          companionName: companion.name,
        ));
        debugPrint('🔊 TTS playback initiated for response');
      } else {
        debugPrint('⚠️ TTS not available or no voice config for ${companion.name}');
        debugPrint('   - TTS Service: ${_ttsService.isAvailable}');
        debugPrint('   - Voice Config: ${companion.azureVoiceConfig != null}');
        
        // Fallback: Since TTS isn't available, restart STT listening immediately
        // so the user can continue the conversation
        debugPrint('🔄 TTS unavailable - restarting STT listening for next user input');
        add(StartListeningEvent(sessionId: _activeSession!.id));
      }

    } catch (e) {
      debugPrint('❌ Voice message processing failed: $e');
      add(VoiceErrorEvent(
        sessionId: _activeSession!.id,
        error: 'Failed to process voice message: $e',
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
      // VALIDATION: Check if session has meaningful content
      if (event.voiceSession.conversationFragments.isEmpty) {
        debugPrint('⚠️ Voice session ended with no conversation fragments - discarding session');
        _cleanup();
        emit(VoiceSessionCompleted(
          sessionId: event.sessionId,
          companion: _getCompanionFromSession(event.voiceSession),
          completedSession: event.voiceSession.endSession(),
          conversationSummary: null,
          messageId: null, // No message created for empty sessions
          stats: _calculateSessionStats(event.voiceSession),
        ));
        return;
      }

      // VALIDATION: Check minimum fragment count (at least one meaningful exchange)
      final meaningfulFragments = event.voiceSession.conversationFragments
          .where((fragment) => fragment.trim().isNotEmpty && fragment.length > 3)
          .toList();
      
      if (meaningfulFragments.length < 2) { // Need at least user + AI response
        debugPrint('⚠️ Voice session ended with insufficient meaningful content (${meaningfulFragments.length} fragments) - discarding session');
        _cleanup();
        emit(VoiceSessionCompleted(
          sessionId: event.sessionId,
          companion: _getCompanionFromSession(event.voiceSession),
          completedSession: event.voiceSession.endSession(),
          conversationSummary: null,
          messageId: null, // No message created for insufficient content
          stats: _calculateSessionStats(event.voiceSession),
        ));
        return;
      }

      // OPTIMIZED: Get companion directly from cache - no async needed!
      final companion = _getCompanionFromSession(event.voiceSession);
      
      emit(VoiceSessionEnding(
        sessionId: event.sessionId,
        companion: companion,
        session: event.voiceSession,
        isGeneratingSummary: event.shouldGenerateSummary,
      ));

      String? conversationSummary;
      
      // Generate AI summary if requested and session has conversation
      if (event.shouldGenerateSummary && event.voiceSession.conversationFragments.isNotEmpty) {
        emit(VoiceSessionEnding(
          sessionId: event.sessionId,
          companion: companion,
          session: event.voiceSession,
          isGeneratingSummary: true,
          summaryProgress: 'Analyzing conversation...',
        ));

        conversationSummary = await _generateSessionSummary(
          event.voiceSession.conversationFragments,
          companion,
        );
      }

      // Create message for database storage - MessageBloc will handle proper conversation ID
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
        companion: companion,
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


      emit(VoiceSessionSummaryGenerated(
        sessionId: event.sessionId,
        summary: summary,
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
        final fragments = msg.messageFragments;
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

  /// Generate AI summary for conversation fragments using voice-enhanced service
  Future<String> _generateSessionSummary(
    List<String> fragments,
    AICompanion companion,
  ) async {
    if (fragments.isEmpty) return 'Empty conversation';

    try {
      // Use voice-enhanced service for better summarization with companion context
      return await _voiceGeminiService.generateVoiceConversationSummary(
        conversationFragments: fragments,
        companion: companion,
      );
    } catch (e) {
      debugPrint('Voice-enhanced summary failed, falling back to basic: $e');
      throw Exception('Summary generation failed: $e');
    }
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

  /// Get companion from session - OPTIMIZED: Use cached companion
  AICompanion _getCompanionFromSession(VoiceSession session) {
    if (_currentCompanion == null) {
      throw StateError('No companion cached. Initialize voice system first with InitializeVoiceSystemEvent.');
    }
    
    if (_currentCompanion!.id != session.companionId) {
      throw ArgumentError('Companion ID mismatch: expected ${session.companionId}, got ${_currentCompanion!.id}');
    }
    
    return _currentCompanion!;
  }

  /// Check microphone permission
  Future<bool> _checkMicrophonePermission() async {
    try {
      // Use the continuous voice service for permission check
      final available = await _continuousVoiceService.initialize(
        azureSpeechKey: AzureSpeechConfig.azureSpeechKey,
        azureRegion: AzureSpeechConfig.azureRegion,
        onRealtimeTranscription: (transcription) {
          // Handle real-time transcription updates for UI
          if (_activeSessionId != null) {
            add(UpdateTranscriptionEvent(
              sessionId: _activeSessionId!,
              transcription: transcription,
              isFinal: false,
            ));
          }
        },
        onPotentialSentence: (sentence) {
          // Handle potential sentence completion for quick AI response
          debugPrint('🎯 Potential sentence detected: "$sentence"');
          if (_activeSessionId != null) {
            add(SpeechResultEvent(
              sessionId: _activeSessionId!,
              transcription: sentence,
              isFinal: false,
              confidence: 0.8, // High confidence for potential sentences
            ));
          }
        },
        onFinalTranscription: (transcription, isConfident) {
          if (_activeSessionId != null) {
            add(SpeechResultEvent(
              sessionId: _activeSessionId!,
              transcription: transcription,
              isFinal: true,
              confidence: isConfident ? 0.9 : 0.6,
            ));
          }
        },
        onVoiceActivityChange: (isActive) {
          if (_activeSessionId != null) {
            add(VoiceActivityEvent(
              sessionId: _activeSessionId!,
              soundLevel: isActive ? 0.7 : 0.2, // Approximate sound level
            ));
          }
        },
        onSilenceStateChange: (isSilent) {
          // Handle silence state changes for turn management
          debugPrint('🤫 Silence state: $isSilent');
        },
        onTTSStateChange: (isTTSActive) {
          // Update state to reflect TTS playback
          if (isTTSActive) {
            debugPrint('🔊 TTS started playing');
          } else {
            debugPrint('🔇 TTS finished playing');
          }
        },
        onStateChange: (voiceState) {
          // Store state change for later processing in event handlers
          debugPrint('🔄 ContinuousVoiceV2: State changed to $voiceState');
        },
        onError: (error) {
          if (_activeSessionId != null) {
            add(STTErrorEvent(
              sessionId: _activeSessionId!,
              error: error,
              isRecoverable: true,
            ));
          }
        },
      );
      
      if (!available) {
        debugPrint('❌ Continuous voice service not available');
        return false;
      }
      
      debugPrint('✅ Microphone permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking microphone permission: $e');
      return false;
    }
  }

  /// Check TTS availability
  Future<bool> _checkTTSAvailability() async {
    try {
      // Use the instance field for TTS service
      debugPrint('🔍 Checking TTS service availability...');
      final isAvailable = _ttsService.isAvailable;
      
      debugPrint('📊 TTS Service isAvailable: $isAvailable');
      debugPrint('📊 TTS Service type: ${_ttsService.runtimeType}');
      
      if (!isAvailable) {
        debugPrint('❌ TTS service not available');
        return false;
      }
      
      debugPrint('✅ TTS service available');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking TTS availability: $e');
      debugPrint('📊 Exception type: ${e.runtimeType}');
      return false;
    }
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

  /// Refresh companion data with voice configuration from database
  Future<AICompanion> _refreshCompanionWithVoiceConfig(AICompanion originalCompanion) async {
    try {
      debugPrint('🔍 Fetching companion voice config from database...');
      
      // Fetch voice config directly from database using CompanionVoiceConfigService
      final voiceConfigService = CompanionVoiceConfigService();
      final voiceConfig = await voiceConfigService.getCompanionVoiceConfig(originalCompanion.id);
      
      if (voiceConfig != null) {
        debugPrint('✅ Found voice config for ${originalCompanion.name}');
        debugPrint('🎤 Voice: ${voiceConfig.azureVoiceName}, Style: ${voiceConfig.voiceStyle}');
        
        // Create new companion instance with voice config
        return AICompanion(
          id: originalCompanion.id,
          name: originalCompanion.name,
          gender: originalCompanion.gender,
          artStyle: originalCompanion.artStyle,
          avatarUrl: originalCompanion.avatarUrl,
          description: originalCompanion.description,
          physical: originalCompanion.physical,
          personality: originalCompanion.personality,
          background: originalCompanion.background,
          skills: originalCompanion.skills,
          voice: originalCompanion.voice,
          metadata: originalCompanion.metadata,
          azureVoiceConfig: voiceConfig, // Add the voice config!
        );
      } else {
        debugPrint('⚠️ No voice config found for ${originalCompanion.name} - using original');
        return originalCompanion;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing companion voice config: $e');
      // Return original companion on error
      return originalCompanion;
    }
  }

  /// ENHANCED: Clean up session data (from enhanced version)
  void _cleanup() {
    _activeSessionId = null;
    _activeSession = null;
    _realtimeFragments.clear();
    _fragmentTimestamps.clear();
    _responseTimings.clear();
    // Keep _currentCompanion cached for efficiency - only clear on explicit companion change
    debugPrint('🧹 Voice session cleaned up');
  }

  /// Clear companion cache (call when switching companions)
  void clearCompanionCache() {
    _currentCompanion = null;
    debugPrint('🗑️ Voice companion cache cleared');
  }

  /// Handle start listening event
  Future<void> _onStartListening(
    StartListeningEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || state is! VoiceSessionActive) {
      debugPrint('❌ ContinuousVoice: Cannot start listening - no active session');
      return;
    }

    try {
      final currentState = state as VoiceSessionActive;
      
      // Start continuous voice session using Azure Speech V2
      final started = await _continuousVoiceService.startVoiceSession(
        sessionId: event.sessionId,
        locale: event.locale,
      );

      if (started) {
        debugPrint('🎤 ContinuousVoice: Started continuous listening for session ${event.sessionId}');
        emit(currentState.copyWith(isListening: true));
      } else {
        add(STTErrorEvent(
          sessionId: event.sessionId,
          error: 'Failed to start continuous voice recognition',
          isRecoverable: true,
        ));
      }
    } catch (e) {
      debugPrint('❌ ContinuousVoice: Start listening error: $e');
      add(STTErrorEvent(
        sessionId: event.sessionId,
        error: 'Unexpected error starting continuous voice: $e',
        isRecoverable: true,
      ));
    }
  }

  /// Handle stop listening event
  Future<void> _onStopListening(
    StopListeningEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId) return;

    try {
      await _continuousVoiceService.stopVoiceSession();
      debugPrint('🛑 ContinuousVoice: Stopped listening for session ${event.sessionId}');
      
      if (state is VoiceSessionActive) {
        final currentState = state as VoiceSessionActive;
        emit(currentState.copyWith(isListening: false));
      }
    } catch (e) {
      debugPrint('❌ ContinuousVoice: Stop listening error: $e');
    }
  }

  /// Handle speech result event
  Future<void> _onSpeechResult(
    SpeechResultEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || state is! VoiceSessionActive) {
      return;
    }

    final currentState = state as VoiceSessionActive;

    // Update transcription confidence
    emit(currentState.copyWith(
      currentTranscription: event.transcription,
      transcriptionConfidence: event.confidence,
    ));

    // Process final transcriptions
    if (event.isFinal && event.transcription.trim().isNotEmpty) {
      // Add user fragment to conversation
      final userFragment = 'User: ${event.transcription.trim()}';
      add(AddVoiceFragmentEvent(
        sessionId: event.sessionId,
        fragment: userFragment,
        isUserFragment: true,
      ));

      debugPrint('💬 STT: Final transcription - "${event.transcription}" (confidence: ${(event.confidence * 100).toStringAsFixed(1)}%)');
    }
  }

  /// Handle voice activity event
  Future<void> _onVoiceActivity(
    VoiceActivityEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || state is! VoiceSessionActive) {
      return;
    }

    final currentState = state as VoiceSessionActive;
    emit(currentState.copyWith(voiceActivityLevel: event.soundLevel));
  }

  /// Handle STT error event
  Future<void> _onSTTError(
    STTErrorEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId) return;

    debugPrint('❌ STT: Error - ${event.error} (recoverable: ${event.isRecoverable})');

    // Don't handle "error_no_match" as it's normal behavior
    if (event.error.contains('error_no_match')) {
      debugPrint('ℹ️ STT: Ignoring error_no_match - this is normal when no speech is detected');
      return;
    }

    if (!event.isRecoverable) {
      // Critical error - stop session
      emit(VoiceSessionError(
        sessionId: event.sessionId,
        error: 'Speech recognition failed: ${event.error}',
        errorType: VoiceErrorType.microphonePermission,
        canRetry: false,
        partialSession: _activeSession,
      ));
    } else {
      // Recoverable error - implement exponential backoff retry
      final retryAttempts = _getRetryAttempts(event.sessionId);
      if (retryAttempts < 2) { // Reduce from 3 to 2 attempts
        final delaySeconds = (retryAttempts + 1) * 2; // 2, 4 seconds
        debugPrint('🔄 STT: Attempting recovery in ${delaySeconds}s (attempt ${retryAttempts + 1}/2)');
        
        _incrementRetryAttempts(event.sessionId);
        
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (_activeSessionId == event.sessionId && state is VoiceSessionActive) {
            add(StartListeningEvent(sessionId: event.sessionId));
          }
        });
      } else {
        // Max retries reached
        debugPrint('❌ STT: Max retry attempts reached for session ${event.sessionId}');
        emit(VoiceSessionError(
          sessionId: event.sessionId,
          error: 'Speech recognition failed after multiple attempts: ${event.error}',
          errorType: VoiceErrorType.speechRecognitionFailed,
          canRetry: true,
          partialSession: _activeSession,
        ));
      }
    }
  }

  // Retry attempt tracking
  final Map<String, int> _retryAttempts = {};
  
  int _getRetryAttempts(String sessionId) {
    return _retryAttempts[sessionId] ?? 0;
  }
  
  void _incrementRetryAttempts(String sessionId) {
    _retryAttempts[sessionId] = (_retryAttempts[sessionId] ?? 0) + 1;
  }

  /// Handle play TTS audio event
  Future<void> _onPlayTTSAudio(
    PlayTTSAudioEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || state is! VoiceSessionActive) {
      return;
    }

    try {
      final companion = _getCompanionFromSession(_activeSession!);

      // Generate TTS audio
      final ttsResult = await _ttsService.synthesizeSpeech(
        text: event.text,
        companion: companion,
      );

      if (ttsResult.success && ttsResult.audioData.isNotEmpty) {
        // Use continuous voice service for TTS playback with interruption handling
        final playbackSuccess = await _continuousVoiceService.playTTSResponse(
          audioData: ttsResult.audioData,
          sessionId: event.sessionId,
          companionName: event.companionName,
        );

        if (playbackSuccess) {
          debugPrint('🔊 TTS playback started with continuous voice service');
          // State updates are handled by the continuous voice service callbacks
        } else {
          add(TTSPlaybackStatusEvent(
            sessionId: event.sessionId,
            status: TTSPlaybackStatus.error,
            error: 'Failed to play TTS audio through continuous voice service',
          ));
        }
      } else {
        add(TTSPlaybackStatusEvent(
          sessionId: event.sessionId,
          status: TTSPlaybackStatus.error,
          error: ttsResult.error ?? 'TTS synthesis failed',
        ));
      }
    } catch (e) {
      debugPrint('❌ TTS: Play audio error: $e');
      add(TTSPlaybackStatusEvent(
        sessionId: event.sessionId,
        status: TTSPlaybackStatus.error,
        error: 'Unexpected TTS error: $e',
      ));
    }
  }

  /// Handle TTS playback status event
  Future<void> _onTTSPlaybackStatus(
    TTSPlaybackStatusEvent event,
    Emitter<VoiceState> emit,
  ) async {
    if (_activeSessionId != event.sessionId || state is! VoiceSessionActive) {
      return;
    }

    final currentState = state as VoiceSessionActive;

    switch (event.status) {
      case TTSPlaybackStatus.starting:
        emit(currentState.copyWith(
          isPlayingTTS: true,
          isSpeaking: true,
        ));
        break;

      case TTSPlaybackStatus.playing:
        emit(currentState.copyWith(
          isPlayingTTS: true,
          isSpeaking: true,
          isListening: false,
        ));
        break;

      case TTSPlaybackStatus.completed:
        // TTS finished - restart STT listening
        emit(currentState.copyWith(
          isPlayingTTS: false,
          isSpeaking: false,
        ));

        // Request audio focus back and restart listening
        _audioPlayerService.requestAudioFocus();
        add(StartListeningEvent(sessionId: event.sessionId));
        break;

      case TTSPlaybackStatus.error:
        debugPrint('❌ TTS: Playback error - ${event.error}');
        emit(currentState.copyWith(
          isPlayingTTS: false,
          isSpeaking: false,
        ));

        // Restart listening even after error
        _audioPlayerService.requestAudioFocus();
        add(StartListeningEvent(sessionId: event.sessionId));
        break;
    }
  }

  /// Get current active session ID
  String? get activeSessionId => _activeSessionId;

  /// Check if there's an active voice session
  bool get hasActiveSession => _activeSessionId != null && _activeSession != null;

  /// Get real-time fragments for current session
  List<String> get currentSessionFragments => List.from(_realtimeFragments);
}
