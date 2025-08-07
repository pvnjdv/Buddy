import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../widgets/flow/color_picker.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late List<ChecklistItem> _checklist;
  late List<String> _labels;
  late String _selectedColor;
  late bool _isPinned;
  late NoteType _noteType;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.note != null) {
      _titleController = TextEditingController(text: widget.note!.title);
      _contentController = TextEditingController(text: widget.note!.content);
      _checklist = List.from(widget.note!.checklist);
      _labels = List.from(widget.note!.labels);
      _selectedColor = widget.note!.color;
      _isPinned = widget.note!.isPinned;
      _noteType = widget.note!.type;
    } else {
      _titleController = TextEditingController();
      _contentController = TextEditingController();
      _checklist = [];
      _labels = [];
      _selectedColor = NoteColors.white;
      _isPinned = false;
      _noteType = NoteType.text;
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _checklist.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      final note = Note(
        id: widget.note?.id ?? '',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        labels: _labels,
        color: _selectedColor,
        isPinned: _isPinned,
        isArchived: false,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        type: _noteType,
        checklist: _checklist,
      );

      final savedNote = widget.note != null
          ? await FlowService.updateNote(note)
          : await FlowService.createNote(note);

      if (mounted) {
        Navigator.pop(context, savedNote);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ColorPicker(
        selectedColor: _selectedColor,
        onColorSelected: (color) {
          setState(() {
            _selectedColor = color;
            _hasChanges = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _toggleNoteType() {
    setState(() {
      _noteType = _noteType == NoteType.text
          ? NoteType.checklist
          : NoteType.text;
      _hasChanges = true;
    });
  }

  void _addChecklistItem() {
    setState(() {
      _checklist.add(
        ChecklistItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '',
        ),
      );
      _hasChanges = true;
    });
  }

  void _updateChecklistItem(int index, ChecklistItem item) {
    setState(() {
      _checklist[index] = item;
      _hasChanges = true;
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklist.removeAt(index);
      _hasChanges = true;
    });
  }

  void _showLabelDialog() {
    showDialog(
      context: context,
      builder: (context) => _LabelDialog(
        selectedLabels: _labels,
        onLabelsChanged: (labels) {
          setState(() {
            _labels = labels;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _parseColor(_selectedColor);
    final isDark = _isDarkColor(backgroundColor);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () async {
            await _saveNote();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
                _hasChanges = true;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _noteType == NoteType.text ? Icons.checklist : Icons.text_fields,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: _toggleNoteType,
          ),
          IconButton(
            icon: Icon(
              Icons.palette,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: _showColorPicker,
          ),
          IconButton(
            icon: Icon(
              Icons.label_outline,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: _showLabelDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              // Labels
              if (_labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _labels
                      .map(
                        (label) => Chip(
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: isDark
                              ? Colors.white24
                              : Colors.black12,
                          onDeleted: () {
                            setState(() {
                              _labels.remove(label);
                              _hasChanges = true;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _noteType == NoteType.text
                    ? _buildTextContent(isDark)
                    : _buildChecklistContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(bool isDark) {
    return TextField(
      controller: _contentController,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black87,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: 'Write your note...',
        hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildChecklistContent(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _checklist.length,
            itemBuilder: (context, index) {
              final item = _checklist[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: item.isCompleted,
                      onChanged: (value) {
                        _updateChecklistItem(
                          index,
                          item.copyWith(isCompleted: value ?? false),
                        );
                      },
                      activeColor: isDark ? Colors.white : Colors.blue,
                      checkColor: isDark ? Colors.black : Colors.white,
                    ),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: item.text),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        decoration: InputDecoration(
                          hintText: 'List item',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (text) {
                          _updateChecklistItem(
                            index,
                            item.copyWith(text: text),
                          );
                        },
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white60 : Colors.black54,
                        size: 20,
                      ),
                      onPressed: () => _removeChecklistItem(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.add,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: _addChecklistItem,
            ),
            Text(
              'Add item',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(
        int.parse(colorString.substring(1, 7), radix: 16) + 0xFF000000,
      );
    } catch (e) {
      return Colors.white;
    }
  }

  bool _isDarkColor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark;
  }
}

class _LabelDialog extends StatefulWidget {
  final List<String> selectedLabels;
  final Function(List<String>) onLabelsChanged;

  const _LabelDialog({
    required this.selectedLabels,
    required this.onLabelsChanged,
  });

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _selectedLabels;
  List<String> _availableLabels = [
    'Personal',
    'Work',
    'Ideas',
    'Shopping',
    'Travel',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLabels = List.from(widget.selectedLabels);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Labels'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Create new label',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final newLabel = _controller.text.trim();
                    if (newLabel.isNotEmpty &&
                        !_availableLabels.contains(newLabel)) {
                      setState(() {
                        _availableLabels.add(newLabel);
                        _selectedLabels.add(newLabel);
                        _controller.clear();
                      });
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                final newLabel = value.trim();
                if (newLabel.isNotEmpty &&
                    !_availableLabels.contains(newLabel)) {
                  setState(() {
                    _availableLabels.add(newLabel);
                    _selectedLabels.add(newLabel);
                    _controller.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _availableLabels.length,
                itemBuilder: (context, index) {
                  final label = _availableLabels[index];
                  final isSelected = _selectedLabels.contains(label);

                  return CheckboxListTile(
                    title: Text(label),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedLabels.add(label);
                        } else {
                          _selectedLabels.remove(label);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onLabelsChanged(_selectedLabels);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
