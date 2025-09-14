import 'package:flutter/material.dart';
import '../../../../models/flow_models.dart';
import '../../../../config/settings/theme_config.dart';
import 'checkpoint_card.dart';

class KanbanColumn extends StatelessWidget {
  final String title;
  final CheckpointStatus status;
  final List<FlowCheckpoint> checkpoints;
  final Function(FlowCheckpoint) onCheckpointTap;
  final Function(FlowCheckpoint, CheckpointStatus) onCheckpointDrop;

  const KanbanColumn({
    super.key,
    required this.title,
    required this.status,
    required this.checkpoints,
    required this.onCheckpointTap,
    required this.onCheckpointDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    checkpoints.length.toString(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column Body
          Expanded(
            child: DragTarget<FlowCheckpoint>(
              onWillAccept: (checkpoint) => checkpoint != null,
              onAccept: (checkpoint) {
                if (checkpoint.status != status) {
                  onCheckpointDrop(checkpoint, status);
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : AppTheme.backgroundColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                  ),
                  child: checkpoints.isEmpty
                      ? Container(
                          height: 200,
                          child: Center(
                            child: Text(
                              'No items',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: checkpoints.length,
                          itemBuilder: (context, index) {
                            final checkpoint = checkpoints[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Draggable<FlowCheckpoint>(
                                data: checkpoint,
                                feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 280,
                                    child: CheckpointCard(
                                      checkpoint: checkpoint,
                                      onTap: () {},
                                      isDragging: true,
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.5,
                                  child: CheckpointCard(
                                    checkpoint: checkpoint,
                                    onTap: () => onCheckpointTap(checkpoint),
                                  ),
                                ),
                                child: CheckpointCard(
                                  checkpoint: checkpoint,
                                  onTap: () => onCheckpointTap(checkpoint),
                                ),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(CheckpointStatus status) {
    switch (status) {
      case CheckpointStatus.todo:
        return Colors.grey;
      case CheckpointStatus.inProgress:
        return Colors.blue;
      case CheckpointStatus.codeReview:
        return Colors.orange;
      case CheckpointStatus.testing:
        return Colors.purple;
      case CheckpointStatus.done:
        return Colors.green;
      case CheckpointStatus.blocked:
        return Colors.red;
      case CheckpointStatus.cancelled:
        return Colors.grey;
    }
  }
}
