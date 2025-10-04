import 'dart:async';
import 'package:flutter/foundation.dart';
import 'azure_speech_plugin_service.dart';
import 'audio_player_service.dart';

/// Enhanced Continuous Voice Chat Service using Azure Speech Streaming
/// Provides TRUE continuous listening without interruptions, beeps, or restarts
/// This is the proper implementation matching RealtimeVoiceChat architecture
class ContinuousVoiceChatServiceV2 {
  static final ContinuousVoiceChatServiceV2 _instance = ContinuousVoiceChatServiceV2._internal();
  factory ContinuousVoiceChatServiceV2() => _instance;
  ContinuousVoiceChatServiceV2._internal();

  // Core services - using Azure Speech Plugin instead of complex WebSocket implementation
  final AzureSpeechPluginService _azureSpeech = AzureSpeechPluginService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  
  // State management
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessingTurn = false;
  bool _isTTSPlaying = false;
  bool _userInterrupted = false;
  String? _activeSessionId;
  
  // Voice activity detection
  double _currentSoundLevel = 0.0;
  bool _voiceActivityDetected = false;
  Timer? _silenceTimer;
  Timer? _potentialSentenceTimer;
  Timer? _hotStateTimer;
  String _realtimeText = '';
  List<String> _sentenceBuffer = [];
  
  // Timing configuration (based on RealtimeVoiceChat)
  static const Duration _silenceThreshold = Duration(milliseconds: 800);
  static const Duration _potentialSentenceDelay = Duration(milliseconds: 500);
  static const Duration _hotStateThreshold = Duration(milliseconds: 300);
  static const double _voiceActivityThreshold = 0.3;
  static const double _silenceLevel = 0.1;
  
  // Callbacks
  Function(String)? _onRealtimeTranscription;
  Function(String)? _onPotentialSentence;
  Function(String, bool)? _onFinalTranscription;
  Function(bool)? _onVoiceActivityChange;
  Function(bool)? _onSilenceStateChange;
  Function(bool)? _onTTSStateChange;
  Function(ContinuousVoiceState)? _onStateChange;
  Function(String)? _onError;

  /// Initialize the enhanced continuous voice chat service
  Future<bool> initialize({
    required String azureSpeechKey,
    required String azureRegion,
    Function(String)? onRealtimeTranscription,
    Function(String)? onPotentialSentence,
    Function(String, bool)? onFinalTranscription,
    Function(bool)? onVoiceActivityChange,
    Function(bool)? onSilenceStateChange,
    Function(bool)? onTTSStateChange,
    Function(ContinuousVoiceState)? onStateChange,
    Function(String)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint('🔄 ContinuousVoiceV2: Initializing with Azure Speech...');

      // Store callbacks
      _onRealtimeTranscription = onRealtimeTranscription;
      _onPotentialSentence = onPotentialSentence;
      _onFinalTranscription = onFinalTranscription;
      _onVoiceActivityChange = onVoiceActivityChange;
      _onSilenceStateChange = onSilenceStateChange;
      _onTTSStateChange = onTTSStateChange;
      _onStateChange = onStateChange;
      _onError = onError;

      // Initialize Azure Speech Streaming first
      debugPrint('🔄 ContinuousVoiceV2: Initializing Azure Speech...');
      final azureInitSuccess = await _azureSpeech.initialize(
        azureSpeechKey: azureSpeechKey,
        azureRegion: azureRegion,
      );

      if (!azureInitSuccess) {
        throw Exception('Azure Speech initialization failed');
      }

      // Initialize audio player with proper delay
      debugPrint('🔄 ContinuousVoiceV2: Initializing audio player...');
      await Future.delayed(Duration(milliseconds: 500));
      
      final audioInitSuccess = await _audioPlayerService.initialize(
        onPlaybackStart: _handleTTSStart,
        onPlaybackComplete: _handleTTSComplete,
        onPlaybackError: (error) => _onError?.call('Audio error: $error'),
      );

      if (!audioInitSuccess) {
        throw Exception('Audio player initialization failed');
      }

      _isInitialized = true;
      _notifyStateChange(ContinuousVoiceState.ready);
      debugPrint('✅ ContinuousVoiceV2: Service initialized successfully');
      return true;

    } catch (e) {
      debugPrint('❌ ContinuousVoiceV2: Initialization failed - $e');
      _onError?.call('Initialization failed: $e');
      return false;
    }
  }

