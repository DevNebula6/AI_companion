import 'package:flutter/material.dart';

class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isTyping;
  final bool isOnline; // Add this parameter

  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isTyping,
    this.isOnline = true, // Default to online
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _hasText && !widget.isTyping;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isOnline 
                    ? theme.colorScheme.outline.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                enabled: widget.isOnline, // Disable when offline
                decoration: InputDecoration(
                  hintText: widget.isOnline 
                    ? 'Type a message...'
                    : 'Connect to internet to send messages',
                  hintStyle: TextStyle(
                    color: widget.isOnline
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  suffixIcon: !widget.isOnline
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.wifi_off,
                          color: Colors.orange,
                          size: 20,
                        ),
                      )
                    : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: (canSend && widget.isOnline) ? widget.onSend : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (canSend && widget.isOnline)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isTyping
                      ? Icons.more_horiz
                      : Icons.send_rounded,
                  color: (canSend && widget.isOnline)
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
}