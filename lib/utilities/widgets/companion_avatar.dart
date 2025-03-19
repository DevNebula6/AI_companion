// lib/utilities/widgets/companion_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ai_companion/Companion/ai_model.dart';

class CompanionAvatar extends StatelessWidget {
  final AICompanion companion;
  final double size;
  final double borderRadius;
  final bool useHero;
  final VoidCallback? onTap;
  final bool showBorder;
  final String? heroTag;

  const CompanionAvatar({
    super.key,
    required this.companion,
    this.size = 120,
    this.borderRadius = 20,
    this.useHero = true,
    this.onTap,
    this.showBorder = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTag = heroTag ?? 'companion-avatar-${companion.id}';
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: companion.avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildShimmerPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(context),
        fadeInDuration: const Duration(milliseconds: 300),
        memCacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
        cacheKey: 'companion-${companion.id}-${size.round()}',
      ),
    );

    final wrappedWidget = Container(
      decoration: showBorder ? BoxDecoration(
        shape: BorderRadius.circular(borderRadius) == BorderRadius.circular(size / 2) 
            ? BoxShape.circle 
            : BoxShape.rectangle,
        borderRadius: borderRadius < size / 2 ? BorderRadius.circular(borderRadius) : null,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageWidget,
        ),
      ),
    );

    if (useHero) {
      return Hero(
        tag: effectiveTag,
        child: wrappedWidget,
      );
    }

    return wrappedWidget;
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    // Style based on companion gender and art style
    Color backgroundColor;
    IconData iconData;
    
    switch (companion.gender) {
      case CompanionGender.female:
        backgroundColor = Colors.purple.shade200;
        iconData = Icons.face_3;
        break;
      case CompanionGender.male:
        backgroundColor = Colors.blue.shade200;
        iconData = Icons.face;
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        iconData = Icons.person;
    }
    
    if (companion.artStyle == CompanionArtStyle.anime) {
      iconData = Icons.animation;
    } else if (companion.artStyle == CompanionArtStyle.cartoon) {
      iconData = Icons.draw;
    }
    
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      child: Icon(
        iconData,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}