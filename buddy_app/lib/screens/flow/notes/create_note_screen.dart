import 'package:flutter/material.dart';
import '../../../models/flow_models.dart';
import '../../../services/flow_service.dart';

class CreateNoteScreen extends StatefulWidget {
  final Note? note; // For editing existing notes
  final String? flowId; // For linking to a specific flow

  const CreateNoteScreen({super.key, this.note, this.flowId});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _labelController = TextEditingController();

  List<String> _labels = [];
  String _selectedColor = '#FFFFFF';
  NoteType _noteType = NoteType.text;
  List<ChecklistItem> _checklistItems = [];
  bool _isPinned = false;
  bool _isLoading = false;

  // Google Keep inspired colors
  final List<Map<String, dynamic>> _colors = [
    {'name': 'Default', 'color': '#FFFFFF'},
    {'name': 'Red', 'color': '#F28B82'},
    {'name': 'Orange', 'color': '#FBBC04'},
    {'name': 'Yellow', 'color': '#FFF475'},
    {'name': 'Green', 'color': '#CCFF90'},
    {'name': 'Teal', 'color': '#A7FFEB'},
    {'name': 'Blue', 'color': '#CBF0F8'},
    {'name': 'Dark Blue', 'color': '#AECBFA'},
    {'name': 'Purple', 'color': '#D7AEFB'},
    {'name': 'Pink', 'color': '#FDCFE8'},
    {'name': 'Brown', 'color': '#E6C9A8'},
    {'name': 'Grey', 'color': '#E8EAED'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _initializeFromNote(widget.note!);
    }
  }

  void _initializeFromNote(Note note) {
    _titleController.text = note.title;
    _contentController.text = note.content;
    _labels = List.from(note.labels);
    _selectedColor = note.color;
    _noteType = note.type;
    _checklistItems = List.from(note.checklist);
    _isPinned = note.isPinned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(
        int.parse(_selectedColor.replaceFirst('#', '0xFF')),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: Colors.black87,
            ),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.black87),
            onPressed: _showColorPicker,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.black54),
                border: InputBorder.none,
              ),
            ),

            const SizedBox(height: 16),

            // Note Type Selector
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Text'),
                  selected: _noteType == NoteType.text,
                  onSelected: (selected) {
                    if (selected) setState(() => _noteType = NoteType.text);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Checklist'),
                  selected: _noteType == NoteType.checklist,
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _noteType = NoteType.checklist);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: _noteType == NoteType.text
                  ? _buildTextContent()
                  : _buildChecklistContent(),
            ),

            // Labels
            _buildLabelsSection(),

            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.note != null ? 'Update Note' : 'Create Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return TextField(
      controller: _contentController,
      maxLines: null,
      expands: true,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: const InputDecoration(
        hintText: 'Note content...',
        hintStyle: TextStyle(color: Colors.black54),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildChecklistContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _checklistItems.length,
            itemBuilder: (context, index) {
              return _buildChecklistItem(index);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.add, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onSubmitted: _addChecklistItem,
                decoration: const InputDecoration(
                  hintText: 'Add list item',
                  hintStyle: TextStyle(color: Colors.black54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistItem(int index) {
    final item = _checklistItems[index];
    return Row(
      children: [
        Checkbox(
          value: item.isCompleted,
          onChanged: (value) {
            setState(() {
              _checklistItems[index] = item.copyWith(
                isCompleted: value ?? false,
              );
            });
          },
        ),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: item.text),
            onChanged: (value) {
              _checklistItems[index] = item.copyWith(text: value);
            },
            style: TextStyle(
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              color: item.isCompleted ? Colors.black54 : Colors.black87,
            ),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () {
            setState(() {
              _checklistItems.removeAt(index);
            });
          },
        ),
      ],
    );
  }

  Widget _buildLabelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_labels.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: _labels.map((label) {
              return Chip(
                label: Text(label),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _labels.remove(label);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Icon(Icons.label_outline, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _labelController,
                onSubmitted: _addLabel,
                decoration: const InputDecoration(
                  hintText: 'Add label',
                  hintStyle: TextStyle(color: Colors.black54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addChecklistItem(String text) {
    if (text.trim().isNotEmpty) {
      setState(() {
        _checklistItems.add(
          ChecklistItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text.trim(),
            isCompleted: false,
          ),
        );
      });
    }
  }

  void _addLabel(String label) {
    if (label.trim().isNotEmpty && !_labels.contains(label.trim())) {
      setState(() {
        _labels.add(label.trim());
        _labelController.clear();
      });
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Color',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final colorData = _colors[index];
                  final color = Color(
                    int.parse(colorData['color'].replaceFirst('#', '0xFF')),
                  );
                  final isSelected = _selectedColor == colorData['color'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorData['color'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.black
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.black)
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Archive note
                },
              ),
              if (widget.note != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteNote();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final note = Note(
        id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        labels: _labels,
        color: _selectedColor,
        isPinned: _isPinned,
        isArchived: false,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        type: _noteType,
        checklist: _checklistItems,
      );

      if (widget.note != null) {
        await FlowService.updateNote(note);
      } else {
        await FlowService.createNote(note);
      }

      if (mounted) {
        Navigator.pop(context, note);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FlowService.deleteNote(widget.note!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _labelController.dispose();
    super.dispose();
  }
}
