import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/auth_service.dart';
import '../../config/settings/theme_config.dart';
import '../settings/settings_screen.dart';
import 'flows/flow_detail_screen.dart';
import 'flows/notes_alarms_screen.dart';
import 'notes/create_note_screen.dart';
import 'alarms/create_alarm_screen.dart';
import 'notes/enhanced_notes_screen.dart';
import 'alarms/enhanced_alarms_screen.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen>
    with SingleTickerProviderStateMixin {
  List<ProjectFlow> _flows = [];

  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final flows = await FlowService.getProjectFlows();

      setState(() {
        _flows = flows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _refreshData() async {
    await _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Buddy',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Flows', icon: Icon(Icons.account_tree)),
            Tab(text: 'Notes', icon: Icon(Icons.note_alt)),
            Tab(text: 'Alarms', icon: Icon(Icons.alarm)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimaryColor),
            onPressed: _refreshData,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimaryColor),
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'auto_generate':
                  _promptAutoGenerateFlow();
                  break;
                case 'create_note':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateNoteScreen(),
                    ),
                  );
                  break;
                case 'create_alarm':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAlarmScreen(),
                    ),
                  );
                  break;
                case 'view_notes_alarms':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotesAlarmsScreen(),
                    ),
                  );
                  break;
                  _refreshAccessToken();
                  break;
                case 'create_group':
                  _createGroup();
                  break;
                case 'suspend':
                  _suspendRefreshToken();
                  break;
                case 'logout':
                  // Logout handled in settings
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'auto_generate',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-generate Flow',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'create_note',
                child: Row(
                  children: [
                    Icon(Icons.note_add, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Create Note',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_alarm',
                child: Row(
                  children: [
                    Icon(Icons.alarm_add, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Text(
                      'Create Alarm',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'view_notes_alarms',
                child: Row(
                  children: [
                    Icon(Icons.view_list, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(
                      'View Notes & Alarms',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlowsTab(),
          const EnhancedNotesScreen(),
          const EnhancedAlarmsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _getContextualAction,
        icon: Icon(_getContextualIcon()),
        label: Text(_getContextualLabel()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Project Flows Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with Buddy using:\n"create flow for..." or "generate flow..."',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/buddy'),
            icon: const Icon(Icons.chat),
            label: const Text('Talk to Buddy'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _promptAutoGenerateFlow,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Auto-generate a Flow'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(ProjectFlow flow) {
    final progressPercentage = flow.progressPercentage;
    final currentCheckpoint = flow.currentCheckpoint;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToFlowDetail(flow),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      flow.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(flow.status),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) => _handleFlowAction(value, flow),
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'redesign',
                        child: Row(
                          children: [
                            Icon(Icons.design_services, size: 20),
                            SizedBox(width: 8),
                            Text('Redesign'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                flow.description,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${progressPercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
                      minHeight: 6,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Current checkpoint and metadata
              Row(
                children: [
                  if (currentCheckpoint != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Checkpoint',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentCheckpoint.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDifficultyChip(flow.difficulty),
                      const SizedBox(height: 4),
                      Text(
                        flow.estimatedDuration,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),

              if (flow.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: flow.tags.map((tag) => _buildTag(tag)).toList(),
                ),
              ],
            ],
          ),
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
        borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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

  void _navigateToFlowDetail(ProjectFlow flow) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FlowDetailScreen(flow: flow)),
    );
  }

  void _handleFlowAction(String action, ProjectFlow flow) {
    switch (action) {
      case 'rename':
        _showRenameDialog(flow);
        break;
      case 'redesign':
        _showRedesignDialog(flow);
        break;
      case 'delete':
        _showDeleteDialog(flow);
        break;
    }
  }

  void _showRenameDialog(ProjectFlow flow) {
    final TextEditingController controller = TextEditingController(
      text: flow.title,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Flow'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Flow Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await _renameFlow(flow, controller.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showRedesignDialog(ProjectFlow flow) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Redesign Flow'),
          content: Text(
            'This will create a new version of "${flow.title}" with updated checkpoints and timeline. The original flow will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _redesignFlow(flow);
              },
              child: const Text('Redesign'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(ProjectFlow flow) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Flow'),
          content: Text(
            'Are you sure you want to delete "${flow.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteFlow(flow);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameFlow(ProjectFlow flow, String newName) async {
    try {
      final updatedFlow = flow.copyWith(
        title: newName,
        updatedAt: DateTime.now(),
      );

      await FlowService.updateProjectFlow(updatedFlow);
      await _refreshData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flow renamed to "$newName"')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error renaming flow: $e')));
    }
  }

  Future<void> _deleteFlow(ProjectFlow flow) async {
    try {
      await FlowService.deleteProjectFlow(flow.id);
      await _refreshData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flow "${flow.title}" deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting flow: $e')));
    }
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.flash_on, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Auto-generate Flow Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade700,
                  ),
                ),
                title: const Text(
                  'Auto-generate Flow',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Describe your project and let Buddy create a flow',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _promptAutoGenerateFlow();
                },
              ),

              // Create Note Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.note_add, color: Colors.orange.shade700),
                ),
                title: const Text(
                  'Create Note',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Create a quick note or checklist'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _createNote();
                },
              ),

              // Set Alarm Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.alarm_add, color: Colors.red.shade700),
                ),
                title: const Text(
                  'Set Alarm',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Create a reminder or deadline alarm'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _createAlarm();
                },
              ),

              // View All Notes & Alarms
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.view_list, color: Colors.green.shade700),
                ),
                title: const Text(
                  'View All Notes & Alarms',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Manage all your notes and alarms'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotesAlarmsScreen(),
                    ),
                  );
                },
              ),

              // Talk to Buddy
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chat, color: Colors.purple.shade700),
                ),
                title: const Text(
                  'Talk to Buddy AI',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Generate flows or get assistance'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/buddy');
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNote() async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
    );

    if (result != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Note "${result.title}" created')));
    }
  }

  Future<void> _createAlarm() async {
    final result = await Navigator.push<FlowAlarm>(
      context,
      MaterialPageRoute(builder: (context) => const CreateAlarmScreen()),
    );

    if (result != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Alarm "${result.title}" set')));
    }
  }

  void _redesignFlow(ProjectFlow flow) {
    // Navigate to buddy screen with redesign context
    Navigator.of(context).pushNamed(
      '/buddy',
      arguments: {
        'action': 'redesign_flow',
        'flow': flow,
        'initial_message':
            'redesign flow: ${flow.description} - please create an improved version with better checkpoints and timeline',
      },
    );
  }

  void _refreshAccessToken() async {
    final success = await AuthService.refreshAccessToken();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token refreshed successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to refresh token')));
    }
  }

  Future<void> _createGroup() async {
    try {
      final result = await Navigator.pushNamed(context, '/create_group');
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
    }
  }

  Future<void> _suspendRefreshToken() async {
    await AuthService.suspendRefreshToken();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session suspended. You will be logged out in 30 minutes unless you refresh.',
        ),
      ),
    );
  }

  // Prompt user for a description and auto-generate flow
  void _promptAutoGenerateFlow() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Describe your project'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'e.g., Build a Flutter app for note taking with auth and offline mode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop();
              await _autoGenerateFlow(text);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoGenerateFlow(String description) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating flow...')));

      final flow = await FlowService.generateFlowFromDescription(description);

      // If backend created the flow, it will appear in list on refresh
      await _refreshData();

      // Navigate to detail for immediate view
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => FlowDetailScreen(flow: flow)));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flow "${flow.title}" created')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate flow: $e')));
    }
  }

  Widget _buildFlowsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flows.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _flows.length,
        itemBuilder: (context, index) {
          final flow = _flows[index];
          return _buildFlowCard(flow);
        },
      ),
    );
  }

  void _getContextualAction() {
    switch (_tabController.index) {
      case 0: // Flows tab
        _showQuickActions();
        break;
      case 1: // Notes tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
        );
        break;
      case 2: // Alarms tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateAlarmScreen()),
        );
        break;
    }
  }

  IconData _getContextualIcon() {
    switch (_tabController.index) {
      case 0: // Flows tab
        return Icons.add;
      case 1: // Notes tab
        return Icons.note_add;
      case 2: // Alarms tab
        return Icons.alarm_add;
      default:
        return Icons.add;
    }
  }

  String _getContextualLabel() {
    switch (_tabController.index) {
      case 0: // Flows tab
        return 'Quick Actions';
      case 1: // Notes tab
        return 'Add Note';
      case 2: // Alarms tab
        return 'Add Alarm';
      default:
        return 'Add';
    }
  }
}
