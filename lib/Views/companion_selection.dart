import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanionSelectionPage extends StatefulWidget {
  const CompanionSelectionPage({super.key});

  @override
  State<CompanionSelectionPage> createState() => _CompanionSelectionPageState();
}

class _CompanionSelectionPageState extends State<CompanionSelectionPage> {
  final List<Map<String, dynamic>> companions = [
    {
      'name': 'Sophie',
    'gender': 'female',
    'age': 24,
    'avatar': 'assets/images/sophie.jpg', // Add actual image path
    'physical_attributes': {
      'height': "5'7\"",
      'body_type': 'Athletic',
      'eye_color': 'Green',
      'hair_color': 'Auburn',
      'style_description': 'Modern casual with a creative twist',
    },
    'personality_traits': [
      {'trait_name': 'Empathetic', 'strength': 9},
      {'trait_name': 'Creative', 'strength': 8},
      {'trait_name': 'Witty', 'strength': 7},
      {'trait_name': 'Adventurous', 'strength': 8},
      {'trait_name': 'Intellectual', 'strength': 9}
    ],
    'background_story': {
      'life_story': 'Born in Seattle, Sophie grew up surrounded by art and nature. She graduated with a degree in Fine Arts and has since been pursuing her passion for photography and digital art. Her creative spirit and empathetic nature make her an excellent companion for deep conversations about art, life, and personal growth.',
      'interests': ['Art', 'Photography', 'Travel', 'Nature', 'Technology'],
      'hobbies': ['Painting', 'Hiking', 'Coffee brewing', 'Digital art', 'Reading']
    },
    'conversation_style': {
      'communication_preference': 'Casual but thoughtful',
      'humor_level': 'Witty and playful',
      'depth': 'Can switch between light chat and deep discussions'
    }
  },
    // Add more companions here
  {
        'name': 'Alex',
        'gender': 'male',
        'age': 27,
        'avatar': 'assets/images/companion_welcome.jpg',
        'physical_attributes': {
        'height': "6'0\"",
        'body_type': 'Fit',
        'eye_color': 'Brown',
        'hair_color': 'Black',
        'style_description': 'Smart casual with a tech-savvy edge',
        },
    'personality_traits': [
        {'trait_name': 'Analytical', 'strength': 9},
        {'trait_name': 'Patient', 'strength': 8},
        {'trait_name': 'Humorous', 'strength': 7},
        {'trait_name': 'Supportive', 'strength': 9},
        {'trait_name': 'Tech-savvy', 'strength': 9}
        ],
    'background_story': {
        'life_story': 'A software engineer turned AI companion, Alex combines technical expertise with emotional intelligence. His background in both technology and psychology allows him to offer unique perspectives on various topics while maintaining a supportive and understanding presence.',
        'interests': ['Technology', 'Science', 'Gaming', 'Music', 'Psychology'],
        'hobbies': ['Coding', 'Playing guitar', 'VR gaming', 'Chess', 'Podcasting']
        },
    'conversation_style': {
        'communication_preference': 'Balanced and analytical',
        'humor_level': 'Dry wit with tech humor',
        'depth': 'Enjoys both technical discussions and casual chats'
        }
    }
    ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildSwiper()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceVariant,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Choose Your Companion',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSwiper() {
    return Swiper(
      itemBuilder: (context, index) => _buildCard(companions[index]),
      itemCount: companions.length,
      layout: SwiperLayout.STACK,
      itemWidth: MediaQuery.of(context).size.width * 0.85,
      itemHeight: MediaQuery.of(context).size.height * 0.7,
    );
  }

  Widget _buildCard(Map<String, dynamic> companion) {
    return GestureDetector(
      onTap: () => _showCompanionDetails(companion),
      child: Hero(
        tag: 'companion-${companion['name']}',
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              _buildCardBackground(),
              _buildCardContent(companion),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBackground() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> companion) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          _buildNameAge(companion),
          const SizedBox(height: 8),
          _buildTraits(companion),
          const SizedBox(height: 16),
          _buildInterests(companion),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNameAge(Map<String, dynamic> companion) {
    return Row(
      children: [
        Text(
          '${companion['name']}, ${companion['age']}',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () => _showCompanionDetails(companion),
        ),
      ],
    );
  }

  Widget _buildTraits(Map<String, dynamic> companion) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: companion['personality_traits'].length,
        itemBuilder: (context, index) {
          final trait = companion['personality_traits'][index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                trait['trait_name'],
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInterests(Map<String, dynamic> companion) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: (companion['background_story']['interests'] as List<String>)
          .map((interest) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(color: Colors.white),
                ),
              ))
          .toList(),
    );
  }

