import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';

/// Tracks relationship states between users and companions
class CompanionRelationshipTracker {
  final GeminiService _geminiService;
  
  CompanionRelationshipTracker(this._geminiService);
  
  /// Enrich a conversation with additional relationship data
  Future<Conversation> enrichConversation(Conversation conversation) async {
    final userId = conversation.userId;
    final companionId = conversation.companionId;
    
    // Check if this companion is initialized in GeminiService
    final isInitialized = _geminiService.isInitialized && 
                          _geminiService.isCompanionInitialized(userId, companionId);
    
    if (isInitialized) {
      // Get relationship data
      final metrics = _geminiService.getRelationshipMetrics();
      
      // Create updated metadata
      final updatedMetadata = Map<String, dynamic>.from(conversation.metadata);
      updatedMetadata['relationship_level'] = metrics['level'];
      updatedMetadata['emotion'] = metrics['dominant_emotion'];
      
      // Return enriched conversation
      return conversation.copyWith(metadata: updatedMetadata);
    }
    
    return conversation;
  }
}
