// ignore_for_file: non_constant_identifier_names
import 'package:flutter/foundation.dart';

enum MessageType {
  text,
  image,
  audio,
  voice,
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
  final String? id;
  final List<String> messageFragments;
  final String userId;
  final String companionId;
  final String conversationId;
  final bool isBot;
  final DateTime created_at;
  final MessageType type;
  final Map<String, dynamic> metadata;
  
  // AI specific fields
  final double? confidence;
  final Map<String, dynamic>? aiContext;
  final String? intent;
  final Map<String, dynamic>? entities;
  
  // Media content
  final String? mediaUrl;
  final MediaType? mediaType;
  final Map<String, dynamic>? mediaMetadata;

  const Message({
    this.id,
    required this.messageFragments,
    required this.userId,
    required this.companionId,
    required this.conversationId,
    required this.isBot,
    required this.created_at,
    this.type = MessageType.text,
    this.metadata = const {},
    this.confidence,
    this.aiContext,
    this.intent,
    this.entities,
    this.mediaUrl,
    this.mediaType,
    this.mediaMetadata,
  });

  // Create from database record (expects JSONB array format for message field)
  factory Message.fromJson(Map<String, dynamic> json) {
  try {
    // Parse message fragments from JSONB array format
    final messageData = json['message'];
    final List<String> fragments = messageData is List 
        ? List<String>.from(messageData)
        : <String>[]; // Empty list if no data

    return Message(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      messageFragments: fragments,
      userId: json['user_id']?.toString() ?? '',
      companionId: json['companion_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      isBot: json['is_bot'] ?? false,
      created_at: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      type: _parseMessageType(json['type']),
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : <String, dynamic>{},
      confidence: json['confidence']?.toDouble(),
      aiContext: json['ai_context'] != null 
          ? Map<String, dynamic>.from(json['ai_context'] as Map)
          : null,
      intent: json['intent']?.toString(),
      entities: json['entities'] != null 
          ? Map<String, dynamic>.from(json['entities'] as Map)
          : null,
      mediaUrl: json['media_url']?.toString(),
      mediaType: _parseMediaType(json['media_type']),
      mediaMetadata: json['media_metadata'] != null 
          ? Map<String, dynamic>.from(json['media_metadata'] as Map)
          : null,
    );
  } catch (e) {
    print('Error parsing message JSON: $e');
    // Return a default message on error
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      messageFragments: [] ,
      companionId:'',
      userId: '',
      conversationId: '',
      isBot: false,
      created_at: DateTime.now(),
    );
  }
}

  /// Parse message type from string
  static MessageType _parseMessageType(dynamic typeValue) {
    if (typeValue == null) return MessageType.text;
    
    final typeStr = typeValue.toString();
    for (final type in MessageType.values) {
      if (type.toString().split('.').last == typeStr) {
        return type;
      }
    }
    return MessageType.text;
  }

  /// Parse media type from string
  static MediaType? _parseMediaType(dynamic typeValue) {
    if (typeValue == null) return null;
    
    final typeStr = typeValue.toString();
    for (final type in MediaType.values) {
      if (type.toString().split('.').last == typeStr) {
        return type;
      }
    }
    return null;
  }

  // Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': messageFragments,
      'user_id': userId,
      'companion_id': companionId,
      'conversation_id': conversationId,
      'is_bot': isBot,
      'created_at': created_at.toIso8601String(),
      'type': type.toString().split('.').last,
      'metadata': metadata,
      'confidence': confidence,
      'ai_context': aiContext,
      'intent': intent,
      'entities': entities,
      'media_url': mediaUrl,
      'media_type': mediaType?.toString(),
      'media_metadata': mediaMetadata,
    };
  }

  Message copyWith({
    String? id,
    List<String>? text,
    Map<String, dynamic>? metadata,
    double? confidence,
    List<String>? references,
    Map<String, dynamic>? aiContext,
    String? intent,
    Map<String, dynamic>? entities,
    DateTime? created_at,
  }) {
    return Message(
      id: id ?? this.id,
      messageFragments: text ?? messageFragments,
      userId: userId,
      companionId: companionId,
      conversationId: conversationId,
      isBot: isBot,
      created_at: created_at ?? this.created_at,
      type: type,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
      confidence: confidence ?? this.confidence,
      aiContext: aiContext ?? this.aiContext,
      intent: intent ?? this.intent,
      entities: entities ?? this.entities,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaMetadata: mediaMetadata,
    );
  }

  // Enhanced helper methods for fragment identification
  bool get isFragment => metadata['is_fragment'] == true;
  bool get isCompleteVersion => metadata['is_complete_version'] == true;
  int? get fragmentIndex => metadata['fragment_index'] as int?;
  int? get totalFragments => metadata['total_fragments'] as int?;
  bool get isLastFragment => fragmentIndex != null && totalFragments != null && 
                           fragmentIndex == totalFragments! - 1;
  
  // NEW: Check if this is a temporary fragment (being animated)
  bool get isTemporaryFragment => id?.contains('_fragment_') == true && 
                                 !id!.startsWith('permanent_');
  
  // NEW: Get fragment creation timestamp
  int? get fragmentTimestamp => metadata['fragment_timestamp'] as int?;

  // Helper method to get complete message as string
  String get message => messageFragments.join(' ');
  
  // Helper method to check if message has multiple fragments
  bool get hasFragments => messageFragments.length > 1;

  // Voice helper methods (voice data stored in metadata)
  bool get isVoiceMessage => type == MessageType.voice || metadata['voice_session'] == true;
  String? get voiceTranscription => metadata['transcription']?.toString();
  String? get voiceResponse => metadata['ai_response']?.toString();
  double? get voiceDuration => metadata['duration']?.toDouble();
  int? get voiceFragmentsCount => metadata['fragments_count']?.toInt();
  String? get voiceSessionStatus => metadata['status']?.toString();
  
  // Voice conversation fragments (uses existing messageFragments field)
  List<String> get voiceConversationFragments => isVoiceMessage ? messageFragments : [];
  String get voiceConversationText => voiceConversationFragments.join('\n');

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