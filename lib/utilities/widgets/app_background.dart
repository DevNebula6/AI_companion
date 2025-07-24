import 'package:flutter/material.dart';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';

/// Enhanced reusable background widget with gradient and chat screen support
/// Used throughout the app for consistent visual styling
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showTopCircle;
  final bool showBottomCircle;
  final List<Color>? gradientColors;
  final double topCircleSize;
  final double bottomCircleSize;
  final Color? topCircleColor;
  final Color? bottomCircleColor;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;
  
  // AppBar functionality
  final bool showAppBar;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? appBarTextColor;
  final bool centerTitle;
  final double? appBarElevation;
  final bool extendBodyBehindAppBar;
  
  // Enhanced content area
  final Widget? appBarContent;
  final double? appBarHeight;
  final EdgeInsets? appBarPadding;
  final MainAxisAlignment? appBarMainAxisAlignment;
  final CrossAxisAlignment? appBarCrossAxisAlignment;
  
  // Chat-specific enhancements
  final bool isChatScreen;
  final AICompanion? companion;
  final Widget? chatAppBarContent;
  final bool showConnectivityIndicator;

  const AppBackground({
    super.key,
    required this.child,
    this.showTopCircle = true,
    this.showBottomCircle = true,
    this.gradientColors,
    this.topCircleSize = 400.0,
    this.bottomCircleSize = 500.0,
    this.topCircleColor,
    this.bottomCircleColor,
    this.gradientBegin = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    // AppBar properties
    this.showAppBar = false,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.appBarTextColor,
    this.centerTitle = true,
    this.appBarElevation = 0,
    this.extendBodyBehindAppBar = false,
    // Flexible content properties
    this.appBarContent,
    this.appBarHeight,
    this.appBarPadding,
    this.appBarMainAxisAlignment,
    this.appBarCrossAxisAlignment,
    // Chat-specific properties
    this.isChatScreen = false,
    this.companion,
    this.chatAppBarContent,
    this.showConnectivityIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final textColor = appBarTextColor ?? _getDefaultTextColor(context);
    
    // Determine gradient colors
    final effectiveGradientColors = _getEffectiveGradientColors(context);
    final effectiveTopCircleColor = _getEffectiveTopCircleColor();
    final effectiveBottomCircleColor = _getEffectiveBottomCircleColor();

    return Container(
      width: screenSize.width,
      height: screenSize.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: gradientBegin,
          end: gradientEnd,
          colors: effectiveGradientColors,
        ),
      ),
      child: Stack(
        children: [
          // Top right circle
          if (showTopCircle)
            Positioned(
              top: -topCircleSize * 0.3,
              right: -topCircleSize * 0.3,
              child: Container(
                width: topCircleSize,
                height: topCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveTopCircleColor,
                ),
              ),
            ),
          
          // Bottom left circle
          if (showBottomCircle)
            Positioned(
              bottom: -bottomCircleSize * 0.4,
              left: -bottomCircleSize * 0.4,
              child: Container(
                width: bottomCircleSize,
                height: bottomCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveBottomCircleColor,
                ),
              ),
            ),
          
          // Main content with proper top padding if AppBar is shown
          Positioned.fill(
            top: showAppBar && !extendBodyBehindAppBar ? 0 : 0,
            child: Column(
              children: [
                // Custom AppBar if enabled
                if (showAppBar)
                  _buildCustomAppBar(context, textColor, statusBarHeight),
                
                // Main content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build custom AppBar with enhanced functionality
  Widget _buildCustomAppBar(BuildContext context, Color textColor, double statusBarHeight) {
    final effectivePadding = appBarPadding ?? EdgeInsets.fromLTRB(
      16,
      statusBarHeight + 8,
      16,
      8,
    );

    return Container(
      width: double.infinity,
      padding: effectivePadding,
      child: Stack(
        children: [
          // Main content area
          SizedBox(
            height: appBarHeight ?? 48,
            child: isChatScreen 
              ? _buildChatAppBarContent(context, textColor)
              : (appBarContent != null 
                ? _buildFlexibleAppBarContent(context, textColor)
                : _buildDefaultAppBarContent(context, textColor)),
          ),
          
          // Back button positioned independently
          if (showBackButton || leading != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: leading ?? _buildBackButton(context, textColor),
              ),
            ),
          
          // Actions positioned independently
          if (actions != null && actions!.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build chat-specific AppBar content
  Widget _buildChatAppBarContent(BuildContext context, Color textColor) {
    if (chatAppBarContent != null) {
      return chatAppBarContent!;
    }

    if (companion == null) {
      return _buildDefaultAppBarContent(context, textColor);
    }

    return Row(
      children: [
        // Leading space (back button will be positioned above this)
        if (showBackButton || leading != null)
          const SizedBox(width: 48),
        
        // Companion info in center
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'avatar_${companion!.id}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: companion!.avatarUrl.isNotEmpty 
                      ? NetworkImage(companion!.avatarUrl)
                      : null,
                    child: companion!.avatarUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 20,
                        )
                      : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companion!.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showConnectivityIndicator)
                      Text(
                        'Online',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Actions space (actions will be positioned above this)
        if (actions != null && actions!.isNotEmpty)
          SizedBox(width: actions!.length * 48.0),
      ],
    );
  }

  /// Build flexible AppBar content
  Widget _buildFlexibleAppBarContent(BuildContext context, Color textColor) {
    return IntrinsicHeight(
      child: SizedBox(
        width: double.infinity,
        child: appBarContent!,
      ),
    );
  }

  /// Build default AppBar content
  Widget _buildDefaultAppBarContent(BuildContext context, Color textColor) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // Leading space (back button will be positioned above this)
          if (showBackButton || leading != null)
            const SizedBox(width: 48),
          
          // Title
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Expanded(child: SizedBox()),
          
          // Actions space (actions will be positioned above this)
          if (actions != null && actions!.isNotEmpty)
            SizedBox(width: actions!.length * 48.0),
        ],
      ),
    );
  }

  /// Build back button
  Widget _buildBackButton(BuildContext context, Color textColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onBackPressed ?? () => Navigator.of(context).pop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: textColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Get effective gradient colors based on companion or theme
  List<Color> _getEffectiveGradientColors(BuildContext context) {
    if (gradientColors != null && gradientColors!.isNotEmpty) {
      return gradientColors!;
    }

    if (isChatScreen && companion != null) {
      final companionColors = getCompanionColors(companion!);
      return [
        companionColors.gradient1,
        companionColors.gradient2,
        companionColors.gradient3,
      ];
    }

    // Default gradient based on theme
    final theme = Theme.of(context);
    return [
      theme.colorScheme.primary.withOpacity(0.8),
      theme.colorScheme.primaryContainer.withOpacity(0.6),
      theme.colorScheme.surface,
    ];
  }

  /// Get effective top circle color
  Color _getEffectiveTopCircleColor() {
    if (topCircleColor != null) {
      return topCircleColor!;
    }

    if (isChatScreen && companion != null) {
      return getCompanionColors(companion!).gradient1.withOpacity(0.1);
    }

    return Colors.white.withOpacity(0.1);
  }

  /// Get effective bottom circle color
  Color _getEffectiveBottomCircleColor() {
    if (bottomCircleColor != null) {
      return bottomCircleColor!;
    }

    if (isChatScreen && companion != null) {
      return getCompanionColors(companion!).gradient3.withOpacity(0.1);
    }

    return Colors.white.withOpacity(0.05);
  }

  /// Get default text color based on gradient
  Color _getDefaultTextColor(BuildContext context) {
    if (isChatScreen || (gradientColors != null && gradientColors!.isNotEmpty)) {
      return Colors.white;
    }
    return Theme.of(context).colorScheme.onSurface;
  }
}

/// Specialized AppBackground for chat screens
class ChatAppBackground extends StatelessWidget {
  final Widget child;
  final AICompanion companion;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? appBarContent;
  final bool showConnectivityIndicator;
  final double? appBarHeight;
  final EdgeInsets? appBarPadding;

  const ChatAppBackground({
    super.key,
    required this.child,
    required this.companion,
    this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.appBarContent,
    this.showConnectivityIndicator = false,
    this.appBarHeight,
    this.appBarPadding,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      isChatScreen: true,
      companion: companion,
      showAppBar: true,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      title: title,
      actions: actions,
      chatAppBarContent: appBarContent,
      appBarTextColor: Colors.white,
      showConnectivityIndicator: showConnectivityIndicator,
      appBarHeight: appBarHeight,
      appBarPadding: appBarPadding,
      extendBodyBehindAppBar: false,
      child: child,
    );
  }
}

/// Variant of AppBackground for screens that need a SafeArea
class AppBackgroundSafe extends StatelessWidget {
  final Widget child;
  final bool showTopCircle;
  final bool showBottomCircle;
  final List<Color>? gradientColors;
  final EdgeInsets? padding;
  final double topCircleSize;
  final double bottomCircleSize;
  final Color? topCircleColor;
  final Color? bottomCircleColor;
  
  // AppBar functionality
  final bool showAppBar;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? appBarTextColor;
  final bool centerTitle;
  
  // Flexible content area
  final Widget? appBarContent;
  final double? appBarHeight;
  final EdgeInsets? appBarPadding;
  final MainAxisAlignment? appBarMainAxisAlignment;
  final CrossAxisAlignment? appBarCrossAxisAlignment;

  const AppBackgroundSafe({
    super.key,
    required this.child,
    this.showTopCircle = true,
    this.showBottomCircle = true,
    this.gradientColors,
    this.padding,
    this.topCircleSize = 400.0,
    this.bottomCircleSize = 500.0,
    this.topCircleColor,
    this.bottomCircleColor,
    // AppBar properties
    this.showAppBar = false,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.appBarTextColor,
    this.centerTitle = true,
    // Flexible content properties
    this.appBarContent,
    this.appBarHeight,
    this.appBarPadding,
    this.appBarMainAxisAlignment,
    this.appBarCrossAxisAlignment,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      showTopCircle: showTopCircle,
      showBottomCircle: showBottomCircle,
      gradientColors: gradientColors,
      topCircleSize: topCircleSize,
      bottomCircleSize: bottomCircleSize,
      topCircleColor: topCircleColor,
      bottomCircleColor: bottomCircleColor,
      showAppBar: showAppBar,
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      leading: leading,
      appBarTextColor: appBarTextColor,
      centerTitle: centerTitle,
      appBarContent: appBarContent,
      appBarHeight: appBarHeight,
      appBarPadding: appBarPadding,
      appBarMainAxisAlignment: appBarMainAxisAlignment,
      appBarCrossAxisAlignment: appBarCrossAxisAlignment,
      child: SafeArea(
        top: showAppBar ? false : true,
        minimum: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Helper widget for creating complex AppBar layouts
class AppBarContentBuilder extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const AppBarContentBuilder({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }

  /// Creates a row layout within the AppBar content
  static Widget row({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.spaceBetween,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  /// Creates a column layout within the AppBar content
  static Widget column({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  /// Creates a title with subtitle layout
  static Widget titleWithSubtitle({
    required String title,
    required String subtitle,
    Color? titleColor,
    Color? subtitleColor,
    TextAlign textAlign = TextAlign.center,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: titleColor ?? Colors.white,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: subtitleColor ?? Colors.white70,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }

  /// Creates a search bar layout
  static Widget searchBar({
    required String hintText,
    required ValueChanged<String> onChanged,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: textColor ?? Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(color: textColor ?? Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: textColor?.withOpacity(0.7) ?? Colors.white70),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}