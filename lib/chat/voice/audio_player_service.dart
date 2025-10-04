import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'supabase_tts_service.dart';

/// Audio playback service for TTS and voice recordings
/// Manages audio focus, playback queue, and voice session coordination
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentlyPlaying;
  
  // Audio focus and coordination
  bool _hasAudioFocus = true;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  
  // TTS audio queue for conversation flow
  final List<AudioQueueItem> _audioQueue = [];
  bool _isProcessingQueue = false;
  
  // Callbacks for voice coordination
  Function()? _onPlaybackStart;
  Function()? _onPlaybackComplete;
  Function(String)? _onPlaybackError;
  Function(Duration)? _onPositionChanged;
  Function(Duration)? _onDurationChanged;

  /// Initialize audio player service
  Future<bool> initialize({
    Function()? onPlaybackStart,
    Function()? onPlaybackComplete,
    Function(String)? onPlaybackError,
    Function(Duration)? onPositionChanged,
    Function(Duration)? onDurationChanged,
  }) async {
    if (_isInitialized) return true;

    try {
      // Set callbacks
      _onPlaybackStart = onPlaybackStart;
      _onPlaybackComplete = onPlaybackComplete;
      _onPlaybackError = onPlaybackError;
      _onPositionChanged = onPositionChanged;
      _onDurationChanged = onDurationChanged;

      // Configure audio player for voice chat (simultaneous recording and playback)
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord, // Required for voice chat
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.allowAirPlay,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck, // Allow ducking for voice
        ),
      ));

      // Set up state listeners
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(_handlePlayerStateChange);
      _positionSubscription = _audioPlayer.onPositionChanged.listen(_handlePositionChange);
      _durationSubscription = _audioPlayer.onDurationChanged.listen(_handleDurationChange);

      _isInitialized = true;
      debugPrint('✅ AudioPlayer: Service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayer: Initialization failed: $e');
      return false;
    }
  }

  /// Play TTS audio data directly from memory
  Future<bool> playTTSAudio({
    required Uint8List audioData,
    required String sessionId,
    String? companionName,
    bool skipQueue = false,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Create queue item
      final queueItem = AudioQueueItem(
        id: '${sessionId}_${DateTime.now().millisecondsSinceEpoch}',
        audioData: audioData,
        sessionId: sessionId,
        companionName: companionName ?? 'Companion',
        type: AudioQueueItemType.tts,
      );

      if (skipQueue || _audioQueue.isEmpty) {
        // Play immediately
        return await _playAudioItem(queueItem);
      } else {
        // Add to queue
        _audioQueue.add(queueItem);
        debugPrint('🎵 AudioPlayer: Added TTS audio to queue (${_audioQueue.length} items)');
        
        if (!_isProcessingQueue) {
          _processAudioQueue();
        }
        return true;
      }
    } catch (e) {
      debugPrint('❌ AudioPlayer: Play TTS audio failed: $e');
      _onPlaybackError?.call('Failed to play TTS audio: $e');
      return false;
    }
  }

  /// Play audio from VoiceSynthesisResult
  Future<bool> playVoiceSynthesisResult({
    required VoiceSynthesisResult result,
    required String sessionId,
    String? companionName,
  }) async {
    if (!result.success || result.audioData.isEmpty) {
      debugPrint('❌ AudioPlayer: Invalid voice synthesis result');
      return false;
    }

    return await playTTSAudio(
      audioData: result.audioData,
      sessionId: sessionId,
      companionName: companionName,
    );
  }

  /// Play audio item from queue or directly
  Future<bool> _playAudioItem(AudioQueueItem item) async {
    try {
      debugPrint('🎵 AudioPlayer: Playing ${item.type.name} audio for ${item.companionName}');
      
      // Save audio data to temporary file
      final tempFile = await _saveAudioDataToFile(item.audioData, item.id);
      
      // Stop any current playback
      await stopPlayback();
      
      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      
      _isPlaying = true;
      _currentlyPlaying = item.id;
      _onPlaybackStart?.call();
      
      return true;
    } catch (e) {
      debugPrint('❌ AudioPlayer: Play audio item failed: $e');
      _onPlaybackError?.call('Failed to play audio: $e');
      return false;
    }
  }

  /// Save audio data to temporary file for playback
  Future<File> _saveAudioDataToFile(Uint8List audioData, String itemId) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/tts_audio_$itemId.mp3');
    
    // Clean up old temp files if they exist
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    
    await tempFile.writeAsBytes(audioData);
    return tempFile;
  }

  /// Process audio queue sequentially
  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue || _audioQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    debugPrint('🎵 AudioPlayer: Processing audio queue (${_audioQueue.length} items)');

    while (_audioQueue.isNotEmpty && _hasAudioFocus) {
      final item = _audioQueue.removeAt(0);
      
      final success = await _playAudioItem(item);
      if (success) {
        // Wait for playback to complete
        await _waitForPlaybackCompletion();
      }
      
      // Small delay between audio items
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isProcessingQueue = false;
    debugPrint('🎵 AudioPlayer: Audio queue processing completed');
  }

  /// Wait for current audio playback to complete
  Future<void> _waitForPlaybackCompletion() async {
    final completer = Completer<void>();
    
    late StreamSubscription<PlayerState> subscription;
    subscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        subscription.cancel();
        completer.complete();
      }
    });
    
    // Timeout after 30 seconds to prevent hanging
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription.cancel();
        debugPrint('⚠️ AudioPlayer: Playback timeout - forcing completion');
      },
    );
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
        _currentlyPlaying = null;
        debugPrint('🛑 AudioPlayer: Playback stopped');
      }
    } catch (e) {
      debugPrint('❌ AudioPlayer: Stop playback error: $e');
    }
  }

  /// Pause current playback
  Future<void> pausePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        debugPrint('⏸️ AudioPlayer: Playback paused');
      }
    } catch (e) {
      debugPrint('❌ AudioPlayer: Pause playback error: $e');
    }
  }

  /// Resume paused playback
  Future<void> resumePlayback() async {
    try {
      await _audioPlayer.resume();
      debugPrint('▶️ AudioPlayer: Playback resumed');
    } catch (e) {
      debugPrint('❌ AudioPlayer: Resume playback error: $e');
    }
  }

  /// Clear audio queue
  void clearQueue() {
    _audioQueue.clear();
    debugPrint('🗑️ AudioPlayer: Audio queue cleared');
  }

  /// Request audio focus (for coordinating with STT)
  void requestAudioFocus() {
    _hasAudioFocus = true;
    debugPrint('🎤 AudioPlayer: Audio focus acquired');
  }

  /// Release audio focus (when STT needs to listen)
  void releaseAudioFocus() {
    _hasAudioFocus = false;
    debugPrint('🔇 AudioPlayer: Audio focus released');
  }

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState state) {
    debugPrint('🎵 AudioPlayer: State changed to ${state.name}');
    
    switch (state) {
      case PlayerState.playing:
        _isPlaying = true;
        break;
      case PlayerState.paused:
        _isPlaying = false;
        break;
      case PlayerState.stopped:
        _isPlaying = false;
        _currentlyPlaying = null;
        _cleanupTempFiles();
        break;
      case PlayerState.completed:
        _isPlaying = false;
        _currentlyPlaying = null;
        _onPlaybackComplete?.call();
        _cleanupTempFiles();
        
        // Process next item in queue
        if (_audioQueue.isNotEmpty && !_isProcessingQueue) {
          Future.delayed(const Duration(milliseconds: 200), _processAudioQueue);
        }
        break;
      case PlayerState.disposed:
        _isPlaying = false;
        _currentlyPlaying = null;
        break;
    }
  }

  /// Handle position changes
  void _handlePositionChange(Duration position) {
    _onPositionChanged?.call(position);
  }

  /// Handle duration changes
  void _handleDurationChange(Duration? duration) {
    if (duration != null) {
      _onDurationChanged?.call(duration);
    }
  }

  /// Clean up temporary audio files
  Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync().where((file) => 
        file.path.contains('tts_audio_') && file.path.endsWith('.mp3'));
      
      for (final file in files) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('⚠️ AudioPlayer: Failed to delete temp file ${file.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ AudioPlayer: Cleanup temp files error: $e');
    }
  }

  /// Get current playback position
  Future<Duration> getCurrentPosition() async {
    try {
      return await _audioPlayer.getCurrentPosition() ?? Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Get audio duration
  Future<Duration> getDuration() async {
    try {
      return await _audioPlayer.getDuration() ?? Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Check if service is available
  bool get isAvailable => _isInitialized;

  /// Get queue size
  int get queueSize => _audioQueue.length;

  /// Get current audio item ID
  String? get currentlyPlaying => _currentlyPlaying;

  /// Dispose resources
  Future<void> dispose() async {
    await stopPlayback();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _audioPlayer.dispose();
    clearQueue();
    await _cleanupTempFiles();
    _isInitialized = false;
    debugPrint('🧹 AudioPlayer: Service disposed');
  }
}

/// Audio queue item for TTS playback management
class AudioQueueItem {
  final String id;
  final Uint8List audioData;
  final String sessionId;
  final String companionName;
  final AudioQueueItemType type;
  final DateTime timestamp;

  AudioQueueItem({
    required this.id,
    required this.audioData,
    required this.sessionId,
    required this.companionName,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  AudioQueueItem.now({
    required this.id,
    required this.audioData,
    required this.sessionId,
    required this.companionName,
    required this.type,
  }) : timestamp = DateTime.now();
}

/// Audio queue item types
enum AudioQueueItemType {
  tts,        // Text-to-speech audio
  recording,  // Voice recording playback
  system,     // System audio notifications
}
