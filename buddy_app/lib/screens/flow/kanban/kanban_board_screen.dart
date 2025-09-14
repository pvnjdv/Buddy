import 'package:flutter/material.dart';
import '../../../models/flow_models.dart';
import '../../../services/flow_service.dart';
import 'widgets/kanban_column.dart';
import 'widgets/kanban_header.dart';

class KanbanBoardScreen extends StatefulWidget {
  final ProjectFlow flow;
  final Function(
    String flowId,
    String checkpointId,
    CheckpointStatus newStatus,
  )?
  onCheckpointStatusChanged;

  const KanbanBoardScreen({
    Key? key,
    required this.flow,
    this.onCheckpointStatusChanged,
  }) : super(key: key);

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  List<ProjectFlow> _flows = [];
  List<ProjectFlow> _filteredFlows = [];
  bool _isLoading = true;

  // Filter variables
  String _searchQuery = '';
  CheckpointType? _selectedType;
  CheckpointPriority? _selectedPriority;
  String? _selectedAssignee;
  String? _selectedSprint;

  @override
  void initState() {
    super.initState();
    _loadFlows();
  }

  void _loadFlows() async {
    try {
      final flows = await FlowService.getProjectFlows();
      setState(() {
        _flows = flows;
        _filteredFlows = flows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredFlows = _flows.where((flow) {
        return flow.checkpoints.any((checkpoint) {
          bool matchesSearch =
              _searchQuery.isEmpty ||
              checkpoint.title.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              checkpoint.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );

          bool matchesType =
              _selectedType == null || checkpoint.type == _selectedType;
          bool matchesPriority =
              _selectedPriority == null ||
              checkpoint.priority == _selectedPriority;
          bool matchesAssignee =
              _selectedAssignee == null ||
              checkpoint.assignedTo == _selectedAssignee;
          bool matchesSprint =
              _selectedSprint == null || checkpoint.sprintId == _selectedSprint;

          return matchesSearch &&
              matchesType &&
              matchesPriority &&
              matchesAssignee &&
              matchesSprint;
        });
      }).toList();
    });
  }

  Future<void> _moveCheckpoint(
    String flowId,
    String checkpointId,
    CheckpointStatus newStatus,
  ) async {
    // Find the flow and checkpoint
    final flowIndex = _flows.indexWhere((f) => f.id == flowId);
    if (flowIndex == -1) return;

    final flow = _flows[flowIndex];
    final checkpointIndex = flow.checkpoints.indexWhere(
      (c) => c.id == checkpointId,
    );
    if (checkpointIndex == -1) return;

    final checkpoint = flow.checkpoints[checkpointIndex];

    // Update checkpoint status
    final updatedCheckpoint = checkpoint.copyWith(status: newStatus);
    final updatedCheckpoints = List<FlowCheckpoint>.from(flow.checkpoints);
    updatedCheckpoints[checkpointIndex] = updatedCheckpoint;

    final updatedFlow = flow.copyWith(checkpoints: updatedCheckpoints);

    try {
      // Update in backend/local storage
      await FlowService.updateProjectFlow(updatedFlow);

      setState(() {
        _flows[flowIndex] = updatedFlow;
        _applyFilters();
      });

      // Notify parent if callback provided
      widget.onCheckpointStatusChanged?.call(flowId, checkpointId, newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update checkpoint: $e')),
      );
    }
  }

  List<FlowCheckpoint> _getCheckpointsForStatus(CheckpointStatus status) {
    List<FlowCheckpoint> checkpoints = [];
    for (final flow in _filteredFlows) {
      checkpoints.addAll(flow.checkpoints.where((c) => c.status == status));
    }
    return checkpoints;
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Checkpoints',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // Search field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setModalState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 16),

              // Type filter
              DropdownButtonFormField<CheckpointType>(
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                value: _selectedType,
                items: CheckpointType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setModalState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 16),

              // Priority filter
              DropdownButtonFormField<CheckpointPriority>(
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                value: _selectedPriority,
                items: CheckpointPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: priority.color, size: 12),
                            const SizedBox(width: 8),
                            Text(priority.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setModalState(() => _selectedPriority = value);
                },
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _searchQuery = '';
                        _selectedType = null;
                        _selectedPriority = null;
                        _selectedAssignee = null;
                        _selectedSprint = null;
                      });
                      _applyFilters();
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _applyFilters();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckpointDetails(FlowCheckpoint checkpoint) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(checkpoint.type.icon, color: checkpoint.type.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checkpoint.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status and Priority
              Row(
                children: [
                  Chip(
                    label: Text(checkpoint.status.displayName),
                    backgroundColor: checkpoint.status.color.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      Icons.circle,
                      color: checkpoint.priority.color,
                      size: 12,
                    ),
                    label: Text(checkpoint.priority.displayName),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              if (checkpoint.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(checkpoint.description),
                const SizedBox(height: 16),
              ],

              // Story Points
              if (checkpoint.storyPoints != null) ...[
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 16),
                    const SizedBox(width: 4),
                    Text('Story Points: ${checkpoint.storyPoints}'),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Time tracking
              if (checkpoint.timeTracking != null) ...[
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Original Estimate: ${checkpoint.timeTracking!.originalEstimate}h',
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 4),
                    Text('Time Spent: ${checkpoint.timeTracking!.timeSpent}h'),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Labels
              if (checkpoint.labels.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  children: checkpoint.labels
                      .map(
                        (label) => Chip(
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to edit checkpoint screen
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kanban Board')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get all checkpoints for metrics
    final allCheckpoints = _filteredFlows
        .expand((flow) => flow.checkpoints)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board'),
        actions: [
          IconButton(
            onPressed: _showFilters,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(onPressed: _loadFlows, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Header with metrics
          KanbanHeader(
            flow: widget.flow,
            totalCheckpoints: _flows.expand((f) => f.checkpoints).length,
            filteredCheckpoints: allCheckpoints.length,
          ),

          // Kanban columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: CheckpointStatus.values.map((status) {
                  final checkpoints = _getCheckpointsForStatus(status);
                  return Container(
                    width: 300,
                    margin: const EdgeInsets.only(right: 16),
                    child: KanbanColumn(
                      title: status.displayName,
                      status: status,
                      checkpoints: checkpoints,
                      onCheckpointTap: _showCheckpointDetails,
                      onCheckpointDrop: (checkpoint, newStatus) {
                        // Find the flow containing this checkpoint
                        for (final flow in _flows) {
                          if (flow.checkpoints.any(
                            (c) => c.id == checkpoint.id,
                          )) {
                            _moveCheckpoint(flow.id, checkpoint.id, newStatus);
                            break;
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
