import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../Companion/ai_model.dart';
import '../../chat/voice/voice_bloc/voice_bloc.dart';
import '../../chat/voice/voice_bloc/voice_event.dart';
import '../../chat/voice/voice_bloc/voice_state.dart';
import '../AI_selection/companion_color.dart';
import 'voice_call_background.dart';
import 'widgets/audio_visualizer.dart';
import 'widgets/voice_call_controls.dart';
import 'widgets/companion_avatar.dart';

class VoiceCallScreen extends StatefulWidget {
  final AICompanion companion;
  final String conversationId;
  final String userId;

  const VoiceCallScreen({
    super.key,
    required this.companion,
    required this.conversationId,
    required this.userId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _companionAvatarController;
  late ColorScheme _companionColors;
  
  // Voice call state
  bool _isCallActive = false;
  bool _isUserSpeaking = false;
  bool _isCompanionSpeaking = false;
  bool _isMuted = false;
  String _currentTranscription = '';
  final Duration _callDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    
    _companionColors = getCompanionColorScheme(widget.companion);
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _companionAvatarController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Initialize voice system
    _initializeVoiceCall();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _companionAvatarController.dispose();
    super.dispose();
  }
  
  void _initializeVoiceCall() {
    // Initialize voice system for this companion
    context.read<VoiceBloc>().add(
      InitializeVoiceSystemEvent(
        userId: widget.userId,
        companion: widget.companion,
      ),
    );
  }
  
  void _startVoiceCall() {
    setState(() {
      _isCallActive = true;
    });
    
    _pulseController.repeat();
    _waveController.repeat();
    
    // Start voice session
    context.read<VoiceBloc>().add(
      StartVoiceSessionEvent(
        companion: widget.companion,
        userId: widget.userId,
        conversationId: widget.conversationId,
      ),
    );
    
    HapticFeedback.heavyImpact();
  }
  
  void _endVoiceCall() async {
    setState(() {
      _isCallActive = false;
      _isUserSpeaking = false;
      _isCompanionSpeaking = false;
    });
    
    _pulseController.stop();
    _waveController.stop();
    _companionAvatarController.reverse();
    
    HapticFeedback.heavyImpact();
    
    // End voice session (this will save to database)
    // Get current voice bloc state to access active session
    final voiceState = context.read<VoiceBloc>().state;
    if (voiceState is VoiceSessionActive) {
      context.read<VoiceBloc>().add(
        EndVoiceSessionEvent(
          sessionId: voiceState.sessionId,
          voiceSession: voiceState.session,
          shouldGenerateSummary: true,
        ),
      );
    }
    
    // Navigate back to chat
    if (mounted) {
      context.pop();
    }
  }
  
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    HapticFeedback.selectionClick();
    
    // TODO: Implement actual mute functionality
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<VoiceBloc, VoiceState>(
        listener: _handleVoiceStateChanges,
        child: AnimatedVoiceCallBackground(
          companion: widget.companion,
          isActive: _isCallActive,
          isUserSpeaking: _isUserSpeaking,
          isCompanionSpeaking: _isCompanionSpeaking,
          child: SafeArea(
            child: Column(
              children: [
                // Top bar with call info
                _buildTopBar(),
                
                // Main content area
                Expanded(
                  child: _buildMainContent(),
                ),
                
                // Bottom controls
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _handleVoiceStateChanges(BuildContext context, VoiceState state) {
    if (state is VoiceSessionActive) {
      setState(() {
        _isCallActive = true;
        _isUserSpeaking = state.isListening && !state.isProcessing;
        _isCompanionSpeaking = state.isSpeaking;
        _currentTranscription = state.currentTranscription;
      });
      
      // Start avatar animation when call becomes active
      if (!_companionAvatarController.isAnimating) {
        _companionAvatarController.forward();
      }
      
      // Control pulse animation based on speaking state
      if (_isCompanionSpeaking && !_pulseController.isAnimating) {
        _pulseController.repeat();
      } else if (!_isCompanionSpeaking && _pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else if (state is VoiceSessionCompleted) {
      // Call completed successfully
      _endVoiceCall();
    } else if (state is VoiceSessionError) {
      // Handle error
      _showErrorDialog(state.error);
    }
  }
  
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: _endVoiceCall,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const Spacer(),
          
          // Call status
          Column(
            children: [
              Text(
                _isCallActive ? 'Voice Call' : 'Connecting...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isCallActive)
                Text(
                  _formatCallDuration(_callDuration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          
          const Spacer(),
          
          // Settings button
          IconButton(
            onPressed: () {
              // TODO: Show voice call settings
            },
            icon: Icon(
              Icons.settings,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Companion name
        Text(
          widget.companion.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
        
        const SizedBox(height: 8),
        
        // Companion personality hint
        Text(
          widget.companion.personality.primaryTraits.take(2).join(' • '),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
        
        const SizedBox(height: 60),
        
        // Main companion avatar with audio visualizer
        _buildCompanionAvatarSection(),
        
        const SizedBox(height: 60),
        
        // Current transcription display
        _buildTranscriptionArea(),
        
        // Audio visualizer
        if (_isCallActive)
          AudioVisualizer(
            isUserSpeaking: _isUserSpeaking,
            isCompanionSpeaking: _isCompanionSpeaking,
            companionColors: _companionColors,
          ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
  
  Widget _buildCompanionAvatarSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse ring for companion speaking
        if (_isCompanionSpeaking)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 280 + (40 * _pulseController.value),
                height: 280 + (40 * _pulseController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _companionColors.primary.withOpacity(
                      0.3 * (1 - _pulseController.value),
                    ),
                    width: 3,
                  ),
                ),
              );
            },
          ),
        
        // Middle pulse ring
        if (_isCompanionSpeaking)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final offset = _pulseController.value * 0.5;
              return Container(
                width: 240 + (30 * offset),
                height: 240 + (30 * offset),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _companionColors.primary.withOpacity(
                      0.5 * (1 - offset),
                    ),
                    width: 2,
                  ),
                ),
              );
            },
          ),
        
        // Companion avatar
        AnimatedBuilder(
          animation: _companionAvatarController,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * _companionAvatarController.value),
              child: VoiceCallCompanionAvatar(
                companion: widget.companion,
                isActive: _isCallActive,
                isSpeaking: _isCompanionSpeaking,
                size: 200,
              ),
            );
          },
        ),
        
        // User speaking indicator (inner glow)
        if (_isUserSpeaking)
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildTranscriptionArea() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentTranscription.isNotEmpty
              ? Container(
                  key: ValueKey(_currentTranscription),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    _currentTranscription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
  
  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: VoiceCallControls(
        isCallActive: _isCallActive,
        isMuted: _isMuted,
        companionColors: _companionColors,
        onStartCall: _startVoiceCall,
        onEndCall: _endVoiceCall,
        onToggleMute: _toggleMute,
      ),
    );
  }
  
  String _formatCallDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Voice Call Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          error,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endVoiceCall();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
