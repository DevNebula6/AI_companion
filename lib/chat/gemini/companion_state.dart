import 'package:ai_companion/Companion/ai_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class CompanionState {
  final List<Content> history;
  final Map<String, dynamic> userMemory;
  final Map<String, dynamic> conversationMetadata;
  final int relationshipLevel;
  final String? dominantEmotion;
  final AICompanion companion;
  final ChatSession? chatSession;

  CompanionState({
    required this.history,
    required this.userMemory,
    required this.conversationMetadata,
    required this.relationshipLevel,
    this.dominantEmotion,
    required this.companion,
    this.chatSession,
  });
}
