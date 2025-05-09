# AI Companion

![AI Companion Logo](assets/images/logo4.png)

*Connect, converse, and build relationships with AI companions that feel genuinely human.*

## Overview

AI Companion is a Flutter application that enables users to build meaningful relationships with AI-powered companions, each with their own distinct personalities, backgrounds, and communication styles. Whether you're seeking friendship, emotional connection, or simply a space to practice conversation skills, our AI companions provide authentic and engaging interactions.

## Vision

AI Companion offers a unique platform where users can:

- **Build Meaningful Connections**: Develop companionship, friendship, or even emotional and intimate connections with companions that feel real.
- **Practice Communication Skills**: Improve language fluency, build social confidence, and develop conversational abilities in a judgment-free environment.
- **Explore Diverse Personalities**: Interact with companions representing different backgrounds, cultures, personalities, and communication styles.
- **Experience Seamless Conversations**: Chat anytime, anywhere - even offline - with our robust synchronization system.
- **Watch Relationships Evolve**: See how your relationship with companions changes over time based on your interactions.

## Key Features

- **Diverse AI Companions**: Each with unique backstories, personalities, interests, and communication styles
- **Relationship Development**: Companions remember past conversations and build an evolving relationship with users
- **Offline Functionality**: Continue conversations even without internet connection
- **Conversation Synchronization**: Seamlessly transition between online and offline usage
- **Personalized Interactions**: Adaptive responses that reflect your unique relationship with each companion
- **Multiple Conversation Threads**: Maintain separate conversations with different companions
- **Emotional Expression**: Companions display emotions and react to your messages based on their personality
- **Cultural Exploration**: Learn about different cultures through companions with diverse backgrounds
- **Privacy-Focused**: Your conversations remain private and secure

## Application Screenshots

### Onboarding & Authentication
<div align="center">
  <img src="assets/screenshots/onboarding1.jpg" alt="Onboarding Screen 1" width="250" />
  <img src="assets/screenshots/onboarding2.jpg" alt="Onboarding Screen 2" width="250" />
  <img src="assets/screenshots/onboarding3.jpg" alt="Onboarding Screen 3" width="250" />
  <img src="assets/screenshots/onboarding4.jpg" alt="Onboarding Screen 4" width="250" />
  <img src="assets/screenshots/signin.jpg" alt="Sign In Options" width="250" />
  <img src="assets/screenshots/user profile.jpg" alt="Profile Setup" width="250" />
</div>

### Home Screen & Navigation
View your conversations, pin favorites, and explore a well-designed navigation experience.

<div align="center">
  <img src="assets/screenshots/home screen.jpg" alt="Home Screen" width="250" />
</div>

### Companion Selection
Discover a diverse range of AI companions, each with unique personalities and characteristics.

<div align="center">
  <img src="assets/screenshots/companion selection2.jpg" alt="Companion Selection" width="250" />
  <img src="assets/screenshots/companion detail profile.jpg" alt="Companion Details" width="250" />
</div>

### Chat Experience
Engage in natural conversations with emotional expression and relationship development.

<div align="center">
  <img src="assets/screenshots/chat page 1.jpg" alt="Chat Screen" width="250" />
  <img src="assets/screenshots/chat page 2.jpg" alt="Chat Screen" width="250" />
</div>

### User Profile & Settings
Customize your experience and manage your personal information.

<div align="center">
  <img src="assets/screenshots/user profile interests.jpg" alt="User Profile" width="250" />
</div>

## Technical Stack

- **Frontend**: Flutter for cross-platform mobile experience
- **Backend**: Supabase for authentication, data storage, and real-time features
- **AI**: Google's Gemini AI for natural language processing and conversation generation
- **State Management**: BLoC pattern for efficient state management
- **Data Caching**: Hybrid caching system(Hive + shared preference) for offline access
- **Authentication**: Secure authentication through Google

## Caching

AI Companion features a robust Caching and offline system that:

- Caches conversation history for seamless offline viewing
- Stores companion data locally for access without internet
- Queues messages sent while offline and sends them when connectivity is restored
- Synchronizes conversations between device and server automatically
- Provides visual indicators for pending messages

## Project Structure

The project follows a structured architecture:

- `lib/Companion/`: AI companion models and logic
- `lib/auth/`: Authentication management
- `lib/chat/`: Chat functionality including message handling and offline support
- `lib/Views/`: UI screens and components
- `lib/utilities/`: Helper functions and widgets
- `lib/services/`: Core services like caching and API communication
- `lib/themes/`: App styling and theming


## Acknowledgements

- Google Gemini AI for powering our conversation engine
- Supabase for backend infrastructure
- Flutter and Dart teams for the development framework
