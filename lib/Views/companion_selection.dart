import 'dart:math';

import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanionSelectionPage extends StatefulWidget {
  const CompanionSelectionPage({super.key});

  @override
  State<CompanionSelectionPage> createState() => _CompanionSelectionPageState();
}

class _CompanionSelectionPageState extends State<CompanionSelectionPage> {
  late CustomAuthUser user;

  @override
  void initState() {
    super.initState();
    // Initialize user in initState
      _initializeCompanionData();
  }

  void _initializeCompanionData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthStateLoggedIn) {
      setState(() {
        user = authState.user;
      });
      context.read<CompanionBloc>().add(LoadCompanions());
      
    }
  }
  void _initilaizeCompanionAvatar(List<AICompanion> companions) {
    setState(() {
     // Cache images for smooth loading
    for (var companion in companions) {
      precacheImage(
        NetworkImage(companion.avatarUrl),
        context,
      );
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<CompanionBloc, CompanionState>(
        listener: (context, state) {
        print('Companion State: $state'); // Debug print
        },
        builder: (BuildContext context, CompanionState state) {
          if (state is CompanionLoading) {
            return const Center(child: CircularProgressIndicator());
          } 
          if (state is CompanionError) {
            return Center(child: Text('Failed to load companions - ${state.message}'));
          }
          
          if (state is CompanionLoaded) {
            return Stack(
              children: [
                _buildBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _buildSwiper(state.companions),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          
           return const Center(
          child: Text('No companions available'),
           );
        },
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
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
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

  Widget _buildSwiper(List<AICompanion> companions) {
    return Swiper(
      itemBuilder: (context, index) => _buildCard(companions[index]),
      itemCount: companions.length,
      layout: SwiperLayout.STACK,
      itemWidth: MediaQuery.of(context).size.width * 0.85,
      itemHeight: MediaQuery.of(context).size.height * 0.7,
    );
  }

  Widget _buildCard(AICompanion companion) {
    return GestureDetector(
      onTap: () => _showCompanionDetails(companion),
      child: Hero(
        tag: 'companion-${companion.name}',
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
            Colors.blue.shade500,
            Colors.purple.shade800.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(AICompanion companion) {
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

  Widget _buildNameAge(AICompanion companion) {
    return Row(
      children: [
        Text(
          '${companion.name}, ${companion.physical.age}',
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

  Widget _buildTraits(AICompanion companion) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: companion.personality.primaryTraits.length,
        itemBuilder: (context, index) {
          final trait = companion.personality.primaryTraits[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                trait,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInterests(AICompanion companion) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: (companion.personality.interests)
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

  void _showCompanionDetails(AICompanion companion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompanionDetailsSheet(companion: companion),
    );
  }
}

class _CompanionDetailsSheet extends StatelessWidget {
  final AICompanion companion;

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
                      _buildProfileTab(context,scrollController),
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
            companion.name,
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

  Widget _buildProfileTab(BuildContext context,ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildPhysicalAttributes(context),
        const SizedBox(height: 16),
        _buildPersonalityTraits(context),
      ],
    );
  }
Widget _buildPhysicalAttributes(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Physical Attributes',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      _buildAttributeRow(context,'Height', companion.physical.height, Icons.height),
      _buildAttributeRow(context,'Body Type', companion.physical.bodyType, Icons.accessibility_new),
      _buildAttributeRow(context,'Hair Color', companion.physical.hairColor, Icons.face),
      _buildAttributeRow(context,'Eye Color', companion.physical.eyeColor, Icons.remove_red_eye),
      _buildAttributeRow(context,'Style', companion.physical.style, Icons.style),
      const SizedBox(height: 16),
      Text(
        'Distinguishing Features',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: companion.physical.distinguishingFeatures
            .map((feature) => Chip(
                  label: Text(feature),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ))
            .toList(),
      ),
    ],
  );
}

Widget _buildAttributeRow(BuildContext context,String label, String value, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      ],
    ),
  );
}

Widget _buildPersonalityTraits(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Personality',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Primary Traits',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: companion.personality.primaryTraits
            .map((trait) => Chip(
                  label: Text(trait),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 16),
      Text(
        'Secondary Traits',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: companion.personality.secondaryTraits
            .map((trait) => Chip(
                  label: Text(trait),
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 16),
      _buildPersonalityValues(context),
    ],
  );
}

Widget _buildPersonalityValues(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Core Values',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: companion.personality.values
            .map((value) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ))
            .toList(),
      ),
    ],
  );
}

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
        companion.background.join('\n\n'),// Join array elements with newlines
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
        'Skills & Hobbies',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (companion.skills )
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
        itemCount: companion.personality.interests.length,
        itemBuilder: (context, index) {
          final interest = companion.personality.interests[index];
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
  final style = companion.voice;
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
        style[0],
        Icons.chat_bubble_outline,
      ),
      _buildStyleCard(
        'Humor',
        style[1],
        Icons.sentiment_satisfied_alt_outlined,
      ),
      _buildStyleCard(
        'Conversation Depth',
        style[2],
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
          itemCount: companion.personality.primaryTraits.length,
          itemBuilder: (context, index) {
            final trait = companion.personality.primaryTraits[index];
            final intensity = (Random().nextInt(5) + 5); 
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trait + ' - $intensity'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: intensity / 10,
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