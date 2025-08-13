import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/dock_models.dart';
import '../../services/dock_service.dart';
import '../../config/theme_config.dart';
import '../settings_screen.dart';
import 'device_detail_screen.dart';
import 'macro_editor_screen.dart';

class DockScreen extends StatefulWidget {
  const DockScreen({super.key});

  @override
  State<DockScreen> createState() => _DockScreenState();
}

class _DockScreenState extends State<DockScreen> with TickerProviderStateMixin {
  List<ConnectedDevice> _devices = [];
  List<DockMacro> _macros = [];
  List<MacroExecution> _activeExecutions = [];
  bool _isLoading = true;
  bool _isMonitoring = false;

  late TabController _tabController;
  StreamSubscription<List<ConnectedDevice>>? _devicesSubscription;
  StreamSubscription<List<MacroExecution>>? _executionsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _devicesSubscription?.cancel();
    _executionsSubscription?.cancel();
    DockService.dispose();
    super.dispose();
  }

  Future<void> _initializeDock() async {
    setState(() => _isLoading = true);

    try {
      await DockService.initialize();

      // Load initial data
      await Future.wait([_loadDevices(), _loadMacros()]);

      // Set up real-time monitoring
      _setupRealTimeMonitoring();
    } catch (e) {
      _showSnackBar('Error initializing Dock: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await DockService.getConnectedDevices(forceRefresh: true);
      setState(() => _devices = devices);
    } catch (e) {
      _showSnackBar('Error loading devices: $e');
    }
  }

  Future<void> _loadMacros() async {
    try {
      final macros = await DockService.getMacros();
      setState(() => _macros = macros);
    } catch (e) {
      _showSnackBar('Error loading macros: $e');
    }
  }

  void _setupRealTimeMonitoring() {
    setState(() => _isMonitoring = true);

    _devicesSubscription = DockService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() => _devices = devices);
      }
    });

    _executionsSubscription = DockService.executionsStream.listen((executions) {
      if (mounted) {
        setState(() => _activeExecutions = executions);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.accentColor,
                    Colors.cyan.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.developer_board,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Dock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isMonitoring ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_devices.length} devices • ${_activeExecutions.length} active',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppTheme.textPrimaryColor,
            ),
            onPressed: _showAddDeviceDialog,
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
                case 'refresh':
                  _initializeDock();
                  break;
                case 'automation':
                  _showAutomationDialog();
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
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppTheme.textPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'automation',
                child: Row(
                  children: [
                    Icon(Icons.auto_mode, color: AppTheme.textPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Automation',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.devices), text: 'Devices'),
            Tab(icon: Icon(Icons.smart_button), text: 'Macros'),
            Tab(icon: Icon(Icons.timeline), text: 'Activity'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing Dock...',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDevicesTab(),
                _buildMacrosTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  Widget _buildDevicesTab() {
    if (_devices.isEmpty) {
      return _buildEmptyDevicesState();
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device) {
    final isOnline = device.isOnline;
    final status = device.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () => _navigateToDeviceDetail(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOnline
                            ? AppTheme.primaryColor.withValues(alpha: 0.3)
                            : AppTheme.textSecondaryColor.withValues(
                                alpha: 0.3,
                              ),
                      ),
                    ),
                    child: Icon(
                      _getDeviceIcon(device.type),
                      color: isOnline
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        Text(
                          '${device.platform} • ${device.type.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),

              if (isOnline) ...[
                const SizedBox(height: 16),
                // Resource Meters
                _buildResourceMeter('CPU', status.cpuUsage, Colors.blue),
                const SizedBox(height: 8),
                _buildResourceMeter(
                  'Memory',
                  status.memoryUsage,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildResourceMeter('Disk', status.diskUsage, Colors.purple),

                if (status.gpuUsage != null) ...[
                  const SizedBox(height: 8),
                  _buildResourceMeter('GPU', status.gpuUsage!, Colors.green),
                ],

                const SizedBox(height: 16),
                // Quick Actions
                Row(
                  children: [
                    _buildQuickAction(
                      Icons.power_settings_new,
                      'Restart',
                      () => _quickRestart(device.id),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickAction(
                      Icons.bedtime,
                      'Sleep',
                      () => _quickSleep(device.id),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickAction(
                      Icons.terminal,
                      'Terminal',
                      () => _openTerminal(device.id),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz,
                        color: AppTheme.textSecondaryColor,
                      ),
                      onPressed: () => _showDeviceOptions(device),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceMeter(String label, double percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${percentage.toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacrosTab() {
    if (_macros.isEmpty) {
      return _buildEmptyMacrosState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _macros.length,
      itemBuilder: (context, index) {
        final macro = _macros[index];
        return _buildMacroCard(macro);
      },
    );
  }

  Widget _buildMacroCard(DockMacro macro) {
    final isRunning = _activeExecutions.any((e) => e.macroId == macro.id);
    final execution = isRunning
        ? _activeExecutions.firstWhere((e) => e.macroId == macro.id)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: macro.isEnabled
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.smart_button,
                    color: macro.isEnabled
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        macro.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        macro.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isRunning) ...[
                  CircularProgressIndicator(
                    value: execution?.progress,
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMacroAction(value, macro),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'execute',
                      enabled: macro.isEnabled && !isRunning,
                      child: const Row(
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 8),
                          Text('Execute'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: macro.isEnabled ? 'disable' : 'enable',
                      child: Row(
                        children: [
                          Icon(
                            macro.isEnabled ? Icons.pause : Icons.play_arrow,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(macro.isEnabled ? 'Disable' : 'Enable'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${macro.steps.length} steps',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.device_hub,
                  size: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  macro.targetDeviceId == '*'
                      ? 'All devices'
                      : 'Specific device',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            if (isRunning && execution != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: execution.progress,
                backgroundColor: AppTheme.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Step ${execution.currentStepIndex + 1} of ${macro.steps.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activeExecutions.isEmpty) {
      return _buildEmptyActivityState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeExecutions.length,
      itemBuilder: (context, index) {
        final execution = _activeExecutions[index];
        return _buildExecutionCard(execution);
      },
    );
  }

  Widget _buildExecutionCard(MacroExecution execution) {
    final macro = _macros.firstWhere(
      (m) => m.id == execution.macroId,
      orElse: () => DockMacro(
        id: '',
        name: 'Unknown Macro',
        description: '',
        targetDeviceId: '',
        steps: [],
        isEnabled: false,
        createdAt: DateTime.now(),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      execution.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getStatusIcon(execution.status),
                    color: _getStatusColor(execution.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        macro.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        execution.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(execution.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (execution.status == ExecutionStatus.running) ...[
                  IconButton(
                    icon: const Icon(Icons.pause, size: 20),
                    onPressed: () => _pauseExecution(execution.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, size: 20),
                    onPressed: () => _cancelExecution(execution.id),
                  ),
                ] else if (execution.status == ExecutionStatus.paused) ...[
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    onPressed: () => _resumeExecution(execution.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, size: 20),
                    onPressed: () => _cancelExecution(execution.id),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: execution.progress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(execution.status),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${execution.currentStepIndex + 1} of ${macro.steps.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  _formatDuration(
                    DateTime.now().difference(execution.startTime),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Empty state builders
  Widget _buildEmptyDevicesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(Icons.devices, size: 60, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'No Devices Connected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect devices to monitor and control them remotely',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddDeviceDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMacrosState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.smart_button,
              size: 60,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Macros Created',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create automation macros to control your devices',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createMacro,
            icon: const Icon(Icons.add),
            label: const Text('Create Macro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(Icons.timeline, size: 60, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Executions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Macro executions will appear here when running',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.mobile:
        return Icons.smartphone;
      case DeviceType.tablet:
        return Icons.tablet;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.iot:
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getStatusColor(ExecutionStatus status) {
    switch (status) {
      case ExecutionStatus.running:
        return Colors.blue;
      case ExecutionStatus.completed:
        return Colors.green;
      case ExecutionStatus.failed:
        return Colors.red;
      case ExecutionStatus.paused:
        return Colors.orange;
      case ExecutionStatus.cancelled:
        return Colors.grey;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getStatusIcon(ExecutionStatus status) {
    switch (status) {
      case ExecutionStatus.running:
        return Icons.play_arrow;
      case ExecutionStatus.completed:
        return Icons.check_circle;
      case ExecutionStatus.failed:
        return Icons.error;
      case ExecutionStatus.paused:
        return Icons.pause;
      case ExecutionStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Action methods
  void _navigateToDeviceDetail(ConnectedDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailScreen(device: device),
      ),
    );
  }

  void _showAddDeviceDialog() {
    // TODO: Implement add device dialog
    _showSnackBar('Add device feature coming soon!');
  }

  void _showAutomationDialog() {
    // TODO: Implement automation rules dialog
    _showSnackBar('Automation rules feature coming soon!');
  }

  void _showDeviceOptions(ConnectedDevice device) {
    // TODO: Implement device options menu
    _showSnackBar('Device options feature coming soon!');
  }

  void _createMacro() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MacroEditorScreen()),
    ).then((result) {
      if (result == true) {
        _loadMacros();
      }
    });
  }

  void _handleMacroAction(String action, DockMacro macro) async {
    switch (action) {
      case 'execute':
        final execution = await DockService.executeMacro(macro.id);
        if (execution != null) {
          _showSnackBar('Macro "${macro.name}" started');
        } else {
          _showSnackBar('Failed to start macro');
        }
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MacroEditorScreen(macro: macro),
          ),
        ).then((result) {
          if (result == true) {
            _loadMacros();
          }
        });
        break;
      case 'enable':
      case 'disable':
        // TODO: Implement enable/disable macro
        _showSnackBar('${action.capitalize()} macro feature coming soon!');
        break;
      case 'delete':
        // TODO: Implement delete macro
        _showSnackBar('Delete macro feature coming soon!');
        break;
    }
  }

  Future<void> _quickRestart(String deviceId) async {
    final success = await DockService.quickRestart(deviceId);
    _showSnackBar(
      success ? 'Restart command sent' : 'Failed to restart device',
    );
  }

  Future<void> _quickSleep(String deviceId) async {
    final success = await DockService.quickSleep(deviceId);
    _showSnackBar(success ? 'Sleep command sent' : 'Failed to sleep device');
  }

  void _openTerminal(String deviceId) {
    // TODO: Implement remote terminal
    _showSnackBar('Remote terminal feature coming soon!');
  }

  Future<void> _pauseExecution(String executionId) async {
    final success = await DockService.pauseExecution(executionId);
    _showSnackBar(success ? 'Execution paused' : 'Failed to pause execution');
  }

  Future<void> _resumeExecution(String executionId) async {
    final success = await DockService.resumeExecution(executionId);
    _showSnackBar(success ? 'Execution resumed' : 'Failed to resume execution');
  }

  Future<void> _cancelExecution(String executionId) async {
    final success = await DockService.cancelExecution(executionId);
    _showSnackBar(
      success ? 'Execution cancelled' : 'Failed to cancel execution',
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
