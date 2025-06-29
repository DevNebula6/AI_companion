import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:collection/collection.dart'; // For ListEquality

class CompanionState {
  final String userId;
  final String companionId; // Store only the ID
  final List<Content> history;
  final Map<String, dynamic> userMemory;
  final Map<String, dynamic> conversationMetadata;
  int relationshipLevel; // Make mutable
  String? dominantEmotion; // Make mutable

  // Transient fields, not stored directly in JSON, recreated on load
  ChatSession? chatSession;
  AICompanion? _companion; // Loaded separately when needed

  static const int maxStoredHistoryLength = 30; // Limit history stored in JSON
  
  AICompanion get companion {
    if (_companion == null) {
      throw StateError('Companion not loaded. Call loadCompanion() first.');
    }
    return _companion!;
  }
  
  // **FIXED: Companion setter**
  set companion(AICompanion comp) => _companion = comp;
  bool get hasCompanion => _companion != null;

  CompanionState({
    required this.userId,
    required this.companionId,
    required this.history,
    required this.userMemory,
    required this.conversationMetadata,
    required this.relationshipLevel,
    this.dominantEmotion,
    this.chatSession, // Optional initial session
  })
  {
    if (relationshipLevel < 1 || relationshipLevel > 5) {
      relationshipLevel = 1; // Default to 1 if invalid
      print('Warning: Invalid relationshipLevel corrected to 1.');
    }
    // Note: History trimming for the *active* session happens in GeminiService
  }
  Future<void> loadCompanion(AICompanion comp) async {
    if (comp.id != companionId) {
      throw ArgumentError('Companion ID mismatch: expected $companionId, got ${comp.id}');
    }
    _companion = comp;
  }

  /// Serializable version for persistent storage (stores limited history)
  Map<String, dynamic> toJson() {
    final historyToStore = history.length <= maxStoredHistoryLength
        ? history
        : history.sublist(history.length - maxStoredHistoryLength);

    final storableHistory = historyToStore.map((content) {
      final text = content.parts.whereType<TextPart>().map((p) => p.text).join('\n');
      return {
        'role': content.role ?? 'user',
        'text': text,
      };
    }).toList();

    return {
      'version': GeminiService.storageVersion,
      'userId': userId,
      'companionId': companionId,
      'history': storableHistory,
      'userMemory': userMemory,
      'metadata': conversationMetadata,
      'relationshipLevel': relationshipLevel,
      'dominantEmotion': dominantEmotion,
    };
  }


  /// Create state from stored JSON data
  factory CompanionState.fromJson(Map<String, dynamic> json) {
    final List<Content> history = [];
    if (json['history'] is List) {
      for (var item in (json['history'] as List)) {
        if (item is Map && item['role'] is String && item['text'] is String) {
          final role = item['role'] as String;
          final text = item['text'] as String;
          history.add(Content(role, [TextPart(text)]));
        }
      }
    }

    return CompanionState(
      userId: json['userId'] ?? '',
      companionId: json['companionId'] ?? '',
      history: history,
      userMemory: Map<String, dynamic>.from(json['userMemory'] ?? {}),
      conversationMetadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      relationshipLevel: (json['relationshipLevel'] as int?) ?? 1,
      dominantEmotion: json['dominantEmotion'] as String?,
      //Companion loaded separately**
    );
  }

  // --- Helper Methods ---

  /// Adds content to history (in-memory only, trimming happens in GeminiService)
  void addHistory(Content content) {
    history.add(content);
  }

  /// Updates a specific memory item
  void updateMemory(String key, dynamic value) {
    userMemory[key] = value;
  }

  /// Updates a specific metadata item
  void updateMetadata(String key, dynamic value) {
    conversationMetadata[key] = value;
  }

  // --- Equality and HashCode ---
  // Useful for comparing states if needed, e.g., before saving
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          companionId == other.companionId &&
          const MapEquality().equals(userMemory, other.userMemory) &&
          const MapEquality().equals(conversationMetadata, other.conversationMetadata) &&
          relationshipLevel == other.relationshipLevel &&
          dominantEmotion == other.dominantEmotion &&
          // Compare history content for equality
          const ListEquality().equals(history, other.history);

  @override
  int get hashCode =>
      userId.hashCode ^
      companionId.hashCode ^
      const MapEquality().hash(userMemory) ^
      const MapEquality().hash(conversationMetadata) ^
      relationshipLevel.hashCode ^
      dominantEmotion.hashCode ^
      // Include history in hash code
      const ListEquality().hash(history);
}
