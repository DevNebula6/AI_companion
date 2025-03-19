import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/AI_selection/companion_details_sheet.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
            // Trigger image preloading
            context.read<CompanionBloc>().add(
              PreloadCompanionImages(state.companions)
            );

            return Stack(
              children: [
                _buildBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: 
                          (state.companions.toList().isNotEmpty)?
                            _buildSwiper(state.companions):
                            Center(child: const Text("No Companion Available")),
                      ),
                      const SizedBox(height: 4),
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
            Colors.grey.shade200,
            Colors.grey.shade300,
            
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
      layout: SwiperLayout.TINDER,
      itemWidth: MediaQuery.of(context).size.width ,
      itemHeight: MediaQuery.of(context).size.height * 0.85,
    );
  }

  Widget _buildCard(AICompanion companion) {
    List<Color> colors = [
      getTraitColor(companion.personality.primaryTraits[0], context),
      getTraitColor(companion.personality.primaryTraits.last, context),
    ];

    return GestureDetector(
      onTap: () => _showCompanionDetails(companion),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Full-size background image
          Hero(
            tag: 'companion-avatar-${companion.id}',
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CachedNetworkImage(
                imageUrl: companion.avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colors[1],
                  child: Center(
                    child: 
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(colors[0]),
                      strokeAlign: BorderSide.strokeAlignOutside,
                      strokeWidth: 4,
                    )),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors[0],
                        colors[1],
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      companion.gender == CompanionGender.female ? Icons.face_3 : Icons.face,
                      size: 80,
                      color: Colors.white60,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Gradient overlay to ensure text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.55),
                ],
                stops: const [0.7, 0.8, 1.0],
              ),
            ),
          ),
          
          // Content on top of the image
          _buildCardContent(companion),
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
      Expanded(
        flex: 4,  // Give more space to the name
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
          colors: [
            Colors.white.withOpacity(0.99), 
            Colors.white.withOpacity(0.99)
            ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          '${companion.name}, ${companion.physical.age}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                offset: const Offset(1.5, 2),
                blurRadius: 1.5,
              ),
            ], 
          ),
        ),
      ),
        ),
      ),
      const SizedBox(width: 10,),
       Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.favorite_border, color: Colors.white, size: 20),
          ),
    ],
  );
}
// In _buildTraits method
  Widget _buildTraits(AICompanion companion) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: companion.personality.primaryTraits.length,
        itemBuilder: (context, index) {
          final trait = companion.personality.primaryTraits[index];
          return _buildTraitChip(companion, trait, context);
        },
      ),
    );
  }
  Widget _buildInterests(AICompanion companion) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: (companion.personality.interests)
          .map((interest) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      getInterestIcon(interest),
                      color: Colors.white.withOpacity(0.8),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      interest,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
  Widget _buildTraitChip(AICompanion companion, String trait, BuildContext context) {
    final Color traitColor = getTraitColor(trait, context);
    final IconData traitIcon = getTraitIcon(trait);
    
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traitColor.withOpacity(0.05),
            traitColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white24,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: traitColor.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            traitIcon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            trait,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  void _showCompanionDetails(AICompanion companion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanionDetailsSheet(companion: companion),
    );
  }
}
