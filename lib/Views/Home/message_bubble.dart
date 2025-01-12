import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/utilities/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
class MessageBubble extends StatelessWidget {
  final Message message;
  final UserAvatar userAvatar;
  const MessageBubble({
    super.key,
    required this.message, required this.userAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) _buildBotAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: message.isBot 
                    ? Colors.grey[200] 
                    : const Color(0xFF007AFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(message.isBot ? 4 : 20),
                  topRight: Radius.circular(message.isBot ? 20 : 4),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: message.isBot 
                      ? CrossAxisAlignment.start 
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.message,
                      style: TextStyle(
                        color: message.isBot ? Colors.black87 : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.messageTime,
                          style: TextStyle(
                            color: message.isBot 
                                ? Colors.black45 
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (!message.isBot) ...[
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!message.isBot) userAvatar,
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return const SizedBox(
      width: 32,
      height: 32,
      
      child: Icon(
        Icons.wb_sunny_rounded,
        size: 32,
        color: Colors.orange,
      ),
    );
  }

  
  }

  // Widget _buildMessageStatus(MessageStatus status) {
  //   IconData icon;
  //   Color color;

  //   switch (status) {
  //     case MessageStatus.sending:
  //       icon = Icons.access_time;
  //       color = Colors.white70;
  //       break;
  //     case MessageStatus.sent:
  //       icon = Icons.check;
  //       color = Colors.white70;
  //       break;
  //     case MessageStatus.delivered:
  //       icon = Icons.done_all;
  //       color = Colors.white70;
  //       break;
  //     case MessageStatus.read:
  //       icon = Icons.done_all;
  //       color = Colors.blue[300]!;
  //       break;
  //     case MessageStatus.failed:
  //       icon = Icons.error_outline;
  //       color = Colors.red[300]!;
  //       break;
  //   }

  //   return Icon(
  //     icon,
  //     size: 14,
  //     color: color,
  //   );
  // }
