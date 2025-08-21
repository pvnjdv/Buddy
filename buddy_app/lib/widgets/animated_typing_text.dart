import 'package:flutter/material.dart';
import 'dart:async';

class AnimatedTypingText extends StatefulWidget {
  final String text;
  final Duration? typingSpeed;
  final TextStyle? textStyle;
  final VoidCallback? onComplete;

  const AnimatedTypingText({
    super.key,
    required this.text,
    this.typingSpeed,
    this.textStyle,
    this.onComplete,
  });

  @override
  State<AnimatedTypingText> createState() => _AnimatedTypingTextState();
}

class _AnimatedTypingTextState extends State<AnimatedTypingText> {
  String _displayedText = '';
  Timer? _typingTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    if (widget.text.isEmpty) {
      widget.onComplete?.call();
      return;
    }

    // Split text into words for natural typing, handling multiple spaces
    final words = widget.text.trim().split(RegExp(r'\s+'));
    _currentIndex = 0;
    _displayedText = '';

    _typeNextWord();
  }

  void _typeNextWord() {
    final words = widget.text.trim().split(RegExp(r'\s+'));

    if (_currentIndex >= words.length) {
      widget.onComplete?.call();
      return;
    }

    final word = words[_currentIndex];

    setState(() {
      if (_currentIndex == 0) {
        _displayedText = word;
      } else {
        _displayedText += ' $word';
      }
      _currentIndex++;
    });

    // Variable typing speed: slower after punctuation for natural feel
    Duration nextDelay = widget.typingSpeed ?? const Duration(milliseconds: 80);
    if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
      nextDelay = Duration(
        milliseconds: (nextDelay.inMilliseconds * 1.5).round(),
      );
    } else if (word.endsWith(',') || word.endsWith(';') || word.endsWith(':')) {
      nextDelay = Duration(
        milliseconds: (nextDelay.inMilliseconds * 1.2).round(),
      );
    }

    _typingTimer = Timer(nextDelay, _typeNextWord);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.textStyle);
  }
}
