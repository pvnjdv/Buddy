import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../models/code_editor_models.dart';
import '../../services/flow_service.dart';
import '../../services/code_editor_service.dart';
import '../../config/settings/theme_config.dart';
import '../settings/settings_screen.dart';
import '../code_editor/buddy_editor_screen.dart';
import '../code_editor/project_templates_screen.dart';
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
  List<CodeProject> _codeProjects = [];
  bool _isLoading = true;
  late TabController _tabController;
  final CodeEditorService _codeEditorService = CodeEditorService();

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
      // For now, use empty list for code projects since the method doesn't exist yet
      final projects = <CodeProject>[];

      setState(() {
        _flows = flows;
        _codeProjects = projects;
        _isLoading = false;
      });
    } catch (e) {
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
          _buildCodeEditorTab(),
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

  Widget _buildCodeEditorTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code Editor Header
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
                        'Buddy Code Editor',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create, edit, and manage projects with real-time VS Code sync',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openCodeEditor(),
                  icon: const Icon(Icons.launch),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Recent Projects
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Projects',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => _createNewProject(),
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Projects Grid
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : _codeProjects.isEmpty
                ? _buildEmptyCodeProjectsState()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _codeProjects.length,
                    itemBuilder: (context, index) {
                      final project = _codeProjects[index];
                      return _buildProjectCard(project);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCodeProjectsState() {
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
            child: Icon(Icons.code_off, size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'No Projects Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first project to start coding',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewProject(),
            icon: const Icon(Icons.add),
            label: const Text('Create Project'),
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

  Widget _buildProjectCard(CodeProject project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData getProjectIcon(String type) {
      switch (type.toLowerCase()) {
        case 'flutter':
          return Icons.flutter_dash;
        case 'python':
          return Icons.code;
        case 'nodejs':
          return Icons.javascript;
        case 'android':
          return Icons.android;
        default:
          return Icons.folder_open;
      }
    }

    Color getProjectColor(String type) {
      switch (type.toLowerCase()) {
        case 'flutter':
          return Colors.blue;
        case 'python':
          return Colors.green;
        case 'nodejs':
          return Colors.yellow;
        case 'android':
          return Colors.green;
        default:
          return AppTheme.primaryColor;
      }
    }

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
        onTap: () => _openProjectInEditor(project),
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
                      color: getProjectColor(
                        project.type,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getProjectIcon(project.type),
                      color: getProjectColor(project.type),
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleProjectAction(value, project),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                      const PopupMenuItem(value: 'build', child: Text('Build')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                project.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'No description available',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.folder,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.type.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: getProjectColor(project.type),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.work, color: AppTheme.primaryColor),
            ),
            title: Text(
              flow.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              flow.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleFlowAction(value, flow),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'open', child: Text('Open')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              child: Icon(
                Icons.more_vert,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FlowDetailScreen(flow: flow),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create New',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2,
              children: [
                _buildCreateOption(
                  icon: Icons.code,
                  title: 'Code Project',
                  onTap: () {
                    Navigator.pop(context);
                    _createNewProject();
                  },
                ),
                _buildCreateOption(
                  icon: Icons.work,
                  title: 'Project Flow',
                  onTap: () {
                    Navigator.pop(context);
                    _createFlow();
                  },
                ),
                _buildCreateOption(
                  icon: Icons.note_add,
                  title: 'Note',
                  onTap: () {
                    Navigator.pop(context);
                    _createNote();
                  },
                ),
                _buildCreateOption(
                  icon: Icons.alarm_add,
                  title: 'Alarm',
                  onTap: () {
                    Navigator.pop(context);
                    _createAlarm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 4 : 2,
      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Action methods
  void _openCodeEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BuddyEditorScreen()),
    );
  }

  void _createNewProject() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProjectTemplatesScreen()),
    ).then((_) => _loadAllData());
  }

  void _openProjectInEditor(CodeProject project) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BuddyEditorScreen()),
    );
  }

  void _handleProjectAction(String action, CodeProject project) async {
    switch (action) {
      case 'open':
        _openProjectInEditor(project);
        break;
      case 'build':
        await _codeEditorService.buildProject(project);
        break;
      case 'delete':
        _deleteCodeProject(project);
        break;
    }
  }

  Future<void> _deleteCodeProject(CodeProject project) async {
    // Show confirmation dialog
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Project'),
              content: Text(
                'Are you sure you want to delete "${project.name}"?\n\n'
                'This will permanently delete:\n'
                '• Project files and folders\n'
                '• All associated data\n'
                '• Notes and documentation\n'
                '• Flow configurations\n\n'
                'This action cannot be undone.',
              ),
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
              Text('Deleting project "${project.name}"...'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Delete from backend service
      await FlowService.deleteProjectFlow(project.id);

      // Remove from local list
      setState(() {
        _codeProjects.removeWhere((p) => p.id == project.id);
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project "${project.name}" deleted successfully'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _restoreCodeProject(project),
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete project: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _deleteCodeProject(project),
          ),
        ),
      );
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

  Future<void> _restoreCodeProject(CodeProject project) async {
    try {
      // For code projects, restoration would need to recreate the project
      // This is a simplified version - in reality, you'd need proper backup/restore

      // Reload data to refresh the list
      await _loadAllData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attempting to restore project "${project.name}"...'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore project: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createFlow() {
    // Navigate to create flow screen (existing functionality)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create flow functionality coming soon')),
    );
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
      case 1: // Code Editor tab
        _createNewProject();
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
      case 1: // Code Editor tab
        return 'New Project';
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
