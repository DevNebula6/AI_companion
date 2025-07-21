import 'package:ai_companion/chat/message.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isUser;
  final String? companionAvatar;
  final bool showAvatar;
  final bool isPreviousSameSender;
  final bool isNextSameSender;
  final bool isPending;
  final bool isFragment;
  final bool isLastFragment;
  final int? fragmentIndex;
  final int? totalFragments;
  final bool isActiveFragment; // Track if this is the currently active fragment
  final LinearGradient? gradient;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.companionAvatar,
    this.showAvatar = true,
    this.isPreviousSameSender = false,
    this.isNextSameSender = false,
    this.isPending = false,
    this.isFragment = false,
    this.isLastFragment = false,
    this.fragmentIndex,
    this.totalFragments,
    this.isActiveFragment = false, 
    this.gradient,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _avatarController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _avatarScaleAnimation;
  late Animation<double> _avatarOpacityAnimation;
  
  bool _avatarHasAnimated = false;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller for message appearance
    _fadeController = AnimationController(
      duration: Duration(milliseconds: widget.isFragment ? 300 : 400),
      vsync: this,
    );
    
    // Separate controller for avatar animations
    _avatarController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _setupAnimations();
    _triggerInitialAnimation();
  }

  void _setupAnimations() {
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _avatarScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _avatarController,
      curve: Curves.elasticOut,
    ));
    
    _avatarOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _avatarController,
      curve: Curves.easeOut,
    ));
  }

  void _triggerInitialAnimation() {
    // Determine if this is a new message that should animate
    final isNewMessage = _isMessageNew();
    final isNewFragment = widget.isFragment && !_isPersistedFragment();
    
    if (isNewMessage || isNewFragment) {
      _fadeController.forward();
      
      // Trigger avatar animation if avatar should be shown
      if (widget.showAvatar && !widget.isUser) {
        _triggerAvatarAnimation();
      }
    } else {
      // Skip animation for existing messages
      _fadeController.value = 1.0;
      _avatarController.value = 1.0;
      _avatarHasAnimated = true;
    }
  }

  void _triggerAvatarAnimation() {
    if (!_avatarHasAnimated && widget.showAvatar && !widget.isUser) {
      _avatarHasAnimated = true;
      
      // Slight delay for avatar animation to create nice effect
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _avatarController.forward();
        }
      });
    }
  }

  bool _isMessageNew() {
    // Consider message new if created within last 3 seconds
    return widget.message.created_at.isAfter(
      DateTime.now().subtract(const Duration(seconds: 3))
    );
  }

  bool _isPersistedFragment() {
    // Check if this is a persisted fragment (starts with 'permanent_')
    return widget.message.id?.startsWith('permanent_') == true;
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CRITICAL: Handle avatar cycling for fragments
    if (widget.isFragment && 
        oldWidget.showAvatar != widget.showAvatar) {
      
      if (widget.showAvatar && !_avatarHasAnimated) {
        // Avatar is appearing - animate it in
        _triggerAvatarAnimation();
      } else if (!widget.showAvatar && _avatarHasAnimated) {
        // Avatar is disappearing - animate it out
        _avatarController.reverse().then((_) {
          _avatarHasAnimated = false;
        });
      }
    }
    
    // Handle active fragment highlighting
    if (widget.isFragment && 
        oldWidget.isActiveFragment != widget.isActiveFragment &&
        widget.isActiveFragment) {
      _triggerHighlightAnimation();
    }
  }

  void _triggerHighlightAnimation() {
    // Subtle highlight animation for active fragment
    if (mounted) {
      _fadeController.forward(from: 0.7);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFragment = widget.isFragment || widget.message.metadata['is_fragment'] == true;
    final topMargin = _calculateTopMargin(isFragment);
    final bottomMargin = _calculateBottomMargin(isFragment);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            bottom: bottomMargin,
            left: widget.isUser ? 50 : 8,
            right: widget.isUser ? 8 : 50,
          ),
          child: Row(
            mainAxisAlignment: widget.isUser 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.isUser)
                _buildAnimatedAvatarOrSpacer(),
              
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getBubbleColor(context),
                    borderRadius: _getBorderRadius(isFragment),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.message,
                        style: TextStyle(
                          color: _getTextColor(context),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      if (_shouldShowMetadata(isFragment))
                        const SizedBox(height: 6),
                      if (_shouldShowMetadata(isFragment))
                        _buildMessageMetadata(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAvatarOrSpacer() {
    if (widget.showAvatar) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: FadeTransition(
          opacity: _avatarOpacityAnimation,
          child: ScaleTransition(
            scale: _avatarScaleAnimation,
            child: CircleAvatar(
              radius: 18,
              backgroundImage: widget.companionAvatar != null
                  ? NetworkImage(widget.companionAvatar!)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: widget.companionAvatar == null
                  ? Icon(
                      Icons.person, 
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
          ),
        ),
      );
    } else {
      return const SizedBox(width: 44); // 36 (avatar diameter) + 8 (margin)
    }
  }

  Widget _buildMessageMetadata(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // REMOVED: Fragment count indicator (too robotic)
        
        // Timestamp
        Text(
          widget.message.messageTime,
          style: TextStyle(
            color: _getTextColor(context).withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        
        // Pending indicator
        if (widget.isPending) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTextColor(context).withOpacity(0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _shouldShowMetadata(bool isFragment) {
    // Show metadata on last fragment or non-fragment messages
    return !isFragment || widget.isLastFragment;
  }

  double _calculateTopMargin(bool isFragment) {
    if (isFragment) {
      // First fragment gets more space, others get reduced space
      return widget.fragmentIndex == 0 
          ? (widget.isPreviousSameSender ? 6 : 12)
          : 3;
    }
    return widget.isPreviousSameSender ? 2 : 12;
  }

  double _calculateBottomMargin(bool isFragment) {
    if (isFragment) {
      // Last fragment gets more space, others get reduced space
      return widget.isLastFragment 
          ? (widget.isNextSameSender ? 6 : 12)
          : 3;
    }
    return widget.isNextSameSender ? 2 : 12;
  }

  BorderRadius _getBorderRadius(bool isFragment) {
    const radius = Radius.circular(20);
    const smallRadius = Radius.circular(6);
    const fragmentRadius = Radius.circular(16);
    
    if (widget.isUser) {
      if (isFragment) {
        return BorderRadius.only(
          topLeft: fragmentRadius,
          topRight: widget.fragmentIndex == 0 
              ? (widget.isPreviousSameSender ? smallRadius : radius)
              : fragmentRadius,
          bottomLeft: fragmentRadius,
          bottomRight: widget.isLastFragment 
              ? (widget.isNextSameSender ? smallRadius : radius)
              : fragmentRadius,
        );
      }
      return BorderRadius.only(
        topLeft: radius,
        topRight: widget.isPreviousSameSender ? smallRadius : radius,
        bottomLeft: radius,
        bottomRight: widget.isNextSameSender ? smallRadius : radius,
      );
    } else {
      if (isFragment) {
        return BorderRadius.only(
          topLeft: widget.fragmentIndex == 0 
              ? (widget.isPreviousSameSender ? smallRadius : radius)
              : fragmentRadius,
          topRight: fragmentRadius,
          bottomLeft: widget.isLastFragment 
              ? (widget.isNextSameSender ? smallRadius : radius)
              : fragmentRadius,
          bottomRight: fragmentRadius,
        );
      }
      return BorderRadius.only(
        topLeft: widget.isPreviousSameSender ? smallRadius : radius,
        topRight: radius,
        bottomLeft: widget.isNextSameSender ? smallRadius : radius,
        bottomRight: radius,
      );
    }
  }

  Color _getBubbleColor(BuildContext context) {
    if (widget.isUser) {
      return Theme.of(context).colorScheme.primary;
    } else {
      // REMOVED: Active fragment highlighting (too robotic)
      return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  Color _getTextColor(BuildContext context) {
    if (widget.isUser) {
      return Theme.of(context).colorScheme.onPrimary;
    } else {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}