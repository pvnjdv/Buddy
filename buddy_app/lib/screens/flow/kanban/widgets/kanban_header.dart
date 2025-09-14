import 'package:flutter/material.dart';
import '../../../../models/flow_models.dart';
import '../../../../config/settings/theme_config.dart';

class KanbanHeader extends StatelessWidget {
  final ProjectFlow flow;
  final int totalCheckpoints;
  final int filteredCheckpoints;

  const KanbanHeader({
    super.key,
    required this.flow,
    required this.totalCheckpoints,
    required this.filteredCheckpoints,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _calculateMetrics();

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          // Project info and progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flow.title,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flow.description,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Progress circle
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: flow.progressPercentage / 100,
                      strokeWidth: 6,
                      backgroundColor: AppTheme.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${flow.progressPercentage.toInt()}%',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metrics row
          Row(
            children: [
              _buildMetricCard(
                'Total',
                totalCheckpoints.toString(),
                Icons.assignment,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Filtered',
                filteredCheckpoints.toString(),
                Icons.filter_alt,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Done',
                metrics['done'].toString(),
                Icons.check_circle,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'In Progress',
                metrics['inProgress'].toString(),
                Icons.play_circle,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Blocked',
                metrics['blocked'].toString(),
                Icons.block,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status breakdown
          _buildStatusBreakdown(metrics),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown(Map<String, int> metrics) {
    final total = metrics.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Breakdown',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (metrics['todo']! > 0)
                      Expanded(
                        flex: metrics['todo']!,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    if (metrics['inProgress']! > 0)
                      Expanded(
                        flex: metrics['inProgress']!,
                        child: Container(color: Colors.blue),
                      ),
                    if (metrics['codeReview']! > 0)
                      Expanded(
                        flex: metrics['codeReview']!,
                        child: Container(color: Colors.orange),
                      ),
                    if (metrics['testing']! > 0)
                      Expanded(
                        flex: metrics['testing']!,
                        child: Container(color: Colors.purple),
                      ),
                    if (metrics['done']! > 0)
                      Expanded(
                        flex: metrics['done']!,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    if (metrics['blocked']! > 0)
                      Expanded(
                        flex: metrics['blocked']!,
                        child: Container(color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$total items',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _buildLegendItem('To Do', Colors.grey, metrics['todo']!),
            _buildLegendItem(
              'In Progress',
              Colors.blue,
              metrics['inProgress']!,
            ),
            _buildLegendItem(
              'Code Review',
              Colors.orange,
              metrics['codeReview']!,
            ),
            _buildLegendItem('Testing', Colors.purple, metrics['testing']!),
            _buildLegendItem('Done', Colors.green, metrics['done']!),
            _buildLegendItem('Blocked', Colors.red, metrics['blocked']!),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
        ),
      ],
    );
  }

  Map<String, int> _calculateMetrics() {
    final metrics = <String, int>{
      'todo': 0,
      'inProgress': 0,
      'codeReview': 0,
      'testing': 0,
      'done': 0,
      'blocked': 0,
      'cancelled': 0,
    };

    for (final checkpoint in flow.checkpoints) {
      switch (checkpoint.status) {
        case CheckpointStatus.todo:
          metrics['todo'] = metrics['todo']! + 1;
          break;
        case CheckpointStatus.inProgress:
          metrics['inProgress'] = metrics['inProgress']! + 1;
          break;
        case CheckpointStatus.codeReview:
          metrics['codeReview'] = metrics['codeReview']! + 1;
          break;
        case CheckpointStatus.testing:
          metrics['testing'] = metrics['testing']! + 1;
          break;
        case CheckpointStatus.done:
          metrics['done'] = metrics['done']! + 1;
          break;
        case CheckpointStatus.blocked:
          metrics['blocked'] = metrics['blocked']! + 1;
          break;
        case CheckpointStatus.cancelled:
          metrics['cancelled'] = metrics['cancelled']! + 1;
          break;
      }
    }

    return metrics;
  }
}
