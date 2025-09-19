import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/flow_models.dart';
import '../animated_typing_text.dart';

class EnhancedMessageBubble extends StatefulWidget {
  final BuddyMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onTypingComplete;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onTypingComplete,
  });

  @override
  State<EnhancedMessageBubble> createState() => _EnhancedMessageBubbleState();
}

class _EnhancedMessageBubbleState extends State<EnhancedMessageBubble> {
  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == BuddyRole.user;

    return GestureDetector(
      onLongPress: widget.onLongPress,
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
              // Buddy Logo Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00ACC1),
                      Color(0xFF0277BD),
                    ], // Buddy AI brand colors
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00ACC1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                    // Enhanced message content with markdown support
                    if (!isUser && widget.message.isTyping)
                      AnimatedTypingText(
                        text: widget.message.content,
                        typingSpeed: const Duration(milliseconds: 80),
                        textStyle: TextStyle(
                          fontSize: 15,
                          color: const Color(0xFF2D3748),
                          height: 1.4,
                          fontFamily: GoogleFonts.inter().fontFamily,
                        ),
                        onComplete: widget.onTypingComplete,
                      )
                    else
                      _buildMessageContent(isUser),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(widget.message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isUser ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 16, color: Colors.white70),
                        ],
                        if (!isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                _copyToClipboard(widget.message.content),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.grey[600],
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

  Widget _buildMessageContent(bool isUser) {
    final content = widget.message.content;

    // Check if the message contains code blocks
    if (content.contains('```') && !isUser) {
      return _buildMarkdownContent(content);
    }

    // Check if the message contains tables or other markdown
    if ((content.contains('|') ||
            content.contains('**') ||
            content.contains('*')) &&
        !isUser) {
      return _buildMarkdownContent(content);
    }

    // Regular text message
    return Text(
      content,
      style: TextStyle(
        fontSize: 15,
        color: isUser ? Colors.white : const Color(0xFF2D3748),
        height: 1.4,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
    );
  }

  Widget _buildMarkdownContent(String content) {
    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          color: const Color(0xFF2D3748),
          height: 1.4,
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        code: TextStyle(
          backgroundColor: Colors.grey[100],
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        tableBorder: TableBorder.all(color: Colors.grey[300]!, width: 1),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        tableBody: TextStyle(
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        h1: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        h2: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        h3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        blockquote: TextStyle(
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        listBullet: TextStyle(
          color: const Color(0xFF2D3748),
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
      ),
      builders: {'code': CodeElementBuilder()},
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'code') {
      final text = element.textContent;
      final language =
          element.attributes['class']?.replaceFirst('language-', '') ?? '';

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code header with language and copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.isEmpty ? 'code' : language,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _copyCodeToClipboard(text),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Syntax highlighted code
            Container(
              padding: const EdgeInsets.all(12),
              child: HighlightView(
                text,
                language: language.isEmpty ? 'plaintext' : language,
                theme: githubTheme,
                textStyle: TextStyle(
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return null;
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    // Note: We can't show snackbar here as we don't have context
    // The parent widget should handle this
  }
}
