import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/editor_file.dart';
import '../models/editor_theme.dart';
import '../services/syntax_highlight_service.dart';

class CodeEditorWidget extends StatefulWidget {
  final EditorFile file;
  final EditorTheme theme;
  final Function(String) onContentChanged;
  final Function() onSave;
  final VoidCallback? onClose;

  const CodeEditorWidget({
    super.key,
    required this.file,
    required this.theme,
    required this.onContentChanged,
    required this.onSave,
    this.onClose,
  });

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late ScrollController _lineNumberController;
  final FocusNode _focusNode = FocusNode();

  int _currentLine = 1;
  int _currentColumn = 1;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.file.content);
    _scrollController = ScrollController();
    _lineNumberController = ScrollController();

    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncScrolling);
    _updateCursorPosition();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lineNumberController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newContent = _controller.text;
    if (newContent != widget.file.content) {
      setState(() {
        _isModified = true;
      });
      widget.onContentChanged(newContent);
    }
    _updateCursorPosition();
  }

  void _updateCursorPosition() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final lines = textBeforeCursor.split('\n');

      setState(() {
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
      });
    }
  }

  void _syncScrolling() {
    if (_lineNumberController.hasClients) {
      _lineNumberController.jumpTo(_scrollController.offset);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle Ctrl+S for save
      if (event.logicalKey == LogicalKeyboardKey.keyS &&
          HardwareKeyboard.instance.isControlPressed) {
        widget.onSave();
        setState(() {
          _isModified = false;
        });
      }
      // Handle Ctrl+W for close
      else if (event.logicalKey == LogicalKeyboardKey.keyW &&
          HardwareKeyboard.instance.isControlPressed &&
          widget.onClose != null) {
        widget.onClose!();
      }
    }
  }

  Widget _buildLineNumbers() {
    final lineCount = _controller.text.split('\n').length;
    final lineHeight = 20.0;

    return Container(
      width: 60,
      color: widget.theme.gutterColor,
      child: ListView.builder(
        controller: _lineNumberController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lineCount,
        itemBuilder: (context, index) {
          final lineNumber = index + 1;
          final isCurrentLine = lineNumber == _currentLine;

          return Container(
            height: lineHeight,
            padding: const EdgeInsets.only(right: 8),
            alignment: Alignment.centerRight,
            child: Text(
              lineNumber.toString(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: isCurrentLine
                    ? widget.theme.textColor
                    : widget.theme.lineNumberColor,
                fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditor() {
    return Expanded(
      child: Stack(
        children: [
          // Syntax highlighted view
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: HighlightView(
              _controller.text,
              language: widget.file.language,
              theme: SyntaxHighlightService.getHighlightTheme(widget.theme),
              padding: EdgeInsets.zero,
              textStyle: GoogleFonts.jetBrainsMono(fontSize: 14, height: 1.4),
            ),
          ),
          // Transparent text field for editing
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: false,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.transparent,
                ),
                cursorColor: widget.theme.cursorColor,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => _onTextChanged(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        border: Border(
          top: BorderSide(color: widget.theme.gutterColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Ln $_currentLine, Col $_currentColumn',
            style: TextStyle(fontSize: 11, color: widget.theme.lineNumberColor),
          ),
          const Spacer(),
          Text(
            widget.file.language.toUpperCase(),
            style: TextStyle(fontSize: 11, color: widget.theme.lineNumberColor),
          ),
          const SizedBox(width: 16),
          if (_isModified)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.theme.accentColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.theme.backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildLineNumbers(),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: widget.theme.gutterColor,
                ),
                _buildEditor(),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }
}
