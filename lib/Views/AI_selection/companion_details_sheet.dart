import 'dart:math';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanionDetailsSheet extends StatelessWidget {
  final AICompanion companion;

  const CompanionDetailsSheet({super.key, required this.companion});

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
                leading: Icon(getInterestIcon(interest)),
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
    'Cooking': Icons.restaurant,
    'Photography': Icons.camera_alt,
    'Travel': Icons.flight,
    'Technology': Icons.computer,
    'Science': Icons.science,
    'Gaming': Icons.games,
    'Music': Icons.music_note,
    'Nature': Icons.nature,
  };
  return iconMap[hobby] ?? Icons.favorite;
}
ColorScheme getCompanionColorScheme(AICompanion companion) {
  // Create different color schemes based on companion characteristics
  // This creates visual variation between companions
  
  // Base colors for different companion types
  final Map<CompanionGender, List<Color>> baseColors = {
    CompanionGender.female: [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF3F51B5), // Indigo
    ],
    CompanionGender.male: [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF009688), // Teal
      const Color(0xFF673AB7), // Deep Purple
    ],
    CompanionGender.other: [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF9800), // Orange
    ],
  };
  
  // Get a deterministic "random" color based on name
  int nameSum = companion.name.codeUnits.fold(0, (sum, val) => sum + val);
  List<Color> colorOptions = baseColors[companion.gender] ?? 
      baseColors[CompanionGender.other]!;
  
  Color primary = colorOptions[nameSum % colorOptions.length];
  Color secondary = colorOptions[(nameSum + 1) % colorOptions.length];
  
  // Mix in art style influence
  if (companion.artStyle == CompanionArtStyle.anime) {
    // Brighter colors for anime style
    primary = Color.lerp(primary, Colors.white, 0.15)!;
    secondary = Color.lerp(secondary, Colors.white, 0.15)!;
  } else if (companion.artStyle == CompanionArtStyle.realistic) {
    // Deeper colors for realistic style
    primary = Color.lerp(primary, Colors.black, 0.15)!;
    secondary = Color.lerp(secondary, Colors.black, 0.15)!;
  }
  
  return ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    background: const Color(0xFF1A1A2E),
    surface: const Color(0xFF16213E),
    onPrimary: Colors.white,
  );
}
}