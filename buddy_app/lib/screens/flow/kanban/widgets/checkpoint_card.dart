import 'package:flutter/material.dart';
import '../../../../models/flow_models.dart';
import '../../../../config/settings/theme_config.dart';

class CheckpointCard extends StatelessWidget {
  final FlowCheckpoint checkpoint;
  final VoidCallback onTap;
  final bool isDragging;

  const CheckpointCard({
    super.key,
    required this.checkpoint,
    required this.onTap,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isDragging
            ? AppTheme.surfaceColor.withOpacity(0.9)
            : AppTheme.surfaceColor,
        elevation: isDragging ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: _getPriorityColor(checkpoint.priority),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type and priority
              Row(
                children: [
                  // Issue type icon
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(checkpoint.type),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTypeIcon(checkpoint.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Priority indicator
                  Icon(
                    _getPriorityIcon(checkpoint.priority),
                    color: _getPriorityColor(checkpoint.priority),
                    size: 16,
                  ),
                  const Spacer(),
                  // Story points
                  if (checkpoint.storyPoints != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${checkpoint.storyPoints}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                checkpoint.title,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (checkpoint.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  checkpoint.description,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 8),

              // Bottom row with assignee and labels
              Row(
                children: [
                  // Assignee avatar
                  if (checkpoint.assignedTo != null)
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        checkpoint.assignedTo!.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Labels
                  if (checkpoint.labels.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: checkpoint.labels.take(2).map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getLabelColor(label),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),

              // Progress bar for time tracking
              if (checkpoint.timeTracking != null &&
                  checkpoint.timeTracking!.originalEstimate != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: checkpoint.timeTracking!.progressPercentage / 100,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    checkpoint.timeTracking!.progressPercentage > 100
                        ? Colors.red
                        : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${checkpoint.timeTracking!.timeSpent.inHours}h / ${checkpoint.timeTracking!.originalEstimate!.inHours}h',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(CheckpointType type) {
    switch (type) {
      case CheckpointType.epic:
        return Colors.purple;
      case CheckpointType.story:
        return Colors.green;
      case CheckpointType.task:
        return Colors.blue;
      case CheckpointType.bug:
        return Colors.red;
      case CheckpointType.subtask:
        return Colors.cyan;
      case CheckpointType.milestone:
        return Colors.orange;
      case CheckpointType.review:
        return Colors.indigo;
      case CheckpointType.testing:
        return Colors.teal;
    }
  }

  String _getTypeIcon(CheckpointType type) {
    switch (type) {
      case CheckpointType.epic:
        return 'E';
      case CheckpointType.story:
        return 'S';
      case CheckpointType.task:
        return 'T';
      case CheckpointType.bug:
        return 'B';
      case CheckpointType.subtask:
        return 'ST';
      case CheckpointType.milestone:
        return 'M';
      case CheckpointType.review:
        return 'R';
      case CheckpointType.testing:
        return 'TS';
    }
  }

  Color _getPriorityColor(CheckpointPriority priority) {
    switch (priority) {
      case CheckpointPriority.highest:
        return Colors.red;
      case CheckpointPriority.high:
        return Colors.orange;
      case CheckpointPriority.medium:
        return Colors.yellow;
      case CheckpointPriority.low:
        return Colors.blue;
      case CheckpointPriority.lowest:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(CheckpointPriority priority) {
    switch (priority) {
      case CheckpointPriority.highest:
        return Icons.keyboard_double_arrow_up;
      case CheckpointPriority.high:
        return Icons.keyboard_arrow_up;
      case CheckpointPriority.medium:
        return Icons.drag_handle;
      case CheckpointPriority.low:
        return Icons.keyboard_arrow_down;
      case CheckpointPriority.lowest:
        return Icons.keyboard_double_arrow_down;
    }
  }

  Color _getLabelColor(String label) {
    // Generate a color based on the label text
    final hash = label.hashCode;
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[hash.abs() % colors.length];
  }
}
