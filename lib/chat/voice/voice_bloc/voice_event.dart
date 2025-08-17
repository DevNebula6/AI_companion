import 'package:ai_companion/chat/voice/voice_bloc/voice_state.dart';
import 'package:equatable/equatable.dart';
import '../../../Companion/ai_model.dart';
import '../voice_message_model.dart';

/// Voice-specific events for real-time voice chat functionality
/// Separated from regular message events to prevent UI interference
abstract class VoiceEvent extends Equatable {
  const VoiceEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize voice chat system
class InitializeVoiceSystemEvent extends VoiceEvent {
  final String userId;
  final AICompanion companion;

  const InitializeVoiceSystemEvent({
    required this.userId,
    required this.companion,
  });

  @override
  List<Object?> get props => [userId, companion];
}

/// Start voice chat session (does not create message until session ends)
class StartVoiceSessionEvent extends VoiceEvent {
  final AICompanion companion;
  final String userId;
  final String conversationId;

  const StartVoiceSessionEvent({
    required this.companion,
    required this.userId,
    required this.conversationId,
  });

  @override
  List<Object?> get props => [companion, userId, conversationId];
}

/// Add conversation fragment during active session (real-time, no DB storage yet)
class AddVoiceFragmentEvent extends VoiceEvent {
  final String sessionId;
  final String fragment; // "User: Hello" or "Emma: Hi there!"
  final bool isUserFragment;

  const AddVoiceFragmentEvent({
    required this.sessionId,
    required this.fragment,
    required this.isUserFragment,
  });

  @override
  List<Object?> get props => [sessionId, fragment, isUserFragment];
}

/// Update real-time transcription (for UI display only)
class UpdateTranscriptionEvent extends VoiceEvent {
  final String sessionId;
  final String transcription;
  final bool isFinal;

  const UpdateTranscriptionEvent({
    required this.sessionId,
    required this.transcription,
    required this.isFinal,
  });

  @override
  List<Object?> get props => [sessionId, transcription, isFinal];
}

/// End voice session and create single database message with summary
class EndVoiceSessionEvent extends VoiceEvent {
  final String sessionId;
  final VoiceSession voiceSession;
  final bool shouldGenerateSummary;

  const EndVoiceSessionEvent({
    required this.sessionId,
    required this.voiceSession,
    this.shouldGenerateSummary = true,
  });

  @override
  List<Object?> get props => [sessionId, voiceSession, shouldGenerateSummary];
}

/// Generate AI summary for voice session (for efficient context usage)
class GenerateVoiceSessionSummaryEvent extends VoiceEvent {
  final String sessionId;
  final List<String> conversationFragments;
  final AICompanion companion;

  const GenerateVoiceSessionSummaryEvent({
    required this.sessionId,
    required this.conversationFragments,
    required this.companion,
  });

  @override
  List<Object?> get props => [sessionId, conversationFragments, companion];
}

/// Voice error handling
class VoiceErrorEvent extends VoiceEvent {
  final String sessionId;
  final String error;
  final VoiceErrorType errorType;

  const VoiceErrorEvent({
    required this.sessionId,
    required this.error,
    required this.errorType,
  });

  @override
  List<Object?> get props => [sessionId, error, errorType];
}

/// Request voice session context for AI generation
class RequestVoiceContextEvent extends VoiceEvent {
  final String userId;
  final String companionId;
  final int maxMessages; // Number of recent voice sessions to include

  const RequestVoiceContextEvent({
    required this.userId,
    required this.companionId,
    this.maxMessages = 5,
  });

  @override
  List<Object?> get props => [userId, companionId, maxMessages];
}

/// Voice session status update
class UpdateVoiceSessionStatusEvent extends VoiceEvent {
  final String sessionId;
  final VoiceSessionStatus status;
  final Map<String, dynamic>? additionalData;

  const UpdateVoiceSessionStatusEvent({
    required this.sessionId,
    required this.status,
    this.additionalData,
  });

  @override
  List<Object?> get props => [sessionId, status, additionalData];
}


/// Voice session lifecycle events
class VoiceSessionLifecycleEvent extends VoiceEvent {
  final String sessionId;
  final VoiceLifecycleAction action;
  final Map<String, dynamic>? metadata;

  const VoiceSessionLifecycleEvent({
    required this.sessionId,
    required this.action,
    this.metadata,
  });

  @override
  List<Object?> get props => [sessionId, action, metadata];
}

enum VoiceLifecycleAction {
  sessionStarted,
  listeningStarted,
  userSpeaking,
  userStoppedSpeaking,
  aiResponding,
  aiResponseComplete,
  sessionPaused,
  sessionResumed,
  sessionEnding,
  sessionCompleted,
}
