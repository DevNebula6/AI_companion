// ignore_for_file: non_constant_identifier_names
import 'package:flutter/foundation.dart';

enum MessageType {
  text,
  image,
  audio,
  emoji,
  typing,
  systemMessage,
  action
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed
}

@immutable
class Message {
  final String id;
  final String message;
  final String userId;
  final String companionId;
  final bool isBot;
  final DateTime created_at;
  final MessageType type;
  final Map<String, dynamic> metadata;
  
  // AI specific fields
  final double? confidence;
  final List<String>? references;
  final Map<String, dynamic>? aiContext;
  final String? intent;
  final Map<String, dynamic>? entities;
  
  // Media content
  final String? mediaUrl;
  final MediaType? mediaType;
  final Map<String, dynamic>? mediaMetadata;

  const Message({
    required this.id,
    required this.message,
    required this.userId,
    required this.companionId, 
    required this.isBot,
    required this.created_at,
    this.type = MessageType.text,
    this.metadata = const {},
    this.confidence,
    this.references,
    this.aiContext,
    this.intent,
    this.entities,
    this.mediaUrl,
    this.mediaType,
    this.mediaMetadata,
  });

  // Create from database record
  factory Message.fromJson(Map<String, dynamic> json) {
  try {
    return Message(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: json['message']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      companionId: json['companion_id']?.toString() ?? '',
      isBot: json['is_bot'] ?? false,
      created_at: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      type: MessageType.text,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      confidence: json['confidence']?.toDouble(),
      references: (json['references'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      aiContext: json['ai_context'] as Map<String, dynamic>?,
      intent: json['intent']?.toString(),
      entities: json['entities'] as Map<String, dynamic>?,
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type'] != null 
          ? MediaType.values.firstWhere(
              (e) => e.toString() == json['media_type'],
              orElse: () => MediaType.image,
            )
          : null,
      mediaMetadata: json['media_metadata'] as Map<String, dynamic>?,
    );
  } catch (e) {
    print('Error parsing message JSON: $e');
    // Return a default message on error
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: 'Error loading message',
      companionId:'',
      userId: '',
      isBot: false,
      created_at: DateTime.now(),
    );
  }
}

  // Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'user_id': userId,
      'companion_id': companionId,
      'is_bot': isBot,
      'created_at': created_at.toIso8601String(),
      'type': type.toString(),
      'metadata': metadata,
      'confidence': confidence,
      'references': references,
      'ai_context': aiContext,
      'intent': intent,
      'entities': entities,
      'media_url': mediaUrl,
      'media_type': mediaType?.toString(),
      'media_metadata': mediaMetadata,
    };
  }

  Message copyWith({
    String? text,
    Map<String, dynamic>? metadata,
    double? confidence,
    List<String>? references,
    Map<String, dynamic>? aiContext,
    String? intent,
    Map<String, dynamic>? entities,
  }) {
    return Message(
      id: id,
      message: text ?? message,
      userId: userId,
      companionId: companionId,
      isBot: isBot,
      created_at: created_at,
      type: type,
      metadata: metadata ?? this.metadata,
      confidence: confidence ?? this.confidence,
      references: references ?? this.references,
      aiContext: aiContext ?? this.aiContext,
      intent: intent ?? this.intent,
      entities: entities ?? this.entities,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaMetadata: mediaMetadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum MediaType { image, video, audio, document }

// Extension for time-related utilities
extension MessageTime on Message {
  bool get isRecent => 
      DateTime.now().difference(created_at) < const Duration(minutes: 5);

 String get messageTime {
    int hour = created_at.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    
    // Format minutes with leading zero if needed
    final minutes = created_at.minute.toString().padLeft(2, '0');
    
    return '$hour:$minutes $period';
  }
  String get fullMessageTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(created_at.year, created_at.month, created_at.day);
    if (messageDate == today) {
      return messageTime;
    } else if (messageDate == yesterday) {
      return 'Yesterday, $messageTime';
    } else if (now.difference(created_at).inDays < 7) {
      return '${_getWeekday(created_at.weekday)}, $messageTime';
    } else {
      return '${created_at.day}/${created_at.month}/${created_at.year}, $messageTime';
    }
  }
  String _getWeekday(int day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
  String get timeAgo {
    final difference = DateTime.now().difference(created_at);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// Extension for AI-specific functionality
extension AIMessage on Message {
  bool get hasHighConfidence => confidence != null && confidence! > 0.8;
  bool get needsHumanReview => confidence != null && confidence! < 0.5;
  bool get hasContext => aiContext != null && aiContext!.isNotEmpty;
}