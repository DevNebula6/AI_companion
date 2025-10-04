import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:azure_speech_recognition_flutter/azure_speech_recognition_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'azure_speech_config.dart';

/// Simple and reliable Azure Speech service using the azure_speech_recognition_flutter plugin
/// Replaces our complex WebSocket implementation with a battle-tested plugin approach
class AzureSpeechPluginService {
  static final AzureSpeechPluginService _instance = AzureSpeechPluginService._internal();
  factory AzureSpeechPluginService() => _instance;
  AzureSpeechPluginService._internal();

  // Plugin instance
  AzureSpeechRecognitionFlutter? _speechRecognizer;
  
  // State management
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Recognition callbacks
  Function(String, bool)? _onTranscription;
  Function(String)? _onError;
  Function()? _onSessionStart;
  Function()? _onSessionEnd;
  
  // Recognition results
  final StreamController<SpeechRecognitionResult> _recognitionController = 
      StreamController<SpeechRecognitionResult>.broadcast();

  /// Initialize Azure Speech service with plugin
  Future<bool> initialize({
    required String azureSpeechKey,
    required String azureRegion,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint('🔄 Initializing Azure Speech Plugin Service...');
      debugPrint('📊 Azure API Key: ${azureSpeechKey.isNotEmpty ? '[SET - ${azureSpeechKey.length} chars]' : '[MISSING]'}');
      debugPrint('📊 Azure Region: $azureRegion');
      
      // Validate Azure configuration
      if (azureSpeechKey.isEmpty) {
        debugPrint('❌ Azure Speech Plugin: API key is empty');
        return false;
      }
      
      if (azureRegion.isEmpty) {
        debugPrint('❌ Azure Speech Plugin: Region is empty');
        return false;
      }

      // Initialize the plugin
      debugPrint('🔄 Azure Speech Plugin: Calling plugin initialize...');
      await AzureSpeechRecognitionFlutter.initialize(
        azureSpeechKey,
        azureRegion,
        lang: AzureSpeechConfig.defaultLocale,
        timeout: "3000", // 3 second silence timeout
      );
      debugPrint('✅ Azure Speech Plugin: Plugin initialize completed');

      // Create plugin instance
      _speechRecognizer = AzureSpeechRecognitionFlutter();

      // Set up recognition handlers
      _setupRecognitionHandlers();

      _isInitialized = true;
      debugPrint('✅ Azure Speech Plugin: Service initialized successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Azure Speech Plugin: Initialization failed - $e');
      debugPrint('❌ Azure Speech Plugin: Error type: ${e.runtimeType}');
      return false;
    }
  }

  /// Set up recognition result handlers
  void _setupRecognitionHandlers() {
    if (_speechRecognizer == null) return;

    // Handle partial/interim results (real-time transcription)
    _speechRecognizer!.setRecognitionResultHandler((text) {
      if (text.isNotEmpty) {
        debugPrint('📝 Azure Speech Plugin: Partial result - "$text"');
        _onTranscription?.call(text, false); // isInterim = true
        
        // Add to recognition stream
        _recognitionController.add(SpeechRecognitionResult(
          text: text,
          confidence: 0.8, // Default confidence for interim results
          isInterim: true,
        ));
      } else {
        debugPrint('📝 Azure Speech Plugin: Empty partial result received');
      }
    });

    // Handle final transcription results
    _speechRecognizer!.setFinalTranscription((text) {
      if (text.isNotEmpty) {
        debugPrint('📝 Azure Speech Plugin: Final result - "$text"');
        _onTranscription?.call(text, true); // isFinal = true
        
        // Add to recognition stream
        _recognitionController.add(SpeechRecognitionResult(
          text: text,
          confidence: 0.9, // Higher confidence for final results
          isInterim: false,
        ));
      } else {
        debugPrint('📝 Azure Speech Plugin: Empty final result received');
      }
    });

    // Handle recognition started
    _speechRecognizer!.setRecognitionStartedHandler(() {
      debugPrint('🎤 Azure Speech Plugin: Recognition started');
      _isListening = true;
      _onSessionStart?.call();
    });

    // Handle recognition stopped (important for continuous mode)
    _speechRecognizer!.setRecognitionStoppedHandler(() {
      debugPrint('🛑 Azure Speech Plugin: Recognition stopped');
      _isListening = false;
      _onSessionEnd?.call();
    });

    // Handle errors/exceptions
    _speechRecognizer!.onExceptionHandler((error) {
      debugPrint('❌ Azure Speech Plugin: Exception - $error');
      _onError?.call('Speech recognition error: $error');
    });

    debugPrint('✅ Azure Speech Plugin: Core recognition handlers configured');
  }

  /// Start continuous speech recognition
  Future<bool> startContinuousRecognition({
    required String sessionId,
    required Function(String, bool) onTranscription,
    Function(double)? onSoundLevel,
    Function(String)? onError,
    Function()? onSessionStart,
    Function()? onSessionEnd,
    String locale = 'en-US',
    String? customEndpointId,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ Azure Speech Plugin: Service not initialized');
      return false;
    }

    // Check microphone permission first
    final permissionStatus = await Permission.microphone.status;
    if (!permissionStatus.isGranted) {
      debugPrint('🎤 Azure Speech Plugin: Requesting microphone permission...');
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        debugPrint('❌ Azure Speech Plugin: Microphone permission denied');
        onError?.call('Microphone permission is required for speech recognition');
        return false;
      }
      debugPrint('✅ Azure Speech Plugin: Microphone permission granted');
    }

