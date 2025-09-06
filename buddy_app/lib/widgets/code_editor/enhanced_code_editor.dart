// lib/widgets/code_editor/enhanced_code_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class EnhancedCodeEditor extends StatefulWidget {
  final String content;
  final String language;
  final Function(String) onChanged;
  final bool readOnly;
  final int? maxLines;
  final TextEditingController? controller;
  final bool showLineNumbers;
  final bool enableSyntaxHighlighting;
  final Map<String, TextStyle> syntaxTheme;

  const EnhancedCodeEditor({
    super.key,
    required this.content,
    required this.language,
    required this.onChanged,
    this.readOnly = false,
    this.maxLines,
    this.controller,
    this.showLineNumbers = true,
    this.enableSyntaxHighlighting = true,
    this.syntaxTheme = const {},
  });

  @override
  State<EnhancedCodeEditor> createState() => _EnhancedCodeEditorState();
}

class _EnhancedCodeEditorState extends State<EnhancedCodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  late ScrollController _lineNumberScrollController;

  List<TextEditingValue> _history = [];
  int _historyIndex = -1;
  bool _isComposingUndo = false;

  List<int> _selectedLines = [];

  Timer? _autocompleteTimer;
  OverlayEntry? _autocompleteOverlay;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.content);
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _lineNumberScrollController = ScrollController();

    // Sync scroll controllers
    _scrollController.addListener(_syncScrollControllers);
    _lineNumberScrollController.addListener(_syncScrollControllers);

    _controller.addListener(_onTextChanged);
    _addToHistory(_controller.value);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    _autocompleteTimer?.cancel();
    _autocompleteOverlay?.remove();
    super.dispose();
  }

  void _syncScrollControllers() {
    if (_scrollController.hasClients &&
        _lineNumberScrollController.hasClients) {
      if (_scrollController.offset != _lineNumberScrollController.offset) {
        _lineNumberScrollController.jumpTo(_scrollController.offset);
      }
    }
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
    _scheduleAutocomplete();

    if (!_isComposingUndo) {
      _addToHistory(_controller.value);
    }
  }

  void _addToHistory(TextEditingValue value) {
    // Remove future history if we're in the middle
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    _history.add(value);
    if (_history.length > 100) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _isComposingUndo = true;
      _historyIndex--;
      final value = _history[_historyIndex];
      _controller.value = value;
      _isComposingUndo = false;
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _isComposingUndo = true;
      _historyIndex++;
      final value = _history[_historyIndex];
      _controller.value = value;
      _isComposingUndo = false;
    }
  }

  void _scheduleAutocomplete() {
    _autocompleteTimer?.cancel();
    _autocompleteTimer = Timer(
      const Duration(milliseconds: 300),
      _showAutocomplete,
    );
  }

  void _showAutocomplete() {
    // Get current cursor position and word
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final cursorPos = selection.baseOffset;

    // Find current word
    int start = cursorPos;
    while (start > 0 && text[start - 1].contains(RegExp(r'[a-zA-Z0-9_]'))) {
      start--;
    }

    if (cursorPos == start) return; // No word to complete

    final currentWord = text.substring(start, cursorPos);
    final suggestions = _getAutocompleteSuggestions(currentWord);

    if (suggestions.isNotEmpty) {
      _showAutocompleteOverlay(suggestions, start, cursorPos);
    }
  }

  List<String> _getAutocompleteSuggestions(String prefix) {
    // Language-specific autocomplete suggestions
    switch (widget.language.toLowerCase()) {
      case 'dart':
        return _getDartSuggestions(prefix);
      case 'javascript':
      case 'js':
        return _getJavaScriptSuggestions(prefix);
      case 'python':
        return _getPythonSuggestions(prefix);
      default:
        return _getCommonSuggestions(prefix);
    }
  }

  List<String> _getDartSuggestions(String prefix) {
    final suggestions = [
      'class',
      'void',
      'String',
      'int',
      'double',
      'bool',
      'List',
      'Map',
      'setState',
      'Widget',
      'StatefulWidget',
      'StatelessWidget',
      'BuildContext',
      'Future',
      'async',
      'await',
      'import',
      'library',
      'part',
      'export',
      'final',
      'const',
      'var',
      'dynamic',
      'extends',
      'implements',
      'mixin',
      'abstract',
      'static',
      'override',
      'required',
      'factory',
      'constructor',
    ];
    return suggestions
        .where((s) => s.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList();
  }

  List<String> _getJavaScriptSuggestions(String prefix) {
    final suggestions = [
      'function',
      'const',
      'let',
      'var',
      'class',
      'extends',
      'import',
      'export',
      'async',
      'await',
      'Promise',
      'Array',
      'Object',
      'String',
      'Number',
      'console.log',
      'document',
      'window',
      'addEventListener',
      'querySelector',
    ];
    return suggestions
        .where((s) => s.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList();
  }

  List<String> _getPythonSuggestions(String prefix) {
    final suggestions = [
      'def',
      'class',
      'import',
      'from',
      'if',
      'else',
      'elif',
      'for',
      'while',
      'try',
      'except',
      'finally',
      'with',
      'as',
      'lambda',
      'yield',
      'return',
      'print',
      'len',
      'range',
      'str',
      'int',
      'float',
      'list',
      'dict',
      'set',
    ];
    return suggestions
        .where((s) => s.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList();
  }

  List<String> _getCommonSuggestions(String prefix) {
    final suggestions = ['if', 'else', 'for', 'while', 'function', 'return'];
    return suggestions
        .where((s) => s.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList();
  }

  void _showAutocompleteOverlay(List<String> suggestions, int start, int end) {
    _autocompleteOverlay?.remove();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context);
    final position = renderBox.localToGlobal(Offset.zero);

    _autocompleteOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + 50, // Approximate cursor position
        top: position.dy + 100,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(suggestions[index]),
                  onTap: () =>
                      _insertSuggestion(suggestions[index], start, end),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(_autocompleteOverlay!);

    // Auto-remove after 5 seconds
    Timer(const Duration(seconds: 5), () {
      _autocompleteOverlay?.remove();
      _autocompleteOverlay = null;
    });
  }

  void _insertSuggestion(String suggestion, int start, int end) {
    final text = _controller.text;
    final newText = text.substring(0, start) + suggestion + text.substring(end);

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + suggestion.length),
    );

    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
  }

  Widget _buildLineNumbers() {
    if (!widget.showLineNumbers) return const SizedBox.shrink();

    final lines = _controller.text.split('\n');
    final lineCount = lines.length;

    return Container(
      width: 50,
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: ListView.builder(
        controller: _lineNumberScrollController,
        itemCount: lineCount,
        itemBuilder: (context, index) {
          final isSelected = _selectedLines.contains(index + 1);
          return Container(
            height: 20,
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : null,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontFamily: 'monospace',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Handle keyboard shortcuts
          if (event.logicalKey == LogicalKeyboardKey.keyZ &&
              HardwareKeyboard.instance.isControlPressed) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _redo();
            } else {
              _undo();
            }
            return KeyEventResult.handled;
          }

          // Ctrl+S for save
          if (event.logicalKey == LogicalKeyboardKey.keyS &&
              HardwareKeyboard.instance.isControlPressed) {
            // Trigger save callback
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildLineNumbers(),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: _scrollController,
                maxLines: widget.maxLines,
                readOnly: widget.readOnly,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
