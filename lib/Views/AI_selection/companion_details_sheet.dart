import 'dart:async';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart';
import 'package:ai_companion/chat/conversation/conversation_state.dart';
import 'package:ai_companion/navigation/routes_name.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CompanionDetailsSheet extends StatefulWidget {
  final AICompanion companion;
  final CustomAuthUser user;
  const CompanionDetailsSheet({super.key, required this.companion, required this.user});

  @override
  State<CompanionDetailsSheet> createState() => _CompanionDetailsSheetState();
}

class _CompanionDetailsSheetState extends State<CompanionDetailsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ScrollController? _scrollController;
  bool _isHeaderCollapsed = false;
  late int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Add listener for tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  void _onScroll() {
    // Only use _scrollController if it's not null
    if (_scrollController != null) {
      // Collapse header after scrolling past a threshold
      if (_scrollController!.offset > 360 && !_isHeaderCollapsed) {
        setState(() => _isHeaderCollapsed = true);
      } else if (_scrollController!.offset <= 360 && _isHeaderCollapsed) {
        setState(() => _isHeaderCollapsed = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    if (_scrollController != null) {
      _scrollController!.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = getCompanionColorScheme(widget.companion);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 1,
      builder: (context, scrollController) {
        // Clean up previous controller if it exists
        if (_scrollController != null) {
          _scrollController!.removeListener(_onScroll);
        }
        // Use the controller provided by DraggableScrollableSheet
        _scrollController = scrollController;
        _scrollController!.addListener(_onScroll);
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: // Content
                    CustomScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Expandable Header
                    _buildSliverHeader(),

                    // Tabs
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: colorScheme.primary,
                          indicatorWeight: 3,
                          labelColor: colorScheme.primary,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: AppTextStyles.buttonMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.person_outline),
                              text: 'Profile',
                            ),
                            Tab(
                              icon: Icon(Icons.auto_stories_outlined),
                              text: 'Story',
                            ),
                            Tab(
                              icon: Icon(Icons.favorite_outline),
                              text: 'Interests',
                            ),
                            Tab(
                              icon: Icon(Icons.style_outlined),
                              text: 'Voice',
                            ),
                          ],
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),

                    // Tab Content
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: _getTabHeight(),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProfileTab(colorScheme),
                            _buildStoryTab(colorScheme),
                            _buildInterestsTab(colorScheme),
                            _buildVoiceTab(colorScheme),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Header when collapsed
              if (_isHeaderCollapsed) _buildFloatingHeader(colorScheme),

              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: _buildCloseButton(),
              ),

              // Bottom Action Button
              Positioned(
                bottom: 16,
                left: 24,
                right: 24,
                child: _buildActionButton(colorScheme),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getTabHeight() {
    switch (_currentTabIndex) {
      case 0: // Profile tab
        return 1300;
      case 2: // Interests tab
        return 1100;
      default:
        return 850;
    }
  }

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Hero image - full width
          SizedBox(
            height: _isHeaderCollapsed ? 0 : 530,
            width: double.infinity,
            child: Hero(
              tag: 'companion-avatar-${widget.companion.id}',
              child: CachedNetworkImage(
                imageUrl: widget.companion.avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.transparent,
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.transparent,
                  child: const Icon(Icons.person, size: 150, color: Colors.black26),
                ),
              ),
            ),
          ),

          // Gradient overlay
          Container(
            height: 530,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),

          // Name and Info
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  widget.companion.name,
                  style: AppTextStyles.companionNamePopins.copyWith(
                    color: Colors.white,
                  ),
                ),

                // Age and short description
                Text(
                  '${widget.companion.physical.age} • ${widget.companion.physical.style}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 12),

                // Personality type indicator
                _buildPersonalityTypeChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Small avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.companion.avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => CircleAvatar(
                  backgroundColor: colorScheme.primary.withOpacity(0.5),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  backgroundColor: colorScheme.primary.withOpacity(0.5),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Text(
            widget.companion.name,
            style: AppTextStyles.displaySmall.copyWith(
              color: Colors.black87,
            ),
          ),

          const Spacer(),

          // Like button
          IconButton(
            icon: Icon(Icons.favorite_border, color: colorScheme.primary),
            onPressed: () {
              // Add favorite functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityTypeChip() {
    final type = getPersonalityType(widget.companion);
    final color = getTraitColor(widget.companion.personality.primaryTraits.first, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getPersonalityIcon(widget.companion),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            type,
            style: AppTextStyles.chipLabel.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Physical Attributes',
            icon: Icons.person_outline,
            color: colorScheme.primary,
            child: Column(
              children: [
                _buildAttributeRow('Height', widget.companion.physical.height, Icons.height),
                _buildAttributeRow('Body Type', widget.companion.physical.bodyType, Icons.accessibility_new),
                _buildAttributeRow('Hair', widget.companion.physical.hairColor, Icons.face),
                _buildAttributeRow('Eyes', widget.companion.physical.eyeColor, Icons.remove_red_eye),
                _buildAttributeRow('Style', widget.companion.physical.style, Icons.style),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Distinguishing Features',
            icon: Icons.auto_awesome,
            color: colorScheme.secondary,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.companion.physical.distinguishingFeatures
                  .map((feature) => _buildFeatureChip(feature, colorScheme))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Personality Traits',
            icon: Icons.psychology,
            color: colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTraitList('Primary', widget.companion.personality.primaryTraits, colorScheme.primary),
                const SizedBox(height: 16),
                _buildTraitList('Secondary', widget.companion.personality.secondaryTraits, colorScheme.secondary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Core Values',
            icon: Icons.volunteer_activism,
            color: colorScheme.secondary,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.companion.personality.values
                  .map((value) => _buildValueChip(value, colorScheme))
                  .toList(),
            ),
          ),
          // Space for bottom action button
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStoryTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Background Story',
            icon: Icons.auto_stories_outlined,
            color: colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.companion.background
                  .asMap()
                  .entries
                  .map((entry) => _buildStoryItem(entry.value, entry.key, colorScheme))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Skills & Abilities',
            icon: Icons.workspace_premium,
            color: colorScheme.secondary,
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: widget.companion.skills
                  .map((skill) => _buildSkillChip(skill, colorScheme))
                  .toList(),
            ),
          ),
          // Space for bottom action button
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInterestsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Interests & Hobbies',
            icon: Icons.favorite_border,
            color: colorScheme.primary,
            child: _buildInterestsGrid(colorScheme),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Conversation Topics',
            icon: Icons.chat_bubble_outline,
            color: colorScheme.secondary,
            child: _buildConversationTopics(colorScheme),
          ),
          // Space for bottom action button
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVoiceTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Voice & Communication',
            icon: Icons.record_voice_over,
            color: colorScheme.primary,
            child: Column(
              children: widget.companion.voice
                  .asMap()
                  .entries
                  .map((entry) => _buildVoiceAttribute(entry.value, entry.key, colorScheme))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Voice Sample',
            icon: Icons.graphic_eq,
            color: colorScheme.secondary,
            child: Column(
              children: [
                // Voice waveform visualization
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(30, (index) {
                      // Create random height bars for waveform
                      final height = 10 + (index % 3) * 10.0 + (index % 7) * 5.0;
                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                // Play button
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice sample coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Listen to voice sample'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
          // Space for bottom action button
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.sectionHeader.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.attributeLabel,
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: AppTextStyles.attributeValue,
              textAlign: TextAlign.end, // Right-align the text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String feature, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Text(
        feature,
        style: AppTextStyles.chipLabel.copyWith(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTraitList(String type, List<String> traits, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$type Traits',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: traits.map((trait) {
            final IconData traitIcon = getTraitIcon(trait);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(traitIcon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    trait,
                    style: AppTextStyles.chipLabel.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildValueChip(String value, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        value,
        style: AppTextStyles.chipLabel.copyWith(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStoryItem(String story, int index, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot and line
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // Line to next item
              if (index < widget.companion.background.length - 1)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                story,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getSkillIcon(skill),
            size: 16,
            color: colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            skill,
            style: AppTextStyles.chipLabel.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.companion.personality.interests.length,
      itemBuilder: (context, index) {
        final interest = widget.companion.personality.interests[index];
        return Container(
          decoration: BoxDecoration(
            color: index % 2 == 0
                ? colorScheme.primary.withOpacity(0.07)
                : colorScheme.secondary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: index % 2 == 0
                  ? colorScheme.primary.withOpacity(0.3)
                  : colorScheme.secondary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Subtle decoration
              Positioned(
                top: -15,
                right: -15,
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(
                    getInterestIcon(interest),
                    size: 50,
                    color: index % 2 == 0
                        ? colorScheme.primary
                        : colorScheme.secondary,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 8,
                  top: 12,
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      getInterestIcon(interest),
                      size: 22,
                      color: index % 2 == 0
                          ? colorScheme.primary
                          : colorScheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        interest,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationTopics(ColorScheme colorScheme) {
    // Generate conversation topics based on interests and background
    final List<String> topics = [
      ...widget.companion.personality.interests,
      ...widget.companion.personality.values,
      ...widget.companion.skills.take(2),
    ].take(6).toList();

    return Column(
      children: [
        for (int i = 0; i < topics.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  getConversationIcon(topics[i]),
                  color: i % 2 == 0 ? colorScheme.secondary : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Talk about ${topics[i]}",
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        getConversationPrompt(topics[i]),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 14,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVoiceAttribute(String attribute, int index, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? colorScheme.primary.withOpacity(0.05)
            : colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              getVoiceIcon(attribute, index),
              size: 18,
              color: index % 2 == 0 ? colorScheme.primary : colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attribute,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  Color.lerp(colorScheme.primary, colorScheme.secondary, 0.5)!,
                  colorScheme.secondary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  String text = 'Starting conversation with ${widget.companion.name}';
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(text),
                      duration: const Duration(seconds: 2),
                      backgroundColor: colorScheme.secondary,
                    ),
                  );

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  // Create conversation and listen for the result
                  final conversationBloc = context.read<ConversationBloc>();
                  late final StreamSubscription subscription;

                  subscription = conversationBloc.stream.listen((state) {
                    if (state is ConversationCreated) {
                      subscription.cancel();

                      // Now we have the conversation ID
                      context.pushReplacement(RoutesName.chat, extra: {
                        'companion': widget.companion,
                        'conversationId': state.conversationId,
                        'navigationSource': 'companionDetails',
                      });

                      // Close the loading dialog
                      Navigator.of(context).pop();

                      // Close the details sheet
                      Navigator.of(context).pop();
                    } else if (state is ConversationError) {
                      subscription.cancel();

                      // Show error message
                      Navigator.of(context).pop(); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${state.message}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });

                  // Send the event to create the conversation
                  conversationBloc.add(CreateConversation(widget.companion.id));
                },
                splashColor: Colors.white.withOpacity(0.1),
                highlightColor: Colors.transparent,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start conversation',
                        style: AppTextStyles.buttonLarge.copyWith(
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chat_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Tab Bar Delegate implementation
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || backgroundColor != oldDelegate.backgroundColor;
  }
}