    // Check if already listening - if so, stop first
    try {
      final isCurrentlyListening = await AzureSpeechRecognitionFlutter.isContinuousRecognitionOn();
      debugPrint('📊 Azure Speech Plugin: Current recognition state - $isCurrentlyListening');
      
      if (isCurrentlyListening) {
        debugPrint('! Azure Speech Plugin: Already listening, stopping previous session');
        await stopContinuousRecognition();
        await Future.delayed(Duration(milliseconds: 500)); // Give it time to stop
      }
    } catch (e) {
      debugPrint('⚠️ Azure Speech Plugin: Error checking recognition state - $e');
    }

    try {
      _onTranscription = onTranscription;
      _onError = onError;
      _onSessionStart = onSessionStart;
      _onSessionEnd = onSessionEnd;

      debugPrint('🎤 Azure Speech Plugin: Starting continuous recognition for session $sessionId');
      debugPrint('🔧 Azure Speech Plugin: Language set to $locale');

      // Start continuous recording using the plugin
      AzureSpeechRecognitionFlutter.continuousRecording();
      
      // Verify it started
      await Future.delayed(Duration(milliseconds: 100));
      final isNowListening = await AzureSpeechRecognitionFlutter.isContinuousRecognitionOn();
      debugPrint('📊 Azure Speech Plugin: Recognition state after start - $isNowListening');

      if (isNowListening) {
        debugPrint('✅ Azure Speech Plugin: Started continuous recognition for session $sessionId');
        return true;
      } else {
        debugPrint('❌ Azure Speech Plugin: Failed to start recognition - state check failed');
        onError?.call('Failed to start continuous recognition - plugin state error');
        return false;
      }

    } catch (e) {
      debugPrint('❌ Azure Speech Plugin: Failed to start recognition - $e');
      onError?.call('Failed to start continuous recognition: $e');
      return false;
    }
  }

  /// Stop continuous recognition
  Future<void> stopContinuousRecognition() async {
    debugPrint('🛑 Azure Speech Plugin: Stopping continuous recognition...');

    try {
      // Check if currently listening
      final isCurrentlyListening = await AzureSpeechRecognitionFlutter.isContinuousRecognitionOn();
      
      if (isCurrentlyListening) {
        // Stop the plugin recognition using stopContinuousRecognition
        await AzureSpeechRecognitionFlutter.stopContinuousRecognition();
        debugPrint('✅ Azure Speech Plugin: Stopped continuous recognition');
      } else {
        debugPrint('📝 Azure Speech Plugin: Recognition was not running');
      }
      
      _isListening = false;
      _onSessionEnd?.call();

    } catch (e) {
      debugPrint('❌ Azure Speech Plugin: Error stopping recognition - $e');
    }
  }

  /// Simple voice recognition (stops after silence)
  Future<bool> simpleVoiceRecognition({
    required Function(String, bool) onTranscription,
    Function(String)? onError,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ Azure Speech Plugin: Service not initialized');
      return false;
    }

    try {
      _onTranscription = onTranscription;
      _onError = onError;

      debugPrint('🎤 Azure Speech Plugin: Starting simple voice recognition');
      AzureSpeechRecognitionFlutter.simpleVoiceRecognition();

      return true;
    } catch (e) {
      debugPrint('❌ Azure Speech Plugin: Simple recognition failed - $e');
      _onError?.call('Simple recognition failed: $e');
      return false;
    }
  }

  /// Get recognition results stream
  Stream<SpeechRecognitionResult> get recognitionStream => _recognitionController.stream;

  /// Check if currently listening
  bool get isStreaming => _isListening;

  /// Check if service is available
  bool get isAvailable => _isInitialized;

  /// Debug method to test plugin functionality
  Future<void> testPluginFunctionality() async {
    debugPrint('🔧 Azure Speech Plugin: Running functionality test...');
    
    try {
      // Test microphone permission
      final micPermission = await Permission.microphone.status;
      debugPrint('🔧 Microphone permission: $micPermission');
      
      // Test plugin state
      final isListening = await AzureSpeechRecognitionFlutter.isContinuousRecognitionOn();
      debugPrint('🔧 Plugin listening state: $isListening');
      
      // Test initialization state
      debugPrint('🔧 Service initialized: $_isInitialized');
      debugPrint('🔧 Internal listening state: $_isListening');
      
    } catch (e) {
      debugPrint('🔧 Plugin test error: $e');
    }
  }

  /// Simple test method to try a quick recognition
  Future<void> testSimpleRecognition() async {
    if (!_isInitialized) {
      debugPrint('❌ Cannot test - service not initialized');
      return;
    }

    debugPrint('🧪 Testing simple voice recognition...');
    
    try {
      // Set up test handlers
      _onTranscription = (text, isFinal) {
        debugPrint('🧪 Test result: "$text" (final: $isFinal)');
      };
      
      _onError = (error) {
        debugPrint('🧪 Test error: $error');
      };

      // Try simple recognition (auto-stops after silence)
      AzureSpeechRecognitionFlutter.simpleVoiceRecognition();
      debugPrint('🧪 Simple recognition started - speak now!');
      
    } catch (e) {
      debugPrint('🧪 Test failed: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    debugPrint('🧹 Azure Speech Plugin: Disposing service...');
    
    await stopContinuousRecognition();
    await _recognitionController.close();
    
    _isInitialized = false;
    _speechRecognizer = null;
    
    debugPrint('✅ Azure Speech Plugin: Service disposed');
  }
}

/// Speech recognition result model (keeping the same interface)
class SpeechRecognitionResult {
  final String text;
  final double confidence;
  final bool isInterim;
  final int? offset;
  final int? duration;

  const SpeechRecognitionResult({
    required this.text,
    required this.confidence,
    this.isInterim = false,
    this.offset,
    this.duration,
  });
}