  /// Start continuous voice session with Azure Speech
  Future<bool> startVoiceSession({
    required String sessionId,
    String locale = 'en-US',
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ ContinuousVoiceV2: Service not initialized');
      return false;
    }

    if (_isListening) {
      debugPrint('⚠️ ContinuousVoiceV2: Already listening, stopping previous session');
      await stopVoiceSession();
    }

    try {
      _activeSessionId = sessionId;
      _resetState();

      debugPrint('🎤 ContinuousVoiceV2: Starting continuous session $sessionId');

      // Start Azure Speech continuous recognition
      final success = await _azureSpeech.startContinuousRecognition(
        sessionId: sessionId,
        onTranscription: _handleContinuousRecognitionResult,
        onSoundLevel: _handleSoundLevelChange,
        onError: _handleAzureSpeechError,
        onSessionStart: () {
          _isListening = true;
          _notifyStateChange(ContinuousVoiceState.listening);
          debugPrint('🎤 ContinuousVoiceV2: Azure Speech session started');
        },
        onSessionEnd: () {
          _isListening = false;
          _notifyStateChange(ContinuousVoiceState.idle);
          debugPrint('🎤 ContinuousVoiceV2: Azure Speech session ended');
        },
        locale: locale,
      );

      if (!success) {
        throw Exception('Failed to start Azure Speech recognition');
      }

      debugPrint('✅ ContinuousVoiceV2: Started continuous listening for session $sessionId');
      return true;

    } catch (e) {
      debugPrint('❌ ContinuousVoiceV2: Failed to start voice session - $e');
      _onError?.call('Failed to start voice session: $e');
      return false;
    }
  }

  /// Handle continuous recognition results from Azure Speech
  void _handleContinuousRecognitionResult(String transcription, bool isFinal) {
    if (transcription.trim().isEmpty) return;

    if (isFinal) {
      // Final transcription received
      debugPrint('📝 ContinuousVoiceV2: Final transcription - "$transcription"');
      _processFinalTranscription(transcription, 0.95); // Azure provides high confidence
      
      // Clear realtime buffer
      _realtimeText = '';
    } else {
      // Interim/realtime transcription
      _realtimeText = transcription;
      _onRealtimeTranscription?.call(transcription);
      
      // Detect potential sentence completion
      _detectPotentialSentence(transcription);
      
      debugPrint('📝 ContinuousVoiceV2: Realtime - "$transcription"');
    }
  }

  /// Detect potential sentence completion without waiting for final result
  void _detectPotentialSentence(String text) {
    if (_hasSentenceEndingPattern(text)) {
      _potentialSentenceTimer?.cancel();
      _potentialSentenceTimer = Timer(_potentialSentenceDelay, () {
        _onPotentialSentence?.call(text);
        _enterHotState(text);
      });
    }
  }

  /// Check if text has sentence-ending patterns
  bool _hasSentenceEndingPattern(String text) {
    final trimmed = text.trim();
    return trimmed.endsWith('.') || 
           trimmed.endsWith('?') || 
           trimmed.endsWith('!') ||
           RegExp(r'\b(thanks?|thank you|bye|goodbye|okay|ok|sure|yes|no|right)\b$', caseSensitive: false).hasMatch(trimmed);
  }

