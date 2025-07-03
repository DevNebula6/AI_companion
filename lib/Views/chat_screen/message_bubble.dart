import 'package:ai_companion/chat/message.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isUser;
  final String? companionAvatar;
  final bool showAvatar;
  final bool isPreviousSameSender;
  final bool isNextSameSender;
  final Animation<double>? animation;
  final bool isPending;
  final bool isFragment;
  final bool isLastFragment;
  final int? fragmentIndex;
  final int? totalFragments;
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.companionAvatar,
    this.showAvatar = true,
    this.isPreviousSameSender = false,
    this.isNextSameSender = false,
    this.animation,
    this.isPending = false,
    this.isFragment = false,
    this.isLastFragment = false,
    this.fragmentIndex,
    this.totalFragments,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _avatarScaleAnimation;
  bool _hasAnimated = false; // NEW: Track if this bubble has already animated

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: widget.isFragment ? 200 : 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _avatarScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // FIXED: Enhanced animation logic for fragments with better detection
    final isNewMessage = widget.message.created_at.isAfter(DateTime.now().subtract(const Duration(seconds: 2)));
    final isTemporaryFragment = widget.message.id?.contains('_fragment_') == true && 
                               !widget.message.id!.startsWith('permanent_');
    
    // CRITICAL FIX: Only animate if this is a truly new fragment or message
    final shouldAnimate = (widget.isFragment && isTemporaryFragment) || 
                         (!widget.isFragment && isNewMessage);
    
    if (shouldAnimate) {
      _hasAnimated = true;
      _animationController.forward();
    } else {
      // Skip animation for existing/permanent fragments
      _animationController.value = 1.0;
      _hasAnimated = true; // Mark as already animated to prevent future animations
    }
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CRITICAL FIX: Only trigger avatar animation for new fragments that haven't animated yet
    if (widget.isFragment && 
        !_hasAnimated && // Prevent re-animation of existing fragments
        oldWidget.showAvatar != widget.showAvatar && 
        widget.showAvatar &&
        widget.message.id?.contains('_fragment_') == true &&
        !widget.message.id!.startsWith('permanent_')) {
      
      // This is a temporary fragment getting an avatar for the first time
      _hasAnimated = true;
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enhanced fragment detection
    final isFragment = widget.isFragment || widget.message.metadata['is_fragment'] == true;
    final isLastFragment = widget.isLastFragment || (isFragment && (widget.fragmentIndex == (widget.totalFragments ?? 1) - 1));
    
    // Calculate proper spacing for fragments
    final topMargin = _calculateTopMargin();
    final bottomMargin = _calculateBottomMargin();
    
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
                _buildAvatarOrSpacer(isFragment, isLastFragment),
              
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getBubbleColor(context),
                    borderRadius: _getBorderRadius(isFragment, isLastFragment),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
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
                          height: 1.3,
                        ),
                      ),
                      if (!isFragment || isLastFragment)
                        const SizedBox(height: 4),
                      if (!isFragment || isLastFragment)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.message.messageTime,
                              style: TextStyle(
                                color: _getTextColor(context).withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            if (widget.isPending) ...[
                              const SizedBox(width: 4),
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
                        ),
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

  double _calculateTopMargin() {
    if (widget.isFragment) {
      return widget.fragmentIndex == 0 
          ? (widget.isPreviousSameSender ? 8 : 12)  // Increased spacing for first fragment
          : 8; // Increased spacing between fragments
    }
    return widget.isPreviousSameSender ? 2 : 8;
  }

  double _calculateBottomMargin() {
    if (widget.isFragment) {
      return widget.isLastFragment 
          ? (widget.isNextSameSender ? 8 : 12)  // Increased spacing for last fragment
          : 8; // Increased spacing between fragments
    }
    return widget.isNextSameSender ? 2 : 8;
  }

  Widget _buildAvatarOrSpacer(bool isFragment, bool isLastFragment) {
    final shouldShowAvatar = widget.showAvatar;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: shouldShowAvatar 
          ? ScaleTransition( // NEW: Animated avatar appearance
              scale: _avatarScaleAnimation,
              child: CircleAvatar(
                radius: 16,
                backgroundImage: widget.companionAvatar != null
                    ? NetworkImage(widget.companionAvatar!)
                    : null,
                child: widget.companionAvatar == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
            )
          : const SizedBox(width: 32), // Consistent spacing
    );
  }

  BorderRadius _getBorderRadius(bool isFragment, bool isLastFragment) {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(6);
    const fragmentRadius = Radius.circular(14); // Slightly larger for better visual distinction
    
    if (widget.isUser) {
      if (isFragment) {
        return BorderRadius.only(
          topLeft: fragmentRadius,
          topRight: widget.fragmentIndex == 0 
              ? (widget.isPreviousSameSender ? smallRadius : radius)
              : fragmentRadius,
          bottomLeft: fragmentRadius,
          bottomRight: isLastFragment 
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
          bottomLeft: isLastFragment 
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