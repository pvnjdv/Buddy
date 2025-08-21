import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../animated_typing_text.dart';

class BuddyMessageBubble extends StatelessWidget {
  final BuddyMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onTypingComplete;

  const BuddyMessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onTypingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == BuddyRole.user;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 64 : 16,
          right: isUser ? 16 : 64,
        ),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF25D366),
                child: const Icon(
                  Icons.smart_toy,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF007AFF) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message content with typing animation for assistant
                    if (!isUser && message.isTyping)
                      AnimatedTypingText(
                        text: message.content,
                        typingSpeed: const Duration(
                          milliseconds: 80,
                        ), // Faster typing
                        textStyle: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2D3748),
                          height: 1.4,
                        ),
                        onComplete: onTypingComplete,
                      )
                    else
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: isUser
                              ? Colors.white
                              : const Color(0xFF2D3748),
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isUser ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 16, color: Colors.white70),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF007AFF),
                child: const Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
