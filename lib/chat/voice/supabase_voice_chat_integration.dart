import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../message_bloc/message_bloc.dart';
import '../message_bloc/message_event.dart';
import '../message_bloc/message_state.dart';
import '../message.dart';
import '../../Companion/ai_model.dart';
import 'supabase_tts_service.dart';
import 'voice_enhanced_gemini_service.dart';

/// Supabase-native voice chat integration
/// Uses your existing tech stack and database structure
class SupabaseVoiceChatIntegration extends ChangeNotifier {
  static final SupabaseVoiceChatIntegration _instance = 
      SupabaseVoiceChatIntegration._internal();
  factory SupabaseVoiceChatIntegration() => _instance;
  SupabaseVoiceChatIntegration._internal();

  // Core services
  final SupabaseTTSService _ttsService = SupabaseTTSService();
  final VoiceEnhancedGeminiService _geminiService = VoiceEnhancedGeminiService();
  
  // Audio components
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  
  // State management
  MessageBloc? _messageBloc;
  AICompanion? _currentCompanion;
  VoiceChatState _state = VoiceChatState.idle;
  
  // Voice processing state
  String _currentTranscription = '';
  bool _isProcessingVoice = false;
  Timer? _recordingTimer;
  StreamSubscription? _messageSubscription;
  
  // Configuration
  static const Duration _maxRecordingDuration = Duration(seconds: 30);
  static const Duration _silenceThreshold = Duration(seconds: 3);

  // Getters
  VoiceChatState get state => _state;
  bool get isIdle => _state == VoiceChatState.idle;
  bool get isListening => _state == VoiceChatState.listening;
  bool get isProcessing => _state == VoiceChatState.processing;
  bool get isPlaying => _state == VoiceChatState.playing;
  bool get isProcessingVoice => _isProcessingVoice;
  String get currentTranscription => _currentTranscription;
  AICompanion? get currentCompanion => _currentCompanion;

