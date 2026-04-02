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
  final Function(String)? onFind;
  final Function(String, String)? onReplace;

  const CodeEditorWidget({
    super.key,
    required this.file,
    required this.theme,
    required this.onContentChanged,
    required this.onSave,
    this.onClose,
    this.onFind,
    this.onReplace,
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
  bool _showFindReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  List<TextRange> _findResults = [];
  int _currentFindIndex = -1;

  // Multi-cursor support
  List<TextSelection> _selections = [];
  bool _isMultiCursorMode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.file.content);
    _scrollController = ScrollController();
    _lineNumberController = ScrollController();

    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncScrolling);
    _updateCursorPosition();

    // Add keyboard shortcuts
    _setupKeyboardShortcuts();
  }

  void _setupKeyboardShortcuts() {
    // Save (Ctrl+S)
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.keyS &&
          HardwareKeyboard.instance.isControlPressed) {
        widget.onSave();
        return true;
      }
      return false;
    });

    // Find (Ctrl+F)
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.keyF &&
          HardwareKeyboard.instance.isControlPressed) {
        setState(() => _showFindReplace = !_showFindReplace);
        return true;
      }
      return false;
    });

    // Undo (Ctrl+Z)
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ &&
          HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isShiftPressed) {
        // Implement undo
        return true;
      }
      return false;
    });

    // Redo (Ctrl+Y or Ctrl+Shift+Z)
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if ((event.logicalKey == LogicalKeyboardKey.keyY ||
              (event.logicalKey == LogicalKeyboardKey.keyZ &&
                  HardwareKeyboard.instance.isShiftPressed)) &&
          HardwareKeyboard.instance.isControlPressed) {
        // Implement redo
        return true;
      }
      return false;
    });

    // Multi-cursor (Ctrl+Alt+Click or Ctrl+D)
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.keyD &&
          HardwareKeyboard.instance.isControlPressed) {
        _addCursorAtNextOccurrence();
        return true;
      }
      return false;
    });
  }

  void _addCursorAtNextOccurrence() {
    if (_controller.selection.isCollapsed) {
      final text = _controller.text;
      final start = _controller.selection.start;
      final word = _getWordAtPosition(text, start);

      if (word.isNotEmpty) {
        final nextIndex = text.indexOf(word, start + 1);
        if (nextIndex != -1) {
          final newSelection = TextSelection(
            baseOffset: nextIndex,
            extentOffset: nextIndex + word.length,
          );
          _selections.add(newSelection);
          setState(() => _isMultiCursorMode = true);
        }
      }
    }
  }

  String _getWordAtPosition(String text, int position) {
    if (position < 0 || position >= text.length) return '';

    int start = position;
    int end = position;

    // Find word boundaries
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    while (end < text.length && _isWordChar(text[end])) {
      end++;
    }

    return text.substring(start, end);
  }

  bool _isWordChar(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  void _handleTabKey() {
    const tabSize = 2;
    const tabString = '  ';

    final selection = _controller.selection;
    final text = _controller.text;

    if (selection.isCollapsed) {
      // Insert tab at cursor
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        tabString,
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tabSize),
      );
    } else {
      // Indent selected lines
      _indentSelection();
    }
  }

  void _handleEnterKey() {
    final selection = _controller.selection;
    final text = _controller.text;

    // Get current line
    final lines = text.split('\n');
    final currentLineIndex =
        text.substring(0, selection.start).split('\n').length - 1;
    final currentLine = lines[currentLineIndex];

    // Calculate indentation
    final indentMatch = RegExp(r'^(\s*)').firstMatch(currentLine);
    final indentation = indentMatch?.group(1) ?? '';

    // Check if current line ends with opening brace
    final shouldIncreaseIndent =
        currentLine.trim().endsWith('{') ||
        currentLine.trim().endsWith('[') ||
        currentLine.trim().endsWith('(');

    final newIndent = shouldIncreaseIndent ? indentation + '  ' : indentation;

    // Insert new line with proper indentation
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '\n$newIndent',
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + 1 + newIndent.length,
      ),
    );
  }

  void _indentSelection() {
    final selection = _controller.selection;
    final text = _controller.text;

    final startLine = text.substring(0, selection.start).split('\n').length - 1;
    final endLine = text.substring(0, selection.end).split('\n').length - 1;

    final lines = text.split('\n');
    for (int i = startLine; i <= endLine; i++) {
      lines[i] = '  ' + lines[i];
    }

    final newText = lines.join('\n');
    final newStart = selection.start + 2;
    final newEnd = selection.end + 2 + ((endLine - startLine + 1) * 2);

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: newStart, extentOffset: newEnd),
    );
  }

  void _findText(String query) {
    if (query.isEmpty) {
      setState(() {
        _findResults.clear();
        _currentFindIndex = -1;
      });
      return;
    }

    final text = _controller.text;
    final results = <TextRange>[];
    int startIndex = 0;

    while (true) {
      final index = text.indexOf(query, startIndex);
      if (index == -1) break;

      results.add(TextRange(start: index, end: index + query.length));
      startIndex = index + 1;
    }

    setState(() {
      _findResults = results;
      _currentFindIndex = results.isNotEmpty ? 0 : -1;
      if (_currentFindIndex >= 0) {
        _controller.selection = TextSelection(
          baseOffset: results[0].start,
          extentOffset: results[0].end,
        );
      }
    });
  }

  void _replaceText() {
    if (_findResults.isEmpty || _currentFindIndex < 0) return;

    final result = _findResults[_currentFindIndex];
    final newText = _controller.text.replaceRange(
      result.start,
      result.end,
      _replaceController.text,
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: result.start + _replaceController.text.length,
      ),
    );

    // Update find results
    _findText(_findController.text);
  }

  void _replaceAll() {
    if (_findResults.isEmpty) return;

    String newText = _controller.text;
    int offset = 0;

    for (final result in _findResults.reversed) {
      newText = newText.replaceRange(
        result.start + offset,
        result.end + offset,
        _replaceController.text,
      );
      offset += _replaceController.text.length - (result.end - result.start);
    }

    _controller.value = TextEditingValue(text: newText);
    _findText(_findController.text);
  }

  void _nextFindResult() {
    if (_findResults.isEmpty) return;

    setState(() {
      _currentFindIndex = (_currentFindIndex + 1) % _findResults.length;
      final result = _findResults[_currentFindIndex];
      _controller.selection = TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      );
    });
  }

  void _previousFindResult() {
    if (_findResults.isEmpty) return;

    setState(() {
      _currentFindIndex = _currentFindIndex <= 0
          ? _findResults.length - 1
          : _currentFindIndex - 1;
      final result = _findResults[_currentFindIndex];
      _controller.selection = TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      );
    });
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

  Widget _buildFindReplaceBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: widget.theme.gutterColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _findController,
              decoration: InputDecoration(
                hintText: 'Find',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: widget.theme.lineNumberColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(fontSize: 12, color: widget.theme.textColor),
              onChanged: _findText,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_upward,
              size: 16,
              color: widget.theme.lineNumberColor,
            ),
            onPressed: _previousFindResult,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_downward,
              size: 16,
              color: widget.theme.lineNumberColor,
            ),
            onPressed: _nextFindResult,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          Container(
            width: 1,
            height: 20,
            color: widget.theme.gutterColor,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _replaceController,
              decoration: InputDecoration(
                hintText: 'Replace',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: widget.theme.lineNumberColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(fontSize: 12, color: widget.theme.textColor),
            ),
          ),
          TextButton(
            onPressed: _replaceText,
            child: Text(
              'Replace',
              style: TextStyle(fontSize: 11, color: widget.theme.accentColor),
            ),
          ),
          TextButton(
            onPressed: _replaceAll,
            child: Text(
              'Replace All',
              style: TextStyle(fontSize: 11, color: widget.theme.accentColor),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: widget.theme.lineNumberColor,
            ),
            onPressed: () => setState(() => _showFindReplace = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 8),
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
          if (_showFindReplace) _buildFindReplaceBar(),
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
