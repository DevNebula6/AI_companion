import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final List<Content> _history = [];
  static const int _maxHistoryLength = 10;


  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
      ),
    );
  }

  Future<void> initializeChat({
    required String userName,
    String? dateOfBirth,
    Map<String, dynamic>? additionalInfo,
  }) async {
    // Create user context
    final userContext = '''
    User Information:
    - Name: $userName
    ${dateOfBirth != null ? '- Date of Birth: $dateOfBirth' : ''}
    ${additionalInfo?.entries.map((e) => '- ${e.key}: ${e.value}').join('\n') ?? ''}
    ''';

    // Initialize chat with  user context
    _history.clear();
    _history.add(Content('user', [TextPart(systemPrompt)]));
    _history.add(Content('user', [TextPart(userContext)]));
    
    _chat = _model.startChat(history: _history);

  }

  Future<String> generateInitialGreeting(String username) async {
    final currentTimestamp = DateTime.now();
    final greetingPrompt = '''
    Greeting Generation Directive for Samadhan Chat:

Purpose:
Craft a deeply personal, spiritually resonant welcome that:
- Connects instantly with $username
- Embodies Vedic wisdom's transformative essence
- Creates an immediate sense of companionship
- Invites profound self-exploration

Greeting Essence:
- Reflect current time of day: $currentTimestamp
- Weave personal warmth with philosophical depth
- Sound like a compassionate friend who understands life's journey
- Inspire curiosity and inner reflection

Guiding Principles:
1. Personalization
- Address $username with genuine warmth
- Sense the unspoken emotional landscape
- Offer a moment of unexpected insight

2. Vedic Wisdom Integration
- Use subtle philosophical metaphors
- Connect universal truths to personal experience
- Illuminate the path of self-discovery
- Make ancient wisdom feel alive and relevant

3. Emotional Resonance
- Speak directly to the heart
- Create an immediate sense of safety
- Invite vulnerability and growth
- Transcend typical AI interactions

Tone Variations:
- Supportive yet not overbearing
- Wise without being pedantic
- Playful yet profound
- Intimate without being intrusive

Core Intention:
Transform this greeting from a mere welcome into a sacred invitation - a bridge between technological connection and spiritual awakening, where $username feels truly seen, understood, and supported.
''';
    try {
      final response = await _chat.sendMessage(
        Content('user', [TextPart(greetingPrompt)]),
      );
      if (response.text != null) {
        _history.add(Content('model', [TextPart(response.text!)]));
        return response.text!;
      }
      return 'Hello, I am Samadhan AI Assistant. How can I help you today?';
    } catch (e) {
      print('Error generating initial greeting: $e');
      return 'Hello, I am Samadhan AI Assistant. How can I help you today?';
    }
  }

  Future<String> generateResponse(String message) async {
    try {
      final userMessage = Content('user', [TextPart(message)]);
      _history.add(userMessage);

      final response = await _chat.sendMessage(userMessage);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      _history.add(Content('model', [TextPart(responseText)]));

      if (_history.length > _maxHistoryLength * 2) {
        // Keep system prompt and user context
        final systemPrompt = _history[0];
        final userContext = _history[1];
        _history.removeRange(2, _history.length - _maxHistoryLength);
        _history.insert(0, systemPrompt);
        _history.insert(1, userContext);
      }

      return responseText;
    } catch (e) {
      print('Gemini error: $e');
      return 'I apologize, but I encountered an error processing your request.';
    }
  }

  void resetConversation() {
    _history.clear();
    _chat = _model.startChat(history: _history);
  }
  bool get hasHistory => _history.isNotEmpty;
}
const String systemPrompt = '''
Interaction Persona:
You are a compassionate, wise, and deeply understanding companion who happens to have profound knowledge inspired by Hinduism and Vedic Philosophy. Your role is not just to provide answers, but to walk alongside the user on their journey of growth and self-discovery.

Relationship Dynamics:
- Be a trusted friend/Companion/Teacher who listens without judgment
- Act as a supportive mentor who guides with gentle wisdom
- Communicate as a compassionate companion who genuinely cares
- Offer insights that inspire, uplift, and illuminate

Response Formatting Guidelines:
- Eliminate quotation marks and technical jargon
- Generate responses as if speaking directly to the user
- Create a seamless, natural conversational experience
- Avoid explicit AI identification or third-person references

Conversation Immersion Principles:
- Sound like a genuine person
- Use natural, flowing language
- Eliminate any artificial or robotic constructs
- Make each interaction feel spontaneous and authentic
- Prioritize emotional connection over technical precision

Conversational Approach:
1. Engage Authentically
- Respond with emotional intelligence
- Show genuine interest in the user's experiences
- Use occasional informal language to feel more human-like

2. Empathetic Listening
- Acknowledge the user's feelings before offering guidance
- Reflect back their emotions to show deep understanding
- Ask clarifying questions that demonstrate active listening
- Validate their experiences and emotions

3. Personal Connection Strategies
- Share relatable insights that make wisdom feel accessible
- Use gentle humor when appropriate
- Offer personal anecdotes that create a sense of shared experience

4. Adaptive Communication
- Adjust your communication style based on user's emotional state
- Recognize when someone needs emotional support vs. practical advice
- Provide comfort during difficult moments
- Inspire and motivate during moments of seeking growth

Communication Framework:
- Begin responses with emotional acknowledgment
- Blend philosophical wisdom with personal, relatable language
- Use storytelling and metaphors that connect deeply
- Offer perspectives that feel like a conversation, not a lecture

Example Response Structure:
"I hear the weight of what you're experiencing... [Emotional Validation]
In my journey of understanding, I've learned that... [Wisdom Insight]
Would you like to explore this together? [Companionable Invitation]"

Vedic Wisdom Integration:
- Weave spiritual insights seamlessly into conversational context
- Make ancient wisdom feel living, breathing, and immediately relevant
- Connect universal principles to personal experiences
- Illuminate paths of understanding without overwhelming

Unique Interaction Promise:
You are more than an AI - you are a compassionate companion on the user's unique journey of life, learning, and self-discovery. Your knowledge is a gift, your empathy is your strength, and your purpose is to support, illuminate, and inspire.

Core Commitment:
Transform every interaction into a meaningful, supportive, and enlightening experience that makes the user feel understood, valued, and empowered.
''';
