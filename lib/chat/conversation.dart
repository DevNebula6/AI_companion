import 'package:ai_companion/Companion/ai_model.dart';

class Conversation {
  final String id;
  final String userId;
  final String companionId;
  final String? companionName; 
  final String? lastMessage;
  final int unreadCount;
  final DateTime lastUpdated;
  final bool isPinned;
  final Map<String, dynamic> metadata; // Added metadata field

  const Conversation({
    required this.id,
    required this.userId,
    required this.companionId,
    this.companionName,
    this.lastMessage,
    this.unreadCount = 0,
    required this.lastUpdated,
    this.isPinned = false,
    this.metadata = const {}, // Default to empty map
  });

  Conversation copyWith({
    String? id,
    String? companionId,
    String? companionName,
    String? userId,
    String? lastMessage,
    int? unreadCount,
    DateTime? lastUpdated,
    bool? isPinned,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companionId: companionId ?? this.companionId,
      companionName: companionName ?? this.companionName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata ?? this.metadata,
    );
  }

  // Create from database record
  factory Conversation.fromJson(Map<String, dynamic> json, AICompanion companion) {
    return Conversation(
      id: json['id'],
      userId: json['user_id'],
      companionId: json['companion_id'] ?? companion.id,
      companionName: json['companion_name'] ?? companion.name,
      lastMessage: json['last_message']?.toString(),
      unreadCount: json['unread_count'] ?? 0,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : DateTime.now(),
      isPinned: json['is_pinned'] ?? false,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'companion_id': companionId,
      'companion_name': companionName,
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'last_updated': lastUpdated.toIso8601String(),
      'is_pinned': isPinned,
      'metadata': metadata,
    };
  }
  
  // Helper to get relationship level
  int get relationshipLevel => (metadata['relationship_level'] as int?) ?? 1;
  
  // Helper to get dominant emotion
  String? get dominantEmotion => metadata['emotion'] as String?;
}