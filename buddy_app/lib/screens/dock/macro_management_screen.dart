// MacroDroid-style Macro Management Screen
import 'package:flutter/material.dart';
import '../../models/macro_models.dart';
import '../../models/dock_models.dart' hide DeviceMacro;
import '../../services/macro_automation_service.dart';
import '../../services/dock_service.dart';
import 'macro_editor_screen.dart';
import 'macro_templates_screen.dart';

class MacroManagementScreen extends StatefulWidget {
  final Device? device;

  const MacroManagementScreen({super.key, this.device});

  @override
  State<MacroManagementScreen> createState() => _MacroManagementScreenState();
}

class _MacroManagementScreenState extends State<MacroManagementScreen>
    with TickerProviderStateMixin {
  final MacroAutomationService _macroService = MacroAutomationService();
  final DockService _dockService = DockService();

  late TabController _tabController;
  List<DeviceMacro> _macros = [];
  List<MacroExecution> _executions = [];
  List<Device> _devices = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeScreen();
    _setupListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([_loadMacros(), _loadDevices(), _loadExecutions()]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupListeners() {
    _macroService.macrosUpdated.listen((macros) {
      if (mounted) {
        setState(() => _macros = macros);
      }
    });

    _macroService.executionStatus.listen((execution) {
      if (mounted) {
        setState(() {
          final index = _executions.indexWhere((e) => e.id == execution.id);
          if (index != -1) {
            _executions[index] = execution;
          } else {
            _executions.insert(0, execution);
          }
        });
      }
    });
  }

  Future<void> _loadMacros() async {
    final macros = await _macroService.getAllMacros(
      deviceId: widget.device?.id,
    );
    setState(() => _macros = macros);
  }

  Future<void> _loadDevices() async {
    final devices = await _dockService.getDevices();
    setState(() => _devices = devices);
  }

  Future<void> _loadExecutions() async {
    final executions = _macroService.executions;
    setState(() => _executions = executions);
  }

  List<DeviceMacro> get _filteredMacros {
    if (_selectedCategory == 'all') return _macros;
    return _macros.where((m) => m.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device != null
              ? '${widget.device!.name} Macros'
              : 'Macro Automation',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _macroService.isRunning ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: _toggleAutomation,
            tooltip: _macroService.isRunning
                ? 'Stop Automation'
                : 'Start Automation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeScreen,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import_template',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Import Template'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_macros',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text('Export Macros'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Automation Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Macros', icon: Icon(Icons.settings_input_component)),
            Tab(text: 'Executions', icon: Icon(Icons.history)),
            Tab(text: 'Templates', icon: Icon(Icons.library_books)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMacrosTab(),
                _buildExecutionsTab(),
                _buildTemplatesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewMacro,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeScreen,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosTab() {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: _filteredMacros.isEmpty
              ? _buildEmptyMacrosState()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredMacros.length,
                  itemBuilder: (context, index) {
                    final macro = _filteredMacros[index];
                    return _buildMacroCard(macro);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['all', ...MacroCategories.all];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category == 'all'
                    ? 'All'
                    : MacroCategories.getDisplayName(category),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              avatar: category != 'all'
                  ? Icon(MacroCategories.getIcon(category), size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyMacrosState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_input_component,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No macros yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first automation macro',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _createNewMacro,
                icon: const Icon(Icons.add),
                label: const Text('Create Macro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showTemplates,
                icon: const Icon(Icons.library_books),
                label: const Text('Browse Templates'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(DeviceMacro macro) {
    final device = _devices.firstWhere(
      (d) => d.id == macro.deviceId,
      orElse: () => Device(
        id: macro.deviceId,
        name: 'Unknown Device',
        platform: 'unknown',
        ipAddress: '',
        port: 0,
        status: 'offline',
        lastSeen: DateTime.now().toIso8601String(),
        capabilities: {},
        metadata: {},
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: macro.enabled ? Colors.green : Colors.grey,
          child: Icon(
            MacroCategories.getIcon(macro.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          macro.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: macro.enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(macro.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.devices, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  device.name,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  macro.statusText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (macro.executionCount > 0) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${macro.executionCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'runs',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            Switch(
              value: macro.enabled,
              onChanged: (value) => _toggleMacroEnabled(macro, value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMacroSummary(macro),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: macro.enabled
                            ? () => _executeMacro(macro)
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editMacro(macro),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _deleteMacro(macro),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Icon(Icons.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSummary(DeviceMacro macro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Triggers
        if (macro.triggers.isNotEmpty) ...[
          const Text(
            'Triggers:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: macro.triggers.map((trigger) {
              return Chip(
                label: Text(trigger.name, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue[100],
                avatar: Icon(
                  _getTriggerIcon(trigger.type),
                  size: 16,
                  color: Colors.blue[700],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Conditions
        if (macro.conditions.isNotEmpty) ...[
          const Text(
            'Conditions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: macro.conditions.map((condition) {
              return Chip(
                label: Text(
                  condition.name,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange[100],
                avatar: Icon(
                  _getConditionIcon(condition.type),
                  size: 16,
                  color: Colors.orange[700],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Actions
        if (macro.actions.isNotEmpty) ...[
          const Text('Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: macro.actions.map((action) {
              return Chip(
                label: Text(action.name, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.green[100],
                avatar: Icon(
                  _getActionIcon(action.type),
                  size: 16,
                  color: Colors.green[700],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutionsTab() {
    if (_executions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No executions yet'),
            Text('Run some macros to see execution history'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _executions.length,
      itemBuilder: (context, index) {
        final execution = _executions[index];
        return _buildExecutionCard(execution);
      },
    );
  }

  Widget _buildExecutionCard(MacroExecution execution) {
    final macro = _macros.firstWhere(
      (m) => m.id == execution.macroId,
      orElse: () => DeviceMacro(
        id: execution.macroId,
        name: 'Unknown Macro',
        description: '',
        deviceId: execution.deviceId,
        triggers: [],
        conditions: [],
        actions: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    Color statusColor;
    IconData statusIcon;

    switch (execution.status) {
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.play_arrow;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: Colors.white, size: 20),
        ),
        title: Text(macro.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Triggered by: ${execution.triggerType.toString().split('.').last}',
            ),
            Text('Started: ${_formatDateTime(execution.startedAt)}'),
            if (execution.completedAt != null)
              Text('Duration: ${execution.executionDuration?.inSeconds}s'),
            if (execution.status == 'running')
              LinearProgressIndicator(
                value: execution.progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
          ],
        ),
        trailing: Text(
          '${execution.actionsCompleted}/${execution.totalActions}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        onTap: () => _showExecutionDetails(execution),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return MacroTemplatesScreen(onTemplateSelected: _createMacroFromTemplate);
  }

  // Event handlers
  void _toggleAutomation() {
    if (_macroService.isRunning) {
      _macroService.stopAutomation();
    } else {
      _macroService.startAutomation();
    }
    setState(() {});
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import_template':
        _showTemplates();
        break;
      case 'export_macros':
        _exportMacros();
        break;
      case 'settings':
        _showAutomationSettings();
        break;
    }
  }

  void _createNewMacro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MacroEditorScreen(device: widget.device, devices: _devices),
      ),
    ).then((_) => _loadMacros());
  }

  void _editMacro(DeviceMacro macro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroEditorScreen(
          device: widget.device,
          devices: _devices,
          macro: macro,
        ),
      ),
    ).then((_) => _loadMacros());
  }

  Future<void> _deleteMacro(DeviceMacro macro) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Macro'),
        content: Text('Are you sure you want to delete "${macro.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _macroService.deleteMacro(macro.id);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${macro.name}"')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete macro')));
      }
    }
  }

  Future<void> _toggleMacroEnabled(DeviceMacro macro, bool enabled) async {
    final success = await _macroService.toggleMacroEnabled(macro.id, enabled);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? 'Macro enabled' : 'Macro disabled')),
      );
    }
  }

  Future<void> _executeMacro(DeviceMacro macro) async {
    final execution = await _macroService.executeMacro(macro.id);
    if (execution != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Executing "${macro.name}"')));
      _tabController.animateTo(1); // Switch to executions tab
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to execute macro')));
    }
  }

  void _showTemplates() {
    _tabController.animateTo(2);
  }

  void _createMacroFromTemplate(MacroTemplate template) {
    // Implementation for creating macro from template
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroEditorScreen(
          device: widget.device,
          devices: _devices,
          template: template,
        ),
      ),
    ).then((_) => _loadMacros());
  }

  void _exportMacros() {
    // Implementation for exporting macros
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _showAutomationSettings() {
    // Implementation for automation settings
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Automation Settings'),
        content: const Text('Settings panel coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExecutionDetails(MacroExecution execution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Execution Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${execution.status}'),
              Text('Started: ${_formatDateTime(execution.startedAt)}'),
              if (execution.completedAt != null)
                Text('Completed: ${_formatDateTime(execution.completedAt!)}'),
              if (execution.errorMessage != null)
                Text('Error: ${execution.errorMessage}'),
              const SizedBox(height: 16),
              const Text(
                'Execution Log:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...execution.executionLog.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${log['timestamp']}: ${log['action_name']} - ${log['status']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getTriggerIcon(TriggerType type) {
    switch (type) {
      case TriggerType.time:
        return Icons.schedule;
      case TriggerType.location:
        return Icons.location_on;
      case TriggerType.deviceState:
        return Icons.devices;
      case TriggerType.network:
        return Icons.wifi;
      case TriggerType.battery:
        return Icons.battery_std;
      case TriggerType.appLaunch:
        return Icons.launch;
      case TriggerType.notification:
        return Icons.notifications;
      case TriggerType.webhook:
        return Icons.webhook;
      default:
        return Icons.play_arrow;
    }
  }

  IconData _getConditionIcon(ConditionType type) {
    switch (type) {
      case ConditionType.timeRange:
        return Icons.access_time;
      case ConditionType.location:
        return Icons.location_on;
      case ConditionType.deviceState:
        return Icons.devices;
      case ConditionType.networkStatus:
        return Icons.network_check;
      case ConditionType.batteryLevel:
        return Icons.battery_alert;
      default:
        return Icons.help;
    }
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.systemAction:
        return Icons.computer;
      case ActionType.notification:
        return Icons.notification_add;
      case ActionType.deviceControl:
        return Icons.settings_remote;
      case ActionType.appControl:
        return Icons.apps;
      case ActionType.fileOperation:
        return Icons.folder;
      case ActionType.wait:
        return Icons.timer;
      default:
        return Icons.play_arrow;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
