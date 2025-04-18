import 'package:ai_companion/chat/conversation.dart';
// Import the singleton service
import 'package:ai_companion/chat/gemini/gemini_service.dart';

/// Enriches Conversation objects with relationship data from GeminiService.
class CompanionRelationshipTracker {
  // Access the singleton instance directly
  final GeminiService _geminiService = GeminiService();

  // Constructor no longer needs GeminiService passed in
  CompanionRelationshipTracker();

  /// Enrich a conversation with additional relationship data if it's the active one.
  /// Returns the original conversation if the companion is not active in GeminiService.
  Future<Conversation> enrichConversation(Conversation conversation) async {
    final userId = conversation.userId;
    final companionId = conversation.companionId;

    // Check if this companion is the currently active one in GeminiService
    final isActive = _geminiService.isCompanionInitialized(userId, companionId);

    if (isActive) {
      // Get relationship data directly from the service for the active companion
      final metrics = _geminiService.getRelationshipMetrics();

      // Get current values from conversation metadata
      final currentLevel = conversation.relationshipLevel; // Use getter from Conversation
      final currentEmotion = conversation.dominantEmotion; // Use getter from Conversation

      // Get new values from metrics
      final newLevel = metrics['level'] as int? ?? 1;
      final newEmotion = metrics['dominant_emotion'] as String?;

      // Update only if there's a change to avoid unnecessary object creation
      if (currentLevel != newLevel || currentEmotion != newEmotion) {
         final updatedMetadata = Map<String, dynamic>.from(conversation.metadata);
         updatedMetadata['relationship_level'] = newLevel;
         updatedMetadata['emotion'] = newEmotion;

         // Return enriched conversation using copyWith
         return conversation.copyWith(metadata: updatedMetadata);
      }
    }

    // Return original conversation if not active or no changes detected
    return conversation;
  }
}
