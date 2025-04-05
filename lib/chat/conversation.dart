import 'package:ai_companion/Companion/ai_model.dart';

class Conversation {
  final String id;
  final String userId;
  final String companionId;
  final String? lastMessage;
  final int unreadCount;
  final DateTime lastUpdated;
  final bool isPinned;

  const Conversation({
    required this.id,
    required this.userId,
    required this.companionId,
    this.lastMessage,
    this.unreadCount = 0,
    required this.lastUpdated,
    this.isPinned = false,
  });

  Conversation copyWith({
    String? id,
    String? companionId,
    String? userId,
    String? lastMessage,
    int? unreadCount,
    DateTime? lastUpdated,
    bool? isPinned,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companionId: companionId ?? this.companionId,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  // Create from database record
  factory Conversation.fromJson(Map<String, dynamic> json, AICompanion companion) {
    return Conversation(
      id: json['id'],
      userId: json['user_id'],
      companionId: json['companion_id'] ?? companion.id,
      lastMessage: json['last_message']?.toString(),
      unreadCount: json['unread_count'] ?? 0,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : DateTime.now(),
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'companion_id': companionId,
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'last_updated': lastUpdated.toIso8601String(),
      'is_pinned': isPinned,
    };
  }
}