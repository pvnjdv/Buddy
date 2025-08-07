import 'package:flutter/material.dart';
import '../../models/flow_models.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isListView;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(note.color);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isDarkColor(color) ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: _isDarkColor(color)
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  Expanded(
                    child: note.title.isNotEmpty
                        ? Text(
                            note.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isDarkColor(color)
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            maxLines: isListView ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox.shrink(),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: _isDarkColor(color)
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Content
              if (note.content.isNotEmpty) ...[
                if (note.title.isNotEmpty) const SizedBox(height: 8),
                _buildContent(),
              ],

              // Checklist
              if (note.type == NoteType.checklist &&
                  note.checklist.isNotEmpty) ...[
                if (note.title.isNotEmpty || note.content.isNotEmpty)
                  const SizedBox(height: 8),
                _buildChecklist(),
              ],

              // Labels
              if (note.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildLabels(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final color = _parseColor(note.color);
    final maxLines = isListView ? 2 : 8;

    return Text(
      note.content,
      style: TextStyle(
        fontSize: 13,
        color: _isDarkColor(color)
            ? Colors.white.withOpacity(0.87)
            : Colors.black.withOpacity(0.87),
        height: 1.3,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildChecklist() {
    final color = _parseColor(note.color);
    final itemsToShow = isListView ? 3 : 5;
    final visibleItems = note.checklist.take(itemsToShow).toList();
    final hasMore = note.checklist.length > itemsToShow;

    return Column(
      children: [
        ...visibleItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(
                  item.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 16,
                  color: _isDarkColor(color) ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkColor(color)
                          ? Colors.white.withOpacity(0.87)
                          : Colors.black.withOpacity(0.87),
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
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${note.checklist.length - itemsToShow} more items',
              style: TextStyle(
                fontSize: 11,
                color: _isDarkColor(color) ? Colors.white60 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabels() {
    final color = _parseColor(note.color);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: note.labels
          .take(3)
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _isDarkColor(color) ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: _isDarkColor(color) ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
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
