import 'package:flutter/material.dart';
import 'package:ai_companion/chat/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  final bool showAvatar;
  final String companionAvatar;
  final Animation<double>? animation;
  final bool isPreviousSameSender;
  final bool isNextSameSender;
  final bool isPending; // Add new property for pending state
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.showAvatar = true,
    required this.companionAvatar,
    this.animation,
    this.isPreviousSameSender = false,
    this.isNextSameSender = false,
    this.isPending = false, // Default to not pending
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Different bubble shapes based on grouping
    final BorderRadius radius = isUser 
      ? BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: isPreviousSameSender ? const Radius.circular(4) : const Radius.circular(18),
          bottomLeft: const Radius.circular(18),
          bottomRight: isNextSameSender ? const Radius.circular(4) : const Radius.circular(18),
        )
      : BorderRadius.only(
          topLeft: isPreviousSameSender ? const Radius.circular(4) : const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isNextSameSender ? const Radius.circular(4) : const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        );
    
    Widget bubbleContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: EdgeInsets.only(
        top: isPreviousSameSender ? 2 : 8,
        bottom: isNextSameSender ? 2 : 8,
        // Fix: Reduce excessive margins that push content off screen
        left: isUser ? 24 : showAvatar ? 8 : 12, 
        right: isUser ? 8 : 24,
      ),
      constraints: const BoxConstraints(
        maxWidth: 280, // Add constraint to prevent bubbles from being too wide
      ),
      decoration: BoxDecoration(
        color: isUser 
          ? theme.colorScheme.primary 
          : theme.colorScheme.surfaceVariant,
        borderRadius: radius,
        // Add subtle shadow for depth
        boxShadow: [
          BoxShadow(
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message content
          Text(
            message.message,
            style: TextStyle(
              fontSize: 16,
              color: isUser 
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Timestamp
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.messageTime,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser 
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    
    // Apply animation if provided
    if (animation != null) {
      bubbleContent = SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isUser ? 0.2 : -0.2, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation!,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: animation!,
          child: bubbleContent,
        ),
      );
    }
    
    // Add a pending indicator if the message is waiting to be sent
    if (isPending && isUser) {
      // Show pending indicator for user messages
      return Stack(
        children: [
          _buildRow(bubbleContent),
          Positioned(
            bottom: 0,
            right: isUser ? 8 : null,
            left: isUser ? null : 8,
            child: Icon(
              Icons.access_time,
              size: 12,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
        ],
      );
    }
    
    return _buildRow(bubbleContent);
  }
  
  Widget _buildRow(Widget bubbleContent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(companionAvatar),
            ),
          
          Flexible(
            child: bubbleContent,
          ),
        ],
      ),
    );
  }
}