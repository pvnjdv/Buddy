import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../models/collaboration_models.dart';
import '../../services/flow_service.dart';
import '../../services/ai/chat_service.dart';
import '../../config/settings/theme_config.dart';
import '../settings/settings_screen.dart';
import '../buddy_code_editor/editor_selector.dart';
import 'flows/flow_detail_screen.dart';
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

  Future<void> _refreshData() async {
    await _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Flow',
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
            Tab(text: 'Code', icon: Icon(Icons.code)),
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
          _buildVSCodeTab(),
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

  Widget _buildFlowsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildProjectFlows()],
      ),
    );
  }

  Widget _buildVSCodeTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VS Code Integration Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                        AppTheme.accentColor.withValues(alpha: 0.2),
                      ]
                    : [
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                        AppTheme.accentColor.withValues(alpha: 0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.code,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VS Code Integration',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open your project flows in VS Code with seamless sync across devices',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openVSCode(),
                  icon: const Icon(Icons.launch),
                  label: const Text('Open VS Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
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
              Text(
                'Open in VS Code',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => _createNewVSCodeProject(),
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
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
                        AppTheme.primaryColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.code, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'No Project Flows Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a project flow to open in VS Code',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewVSCodeProject(),
            icon: const Icon(Icons.add),
            label: const Text('Create Project Flow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVSCodeFlowCard(ProjectFlow flow) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      return AppTheme.primaryColor;
    }

    final completedCheckpoints = flow.checkpoints
        .where((c) => c.isCompleted)
        .length;
    final progressPercentage = flow.checkpoints.isEmpty
        ? 0.0
        : completedCheckpoints / flow.checkpoints.length;

    return Card(
      elevation: isDark ? 8 : 4,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                flow.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                ),
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
                      backgroundColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getFlowColor(flow.tags),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progressPercentage * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_flows.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.work_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _flows.length,
      itemBuilder: (context, index) {
        final flow = _flows[index];
        return _buildEnhancedFlowCard(flow, isDark);
      },
    );
  }

  Widget _buildEnhancedFlowCard(ProjectFlow flow, bool isDark) {
    final theme = Theme.of(context);
    final isCollaborative = flow.collaboration != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCollaborative
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: isCollaborative ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Icon(
                          Icons.work,
                          color: AppTheme.primaryColor,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flow.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
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

  // Contextual action methods for old-style floating action button
  void _getContextualAction() {
    switch (_tabController.index) {
      case 0: // Flows tab
        _showQuickActions();
        break;
      case 1: // VS Code tab
        _createNewVSCodeProject();
        break;
      case 2: // Notes tab
        _createNote();
        break;
      case 3: // Alarms tab
        _createAlarm();
        break;
    }
  }

  IconData _getContextualIcon() {
    switch (_tabController.index) {
      case 0: // Flows tab
        return Icons.add;
      case 1: // Code Editor tab
        return Icons.code;
      case 2: // Notes tab
        return Icons.note_add;
      case 3: // Alarms tab
        return Icons.alarm_add;
      default:
        return Icons.add;
    }
  }

  String _getContextualLabel() {
    switch (_tabController.index) {
      case 0: // Flows tab
        return 'Quick Actions';
      case 1: // VS Code tab
        return 'Open VS Code';
      case 2: // Notes tab
        return 'Add Note';
      case 3: // Alarms tab
        return 'Add Alarm';
      default:
        return 'Add';
    }
  }

  // Additional methods for old-style menu functionality
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
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
