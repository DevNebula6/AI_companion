import 'package:equatable/equatable.dart';
import '../voice_message_model.dart';
import '../../../Companion/ai_model.dart';

/// Voice-specific states for real-time voice chat functionality
/// Separated from regular message states to prevent UI interference
abstract class VoiceState extends Equatable {
  const VoiceState();

  @override
  List<Object?> get props => [];
}

/// Initial voice system state
class VoiceInitial extends VoiceState {}

/// Voice system initializing
class VoiceInitializing extends VoiceState {
  final String userId;
  final AICompanion companion;

  const VoiceInitializing({
    required this.userId,
    required this.companion,
  });

  @override
  List<Object?> get props => [userId, companion];
}

/// Voice system ready for use
class VoiceReady extends VoiceState {
  final String userId;
  final AICompanion companion;
  final bool hasMicrophonePermission;
  final bool hasTTSAvailable;

  const VoiceReady({
    required this.userId,
    required this.companion,
    required this.hasMicrophonePermission,
    required this.hasTTSAvailable,
  });

  @override
  List<Object?> get props => [userId, companion, hasMicrophonePermission, hasTTSAvailable];
}

/// Active voice session state
class VoiceSessionActive extends VoiceState {
  final String sessionId;
  final AICompanion companion;
  final VoiceSession session;
  final String currentTranscription;
  final bool isListening;
  final bool isSpeaking;
  final bool isProcessing;
  final List<String> realtimeFragments; // Live conversation during session

  const VoiceSessionActive({
    required this.sessionId,
    required this.companion,
    required this.session,
    this.currentTranscription = '',
    this.isListening = false,
    this.isSpeaking = false,
    this.isProcessing = false,
    this.realtimeFragments = const [],
  });

  @override
  List<Object?> get props => [
    sessionId,
    companion,
    session,
    currentTranscription,
    isListening,
    isSpeaking,
    isProcessing,
    realtimeFragments,
  ];

  /// Create updated state with new values
  VoiceSessionActive copyWith({
    String? currentTranscription,
    bool? isListening,
    bool? isSpeaking,
    bool? isProcessing,
    List<String>? realtimeFragments,
    VoiceSession? session,
  }) {
    return VoiceSessionActive(
      sessionId: sessionId,
      companion: companion,
      session: session ?? this.session,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isProcessing: isProcessing ?? this.isProcessing,
      realtimeFragments: realtimeFragments ?? this.realtimeFragments,
    );
  }

  /// Get conversation progress info
  int get totalExchanges => realtimeFragments.length;
  Duration get sessionDuration => DateTime.now().difference(session.startTime);
  bool get hasConversation => realtimeFragments.isNotEmpty;
}

/// Voice session ending and summarizing
class VoiceSessionEnding extends VoiceState {
  final String sessionId;
  final AICompanion companion;
  final VoiceSession session;
  final bool isGeneratingSummary;
  final String? summaryProgress;

  const VoiceSessionEnding({
    required this.sessionId,
    required this.companion,
    required this.session,
    this.isGeneratingSummary = false,
    this.summaryProgress,
  });

  @override
  List<Object?> get props => [sessionId, companion, session, isGeneratingSummary, summaryProgress];
}

/// Voice session completed and saved
class VoiceSessionCompleted extends VoiceState {
  final String sessionId;
  final AICompanion companion;
  final VoiceSession completedSession;
  final String? conversationSummary;
  final String? messageId; // ID of the message created in database (null if session was discarded)
  final SessionStats stats;

  const VoiceSessionCompleted({
    required this.sessionId,
    required this.companion,
    required this.completedSession,
    this.conversationSummary,
    this.messageId,
    required this.stats,
  });

  @override
  List<Object?> get props => [
    sessionId,
    companion,
    completedSession,
    conversationSummary,
    messageId,
    stats,
  ];
}

/// Voice session error state
class VoiceSessionError extends VoiceState {
  final String sessionId;
  final String error;
  final VoiceErrorType errorType;
  final bool canRetry;
  final VoiceSession? partialSession; // Session data if available

  const VoiceSessionError({
    required this.sessionId,
    required this.error,
    required this.errorType,
    this.canRetry = true,
    this.partialSession,
  });

  @override
  List<Object?> get props => [sessionId, error, errorType, canRetry, partialSession];
}

/// Voice context loaded for AI generation
class VoiceContextLoaded extends VoiceState {
  final String userId;
  final String companionId;
  final List<VoiceSessionContext> recentSessions;
  final String contextSummary; // Combined summary for efficient AI context

  const VoiceContextLoaded({
    required this.userId,
    required this.companionId,
    required this.recentSessions,
    required this.contextSummary,
  });

  @override
  List<Object?> get props => [userId, companionId, recentSessions, contextSummary];
}

/// Voice session summary generated
class VoiceSessionSummaryGenerated extends VoiceState {
  final String sessionId;
  final String summary;
  final Map<String, dynamic> summaryMetadata;

  const VoiceSessionSummaryGenerated({
    required this.sessionId,
    required this.summary,
    required this.summaryMetadata,
  });

  @override
  List<Object?> get props => [sessionId, summary, summaryMetadata];
}

/// Voice error types from events
enum VoiceErrorType {
  microphonePermission,
  speechRecognitionFailed,
  ttsGenerationFailed,
  networkError,
  sessionTimeout,
  aiResponseFailed,
  summaryGenerationFailed,
  storageError,
}

/// Session statistics for analytics
class SessionStats {
  final Duration totalDuration;
  final int totalExchanges;
  final int userFragments;
  final int aiFragments;
  final double averageResponseTime;
  final bool summaryGenerated;

  const SessionStats({
    required this.totalDuration,
    required this.totalExchanges,
    required this.userFragments,
    required this.aiFragments,
    required this.averageResponseTime,
    required this.summaryGenerated,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalDuration': totalDuration.inSeconds,
      'totalExchanges': totalExchanges,
      'userFragments': userFragments,
      'aiFragments': aiFragments,
      'averageResponseTime': averageResponseTime,
      'summaryGenerated': summaryGenerated,
    };
  }

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      totalDuration: Duration(seconds: json['totalDuration'] ?? 0),
      totalExchanges: json['totalExchanges'] ?? 0,
      userFragments: json['userFragments'] ?? 0,
      aiFragments: json['aiFragments'] ?? 0,
      averageResponseTime: (json['averageResponseTime'] ?? 0.0).toDouble(),
      summaryGenerated: json['summaryGenerated'] ?? false,
    );
  }
}

/// Voice session context for AI generation
class VoiceSessionContext {
  final String sessionId;
  final DateTime timestamp;
  final String? summary; // Preferred context if available
  final List<String>? fragments; // Fallback if no summary
  final SessionStats stats;

  const VoiceSessionContext({
    required this.sessionId,
    required this.timestamp,
    this.summary,
    this.fragments,
    required this.stats,
  });

  /// Get context text for AI (summary preferred, fragments as fallback)
  String get contextText {
    if (summary != null && summary!.isNotEmpty) {
      return 'Previous voice conversation summary: $summary';
    } else if (fragments != null && fragments!.isNotEmpty) {
      return 'Previous voice conversation: ${fragments!.join('\n')}';
    } else {
      return 'Previous voice conversation (${stats.totalExchanges} exchanges)';
    }
  }

  /// Check if this context uses efficient summary
  bool get usesEfficientContext => summary != null && summary!.isNotEmpty;
}
