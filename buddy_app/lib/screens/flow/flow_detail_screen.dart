import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/buddy_service.dart';

class FlowDetailScreen extends StatefulWidget {
  final ProjectFlow flow;

  const FlowDetailScreen({super.key, required this.flow});

  @override
  State<FlowDetailScreen> createState() => _FlowDetailScreenState();
}

class _FlowDetailScreenState extends State<FlowDetailScreen>
    with SingleTickerProviderStateMixin {
  late ProjectFlow _flow;
  bool _isLoading = false;

  // New: tabs and related data
  late TabController _tabController;
  List<Note> _flowNotes = [];
  List<FlowAlarm> _flowAlarms = [];
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    _flow = widget.flow;
    _tabController = TabController(length: 3, vsync: this);
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    setState(() => _loadingExtras = true);
    try {
      final allNotes = await FlowService.getNotes();
      // Heuristic: notes labeled with flow title belong to this flow
      _flowNotes = allNotes
          .where((n) => n.labels.contains(_flow.title))
          .toList();
      _flowAlarms = await FlowService.getAlarmsForFlow(_flow.id);
    } catch (_) {}
    if (mounted) setState(() => _loadingExtras = false);
  }

  Future<void> _toggleCheckpoint(FlowCheckpoint checkpoint) async {
    setState(() => _isLoading = true);

    try {
      final newStatus = !checkpoint.isCompleted;
      final updatedFlow = await FlowService.updateCheckpointStatus(
        _flow.id,
        checkpoint.id,
        newStatus,
      );

      // Update progress with Buddy
      await BuddyService.updateFlowProgress(
        _flow.id,
        checkpoint.order,
        newStatus,
      );

      if (updatedFlow != null) {
        setState(() => _flow = updatedFlow);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Checkpoint completed! 🎉'
                  : 'Checkpoint marked as incomplete',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not update checkpoint.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating checkpoint: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCheckpointHelp(FlowCheckpoint checkpoint) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Getting help from Buddy...'),
          ],
        ),
      ),
    );

    try {
      final help = await BuddyService.getCheckpointHelp(
        flowId: _flow.id.toString(),
        checkpointName: checkpoint.title,
      );
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.help, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Help: ${checkpoint.title}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(help['response'] ?? 'No help available.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/buddy');
              },
              child: const Text('Ask More'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting help: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = _flow.progressPercentage;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(_flow.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Timelines'),
            Tab(icon: Icon(Icons.note_alt), text: 'Notes'),
            Tab(icon: Icon(Icons.alarm), text: 'Alarms & Meetings'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => Navigator.of(context).pushNamed('/buddy'),
            tooltip: 'Chat with Buddy',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineTab(progressPercentage),
          _buildNotesTab(),
          _buildAlarmsTab(),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(double progressPercentage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flow Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_flow.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${progressPercentage.toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(progressPercentage),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Metadata
                  Row(
                    children: [
                      _buildInfoChip(Icons.schedule, _flow.estimatedDuration),
                      const SizedBox(width: 8),
                      _buildDifficultyChip(_flow.difficulty),
                      const SizedBox(width: 8),
                      _buildStatusChip(_flow.status),
                    ],
                  ),

                  if (_flow.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: _flow.tags
                          .map((tag) => _buildTag(tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Checkpoints Section
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Checkpoints (${_flow.completedCheckpoints.length}/${_flow.checkpoints.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Checkpoints List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _flow.checkpoints.length,
            itemBuilder: (context, index) {
              final checkpoint = _flow.checkpoints[index];
              final isCurrentCheckpoint = index == _flow.currentCheckpointIndex;
              return _buildCheckpointCard(checkpoint, isCurrentCheckpoint);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_loadingExtras) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flowNotes.isEmpty) {
      return Center(
        child: Text(
          'No notes for this flow yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExtras,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _flowNotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = _flowNotes[i];
          return Card(
            child: ListTile(
              title: Text(n.title.isEmpty ? 'Untitled' : n.title),
              subtitle: n.type == NoteType.text
                  ? Text(
                      n.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text('${n.checklist.length} checklist items'),
              trailing: n.isPinned
                  ? const Icon(Icons.push_pin, size: 18)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlarmsTab() {
    if (_loadingExtras) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flowAlarms.isEmpty) {
      return Center(
        child: Text(
          'No alarms or meetings for this flow yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExtras,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _flowAlarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = _flowAlarms[i];
          return Card(
            child: ListTile(
              leading: Icon(
                a.type == AlarmType.meeting
                    ? Icons.people_alt
                    : (a.type == AlarmType.deadline
                          ? Icons.event_available
                          : Icons.alarm),
                color: Colors.blue,
              ),
              title: Text(a.title),
              subtitle: Text(
                '${a.scheduledTime.toLocal()}\n${a.description}'.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: a.isActive
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.remove_circle, color: Colors.redAccent),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckpointCard(FlowCheckpoint checkpoint, bool isCurrent) {
    final isCompleted = checkpoint.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => _toggleCheckpoint(checkpoint),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? Colors.green : Colors.grey,
                        width: 2,
                      ),
                      color: isCompleted ? Colors.green : Colors.transparent,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),

                const SizedBox(width: 12),

                // Title and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              checkpoint.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isCompleted
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                            ),
                          ),
                          _buildCheckpointTypeChip(checkpoint.type),
                        ],
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Help button
                IconButton(
                  onPressed: () => _getCheckpointHelp(checkpoint),
                  icon: const Icon(Icons.help_outline, color: Colors.blue),
                  tooltip: 'Get help from Buddy',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              checkpoint.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),

            const SizedBox(height: 12),

            // Requirements and Deliverables
            if (checkpoint.requirements.isNotEmpty) ...[
              _buildListSection(
                'Requirements',
                checkpoint.requirements,
                Icons.list,
              ),
              const SizedBox(height: 8),
            ],

            if (checkpoint.deliverables.isNotEmpty) ...[
              _buildListSection(
                'Deliverables',
                checkpoint.deliverables,
                Icons.delivery_dining,
              ),
              const SizedBox(height: 8),
            ],

            // Estimated time
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Estimated: ${checkpoint.estimatedTime}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (checkpoint.completedAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Completed: ${_formatDate(checkpoint.completedAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 2),
            child: Text(
              '• $item',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(FlowDifficulty difficulty) {
    Color color;
    String label;

    switch (difficulty) {
      case FlowDifficulty.easy:
        color = Colors.green;
        label = 'Easy';
        break;
      case FlowDifficulty.medium:
        color = Colors.orange;
        label = 'Medium';
        break;
      case FlowDifficulty.hard:
        color = Colors.red;
        label = 'Hard';
        break;
      case FlowDifficulty.expert:
        color = Colors.purple;
        label = 'Expert';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusChip(FlowStatus status) {
    Color color;
    String label;

    switch (status) {
      case FlowStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case FlowStatus.completed:
        color = Colors.blue;
        label = 'Completed';
        break;
      case FlowStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        break;
      case FlowStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCheckpointTypeChip(CheckpointType type) {
    Color color;
    String label;

    switch (type) {
      case CheckpointType.task:
        color = Colors.blue;
        label = 'Task';
        break;
      case CheckpointType.milestone:
        color = Colors.purple;
        label = 'Milestone';
        break;
      case CheckpointType.review:
        color = Colors.orange;
        label = 'Review';
        break;
      case CheckpointType.testing:
        color = Colors.green;
        label = 'Testing';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tag, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage < 25) return Colors.red;
    if (percentage < 50) return Colors.orange;
    if (percentage < 75) return Colors.blue;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
