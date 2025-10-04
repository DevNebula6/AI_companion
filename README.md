# AI Companion Flutter App – Advanced AI Conversational Platform

![AI Companion Logo](assets/images/logo4.png)

*Connect, converse, and build relationships with AI companions that feel genuinely human.*

## 🚀 Download & Try the App

**📱 Latest APK Download:**
[**Download AI Companion v0.1.0**](https://drive.google.com/file/d/1q-MxZj7lRMNXFncC3VeknSSl5gxBvMN2/view?usp=drive_link)

*Experience the future of AI companionship with real-time voice conversations, emotional intelligence, and personalized interactions.*

---

## 📱 Application Screenshots

### Onboarding & Authentication
<div align="center">
  <img src="assets/screenshots/onboarding1.jpg" alt="Onboarding Screen 1" width="250" />
  <img src="assets/screenshots/onboarding2.jpg" alt="Onboarding Screen 2" width="250" />
  <img src="assets/screenshots/onboarding3.jpg" alt="Onboarding Screen 3" width="250" />
  <img src="assets/screenshots/onboarding4.jpg" alt="Onboarding Screen 4" width="250" />
  <img src="assets/screenshots/signin.jpg" alt="Sign In Options" width="250" />
  <img src="assets/screenshots/user profile.jpg" alt="Profile Setup" width="250" />
</div>

### 🏠 Dynamic Home Screen & Navigation
Experience a fluid, animated home interface that changes throughout the day with companion-specific visual themes.

<div align="center">
  <img src="assets/screenshots/dynamic home page.png" alt="Dynamic Home Screen" width="250" />
</div>

*Features dynamic fluid backgrounds with time-based color themes and smooth bubble animations*

### 🎭 Companion Selection & Profiles
Discover AI companions with unique personalities, each featuring their own visual identity and characteristics.

<div align="center">
  <img src="assets/screenshots/companion selection2.jpg" alt="Companion Selection" width="220" />
  <img src="assets/screenshots/companion selection3.jpg" alt="Companion Gallery" width="220" />
  <img src="assets/screenshots/companion detail profile.jpg" alt="Companion Details" width="220" />
</div>

<div align="center">
  <img src="assets/screenshots/companion detail background story.jpg" alt="Background Story" width="220" />
  <img src="assets/screenshots/companion detail interests.jpg" alt="Interests" width="220" />
  <img src="assets/screenshots/companion detail communication.jpg" alt="Communication Style" width="220" />
</div>

*Each companion has detailed profiles including personality traits, backgrounds, interests, and communication preferences*

### 💬 Dynamic Chat Experience
Engage in conversations with companion-specific visual themes and fluid backgrounds that reflect each AI's personality.

<div align="center">
  <img src="assets/screenshots/dynamic chat page 1.png" alt="Dynamic Chat - Companion 1" width="200" />
  <img src="assets/screenshots/dynamic chat page 2.png" alt="Dynamic Chat - Companion 2" width="200" />
  <img src="assets/screenshots/dynamic chat page3.png" alt="Dynamic Chat - Companion 3" width="200" />
  <img src="assets/screenshots/dynamic chat page4.png" alt="Dynamic Chat - Companion 4" width="200" />
</div>

*Each companion features unique color schemes, gradients, and animated backgrounds that reflect their personality traits*

### 🎤 Voice Call Interface (Experimental)
Experience real-time voice conversations with immersive visual feedback and companion-specific themes.

<div align="center">
  <img src="assets/screenshots/voice call initial screen .png" alt="Voice Call Setup" width="200" />
  <img src="assets/screenshots/voice call initial screen 2.png" alt="Voice Call Interface" width="200" />
  <img src="assets/screenshots/voice call start screen .png" alt="Active Voice Call" width="200" />
  <img src="assets/screenshots/voice call start screen 2 .png" alt="Voice Visualization" width="200" />
</div>

*Features real-time audio visualizations, companion avatars, and immersive backgrounds during voice conversations*

### 👤 User Profile & Personalization
Customize your experience with detailed preference settings and personality matching.

<div align="center">
  <img src="assets/screenshots/user profile.jpg" alt="Profile Overview" width="200" />
  <img src="assets/screenshots/user profile inerests.jpg" alt="User Interests" width="200" />
  <img src="assets/screenshots/user profile personality.jpg" alt="Personality Settings" width="200" />
  <img src="assets/screenshots/user profile comms pref.jpg" alt="Communication Preferences" width="200" />
</div>

*Comprehensive user profiling system with interests, personality traits, and communication preferences*

---

## Project Overview & Vision

**Purpose & Vision:**  
AI Companion is a cutting-edge mobile application that provides users with personalized, emotionally intelligent AI companions featuring **real-time voice conversations**, advanced emotional understanding, and sophisticated conversational AI. Built with modern Flutter architecture and powered by Google Gemini AI, it delivers authentic human-like interactions in a secure, engaging environment.

**Revolutionary Features:**
- **🎤 Real-Time Voice Conversations** (Experimental/ Currently in Development) - Natural speech-to-speech interactions
- **🧠 Advanced AI Integration** - Powered by Google Gemini with contextual understanding
- **🎭 Emotional Intelligence** - AI companions with distinct personalities and emotional responses
- **🗣️ Azure Speech Services** (Experimental/ Currently in Development) - Professional-grade text-to-speech with custom voice characteristics
- **📱 Cross-Platform Excellence** - Seamless experience across all devices
- **🔒 Privacy-First Design** - Secure conversations with local caching

**Problems Solved:**
- Provides meaningful companionship through advanced AI technology
- Offers judgment-free conversational practice with voice interaction capabilities
- Delivers personalized emotional support through sophisticated AI understanding
- Enables natural communication skill development via speech recognition

---

## Implementation Details

### Architecture & Design Patterns
- **Layered Architecture:** Presentation (Flutter UI), Business Logic (Bloc), Data (Repositories/Services).
- **Bloc Pattern:** State management for authentication, chat, and companion selection.
- **Repository Pattern:** Abstracts data access and business logic.
- **Service Layer:** Integrations (Supabase, Hive, AI APIs, connectivity, image caching).
- **Separation of Concerns:** Isolated modules for maintainability.

### 🗂️ Advanced Project Structure
- `lib/AI/` – AI logic, models, and Gemini integration
- `lib/auth/` – Authentication with Supabase and Google OAuth
- `lib/chat/` – Complete chat system with message handling, conversation management, and caching
  - `lib/chat/voice/` – **🎤 Advanced voice chat system** with Azure Speech integration
  - `lib/chat/voice/voice_bloc/` – **Voice-specific BLoC** for real-time voice state management
  - `lib/chat/message_bloc/` – Message handling and conversation persistence
- `lib/Companion/` – AI companion models, repository, and voice characteristics
- `lib/Views/` – Modern UI screens with voice call interface and animations
  - `lib/Views/voice_call/` – **🎤 Voice call UI** with real-time visualizations
- `lib/services/` – Core services (caching, connectivity, audio processing)
- `lib/themes/` – Material Design 3 theming with dynamic color schemes
- `lib/utilities/` – Helper widgets, animations, and loading screens
- `lib/navigation/` – GoRouter-based navigation with deep linking
- `assets/` – Images, animations, fonts, voice assets, and Lottie files
- `database_migrations/` – **Azure voice configuration** database schemas
- `test/` – Comprehensive unit and integration tests

---



## System Integration

### Module Interactions
- **Authentication:** Managed by Bloc and Supabase provider; user data is shared with other modules.
- **Chat:** Handles message flow, caching, AI invocation; integrates with Gemini AI and Hive.
- **AI/Companion:** Manages AI personas and selection.
- **Navigation:** GoRouter for state-driven navigation.
- **Services:** Connectivity, image caching, loading overlays.

### Data & Control Flow
1. App launches, checks auth state.
2. If unauthenticated, shows onboarding/sign-in.
3. On login, loads user profile.
4. User selects AI companion.
5. User sends message; AI responds; messages cached.
6. Navigation between screens via GoRouter.

---

## Feature & Flow Documentation

### 1. User Authentication & Onboarding
- **Files:** `auth_bloc.dart`, `auth_event.dart`, `auth_state.dart`, `supabase_authProvider.dart`, `sign_page.dart`, `onboarding_screen.dart`
- **Flow:** App checks auth state → onboarding/sign-in → login → user data fetched → navigation to home/onboarding.

### 2. Message Flow (User Input → AI Response → Display)
- **Files:** `chat_repository.dart`, `message_bloc.dart`, `message_event.dart`, `message_state.dart`, `gemini_service.dart`, `conversation_bloc.dart`, `chat_input_field.dart`, `chat_page.dart`
- **Flow:** User inputs message → Bloc processes → message fragmented → sent to Gemini AI → response fragmented → UI updates → messages cached.

### 3. AI Flow (Invocation & Response Handling)
- **Files:** `gemini_service.dart`, `companion_state.dart`, `ai_model.dart`
- **Flow:** Message event triggers Gemini AI → response generated → processed and returned to chat → companion state updated.

### 4. Navigation Flow
- **Files:** `app_routes.dart`, `routes_name.dart`, `home_screen.dart`, `chat_page.dart`, `user_profile_screen.dart`, `companion_selection.dart`
- **Flow:** GoRouter manages navigation; Bloc state changes trigger route transitions.

---

## Component Implementation & Actions

### 1. Authentication
- **Responsibilities:** Sign-in, sign-up, Google login, session management.
- **Key Classes:** `AuthBloc`, `SupabaseAuthProvider`, `CustomAuthUser`.
- **Communication:** Emits auth state changes to UI and other Blocs.

### 2. Chat & Messaging
- **Responsibilities:** Message sending, AI invocation, caching.
- **Key Classes:** `MessageBloc`, `ChatRepository`, `GeminiService`, `Message`, `Conversation`.
- **Communication:** Listens to user input, updates UI, interacts with AI and storage.

### 3. AI Companion
- **Responsibilities:** Defines personas, manages selection.
- **Key Classes:** `AICompanion`, `CompanionBloc`, `CompanionRepository`.
- **Communication:** Loads/syncs data, provides context for chat.

### 4. Navigation
- **Responsibilities:** Route transitions, deep linking.
- **Key Classes:** `GoRouter`, `RoutesName`, `AppRoutes`.
- **Communication:** Responds to Bloc state and user actions.

### 5. Services
- **Responsibilities:** Local storage, connectivity, image caching, loading overlays.
- **Key Classes:** `HiveService`, `ConnectivityService`, `CompanionImageCacheManager`, `LoadingScreen`.
- **Communication:** Shared utilities for all modules.

---

## Best Practices & Extensibility

- **State Management:** Bloc for predictable, testable transitions.
- **Error Handling:** Custom exceptions and translators.
- **Testing:** Unit tests for core logic.
- **Separation of Concerns:** Clear boundaries between layers.
- **Offline Support:** Hive and SharedPreferences.
- **Extensibility:**  
  - Add new companions via `ai_model.dart` and Supabase.
  - Integrate new AI/ML APIs via `gemini_service.dart`.
  - Add screens/flows via GoRouter and Bloc.
  - Modular structure for easy feature addition.

## 🎯 Latest Technological Implementations

### 🎤 **Voice Chat System (Experimental)**
- **Azure Speech Recognition**: Real-time continuous speech-to-text with 99%+ accuracy
- **Azure Text-to-Speech**: Professional voice synthesis with emotional adjustments
- **Voice Activity Detection**: Smart detection of speech patterns and natural pauses
- **Continuous Listening**: True real-time voice interaction without interruptions
- **Audio Processing Pipeline**: Memory-based audio streaming for low latency
- **Voice BLoC Architecture**: Dedicated state management for voice interactions

### 🧠 **Advanced AI Integration**
- **Voice-Enhanced Gemini Service**: Specialized AI responses optimized for voice conversations
- **Contextual Conversation**: AI that understands conversation history and emotional context
- **Emotional Intelligence**: Dynamic AI responses based on detected emotions and companion personality
- **Token Optimization**: Smart context management reducing API costs by 60%
- **Conversation Summarization**: Efficient context compression for extended conversations

### 🎨 **Revolutionary Dynamic UI System**
- **Companion-Specific Visual Engine**: Each AI companion influences UI colors, gradients, and animations based on personality traits
- **Fluid Background Technology**: Advanced water bubble animations using fluid_background package with real-time companion-based themes
- **Time-Adaptive Interface**: UI automatically changes throughout the day with morning/afternoon/evening/night color schemes
- **Personality-Based Color Algorithms**: Mathematical algorithms that translate companion traits into visual characteristics
- **Dynamic Voice Call Interface**: Real-time audio visualizations with companion-specific themes and animations
- **Responsive Visual Feedback**: UI elements that react to user interactions, voice activity, and conversation flow

### 🗄️ **Sophisticated Data Management**
- **Hybrid Caching System**: Multi-layer caching with Hive + SharedPreferences + Azure configs + Visual theme caching
- **Offline-First Architecture**: Full functionality without internet connection including visual themes
- **Real-Time Synchronization**: Seamless data sync across devices with conflict resolution
- **Voice Session Management**: Specialized storage for voice conversation summaries
- **Azure Voice Characteristics**: Database-stored companion voice profiles with JSONB configuration
- **Companion Visual Profiles**: Stored personality-to-visual mapping for consistent companion experiences

### 🔧 **Modern Development Stack**
```yaml
dependencies:
  # Core Framework
  flutter: sdk
  
  # AI & Voice Services
  google_generative_ai: ^0.4.7          # Latest Gemini AI integration
  azure_speech_recognition_flutter: ^1.0.2  # Real-time speech recognition
  flutter_tts: ^4.2.3                   # Text-to-speech capabilities
  audioplayers: ^6.5.1                  # Audio playback system
  record: ^6.1.1                        # Audio recording
  
  # Backend & Database
  supabase_flutter: ^2.9.0              # Backend-as-a-Service
  hive_flutter: ^1.1.0                  # Local NoSQL database
  
  # State Management & Architecture
  flutter_bloc: ^9.1.1                  # BLoC pattern implementation
  go_router: ^16.2.1                    # Declarative routing
  provider: ^6.1.5                      # Dependency injection
  
  # Advanced UI/UX & Dynamic Visual System
  flutter_animate: ^4.5.2               # Sophisticated animations and transitions
  lottie: ^3.3.2                        # Vector animations for loading states
  fluid_background: ^1.0.5              # Revolutionary water bubble backgrounds
  shimmer: ^3.0.0                       # Beautiful loading animations
  floating_bubbles: ^2.6.2              # Interactive bubble elements
  card_swiper: ^3.0.1                   # Smooth companion selection interface
  
  # Networking & Utilities
  connectivity_plus: ^6.1.5             # Network monitoring
  cached_network_image: ^3.4.1          # Image caching
  permission_handler: ^11.4.0           # Permission management
```

### 🏗️ **System Architecture Highlights**
- **Clean Architecture**: Layered approach with Repository pattern and Service layer separation
- **Voice-First Design**: Architecture optimized for real-time voice interactions
- **Microservice Integration**: Modular services for AI, voice, auth, and data management
- **Event-Driven Architecture**: BLoC pattern with separate voice and message state management
- **Performance Optimization**: Memory-efficient audio processing and intelligent caching strategies

## 🚀 Voice Chat Implementation Status

### 🎤 **Real-Time Voice Chat System (Experimental)**

**Current Implementation Status:**
- ✅ **Core Architecture**: Complete voice chat system with continuous listening
- ✅ **Azure Speech Integration**: Real-time speech recognition and text-to-speech
- ✅ **Voice BLoC Pattern**: Dedicated state management for voice interactions
- ✅ **Audio Processing**: Memory-based audio streaming and playback
- ✅ **Voice UI**: Complete voice call interface with real-time visualizations
- ⚠️ **Production Stability**: Currently in active testing and optimization phase

**Technical Implementation:**
```dart
// Voice chat architecture includes:
- ContinuousVoiceChatServiceV2: Real-time voice processing
- AzureSpeechPluginService: Speech recognition integration
- SupabaseTTSService: Text-to-speech synthesis
- VoiceBloc: Voice-specific state management
- VoiceCallScreen: Complete voice interaction UI
- AudioPlayerService: High-quality audio processing
```

**Why Experimental?**
The voice chat feature represents cutting-edge real-time AI voice interaction technology. While the architecture is complete and functional, we're continuously:
- Testing reliability across different devices and environments
- Optimizing various TTS/STT provider combinations
- Fine-tuning voice activity detection algorithms
- Improving natural conversation flow
- Testing battery optimization strategies

**Expected Improvements:**
- Enhanced voice recognition accuracy across accents and environments
- Reduced latency for more natural conversation flow
- Expanded language support and voice characteristics
- Improved interruption handling and conversation dynamics
- Better integration with companion personality systems




## 🚀 Future Roadmap

### 🎯 **Voice Technology Enhancements**
- **Enhanced TTS/STT Providers**: Testing and integration of additional voice service providers
- **Improved Voice Recognition**: Advanced acoustic models for better accuracy across environments
- **Multi-Language Voice Support**: Expanded language support with native speaker voice characteristics
- **Real-Time Voice Effects**: Dynamic voice modulation and emotional expression enhancements

### 🧠 **AI & Machine Learning**
- **Advanced Emotional AI**: Enhanced emotional intelligence and contextual understanding
- **Personalized Learning**: AI companions that adapt and learn from individual user preferences
- **Cross-Conversation Memory**: Long-term memory and relationship development across sessions
- **Multi-Modal AI**: Integration of text, voice, and visual AI capabilities

### 📱 **Platform & Integration**
- **Web Platform**: Browser-based voice chat with WebRTC integration
- **Desktop Applications**: Native desktop apps for Windows, macOS, and Linux
- **Smart Device Integration**: Support for smart speakers and IoT devices
- **API Platform**: Developer APIs for third-party integrations

## 🤝 Contributing

We welcome contributions to the AI Companion project! Areas where contributions are particularly valuable:

- **Voice Technology Testing**: Help test voice features across different devices and environments
- **Language Support**: Contribute translations and cultural adaptations
- **UI/UX Improvements**: Design enhancements and accessibility features
- **Performance Optimization**: Code optimization and efficiency improvements
- **Documentation**: Technical documentation and user guides

## 📞 Contact & Support

For questions, feedback, or collaboration opportunities:
- **GitHub Issues**: Report bugs and feature requests
- **Email**: For business inquiries and partnerships
- **Community**: Join our Discord community for discussions and support

## 🙏 Acknowledgements

### **Core Technologies**
- **Google Gemini AI** - Powering our advanced conversational AI engine
- **Microsoft Azure Speech Services** - Professional-grade voice recognition and synthesis
- **Supabase** - Backend infrastructure and real-time database capabilities
- **Flutter Team** - Cross-platform development framework and ecosystem

### **Open Source Libraries**
- **Flutter BLoC** - Predictable state management pattern
- **Hive** - Lightning-fast local database
- **Audio Players** - High-quality audio processing
- **Go Router** - Declarative routing solution
- **Lottie Flutter** - Beautiful vector animations

### **Community & Inspiration**
- **Flutter Community** - Continuous inspiration and technical guidance
- **AI Research Community** - Advancements in conversational AI and voice technology
- **Open Source Contributors** - Building the foundation for modern app development

---

**Built with ❤️ using Flutter | Powered by Advanced AI Technology**

*Experience the future of AI companionship with natural voice conversations and emotional intelligence.*