  void _showCompanionDetails(Map<String, dynamic> companion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompanionDetailsSheet(companion: companion),
    );
  }
}

class _CompanionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> companion;

  const _CompanionDetailsSheet({required this.companion});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                _buildHeader(context),
                const TabBar(
                  tabs: [
                    Tab(text: 'Profile'),
                    Tab(text: 'Story'),
                    Tab(text: 'Interests'),
                    Tab(text: 'Style'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildProfileTab(scrollController),
                      _buildStoryTab(scrollController),
                      _buildInterestsTab(scrollController),
                      _buildStyleTab(scrollController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            companion['name'],
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // _buildPhysicalAttributes(),
        const SizedBox(height: 16),
        // _buildPersonalityTraits(),
      ],
    );
  }
    // Add these methods to the _CompanionDetailsSheet class

Widget _buildStoryTab(ScrollController scrollController) {
  return ListView(
    controller: scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Background Story',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        companion['background_story']['life_story'],
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      _buildHobbiesSection(),
    ],
  );
}

Widget _buildHobbiesSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hobbies',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (companion['background_story']['hobbies'] as List<String>)
            .map((hobby) => Chip(
                  label: Text(hobby),
                  avatar: Icon(
                    _getHobbyIcon(hobby),
                    size: 16,
                  ),
                ))
            .toList(),
      ),
    ],
  );
}

Widget _buildInterestsTab(ScrollController scrollController) {
  return ListView(
    controller: scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      _buildInterestCategories(),
      const SizedBox(height: 24),
    //   _buildConversationStyle(),
    ],
  );
}

Widget _buildInterestCategories() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Interests',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: companion['background_story']['interests'].length,
        itemBuilder: (context, index) {
          final interest = companion['background_story']['interests'][index];
          return Card(
            elevation: 2,
            child: Center(
              child: ListTile(
                leading: Icon(_getInterestIcon(interest)),
                title: Text(interest),
              ),
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildStyleTab(ScrollController scrollController) {
  return ListView(
    controller: scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      _buildCommunicationStyle(),
      const SizedBox(height: 24),
      _buildPersonalityChart(),
    ],
  );
}

Widget _buildCommunicationStyle() {
  final style = companion['conversation_style'];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Communication Style',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      _buildStyleCard(
        'Preference',
        style['communication_preference'],
        Icons.chat_bubble_outline,
      ),
      _buildStyleCard(
        'Humor',
        style['humor_level'],
        Icons.sentiment_satisfied_alt_outlined,
      ),
      _buildStyleCard(
        'Conversation Depth',
        style['depth'],
        Icons.psychology_outlined,
      ),
    ],
  );
}

Widget _buildStyleCard(String title, String content, IconData icon) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(content),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildPersonalityChart() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Personality Traits',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 200,
        child: ListView.builder(
          itemCount: companion['personality_traits'].length,
          itemBuilder: (context, index) {
            final trait = companion['personality_traits'][index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trait['trait_name']),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: trait['strength'] / 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

IconData _getInterestIcon(String interest) {
  // Add more mappings as needed
  final Map<String, IconData> iconMap = {
    'Art': Icons.palette,
    'Photography': Icons.camera_alt,
    'Travel': Icons.flight,
    'Technology': Icons.computer,
    'Science': Icons.science,
    'Gaming': Icons.games,
    'Music': Icons.music_note,
    'Psychology': Icons.psychology,
    'Nature': Icons.nature,
  };
  return iconMap[interest] ?? Icons.interests;
}

IconData _getHobbyIcon(String hobby) {
  // Add more mappings as needed
  final Map<String, IconData> iconMap = {
    'Painting': Icons.palette,
    'Hiking': Icons.landscape,
    'Coffee brewing': Icons.coffee,
    'Digital art': Icons.brush,
    'Reading': Icons.book,
    'Coding': Icons.code,
    'Playing guitar': Icons.music_note,
    'VR gaming': Icons.videogame_asset,
    'Chess': Icons.casino,
    'Podcasting': Icons.mic,
  };
  return iconMap[hobby] ?? Icons.favorite;
}
}