import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../models/flow_models.dart';
import '../../../services/flow_service.dart';
import '../../../config/settings/theme_config.dart';
import 'create_note_screen.dart';

class EnhancedNotesScreen extends StatefulWidget {
  const EnhancedNotesScreen({super.key});

  @override
  State<EnhancedNotesScreen> createState() => _EnhancedNotesScreenState();
}

class _EnhancedNotesScreenState extends State<EnhancedNotesScreen> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isGridView = true;
  TextEditingController _searchController = TextEditingController();
  List<String> _selectedLabels = [];
  String _sortBy = 'created'; // created, updated, title

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await FlowService.getNotes();
      setState(() {
        _notes = notes;
        _filteredNotes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading notes: $e')));
    }
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((note) {
        final matchesSearch =
            note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query);
        final matchesLabels =
            _selectedLabels.isEmpty ||
            _selectedLabels.every((label) => note.labels.contains(label));
        return matchesSearch && matchesLabels && !note.isArchived;
      }).toList();

      // Sort notes
      switch (_sortBy) {
        case 'updated':
          _filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
        case 'title':
          _filteredNotes.sort((a, b) => a.title.compareTo(b.title));
          break;
        case 'created':
        default:
          _filteredNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      // Put pinned notes at the top
      _filteredNotes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    });
  }

  void _togglePin(Note note) async {
    try {
      await FlowService.updateNote(note.copyWith(isPinned: !note.isPinned));
      _loadNotes();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating note: $e')));
    }
  }

  void _deleteNote(Note note) async {
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
        await FlowService.deleteNote(note.id);
        _loadNotes();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search your notes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter and view options
                Row(
                  children: [
                    // Filter by labels
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', _selectedLabels.isEmpty),
                            ..._getAllLabels().map(
                              (label) => _buildFilterChip(
                                label,
                                _selectedLabels.contains(label),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // View toggle and sort
                    IconButton(
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                      ),
                      onPressed: () =>
                          setState(() => _isGridView = !_isGridView),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      onSelected: (value) => setState(() {
                        _sortBy = value;
                        _filterNotes();
                      }),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'created',
                          child: Text('Sort by Created'),
                        ),
                        const PopupMenuItem(
                          value: 'updated',
                          child: Text('Sort by Updated'),
                        ),
                        const PopupMenuItem(
                          value: 'title',
                          child: Text('Sort by Title'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Notes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadNotes,
                    child: _isGridView ? _buildGridView() : _buildListView(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.edit_note, color: Colors.white),
        label: const Text('New Note', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (isSelected) {
          setState(() {
            if (label == 'All') {
              _selectedLabels.clear();
            } else {
              if (isSelected) {
                _selectedLabels.add(label);
              } else {
                _selectedLabels.remove(label);
              }
            }
            _filterNotes();
          });
        },
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) => _buildNoteCard(_filteredNotes[index]),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildNoteCard(_filteredNotes[index], isListView: true),
      ),
    );
  }

  Widget _buildNoteCard(Note note, {bool isListView = false}) {
    final color = Color(int.parse(note.color.replaceFirst('#', '0xFF')));

    return Card(
      color: color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editNote(note),
        onLongPress: () => _showNoteOptions(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and pin icon
              if (note.title.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: isListView ? 1 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.isPinned)
                      const Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Colors.black54,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Content
              if (note.content.isNotEmpty) ...[
                if (note.type == NoteType.checklist)
                  ...note.checklist
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                item.isCompleted
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    decoration: item.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                else
                  Text(
                    note.content,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    maxLines: isListView ? 2 : 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (note.type == NoteType.checklist &&
                    note.checklist.length > 3)
                  Text(
                    '+ ${note.checklist.length - 3} more items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              // Labels
              if (note.labels.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: note.labels
                      .take(3)
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              // Timestamp
              Text(
                _formatDate(note.updatedAt),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture thoughts, ideas, and reminders',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNote,
            icon: const Icon(Icons.add),
            label: const Text('Create Note'),
          ),
        ],
      ),
    );
  }

  void _showNoteOptions(Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                _togglePin(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicateNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                _archiveNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createNote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
    ).then((_) => _loadNotes());
  }

  void _editNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateNoteScreen(note: note)),
    ).then((_) => _loadNotes());
  }

  void _duplicateNote(Note note) async {
    try {
      final duplicatedNote = note.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${note.title} (Copy)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await FlowService.createNote(duplicatedNote);
      _loadNotes();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error duplicating note: $e')));
    }
  }

  void _archiveNote(Note note) async {
    try {
      await FlowService.updateNote(note.copyWith(isArchived: true));
      _loadNotes();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note archived')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error archiving note: $e')));
    }
  }

  List<String> _getAllLabels() {
    final labels = <String>{};
    for (final note in _notes) {
      labels.addAll(note.labels);
    }
    return labels.toList()..sort();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