  /// Initialize voice chat system
  Future<void> initialize({
    required MessageBloc messageBloc,
    String? azureApiKey,
    String? azureRegion,
  }) async {
    _messageBloc = messageBloc;
    
    try {
      // Initialize TTS service
      await _ttsService.initialize(
        azureApiKey: azureApiKey,
        azureRegion: azureRegion,
      );
      
      // Initialize speech recognition
      await _initializeSpeechToText();
      
      // Initialize audio player
      await _initializeAudioPlayer();
      
      // Request permissions
      await _requestPermissions();
      
      debugPrint('✅ Voice chat system initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Voice chat initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize speech-to-text
  Future<void> _initializeSpeechToText() async {
    final available = await _speechToText.initialize(
      onError: (error) => _handleSTTError(error),
      onStatus: (status) => _handleSTTStatus(status),
    );
    
    if (!available) {
      throw Exception('Speech recognition not available on this device');
    }
  }

  /// Initialize audio player
  Future<void> _initializeAudioPlayer() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerComplete.listen((_) => _onAudioPlaybackComplete());
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        _onAudioPlaybackComplete();
      }
    });
  }

  /// Request necessary permissions
  Future<void> _requestPermissions() async {
    // Use speech_to_text permission handling which is more reliable
    final available = await _speechToText.initialize();
    if (!available) {
      throw Exception('Speech recognition permissions denied or not available');
    }
    
    // Check recording permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission is required for voice chat');
    }
  }

  /// Start voice chat session with companion
  Future<void> startVoiceChat(AICompanion companion) async {
    if (_state != VoiceChatState.idle) {
      await stopVoiceChat();
    }
    
    _currentCompanion = companion;
    _setState(VoiceChatState.ready);
    
    debugPrint('🎤 Voice chat started with ${companion.name}');
    notifyListeners();
  }

  /// Stop voice chat session
  Future<void> stopVoiceChat() async {
    await _stopListening();
    await _stopAudioPlayback();
    
    _currentCompanion = null;
    _currentTranscription = '';
    _isProcessingVoice = false;
    _setState(VoiceChatState.idle);
    
    debugPrint('🔇 Voice chat stopped');
    notifyListeners();
  }

  /// Start listening for voice input (push-to-talk start)
  Future<void> startListening() async {
    if (_currentCompanion == null || _state == VoiceChatState.listening) {
      return;
    }
    
    try {
      // Stop any current audio playback
      await _stopAudioPlayback();
      
      // Start recording
      await _startRecording();
      
      // Start speech-to-text
      await _speechToText.listen(
        onResult: (result) => _onSpeechResult(result),
        listenFor: _maxRecordingDuration,
        pauseFor: _silenceThreshold,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
      
      _setState(VoiceChatState.listening);
      _startRecordingTimer();
      
      debugPrint('🎤 Started listening...');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Failed to start listening: $e');
      _setState(VoiceChatState.ready);
      notifyListeners();
    }
  }

  /// Stop listening for voice input (push-to-talk end)
  Future<void> stopListening() async {
    await _stopListening();
  }

  /// Internal stop listening method
  Future<void> _stopListening() async {
    if (_state != VoiceChatState.listening) return;
    
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    await _speechToText.stop();
    await _stopRecording();
    
    // Process the final transcription if available
    if (_currentTranscription.trim().isNotEmpty) {
      await _processVoiceMessage(_currentTranscription);
    }
    
    _setState(VoiceChatState.ready);
    notifyListeners();
  }

  /// Start audio recording
  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      await _recorder.start(RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 128000,
      ), path: 'voice_recording_${DateTime.now().millisecondsSinceEpoch}.aac');
    }
  }

  /// Stop audio recording
  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      debugPrint('📹 Recording saved to: $path');
      // Audio file could be used for additional processing if needed
    }
  }

  /// Start recording timer
  void _startRecordingTimer() {
    _recordingTimer = Timer(_maxRecordingDuration, () {
      debugPrint('⏰ Maximum recording time reached');
      stopListening();
    });
  }

  /// Handle speech recognition results
  void _onSpeechResult(result) {
    _currentTranscription = result.recognizedWords;
    debugPrint('🎯 Speech result: $_currentTranscription');
    notifyListeners();
  }

  /// Process voice message and generate AI response
  Future<void> _processVoiceMessage(String transcription) async {
    if (_currentCompanion == null || _messageBloc == null) return;
    
    _setState(VoiceChatState.processing);
    _isProcessingVoice = true;
    notifyListeners();
    
    try {
      // Create user voice message
      final userMessage = Message(
        messageFragments: [transcription],
        userId: 'current_user', // Replace with actual user ID
        companionId: _currentCompanion!.id,
        conversationId: 'current_conversation', // Replace with actual conversation ID
        isBot: false,
        created_at: DateTime.now(),
        type: MessageType.voice,
        voiceData: {
          'source': 'user_speech',
          'transcription_confidence': 0.9,
        },
      );
      
      // Send user message to bloc
      _messageBloc!.add(SendMessageEvent(message: userMessage));
      
      // Get conversation history
      final conversationHistory = await _getConversationHistory();
      
      // Generate AI response with voice context
      final aiResponse = await _geminiService.generateVoiceResponse(
        companionId: _currentCompanion!.id,
        userMessage: transcription,
        conversationHistory: conversationHistory,
        currentEmotion: null, // Could be enhanced with emotion detection
      );
      
      // Extract emotional context from AI response
      final emotionalContext = _geminiService.extractEmotionalContext(aiResponse);
      
      // Create AI voice message
      final aiMessage = Message(
        messageFragments: [aiResponse],
        userId: 'current_user',
        companionId: _currentCompanion!.id,
        conversationId: 'current_conversation',
        isBot: true,
        created_at: DateTime.now(),
        type: MessageType.voice,
        voiceData: {
          'source': 'ai_response',
          'emotional_context': emotionalContext?.primaryEmotion.toString(),
          'intensity': emotionalContext?.intensity,
        },
      );
      
      // Synthesize speech
      await _synthesizeAndPlayResponse(aiMessage, emotionalContext);
      
      // Send AI message to bloc
      _messageBloc!.add(SendMessageEvent(message: aiMessage));
      
    } catch (e) {
      debugPrint('❌ Voice message processing failed: $e');
      _setState(VoiceChatState.ready);
    } finally {
      _isProcessingVoice = false;
      notifyListeners();
    }
  }

  /// Synthesize AI response and play audio
  Future<void> _synthesizeAndPlayResponse(
    Message aiMessage, 
    EmotionalContext? emotion,
  ) async {
    try {
      _setState(VoiceChatState.synthesizing);
      notifyListeners();
      
      // Synthesize speech using TTS service
      final synthResult = await _ttsService.synthesizeSpeech(
        text: aiMessage.messageFragments.join(' '),
        companion: _currentCompanion!,
        emotion: emotion,
      );
      
      if (synthResult.success) {
        // Update message with audio URL
        aiMessage.toJson()['audio_url'] = synthResult.audioUrl;
        aiMessage.toJson()['voice_duration'] = synthResult.duration;
        aiMessage.toJson()['tts_engine'] = 'azure';
        aiMessage.toJson()['voice_settings'] = {
          'voice_name': synthResult.voiceProfile.voiceName,
          'language': synthResult.voiceProfile.language,
          'style': synthResult.voiceProfile.style,
        };
        
        // Play audio
        await _playAudioResponse(synthResult.audioData);
        
        debugPrint('✅ Voice response synthesized and playing');
      } else {
        debugPrint('❌ Voice synthesis failed: ${synthResult.error}');
        _setState(VoiceChatState.ready);
      }
      
    } catch (e) {
      debugPrint('❌ Voice synthesis error: $e');
      _setState(VoiceChatState.ready);
    }
  }

  /// Play audio response
  Future<void> _playAudioResponse(Uint8List audioData) async {
    try {
      _setState(VoiceChatState.playing);
      notifyListeners();
      
      await _audioPlayer.play(BytesSource(audioData));
      
    } catch (e) {
      debugPrint('❌ Audio playback failed: $e');
      _setState(VoiceChatState.ready);
      notifyListeners();
    }
  }

  /// Stop audio playback
  Future<void> _stopAudioPlayback() async {
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.stop();
    }
  }

  /// Handle audio playback completion
  void _onAudioPlaybackComplete() {
    debugPrint('🔊 Audio playback completed');
    _setState(VoiceChatState.ready);
    notifyListeners();
  }

  /// Get conversation history for context
  Future<List<Message>> _getConversationHistory() async {
    if (_messageBloc == null) return [];
    
    final currentState = _messageBloc!.state;
    if (currentState is MessageLoaded) {
      return currentState.messages;
    }
    
    return [];
  }

  /// Handle STT errors
  void _handleSTTError(error) {
    debugPrint('🎤 STT Error: ${error.errorMsg}');
    _setState(VoiceChatState.ready);
    notifyListeners();
  }

  /// Handle STT status changes
  void _handleSTTStatus(String status) {
    debugPrint('🎤 STT Status: $status');
    
    switch (status) {
      case 'listening':
        // Already handled in startListening
        break;
      case 'notListening':
        if (_state == VoiceChatState.listening) {
          stopListening();
        }
        break;
      case 'done':
        // Final result received
        break;
    }
  }

  /// Set internal state
  void _setState(VoiceChatState newState) {
    if (_state != newState) {
      _state = newState;
      debugPrint('🔄 Voice chat state: ${_state.toString()}');
    }
  }

  /// Check if voice chat is available
  bool get isAvailable => _ttsService.isAvailable;

  /// Get current companion voice description
  String getCompanionVoiceDescription() {
    if (_currentCompanion == null) return 'No companion selected';
    
    // Use a simple voice description based on companion
    switch (_currentCompanion!.id.toLowerCase()) {
      case 'emma':
        return 'Emma - Aria Neural (en-US)';
      case 'alex':
        return 'Alex - Guy Neural (en-US)';
      case 'sophia':
        return 'Sophia - Libby Neural (en-GB)';
      default:
        return '${_currentCompanion!.name} - Default Voice';
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _messageSubscription?.cancel();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

/// Voice chat states
enum VoiceChatState {
  idle,         // Not active
  ready,        // Ready for voice input
  listening,    // Recording voice input
  processing,   // Processing transcription
  synthesizing, // Converting text to speech
  playing,      // Playing audio response
}
