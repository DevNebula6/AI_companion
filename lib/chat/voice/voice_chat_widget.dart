import 'package:flutter/material.dart';
import '../message_bloc/message_bloc.dart';
import 'supabase_voice_chat_integration.dart';
import '../../Companion/ai_model.dart';

/// Supabase-native voice chat widget for AI companion conversations
class VoiceChatWidget extends StatefulWidget {
  final AICompanion companion;
  final MessageBloc messageBloc;
  
  const VoiceChatWidget({
    super.key,
    required this.companion,
    required this.messageBloc,
  });

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget> 
    with SingleTickerProviderStateMixin {
  
  late SupabaseVoiceChatIntegration _voiceChatIntegration;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize voice chat integration
    _voiceChatIntegration = SupabaseVoiceChatIntegration();
    
    // Setup animations for voice visualizations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeVoiceChat();
    
    // Listen to voice chat state changes
    _voiceChatIntegration.addListener(_onVoiceChatStateChanged);
  }
  
  Future<void> _initializeVoiceChat() async {
    try {
      await _voiceChatIntegration.initialize(
        messageBloc: widget.messageBloc,
        // Add your Azure API keys here when ready
        // azureApiKey: 'your_azure_api_key',
        // azureRegion: 'your_azure_region',
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice chat initialization failed: $e')),
      );
    }
  }
  
  void _onVoiceChatStateChanged() {
    setState(() {}); // Rebuild on state changes
  }
  
  /// Start voice conversation
  Future<void> _startVoiceChat() async {
    try {
      await _voiceChatIntegration.startVoiceChat(widget.companion);
      _animationController.repeat(reverse: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start voice chat: $e')),
      );
    }
  }
  
  /// Stop voice conversation
  Future<void> _stopVoiceChat() async {
    await _voiceChatIntegration.stopVoiceChat();
    _animationController.stop();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildVoiceChatHeader(),
          const SizedBox(height: 16),
          _buildVoiceVisualization(),
          const SizedBox(height: 16),
          _buildTranscriptionDisplay(),
          const SizedBox(height: 16),
          _buildVoiceControls(),
          const SizedBox(height: 8),
          _buildConnectionStatus(),
        ],
      ),
    );
  }
  
  /// Build voice chat header with companion info
  Widget _buildVoiceChatHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: widget.companion.avatarUrl.isNotEmpty
              ? NetworkImage(widget.companion.avatarUrl)
              : null,
          child: widget.companion.avatarUrl.isEmpty
              ? Text(widget.companion.name[0])
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.companion.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getVoiceDescription(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Build voice visualization (audio waveform/pulse effect)
  Widget _buildVoiceVisualization() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _getVisualizationColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getVisualizationColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _voiceChatIntegration.isListening ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getVisualizationColor(),
                  shape: BoxShape.circle,
                  boxShadow: _voiceChatIntegration.isListening
                      ? [
                          BoxShadow(
                            color: _getVisualizationColor().withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _getVisualizationIcon(),
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// Build transcription display
  Widget _buildTranscriptionDisplay() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Transcription',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _voiceChatIntegration.currentTranscription.isEmpty 
                  ? 'Speak to ${widget.companion.name}...'
                  : _voiceChatIntegration.currentTranscription,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build voice control buttons
  Widget _buildVoiceControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Start/Stop Voice Chat Button
        ElevatedButton.icon(
          onPressed: _isInitialized
              ? (_voiceChatIntegration.isIdle
                  ? _startVoiceChat
                  : _stopVoiceChat)
              : null,
          icon: Icon(_voiceChatIntegration.isIdle
              ? Icons.phone
              : Icons.phone_disabled),
          label: Text(_voiceChatIntegration.isIdle
              ? 'Start Chat'
              : 'End Chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _voiceChatIntegration.isIdle
                ? Theme.of(context).primaryColor
                : Colors.red,
          ),
        ),
        
        // Push-to-Talk Button (only show when chat is active)
        if (!_voiceChatIntegration.isIdle)
          GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            onTapCancel: () => _stopRecording(),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _voiceChatIntegration.isListening
                    ? Colors.red
                    : Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _voiceChatIntegration.isListening
                    ? Icons.mic
                    : Icons.mic_none,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }
  
  /// Build connection status indicator
  Widget _buildConnectionStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getStatusText(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
  
  // Helper methods
  String _getVoiceDescription() {
    // Use the voice description from the integration
    return _voiceChatIntegration.getCompanionVoiceDescription();
  }
  
  Color _getVisualizationColor() {
    if (_voiceChatIntegration.isListening) return Colors.red;
    if (_voiceChatIntegration.isPlaying) return Colors.green;
    if (!_voiceChatIntegration.isIdle) return Theme.of(context).primaryColor;
    return Colors.grey;
  }
  
  IconData _getVisualizationIcon() {
    if (_voiceChatIntegration.isListening) return Icons.mic;
    if (_voiceChatIntegration.isPlaying) return Icons.volume_up;
    if (_voiceChatIntegration.isProcessing) return Icons.hourglass_empty;
    if (!_voiceChatIntegration.isIdle) return Icons.phone;
    return Icons.phone_disabled;
  }
  
  Color _getStatusColor() {
    if (!_voiceChatIntegration.isIdle) return Colors.green;
    return Colors.red;
  }
  
  String _getStatusText() {
    if (!_isInitialized) return 'Initializing...';
    if (_voiceChatIntegration.isListening) return 'Listening...';
    if (_voiceChatIntegration.isProcessing) return 'Processing...';
    if (_voiceChatIntegration.isPlaying) return 'Playing response...';
    if (!_voiceChatIntegration.isIdle) return 'Ready';
    return 'Voice chat inactive';
  }
  
  // Control methods
  void _startRecording() {
    _voiceChatIntegration.startListening();
  }
  
  void _stopRecording() {
    _voiceChatIntegration.stopListening();
  }
  
  @override
  void dispose() {
    _voiceChatIntegration.removeListener(_onVoiceChatStateChanged);
    _animationController.dispose();
    super.dispose();
  }
}
