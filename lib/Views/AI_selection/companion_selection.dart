import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/AI_selection/companion_details_sheet.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/navigation/routes_name.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/utilities/widgets/floating_connectivity_indicator.dart';
import 'package:go_router/go_router.dart';

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
    return FloatingConnectivityIndicator(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:Color(0xFFE6F0F5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (Navigator.canPop(context)) {
                // If we can pop, go back
                context.pop();
              } else {
                // Otherwise, navigate to home
                context.pushReplacementNamed(RoutesName.home,);
              }
            },
          ),
          title: Text(
          'Choose Your Companion',
          style: AppTextStyles.displayMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          ),
          centerTitle: true,
        ),
        body: BlocConsumer<CompanionBloc, CompanionState>(
          listener: (context, state) {
            if (state is CompanionError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load companions - ${state.message}')),
              );
            }
          },
          builder: (BuildContext context, CompanionState state) {
            if (state is CompanionLoading) {
              return const Center(child: CircularProgressIndicator());
            } 
            if (state is CompanionError) {
              return RetryActionButton();
            }
            if (state is CompanionLoaded) {
              return Stack(
                children: [
                  _buildBackground(),
                  SafeArea(
                    child: Column(
                      children: [
                        // _buildHeader(),
                        Expanded(
                          child: 
                            (state.companions.toList().isNotEmpty)?
                              _buildSwiper(state.companions):
                              const RetryActionButton(),
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
      ),
    );
  }

  Widget _buildBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // Color(0xFFFFFAF5), // Very soft warm white
          // Color(0xFFF8F0F0), // Subtle blush undertone
         // Subtle bluish undertone
          Color(0xFFE6F0F5),
          Color(0xFFE6F0F6),
        ],
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
    return GestureDetector(
      onTap: () => _showCompanionDetails(companion,user),
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                        // Modern teal to blue gradient
                        Color(0xFF4AC8EA),  // Light teal
                        Color(0xFF2A80D7),  // Medium blue

                    ]),
                  ),
                  child: Center(
                    child: 
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      strokeAlign: BorderSide.strokeAlignOutside,
                      strokeWidth: 4,
                    )),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFF4AC8EA),  // Light teal
                      Color(0xFF2A80D7),  // Medium blue
                    ]),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 150,
                      color: Colors.black.withOpacity(0.3),
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
          child: Text(
            '${companion.name}, ${companion.physical.age}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTextStyles.companionNamePopins.copyWith(
              height: 1.5,
              fontSize: 34,
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
      const SizedBox(width: 10,),
       Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite_border, color: Colors.white, size: 20),
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
                      style: AppTextStyles.forDarkTheme(AppTextStyles.bodyMedium).copyWith(
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
            traitColor.withOpacity(0.1),
            traitColor.withOpacity(0.1),
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
            style: AppTextStyles.chipLabel.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  void _showCompanionDetails(AICompanion companion,CustomAuthUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,

      backgroundColor: Colors.transparent,
      builder: (context) => CompanionDetailsSheet(
        companion: companion,
        user: user,

        ),
    );
  }
}

class RetryActionButton extends StatelessWidget {
  const RetryActionButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Center(
            child:Text(
              'Failed to load companions, please try again',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                )
              )
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.read<CompanionBloc>().add(LoadCompanions());
            },
            child: const Text('Retry'),
          ),
        ],
      );
  }
}
