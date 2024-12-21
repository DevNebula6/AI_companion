import 'package:flutter/material.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';

class UserAvatar extends StatelessWidget {
  final CustomAuthUser user;
  final double size;
  final bool showBorder;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.showBorder = false,
  });

  String? _getAvatarUrl() {

    if (user.avatarUrl != null) {
      return user.avatarUrl; // From CustomAuthUser
    }
    
    // Get from Google auth
    if (user.providerType == 'google.com') {
      return user.metadata['picture'] as String?;
    }
    
    // Get from Facebook auth
    if (user.providerType == 'facebook.com') {
      return user.metadata['picture']?['data']?['url'] as String?;
    }

    // Get from email (Gravatar fallback)
    return 'https://www.gravatar.com/avatar/${user.email.hashCode}?d=mp';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _getAvatarUrl();

    return Container(
      width: size,
      height: size,
      decoration: showBorder ? BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: avatarUrl != null
            ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _buildPlaceholder();
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultAvatar();
              },
            )
          : _buildDefaultAvatar(),
      ),
    );
  }


  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: size / 2,
          height: size / 2,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey[400]!,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }
}
