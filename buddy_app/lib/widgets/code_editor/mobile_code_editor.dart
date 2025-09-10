// lib/widgets/code_editor/mobile_code_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/file_model.dart';

class MobileCodeEditor extends StatefulWidget {
  final FileModel file;
  final Function(FileModel, String) onContentChanged;
  final Function(FileModel) onSave;
  final Function(FileModel) onRun;

  const MobileCodeEditor({
    super.key,
    required this.file,
    required this.onContentChanged,
    required this.onSave,
    required this.onRun,
  });

  @override
  State<MobileCodeEditor> createState() => _MobileCodeEditorState();
}

class _MobileCodeEditorState extends State<MobileCodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showLineNumbers = true;
  bool _wordWrap = true;
  double _fontSize = 14.0;
  int _currentLine = 1;
  int _currentColumn = 1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.file.content);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _updateCursorPosition();
  }

  @override
  void didUpdateWidget(MobileCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller.text = widget.file.content;
      _updateCursorPosition();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onContentChanged(widget.file, _controller.text);
    _updateCursorPosition();
  }

  void _updateCursorPosition() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid) {
      final lines = text.substring(0, selection.start).split('\n');
      setState(() {
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showLineNumbers) _buildLineNumbers(),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: _fontSize,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintText: 'Start coding...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    onChanged: (_) => _onTextChanged(),
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildStatusBar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            onPressed: () => widget.onSave(widget.file),
            tooltip: 'Save (Ctrl+S)',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20, color: Colors.green),
            onPressed: widget.file.isExecutable
                ? () => widget.onRun(widget.file)
                : null,
            tooltip: 'Run',
          ),
          const VerticalDivider(width: 1),
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            onPressed: _controller.text.isNotEmpty ? _undo : null,
            tooltip: 'Undo (Ctrl+Z)',
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            onPressed: _controller.text.isNotEmpty ? _redo : null,
            tooltip: 'Redo (Ctrl+Y)',
          ),
          const VerticalDivider(width: 1),
          IconButton(
            icon: const Icon(Icons.find_in_page, size: 20),
            onPressed: _showFindDialog,
            tooltip: 'Find (Ctrl+F)',
          ),
          IconButton(
            icon: const Icon(Icons.find_replace, size: 20),
            onPressed: _showReplaceDialog,
            tooltip: 'Replace (Ctrl+H)',
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'line_numbers',
                child: Row(
                  children: [
                    Icon(
                      _showLineNumbers
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Line Numbers'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'word_wrap',
                child: Row(
                  children: [
                    Icon(
                      _wordWrap
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Word Wrap'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'increase_font',
                child: Row(
                  children: [
                    Icon(Icons.zoom_in, size: 18),
                    SizedBox(width: 8),
                    Text('Increase Font Size'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'decrease_font',
                child: Row(
                  children: [
                    Icon(Icons.zoom_out, size: 18),
                    SizedBox(width: 8),
                    Text('Decrease Font Size'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'goto_line',
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered, size: 18),
                    SizedBox(width: 8),
                    Text('Go to Line'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'select_all',
                child: Row(
                  children: [
                    Icon(Icons.select_all, size: 18),
                    SizedBox(width: 8),
                    Text('Select All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineNumbers() {
    final lines = _controller.text.split('\n');
    final lineCount = lines.length;

    return Container(
      width: 50,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(lineCount, (index) {
            final lineNumber = index + 1;
            final isCurrentLine = lineNumber == _currentLine;

            return Container(
              height: _fontSize * 1.4,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              color: isCurrentLine
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
              child: Text(
                lineNumber.toString(),
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: _fontSize * 0.9,
                  color: isCurrentLine
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: isCurrentLine
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            '${widget.file.fileType} • ${widget.file.fileName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            'Ln $_currentLine, Col $_currentColumn',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 16),
          Text(
            '${_controller.text.length} chars',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.file.isModified) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'line_numbers':
        setState(() => _showLineNumbers = !_showLineNumbers);
        break;
      case 'word_wrap':
        setState(() => _wordWrap = !_wordWrap);
        break;
      case 'increase_font':
        setState(() => _fontSize = (_fontSize + 1).clamp(10.0, 24.0));
        break;
      case 'decrease_font':
        setState(() => _fontSize = (_fontSize - 1).clamp(10.0, 24.0));
        break;
      case 'goto_line':
        _showGoToLineDialog();
        break;
      case 'select_all':
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        break;
    }
  }

  void _undo() {
    // Simple undo implementation
    // In a real editor, you'd implement a proper undo/redo stack
  }

  void _redo() {
    // Simple redo implementation
  }

  void _showFindDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Find'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Search text...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _findText(controller.text);
              },
              child: const Text('Find'),
            ),
          ],
        );
      },
    );
  }

  void _showReplaceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final findController = TextEditingController();
        final replaceController = TextEditingController();

        return AlertDialog(
          title: const Text('Find & Replace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findController,
                decoration: const InputDecoration(
                  hintText: 'Find...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: replaceController,
                decoration: const InputDecoration(
                  hintText: 'Replace with...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _replaceText(findController.text, replaceController.text);
              },
              child: const Text('Replace All'),
            ),
          ],
        );
      },
    );
  }

  void _showGoToLineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Go to Line'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Line number...',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final lineNumber = int.tryParse(controller.text);
                if (lineNumber != null) {
                  _goToLine(lineNumber);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _findText(String searchText) {
    if (searchText.isEmpty) return;

    final text = _controller.text;
    final index = text.indexOf(searchText);

    if (index != -1) {
      _controller.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + searchText.length,
      );
      _focusNode.requestFocus();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Text not found')));
    }
  }

  void _replaceText(String findText, String replaceText) {
    if (findText.isEmpty) return;

    final newText = _controller.text.replaceAll(findText, replaceText);
    _controller.text = newText;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Text replaced')));
  }

  void _goToLine(int lineNumber) {
    final lines = _controller.text.split('\n');
    if (lineNumber > 0 && lineNumber <= lines.length) {
      final offset = lines
          .take(lineNumber - 1)
          .fold<int>(0, (prev, line) => prev + line.length + 1);

      _controller.selection = TextSelection.collapsed(offset: offset);
      _focusNode.requestFocus();
    }
  }
}
