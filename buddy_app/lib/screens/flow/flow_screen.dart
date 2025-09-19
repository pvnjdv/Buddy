import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../models/collaboration_models.dart';
import '../../services/flow_service.dart';
import '../../services/ai/chat_service.dart';
import '../../services/ai/buddy_service.dart';
import '../../config/settings/theme_config.dart';
import '../settings/settings_screen.dart';
import '../buddy_code_editor/editor_selector.dart';
import 'flows/flow_detail_screen.dart';
import 'kanban/kanban_board_screen.dart';
import 'notes/enhanced_notes_screen.dart';
import 'alarms/enhanced_alarms_screen.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

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
    _tabController = TabController(length: 4, vsync: this);
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
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // Login screen background
      appBar: AppBar(
        title: Text(
          'Flow',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1B263B),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: const Color(0xFF667EEA),
          tabs: const [
            Tab(text: 'Flows', icon: Icon(Icons.account_tree)),
            Tab(text: 'Code', icon: Icon(Icons.code)),
            Tab(text: 'Track', icon: Icon(Icons.track_changes)),
            Tab(text: 'Product', icon: Icon(Icons.inventory)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.note_alt, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnhancedNotesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.alarm, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnhancedAlarmsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1A202C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: const Color(0xFF4A5568).withValues(alpha: 0.3),
              ),
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
                  _createNote();
                  break;
                case 'create_alarm':
                  _createAlarm();
                  break;
                case 'view_notes_alarms':
                  _showNotesAlarms();
                  break;
                case 'refresh_token':
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
                    Icon(Icons.settings_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'auto_generate',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: const Color(0xFF667EEA)),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-generate Flow',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'create_note',
                child: Row(
                  children: [
                    Icon(Icons.note_add, color: const Color(0xFF667EEA)),
                    const SizedBox(width: 8),
                    Text('Create Note', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_alarm',
                child: Row(
                  children: [
                    Icon(Icons.alarm_add, color: const Color(0xFF764BA2)),
                    const SizedBox(width: 8),
                    Text('Create Alarm', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'view_notes_alarms',
                child: Row(
                  children: [
                    Icon(Icons.view_list, color: const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      'View Notes & Alarms',
                      style: TextStyle(color: Colors.white),
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
          _buildVSCodeTab(),
          _buildTrackTab(),
          _buildProductTab(),
        ],
      ),
    );
  }

  Widget _buildFlowsTab() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D1B2A), // Deep dark blue
              Color(0xFF1B263B), // Dark slate
              Color(0xFF2D3748), // Darker gray
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D1B2A), // Deep dark blue
            Color(0xFF1B263B), // Dark slate
            Color(0xFF2D3748), // Darker gray
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadAllData,
        color: const Color(0xFF667EEA),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [_buildProjectFlows()],
        ),
      ),
    );
  }

  Widget _buildVSCodeTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D1B2A), // Deep dark blue
            Color(0xFF1B263B), // Dark slate
            Color(0xFF2D3748), // Darker gray
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VS Code Integration Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VS Code Integration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open your project flows in VS Code with seamless sync across devices',
                        style: TextStyle(fontSize: 16, color: Colors.grey[300]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openVSCode(),
                  icon: const Icon(Icons.launch),
                  label: const Text('Open VS Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667EEA),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Project Flows for VS Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Open in VS Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: () => _createNewVSCodeProject(),
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667EEA),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Project Flows Grid for VS Code
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF667EEA),
                      ),
                    ),
                  )
                : _flows.isEmpty
                ? _buildEmptyVSCodeState()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _flows.length,
                    itemBuilder: (context, index) {
                      final flow = _flows[index];
                      return _buildVSCodeFlowCard(flow);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVSCodeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.code, size: 64, color: Color(0xFF667EEA)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Project Flows Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a project flow to open in VS Code',
            style: TextStyle(fontSize: 16, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewVSCodeProject(),
            icon: const Icon(Icons.add),
            label: const Text('Create Project Flow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVSCodeFlowCard(ProjectFlow flow) {
    IconData getFlowIcon(List<String> tags) {
      if (tags.contains('web')) return Icons.web;
      if (tags.contains('mobile')) return Icons.phone_android;
      if (tags.contains('ai')) return Icons.psychology;
      if (tags.contains('game')) return Icons.games;
      if (tags.contains('api')) return Icons.api;
      if (tags.contains('data')) return Icons.data_usage;
      return Icons.folder_open;
    }

    Color getFlowColor(List<String> tags) {
      if (tags.contains('web')) return Colors.blue;
      if (tags.contains('mobile')) return Colors.green;
      if (tags.contains('ai')) return Colors.purple;
      if (tags.contains('game')) return Colors.orange;
      if (tags.contains('api')) return Colors.red;
      if (tags.contains('data')) return Colors.teal;
      return const Color(0xFF667EEA);
    }

    final completedCheckpoints = flow.checkpoints
        .where((c) => c.isCompleted)
        .length;
    final progressPercentage = flow.checkpoints.isEmpty
        ? 0.0
        : completedCheckpoints / flow.checkpoints.length;

    return Card(
      elevation: 8,
      color: const Color(0xFF1A202C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF4A5568).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openFlowInVSCode(flow),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: getFlowColor(flow.tags).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getFlowIcon(flow.tags),
                      color: getFlowColor(flow.tags),
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleFlowVSCodeAction(action, flow),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: ListTile(
                          leading: Icon(Icons.launch),
                          title: Text('Open in VS Code'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sync',
                        child: ListTile(
                          leading: Icon(Icons.sync),
                          title: Text('Force Sync'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'details',
                        child: ListTile(
                          leading: Icon(Icons.info),
                          title: Text('View Details'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                flow.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                flow.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getFlowColor(flow.tags),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progressPercentage * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectFlows() {
    if (_flows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.account_tree,
                size: 64,
                color: Color(0xFF667EEA),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Project Flows Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project flow to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey[300]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Project Flows',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._flows.map((flow) => _buildEnhancedFlowCard(flow)).toList(),
      ],
    );
  }

  Widget _buildEnhancedFlowCard(ProjectFlow flow) {
    final isCollaborative = flow.collaboration != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCollaborative
              ? const Color(0xFF667EEA).withValues(alpha: 0.5)
              : const Color(0xFF4A5568).withValues(alpha: 0.3),
          width: isCollaborative ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FlowDetailScreen(flow: flow)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Icon(
                          Icons.work,
                          color: const Color(0xFF667EEA),
                          size: 20,
                        ),
                        if (isCollaborative)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flow.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flow.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleFlowAction(value, flow),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, size: 16),
                            SizedBox(width: 8),
                            Text('Open'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'kanban',
                        child: Row(
                          children: [
                            Icon(Icons.view_kanban, size: 16),
                            SizedBox(width: 8),
                            Text('Kanban Board'),
                          ],
                        ),
                      ),
                      if (isCollaborative) ...[
                        const PopupMenuItem(
                          value: 'collaborate',
                          child: Row(
                            children: [
                              Icon(Icons.handshake, size: 16),
                              SizedBox(width: 8),
                              Text('Collaboration'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'invite_member',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 16),
                              SizedBox(width: 8),
                              Text('Invite Member'),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  // Quick Kanban Board Access Button
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KanbanBoardScreen(
                          flow: flow,
                          onCheckpointStatusChanged:
                              (flowId, checkpointId, newStatus) {
                                _loadAllData();
                              },
                        ),
                      ),
                    ),
                    icon: Icon(Icons.view_kanban, color: Colors.blue, size: 20),
                    tooltip: 'Open Kanban Board',
                  ),
                ],
              ),

              // Collaboration Info Section
              if (isCollaborative) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.handshake,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Collaborative Project',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (flow.collaboration!.lastActivity != null)
                            Text(
                              _getLastActivityText(
                                flow.collaboration!.lastActivity!,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Members count
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${flow.collaboration!.totalMembers} members',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // My role
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                flow.collaboration!.myRole.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Member avatars
                      Row(
                        children: [
                          ...flow.collaboration!.members.take(3).map((member) {
                            return Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  member.userName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          if (flow.collaboration!.totalMembers > 3)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  '+${flow.collaboration!.totalMembers - 3}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _showFlowCollaborationDetails(flow),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'View Team',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Footer info
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_getRelativeTime(flow.updatedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLastActivityText(DateTime lastActivity) {
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Active now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Now';
    }
  }

  void _showFlowCollaborationDetails(ProjectFlow flow) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${flow.title} Team'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Members (${flow.collaboration!.totalMembers})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...flow.collaboration!.members.map((member) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          member.userName[0].toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              member.role.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: member.role == CollaborationRole.owner
                                    ? Colors.amber
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (member.role == CollaborationRole.owner)
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(
                        _getLastActivityText(member.lastActive),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showInviteToFlowDialog(flow);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Invite More'),
          ),
        ],
      ),
    );
  }

  void _showInviteToFlowDialog(ProjectFlow flow) {
    final TextEditingController mobileController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    CollaborationRole selectedRole = CollaborationRole.contributor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Invite to ${flow.title}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '+1234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CollaborationRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.workspace_premium),
                ),
                items: CollaborationRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText: 'Would you like to collaborate on this project?',
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _sendCollaborationInvite(
                flow,
                mobileController.text,
                selectedRole,
                messageController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  // ...existing methods...

  Future<void> _sendCollaborationInvite(
    ProjectFlow? flow,
    String mobile,
    CollaborationRole role,
    String message,
  ) async {
    if (flow == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a project')));
      return;
    }

    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mobile number')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      // Create collaboration data for the chat message
      final collaborationData = {
        'project_id': flow.id,
        'project_title': flow.title,
        'invitation_id': 'inv_${DateTime.now().millisecondsSinceEpoch}',
        'role': role.name,
        'message': message.isNotEmpty
            ? message
            : 'Would you like to collaborate on this project?',
        'expires_at': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'response': null,
      };

      // Send collaboration request as chat message
      final success = await ChatService.sendCollaborationRequest(
        receiverId: mobile, // In real app, this would be user ID
        collaborationData: collaborationData,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collaboration invite sent to $mobile'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Chat',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushNamed('/chats');
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to send invitation');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // VS Code Integration Action methods
  void _openVSCode() {
    // Create a basic session for opening VS Code
    final basicFlow = ProjectFlow(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Project',
      description: 'Start coding with VS Code',
      estimatedDuration: '1 hour',
      difficulty: FlowDifficulty.easy,
      checkpoints: [],
      tags: ['vscode', 'new'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorSelector(projectFlow: basicFlow),
      ),
    );
  }

  void _createNewVSCodeProject() {
    // For now, just open VS Code - in a real app this would show a project creation dialog
    _openVSCode();
  }

  void _openFlowInVSCode(ProjectFlow flow) async {
    // Navigate to Editor Selector which will choose the best editor for the platform
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorSelector(projectFlow: flow),
      ),
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${flow.title} in editor...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleFlowVSCodeAction(String action, ProjectFlow flow) async {
    switch (action) {
      case 'open':
        _openFlowInVSCode(flow);
        break;
      case 'sync':
        // Future enhancement: implement general project sync
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync feature coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'details':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FlowDetailScreen(flow: flow)),
        );
        break;
    }
  }

  void _handleFlowAction(String action, ProjectFlow flow) async {
    switch (action) {
      case 'open':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FlowDetailScreen(flow: flow)),
        );
        break;
      case 'kanban':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KanbanBoardScreen(
              flow: flow,
              onCheckpointStatusChanged: (flowId, checkpointId, newStatus) {
                // Refresh the flow data after status change
                _loadAllData();
              },
            ),
          ),
        );
        break;
      case 'collaborate':
        _showFlowCollaborationDetails(flow);
        break;
      case 'invite_member':
        _showInviteToFlowDialog(flow);
        break;
      case 'edit':
        // Navigate to edit flow screen (could be implemented later)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit flow functionality coming soon')),
        );
        break;
      case 'delete':
        _deleteProjectFlow(flow);
        break;
    }
  }

  Future<void> _deleteProjectFlow(ProjectFlow flow) async {
    final bool confirmed = await _showDeleteConfirmation(
      'Delete Project Flow',
      'Are you sure you want to delete "${flow.title}"?\n\n'
          'This will permanently delete:\n'
          '• Flow configuration\n'
          '• All checkpoints and progress\n'
          '• Associated documentation\n\n'
          'This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text('Deleting flow "${flow.title}"...'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Delete from backend service
      await FlowService.deleteProjectFlow(flow.id);

      // Remove from local list
      setState(() {
        _flows.removeWhere((f) => f.id == flow.id);
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Flow "${flow.title}" deleted successfully'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _restoreProjectFlow(flow),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete flow: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _deleteProjectFlow(flow),
          ),
        ),
      );
    }
  }

  Future<bool> _showDeleteConfirmation(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _restoreProjectFlow(ProjectFlow flow) async {
    try {
      // For now, just reload data since we don't have a restore API
      await _loadAllData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attempting to restore flow "${flow.title}"...'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore flow: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createNote() {
    // Navigate to create note screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create note functionality coming soon')),
    );
  }

  void _createAlarm() {
    // Navigate to create alarm screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create alarm functionality coming soon')),
    );
  }

  // Additional methods for old-style menu functionality
  void _promptAutoGenerateFlow() {
    final TextEditingController _descriptionController =
        TextEditingController();
    bool _isGenerating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A202C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF667EEA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Flow Generator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Describe your project and let AI create a complete flow with tasks and checkpoints.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'e.g., "Create a Flutter e-commerce app with user authentication, product catalog, shopping cart, and payment integration"',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xFF2D3748),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF667EEA),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: const Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: Be specific about technologies, features, and complexity level for better results.',
                            style: TextStyle(
                              color: const Color(0xFF10B981),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isGenerating
                      ? null
                      : () async {
                          final description = _descriptionController.text
                              .trim();
                          if (description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a project description',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => _isGenerating = true);

                          try {
                            // Use enhanced dynamic flow generation
                            final previewResult =
                                await BuddyService.generateDynamicFlow(
                                  projectDescription: description,
                                  technologies:
                                      [], // Will be extracted from description
                                  complexity:
                                      'medium', // Default, can be enhanced
                                  externalData: null,
                                  includeNotes: true,
                                  includeAlarms: true,
                                  accessExternalData: true,
                                );

                            if (previewResult['success'] == true) {
                              Navigator.of(dialogContext).pop();

                              // Show enhanced preview dialog with detailed structure
                              _showEnhancedFlowPreviewDialog(
                                description: description,
                                previewData: previewResult,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    previewResult['message'] ??
                                        'Failed to generate dynamic flow',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error generating flow: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setState(() => _isGenerating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Generate Flow'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEnhancedFlowPreviewDialog({
    required String description,
    required Map<String, dynamic> previewData,
  }) {
    final TextEditingController _modificationsController =
        TextEditingController();
    bool _isCreating = false;
    bool _showDetails = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A202C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI-Generated Dynamic Flow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Analysis Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics,
                                color: const Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Analysis Complete',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            previewData['preview_text'] ??
                                'Flow analysis in progress...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Flow Structure Visualization
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Flow Structure',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _showDetails = !_showDetails,
                                ),
                                icon: Icon(
                                  _showDetails
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: const Color(0xFF667EEA),
                                ),
                                label: Text(
                                  _showDetails
                                      ? 'Hide Details'
                                      : 'Show Details',
                                  style: const TextStyle(
                                    color: Color(0xFF667EEA),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildFlowStructureVisualization(
                            previewData['flow_data'],
                            showDetails: _showDetails,
                          ),
                        ],
                      ),
                    ),

                    // Notes and Alarms Section
                    if ((previewData['notes'] as List?)?.isNotEmpty == true ||
                        (previewData['alarms'] as List?)?.isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D3748),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Flow Intelligence',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ((previewData['notes'] as List?)?.isNotEmpty ==
                                true) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    size: 16,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Smart Notes Generated:',
                                    style: TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ..._buildNotesList(previewData['notes'] as List),
                            ],
                            if ((previewData['alarms'] as List?)?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.alarm,
                                    size: 16,
                                    color: const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Critical Alarms Set:',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ..._buildAlarmsList(
                                previewData['alarms'] as List,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Modifications Input
                    const Text(
                      'Enhance the flow (optional):',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _modificationsController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'e.g., "Add more security checks" or "Include performance monitoring"',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF2D3748),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF667EEA),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isCreating
                      ? null
                      : () async {
                          setState(() => _isCreating = true);

                          try {
                            final modifications = _modificationsController.text
                                .trim();

                            // Create the flow directly using the enhanced data
                            final flowData =
                                previewData['flow_data']
                                    as Map<String, dynamic>;

                            // Convert the AI-generated structure to ProjectFlow format
                            final projectFlow = _convertAIFlowToProjectFlow(
                              flowData,
                              description,
                              modifications,
                            );

                            // Save the flow
                            await FlowService.createProjectFlow(projectFlow);

                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              await _loadAllData();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Dynamic AI flow "${projectFlow.title}" created successfully!',
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  action: SnackBarAction(
                                    label: 'View',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FlowDetailScreen(
                                                flow: projectFlow,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error creating dynamic flow: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isCreating = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create Dynamic Flow'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFlowStructureVisualization(
    Map<String, dynamic>? flowData, {
    bool showDetails = false,
  }) {
    if (flowData == null) {
      return const Text(
        'Flow structure analysis in progress...',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    final phases = flowData['phases'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats
        Row(
          children: [
            _buildStatChip('${phases.length}', 'Phases'),
            const SizedBox(width: 8),
            _buildStatChip(
              '${phases.fold<int>(0, (sum, phase) => sum + ((phase['steps'] as List?)?.length ?? 0))}',
              'Steps',
            ),
            const SizedBox(width: 8),
            _buildStatChip(
              '${flowData['checkpoints']?.length ?? 0}',
              'Checkpoints',
            ),
          ],
        ),

        if (showDetails && phases.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Execution Flow:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...phases.map((phase) {
            final phaseMap = phase as Map<String, dynamic>;
            final steps = phaseMap['steps'] as List<dynamic>? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A202C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF667EEA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phaseMap['title'] as String? ?? 'Phase',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        phaseMap['estimated_duration'] as String? ?? '',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...steps.map((step) {
                      final stepMap = step as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stepMap['title'] as String? ?? 'Step',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF667EEA).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: Color(0xFF667EEA),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _buildNotesList(List<dynamic> notes) {
    return notes.take(3).map((note) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                '• $note',
                style: TextStyle(color: Colors.grey[300], fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildAlarmsList(List<dynamic> alarms) {
    return alarms.take(3).map((alarm) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                '• $alarm',
                style: TextStyle(color: Colors.grey[300], fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  ProjectFlow _convertAIFlowToProjectFlow(
    Map<String, dynamic> aiFlowData,
    String originalDescription,
    String modifications,
  ) {
    final phases = aiFlowData['phases'] as List<dynamic>? ?? [];
    final notes = aiFlowData['notes'] as List<dynamic>? ?? [];
    final alarms = aiFlowData['alarms'] as List<dynamic>? ?? [];

    // Convert phases to checkpoints
    final checkpoints = <FlowCheckpoint>[];
    int stepIndex = 0;

    for (final phase in phases) {
      final phaseMap = phase as Map<String, dynamic>;
      final phaseSteps = phaseMap['steps'] as List<dynamic>? ?? [];

      for (final step in phaseSteps) {
        final stepMap = step as Map<String, dynamic>;
        checkpoints.add(
          FlowCheckpoint(
            id: 'step_${stepIndex++}',
            title: stepMap['title'] as String? ?? 'Step ${stepIndex}',
            description: stepMap['description'] as String? ?? '',
            isCompleted: false,
            estimatedTime: stepMap['estimated_time'] as String? ?? '1 hour',
            order: stepIndex,
            labels: ['ai-generated', 'dynamic'],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    // Create title from description
    final title = _generateFlowTitle(aiFlowData, originalDescription);

    return ProjectFlow(
      id: 'ai_flow_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description:
          '$originalDescription\n\n${modifications.isNotEmpty ? 'Modifications: $modifications' : ''}',
      estimatedDuration: _calculateTotalDuration(checkpoints),
      difficulty: _determineDifficulty(checkpoints.length),
      checkpoints: checkpoints,
      tags: ['ai-generated', 'dynamic', 'intelligent'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      collaboration: null,
      notes: notes.map((note) => note.toString()).toList(),
      alarms: alarms.map((alarm) => alarm.toString()).toList(),
    );
  }

  String _calculateTotalDuration(List<FlowCheckpoint> checkpoints) {
    int totalHours = 0;

    for (final checkpoint in checkpoints) {
      final timeStr = checkpoint.estimatedTime;
      final hourMatch = RegExp(r'(\d+)').firstMatch(timeStr);
      if (hourMatch != null) {
        totalHours += int.parse(hourMatch.group(1)!);
      } else {
        totalHours += 1; // Default 1 hour
      }
    }

    if (totalHours < 8) return '$totalHours hours';
    final days = (totalHours / 8).ceil();
    return '$days day${days > 1 ? 's' : ''}';
  }

  FlowDifficulty _determineDifficulty(int checkpointCount) {
    if (checkpointCount < 5) return FlowDifficulty.easy;
    if (checkpointCount < 15) return FlowDifficulty.medium;
    return FlowDifficulty.hard;
  }

  void _showNotesAlarms() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes & Alarms view coming soon')),
    );
  }

  void _refreshAccessToken() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refresh token functionality coming soon')),
    );
  }

  void _createGroup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create group functionality coming soon')),
    );
  }

  void _suspendRefreshToken() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suspend token functionality coming soon')),
    );
  }

  Widget _buildTrackTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D1B2A), // Deep dark blue
            Color(0xFF1B263B), // Dark slate
            Color(0xFF2D3748), // Darker gray
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _flows.isEmpty
          ? _buildEmptyTrackState()
          : Column(
              children: [
                // Header with repository selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A202C),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.track_changes,
                        color: Color(0xFF667EEA),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'GitHub Commits Analysis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Repository selector if multiple flows with repos
                if (_flows.where((f) => f.repositoryUrl != null).length > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<ProjectFlow>(
                      decoration: const InputDecoration(
                        labelText: 'Select Repository',
                        border: OutlineInputBorder(),
                        fillColor: Color(0xFF1A202C),
                        filled: true,
                      ),
                      dropdownColor: const Color(0xFF1A202C),
                      style: const TextStyle(color: Colors.white),
                      value: _flows.firstWhere(
                        (f) => f.repositoryUrl != null,
                        orElse: () => _flows.first,
                      ),
                      items: _flows.where((f) => f.repositoryUrl != null).map((
                        flow,
                      ) {
                        return DropdownMenuItem(
                          value: flow,
                          child: Text(flow.title),
                        );
                      }).toList(),
                      onChanged: (flow) {
                        if (flow != null) {
                          // TODO: Load commits for selected repository
                          setState(() {});
                        }
                      },
                    ),
                  ),
                // Commits analysis content
                Expanded(
                  child:
                      _flows.isNotEmpty &&
                          _flows.any((f) => f.repositoryUrl != null)
                      ? _buildCommitsAnalysisView()
                      : _buildEmptyTrackState(),
                ),
              ],
            ),
    );
  }

  Widget _buildCommitsAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repository Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Commits',
                  '247',
                  Icons.commit,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'This Week',
                  '23',
                  Icons.calendar_view_week,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Contributors',
                  '8',
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Avg/Day',
                  '3.3',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Commits Section
          const Text(
            'Recent Commits',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Mock recent commits - in real implementation, this would come from GitHub API
          _buildCommitItem(
            'feat: Add user authentication flow',
            'john.doe',
            '2 hours ago',
            'Added JWT token handling and user login endpoints',
            ['auth', 'backend'],
          ),
          _buildCommitItem(
            'fix: Resolve memory leak in code editor',
            'jane.smith',
            '5 hours ago',
            'Fixed widget disposal and stream cleanup',
            ['bugfix', 'ui'],
          ),
          _buildCommitItem(
            'docs: Update API documentation',
            'mike.johnson',
            '1 day ago',
            'Added comprehensive API docs for new endpoints',
            ['documentation'],
          ),
          _buildCommitItem(
            'refactor: Optimize database queries',
            'sarah.wilson',
            '2 days ago',
            'Improved query performance by 40%',
            ['performance', 'database'],
          ),

          const SizedBox(height: 24),

          // Commit Velocity Chart (Mock visualization)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A202C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4A5568).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commit Velocity (Last 30 Days)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Mock chart visualization
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3748),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '📊 Commit velocity chart would be displayed here',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Development Activity
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A202C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4A5568).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Development Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActivityItem(
                  'Active Branches',
                  '3 feature branches, 1 hotfix',
                  Icons.call_split,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildActivityItem(
                  'Open Pull Requests',
                  '7 PRs awaiting review',
                  Icons.merge,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildActivityItem(
                  'Recent Releases',
                  'v2.1.0 released 3 days ago',
                  Icons.tag,
                  Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildActivityItem(
                  'Code Quality',
                  '94% test coverage, 2 failing checks',
                  Icons.check_circle,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4A5568).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommitItem(
    String message,
    String author,
    String time,
    String description,
    List<String> tags,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4A5568).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.commit, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey[400], size: 16),
              const SizedBox(width: 4),
              Text(
                author,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, color: Colors.grey[400], size: 16),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTrackState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.track_changes,
              size: 64,
              color: Color(0xFF667EEA),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Repositories to Track',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a project flow with a GitHub repository to view commit analysis',
            style: TextStyle(fontSize: 16, color: Colors.grey[300]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductManagementView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product Management Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory, size: 32, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Product Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Manage your product lifecycle, documentation, and deployments',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Product Documentation Section
        _buildProductSection(
          title: 'Documentation',
          icon: Icons.description,
          color: const Color(0xFF10B981),
          children: [
            _buildProductCard(
              title: 'API Documentation',
              subtitle: 'View and manage API docs',
              icon: Icons.api,
              onTap: () => _showDocumentation('api'),
            ),
            _buildProductCard(
              title: 'User Guide',
              subtitle: 'Product usage documentation',
              icon: Icons.book,
              onTap: () => _showDocumentation('user'),
            ),
            _buildProductCard(
              title: 'Technical Specs',
              subtitle: 'System architecture and specs',
              icon: Icons.settings,
              onTap: () => _showDocumentation('technical'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Current Product Preview Section
        _buildProductSection(
          title: 'Current Product',
          icon: Icons.preview,
          color: const Color(0xFFF59E0B),
          children: [
            _buildProductCard(
              title: 'Live Preview',
              subtitle: 'View current product state',
              icon: Icons.visibility,
              onTap: () => _showProductPreview(),
            ),
            _buildProductCard(
              title: 'Feature Status',
              subtitle: 'Track feature implementation',
              icon: Icons.check_circle,
              onTap: () => _showFeatureStatus(),
            ),
            _buildProductCard(
              title: 'User Feedback',
              subtitle: 'View user reviews and feedback',
              icon: Icons.feedback,
              onTap: () => _showUserFeedback(),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Deployment Details Section
        _buildProductSection(
          title: 'Deployments',
          icon: Icons.rocket_launch,
          color: const Color(0xFFEF4444),
          children: [
            _buildProductCard(
              title: 'Deployment History',
              subtitle: 'View past deployments',
              icon: Icons.history,
              onTap: () => _showDeploymentHistory(),
            ),
            _buildProductCard(
              title: 'Environment Status',
              subtitle: 'Check staging/prod status',
              icon: Icons.cloud,
              onTap: () => _showEnvironmentStatus(),
            ),
            _buildProductCard(
              title: 'Release Notes',
              subtitle: 'Current version changelog',
              icon: Icons.new_releases,
              onTap: () => _showReleaseNotes(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[700]!.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showDocumentation(String type) {
    // TODO: Implement documentation viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $type documentation...'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _showProductPreview() {
    // TODO: Implement product preview
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening product preview...'),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
  }

  void _showFeatureStatus() {
    // TODO: Implement feature status tracker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening feature status...'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _showUserFeedback() {
    // TODO: Implement user feedback viewer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening user feedback...'),
        backgroundColor: const Color(0xFF667EEA),
      ),
    );
  }

  void _showDeploymentHistory() {
    // TODO: Implement deployment history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening deployment history...'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _showEnvironmentStatus() {
    // TODO: Implement environment status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening environment status...'),
        backgroundColor: const Color(0xFF764BA2),
      ),
    );
  }

  void _showReleaseNotes() {
    // TODO: Implement release notes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening release notes...'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Widget _buildProductTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D1B2A), // Deep dark blue
            Color(0xFF1B263B), // Dark slate
            Color(0xFF2D3748), // Darker gray
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _buildProductManagementView(),
    );
  }

  Future<ProjectFlow> _convertPreviewDataToProjectFlow(
    Map<String, dynamic> previewData,
    String description,
  ) async {
    final flowTitle = _generateFlowTitle(previewData, description);
    final checkpoints = <FlowCheckpoint>[];

    if (previewData['checkpoints'] != null) {
      int order = 1;
      for (final checkpointData in previewData['checkpoints']) {
        if (checkpointData is Map<String, dynamic>) {
          checkpoints.add(
            FlowCheckpoint(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_$order',
              title: checkpointData['title'] ?? 'Step $order',
              description: checkpointData['description'] ?? '',
              requirements: List<String>.from(
                checkpointData['requirements'] ?? [],
              ),
              deliverables: List<String>.from(
                checkpointData['deliverables'] ?? [],
              ),
              estimatedTime: checkpointData['estimated_time'] ?? '1 day',
              order: order,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          order++;
        }
      }
    }

    return ProjectFlow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: flowTitle,
      description: description,
      checkpoints: checkpoints,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      estimatedDuration: _calculateFlowDuration(checkpoints),
      difficulty: _determineFlowDifficulty(checkpoints),
      notes: List<String>.from(previewData['notes'] ?? []),
      alarms: List<String>.from(previewData['alarms'] ?? []),
    );
  }

  String _generateFlowTitle(
    Map<String, dynamic> previewData,
    String description,
  ) {
    // Use AI-generated title if available, otherwise create from description
    final aiTitle = previewData['title'];
    if (aiTitle != null && aiTitle.toString().isNotEmpty) {
      return aiTitle.toString();
    }
    // Create a title from the first few words of the description
    final words = description.split(' ');
    final titleWords = words.take(4).join(' ');
    return titleWords.capitalize();
  }

  String _calculateFlowDuration(List<FlowCheckpoint> checkpoints) {
    if (checkpoints.isEmpty) return '1 week';

    // Simple estimation based on number of checkpoints
    final weeks = (checkpoints.length / 5).ceil();
    if (weeks == 1) return '1 week';
    return '$weeks weeks';
  }

  FlowDifficulty _determineFlowDifficulty(List<FlowCheckpoint> checkpoints) {
    if (checkpoints.isEmpty) return FlowDifficulty.medium;

    // Determine difficulty based on complexity indicators
    final hasComplexRequirements = checkpoints.any(
      (c) => c.requirements.length > 3 || c.description.length > 200,
    );

    if (hasComplexRequirements) return FlowDifficulty.hard;
    if (checkpoints.length > 10) return FlowDifficulty.medium;
    return FlowDifficulty.easy;
  }

  Future<void> _saveGeneratedFlow(ProjectFlow flow) async {
    try {
      await FlowService.createProjectFlow(flow);
      setState(() {
        _flows.add(flow);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Flow "${flow.title}" created successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save flow: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
