import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool isTyping;
  
  const ChatInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.isTyping = false,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool _hasText = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHasText);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }
  
  void _updateHasText() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, -2),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button for future use
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                // To be implemented later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachments coming soon'))
                );
              },
            ),
            
            // Text field
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.isTyping 
                      ? 'AI is typing...' 
                      : 'Type a message...',
                  hintStyle: TextStyle(
                    color: widget.isTyping
                        ? theme.colorScheme.primary
                        : null,
                    fontStyle: widget.isTyping
                        ? FontStyle.italic
                        : null,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  if (_hasText && !widget.isTyping) {
                    widget.onSend();
                  }
                },
              ),
            ),
            
            // Send button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: _hasText && !widget.isTyping
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: widget.onSend,
                    ).animate().scale(
                      duration: 150.ms,
                      curve: Curves.easeOut,
                    )
                  : IconButton(
                      key: const ValueKey('mic'),
                      icon: const Icon(Icons.mic_none),
                      onPressed: () {
                        // To be implemented later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voice input coming soon'))
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}