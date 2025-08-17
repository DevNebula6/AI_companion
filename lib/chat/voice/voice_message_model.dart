import 'package:flutter/foundation.dart';

/// Voice message model containing all voice-specific properties
/// This keeps the main Message model clean and database manageable
@immutable
class VoiceMessage {
  final String id;
  final VoiceMessageType type;
  final String? transcription;        // User speech-to-text result
  final String? aiResponse;          // AI text response (stored, not audio)
  final double? duration;            // Recording duration in seconds
  final DateTime timestamp;
  final VoiceQuality quality;
  final Map<String, dynamic>? metadata; // Additional voice-specific data

  const VoiceMessage({
    required this.id,
    required this.type,
    this.transcription,
    this.aiResponse,
    this.duration,
    required this.timestamp,
    this.quality = VoiceQuality.good,
    this.metadata,
  });

  /// Create from JSON (for database storage)
  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      id: json['id']?.toString() ?? '',
      type: _parseVoiceMessageType(json['type']),
      transcription: json['transcription']?.toString(),
      aiResponse: json['ai_response']?.toString(),
      duration: json['duration']?.toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      quality: _parseVoiceQuality(json['quality']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON (for database storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'transcription': transcription,
      'ai_response': aiResponse,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'quality': quality.name,
      'metadata': metadata,
    };
  }

  /// Parse voice message type from string
  static VoiceMessageType _parseVoiceMessageType(dynamic typeValue) {
    if (typeValue == null) return VoiceMessageType.user;
    
    final typeStr = typeValue.toString().toLowerCase();
    for (final type in VoiceMessageType.values) {
      if (type.name.toLowerCase() == typeStr) return type;
    }
    return VoiceMessageType.user;
  }

  /// Parse voice quality from string
  static VoiceQuality _parseVoiceQuality(dynamic qualityValue) {
    if (qualityValue == null) return VoiceQuality.good;
    
    final qualityStr = qualityValue.toString().toLowerCase();
    for (final quality in VoiceQuality.values) {
      if (quality.name.toLowerCase() == qualityStr) return quality;
    }
    return VoiceQuality.good;
  }

  /// Copy with new values
  VoiceMessage copyWith({
    String? id,
    VoiceMessageType? type,
    String? transcription,
    String? aiResponse,
    double? duration,
    DateTime? timestamp,
    VoiceQuality? quality,
    Map<String, dynamic>? metadata,
  }) {
    return VoiceMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      transcription: transcription ?? this.transcription,
      aiResponse: aiResponse ?? this.aiResponse,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      quality: quality ?? this.quality,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VoiceMessage{id: $id, type: $type, transcription: $transcription, duration: $duration}';
  }
}

/// Voice message types
enum VoiceMessageType {
  user,        // User voice input
  assistant,   // AI voice response
  system,      // System voice message
}

/// Voice quality levels for transcription accuracy
enum VoiceQuality {
  excellent,   // >95% confidence
  good,        // 80-95% confidence
  fair,        // 60-80% confidence
  poor,        // <60% confidence
}

/// Voice session model for managing real-time conversations
@immutable
class VoiceSession {
  final String id;
  final String userId;
  final String companionId;
  final List<String> conversationFragments; // User + AI responses in order
  final DateTime startTime;
  final DateTime? endTime;
  final VoiceSessionStatus status;
  final Map<String, dynamic>? sessionMetadata;

  const VoiceSession({
    required this.id,
    required this.userId,
    required this.companionId,
    required this.conversationFragments,
    required this.startTime,
    this.endTime,
    this.status = VoiceSessionStatus.active,
    this.sessionMetadata,
  });

  /// Create a new voice session
  factory VoiceSession.create({
    required String userId,
    required String companionId,
  }) {
    return VoiceSession(
      id: 'voice_session_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      companionId: companionId,
      conversationFragments: [],
      startTime: DateTime.now(),
      status: VoiceSessionStatus.active,
    );
  }

  /// Add a conversation fragment (user or AI response)
  VoiceSession addFragment(String fragment) {
    return copyWith(
      conversationFragments: [...conversationFragments, fragment],
    );
  }

  /// End the voice session
  VoiceSession endSession() {
    return copyWith(
      endTime: DateTime.now(),
      status: VoiceSessionStatus.completed,
    );
  }

  /// Convert to Message object for database storage
  /// This stores the entire voice conversation as a single message
  Map<String, dynamic> toMessageJson() {
    return {
      'id': id,
      'message': conversationFragments, // Store as JSONB array in messageFragments
      'user_id': userId,
      'companion_id': companionId,
      'conversation_id': '${userId}_$companionId',
      'is_bot': false, // Voice sessions are collaborative
      'created_at': startTime.toIso8601String(),
      'type': 'voice', // Use MessageType.voice
      'metadata': {
        'voice_session': true,
        'session_duration': endTime?.difference(startTime).inSeconds ?? 0,
        'fragments_count': conversationFragments.length,
        'status': status.name,
        ...?sessionMetadata,
      },
    };
  }

  /// Create from JSON
  factory VoiceSession.fromJson(Map<String, dynamic> json) {
    return VoiceSession(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      companionId: json['companion_id']?.toString() ?? '',
      conversationFragments: List<String>.from(json['message'] ?? []),
      startTime: DateTime.parse(json['created_at']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: _parseSessionStatus(json['metadata']?['status']),
      sessionMetadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Parse session status from string
  static VoiceSessionStatus _parseSessionStatus(dynamic statusValue) {
    if (statusValue == null) return VoiceSessionStatus.active;
    
    final statusStr = statusValue.toString().toLowerCase();
    for (final status in VoiceSessionStatus.values) {
      if (status.name.toLowerCase() == statusStr) return status;
    }
    return VoiceSessionStatus.active;
  }

  /// Copy with new values
  VoiceSession copyWith({
    String? id,
    String? userId,
    String? companionId,
    List<String>? conversationFragments,
    DateTime? startTime,
    DateTime? endTime,
    VoiceSessionStatus? status,
    Map<String, dynamic>? sessionMetadata,
  }) {
    return VoiceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companionId: companionId ?? this.companionId,
      conversationFragments: conversationFragments ?? this.conversationFragments,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      sessionMetadata: sessionMetadata ?? this.sessionMetadata,
    );
  }

  /// Get session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Check if session is active
  bool get isActive => status == VoiceSessionStatus.active;

  /// Get conversation as a single string for AI context
  String get conversationText => conversationFragments.join('\n');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Voice session statuses
enum VoiceSessionStatus {
  active,      // Currently ongoing
  completed,   // Successfully completed
  interrupted, // Interrupted by user
  error,       // Ended due to error
}