  /// Enter hot state for quick response processing
  void _enterHotState(String potentialText) {
    if (_isProcessingTurn || _isTTSPlaying) return;

    debugPrint('🔥 ContinuousVoiceV2: Entering hot state for: "$potentialText"');
    _notifyStateChange(ContinuousVoiceState.hotState);

    _hotStateTimer = Timer(_hotStateThreshold, () {
      if (!_isProcessingTurn && !_isTTSPlaying) {
        debugPrint('🔥 ContinuousVoiceV2: Hot state timeout - processing potential sentence');
        _processFinalTranscription(potentialText, 0.85);
      }
    });
  }

  /// Process final transcription result
  void _processFinalTranscription(String transcription, double confidence) {
    if (_isProcessingTurn || transcription.trim().length < 2) return;

    _cancelTimers();
    _sentenceBuffer.add(transcription);
    
    debugPrint('✅ ContinuousVoiceV2: Processing final transcription: "$transcription"');
    _processTurnCompletion(transcription, confidence);
  }

  /// Process turn completion and prepare for response
  void _processTurnCompletion(String transcription, double confidence) {
    _isProcessingTurn = true;
    _notifyStateChange(ContinuousVoiceState.processing);

    debugPrint('🔄 ContinuousVoiceV2: Turn completed - "$transcription"');
    _onFinalTranscription?.call(transcription, true);

    // Note: The actual AI response generation happens in the UI layer
    // This service just handles the voice I/O coordination
  }

  /// Handle sound level changes for voice activity detection
  void _handleSoundLevelChange(double level) {
    _currentSoundLevel = level;

    final wasVoiceActive = _voiceActivityDetected;
    _voiceActivityDetected = level > _voiceActivityThreshold;

    if (_voiceActivityDetected && !wasVoiceActive) {
      _handleVoiceActivityStart();
    } else if (!_voiceActivityDetected && wasVoiceActive) {
      _handleVoiceActivityEnd();
    }

    _manageSilenceDetection(level);
  }

  /// Handle voice activity start
  void _handleVoiceActivityStart() {
    if (_isTTSPlaying) {
      _handleUserInterruption();
    }

    debugPrint('🗣️ ContinuousVoiceV2: Voice activity started');
    _onVoiceActivityChange?.call(true);
    _onSilenceStateChange?.call(false);
  }

  /// Handle voice activity end
  void _handleVoiceActivityEnd() {
    debugPrint('🤫 ContinuousVoiceV2: Voice activity ended');
    _onVoiceActivityChange?.call(false);
    _startSilenceTimer();
  }

  /// Handle user interruption during TTS
  void _handleUserInterruption() {
    if (!_isTTSPlaying) return;

    _userInterrupted = true;
    _audioPlayerService.stopPlayback();
    debugPrint('✋ ContinuousVoiceV2: User interrupted TTS');
  }

  /// Manage silence detection and timing
  void _manageSilenceDetection(double level) {
    if (level <= _silenceLevel) {
      _onSilenceStateChange?.call(true);
    } else {
      _silenceTimer?.cancel();
      _onSilenceStateChange?.call(false);
    }
  }

  /// Start silence timer for turn completion detection
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, () {
      if (_realtimeText.isNotEmpty) {
        debugPrint('⏰ ContinuousVoiceV2: Silence timeout - processing: "$_realtimeText"');
        _processFinalTranscription(_realtimeText, 0.8);
      }
    });
  }

  /// Play TTS response while maintaining continuous listening
  Future<bool> playTTSResponse({
    required Uint8List audioData,
    required String sessionId,
    String? companionName,
  }) async {
    if (_activeSessionId != sessionId || !_isInitialized) {
      debugPrint('❌ ContinuousVoiceV2: Invalid session for TTS playback');
      return false;
    }

    try {
      _isTTSPlaying = true;
      _userInterrupted = false;
      _isProcessingTurn = false;
      
      debugPrint('🔊 ContinuousVoiceV2: Starting TTS playback');
      _notifyStateChange(ContinuousVoiceState.companionSpeaking);

      final success = await _audioPlayerService.playTTSAudio(
        audioData: audioData,
        sessionId: sessionId,
        companionName: companionName,
      );

      if (!success) {
        _handleTTSError('TTS playback failed');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ ContinuousVoiceV2: TTS playback error - $e');
      _handleTTSError(e.toString());
      return false;
    }
  }

  /// Handle TTS playback start
  void _handleTTSStart() {
    _onTTSStateChange?.call(true);
    debugPrint('🔊 ContinuousVoiceV2: TTS playback started');
  }

  /// Handle TTS playback completion
  void _handleTTSComplete() {
    _isTTSPlaying = false;
    _onTTSStateChange?.call(false);
    
    if (!_userInterrupted) {
      _notifyStateChange(ContinuousVoiceState.listening);
      debugPrint('✅ ContinuousVoiceV2: TTS completed, back to listening');
    } else {
      debugPrint('✅ ContinuousVoiceV2: TTS completed after interruption');
    }
    
    _userInterrupted = false;
  }

  /// Handle TTS errors
  void _handleTTSError(String error) {
    _isTTSPlaying = false;
    _isProcessingTurn = false;
    _onTTSStateChange?.call(false);
    _notifyStateChange(ContinuousVoiceState.listening);
    
    debugPrint('❌ ContinuousVoiceV2: TTS error - $error');
    _onError?.call('TTS error: $error');
  }

  /// Handle Azure Speech errors
  void _handleAzureSpeechError(String error) {
    debugPrint('❌ ContinuousVoiceV2: Azure Speech error - $error');
    _onError?.call('Speech recognition error: $error');
    
    // Azure Speech handles its own reconnection
    // Just log the error for monitoring
  }

  /// Stop voice session
  Future<void> stopVoiceSession() async {
    if (!_isListening) return;

    debugPrint('🛑 ContinuousVoiceV2: Stopping voice session');

    try {
      // Stop Azure Speech recognition
      await _azureSpeech.stopContinuousRecognition();
      
      // Stop any playing audio
      await _audioPlayerService.stopPlayback();
      
      _resetState();
      _notifyStateChange(ContinuousVoiceState.idle);
      
      debugPrint('✅ ContinuousVoiceV2: Voice session stopped');
    } catch (e) {
      debugPrint('❌ ContinuousVoiceV2: Error stopping session - $e');
    }
  }

  /// Reset service state
  void _resetState() {
    _isListening = false;
    _isProcessingTurn = false;
    _isTTSPlaying = false;
    _userInterrupted = false;
    _currentSoundLevel = 0.0;
    _voiceActivityDetected = false;
    _realtimeText = '';
    _sentenceBuffer.clear();
    _cancelTimers();
  }

  /// Cancel all active timers
  void _cancelTimers() {
    _silenceTimer?.cancel();
    _potentialSentenceTimer?.cancel();
    _hotStateTimer?.cancel();
    _silenceTimer = null;
    _potentialSentenceTimer = null;
    _hotStateTimer = null;
  }

  /// Notify state change
  void _notifyStateChange(ContinuousVoiceState state) {
    _onStateChange?.call(state);
  }

  // Getters
  bool get isListening => _isListening;
  bool get isTTSPlaying => _isTTSPlaying;
  bool get isProcessing => _isProcessingTurn;
  bool get isInitialized => _isInitialized;
  double get currentSoundLevel => _currentSoundLevel;
  String get activeSessionId => _activeSessionId ?? '';
  
  /// Dispose resources
  Future<void> dispose() async {
    await stopVoiceSession();
    await _azureSpeech.dispose();
    await _audioPlayerService.dispose();
    _cancelTimers();
    _isInitialized = false;
    debugPrint('🔄 ContinuousVoiceV2: Service disposed');
  }
}

/// Continuous voice chat states
enum ContinuousVoiceState {
  idle,              // Not active
  ready,             // Initialized and ready
  listening,         // Continuously listening
  voiceDetected,     // Voice activity detected
  hotState,          // Quick response mode
  processing,        // Processing user input
  companionSpeaking, // TTS playing
  error,             // Error state
}
