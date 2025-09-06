// lib/screens/dock/dock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/dock_models.dart';
import '../../services/dock_service.dart';
import '../../services/device_discovery_service.dart';
import '../../services/auth_service.dart';
import '../../services/system_metrics_service.dart';
import '../../widgets/dock_widgets.dart';
import 'device_detail_screen.dart';
import 'remote_control_screen.dart';
import 'buddy_terminal_screen.dart';
import '../code_editor/buddy_code_editor_screen.dart';
import 'macro_management_screen.dart';

// Terminal Block Model for Warp-like terminal blocks
enum TerminalBlockType { welcome, info, command, output, error }

class TerminalBlock {
  final TerminalBlockType type;
  final String content;
  final DateTime timestamp;
  final String deviceName;
  final String? directory;
  final bool isSuccess;
  final Duration? duration;

  TerminalBlock({
    required this.type,
    required this.content,
    required this.timestamp,
    required this.deviceName,
    this.directory,
    this.isSuccess = true,
    this.duration,
  });
}

class DockScreen extends StatefulWidget {
  const DockScreen({super.key});

  @override
  State<DockScreen> createState() => _DockScreenState();
}

class _DockScreenState extends State<DockScreen> with TickerProviderStateMixin {
  final DockService _dockService = DockService();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final SystemMetricsService _metricsService = SystemMetricsService();
  late TabController _tabController;

  // Device and Macro Management
  List<Device> _devices = [];
  List<DeviceMacro> _macros = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeServices();
  }

  // Initialize auto-discovery and services
  Future<void> _initializeServices() async {
    // Check if user is logged in first
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      print('❌ User not logged in, cannot initialize dock services');
      return;
    }

    // Start auto-discovery service only if user is logged in
    final userId = await AuthService.getMobileNumber() ?? "unknown_user";
    await _discoveryService.autoRegisterOnLogin(userId);

    // Listen to discovered devices
    _discoveryService.discoveredDevicesStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    // Load initial data and connect WebSocket
    _loadData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dockService.dispose();
    _discoveryService.stopAutoDiscovery();
    _metricsService.removeListener(_onMetricsUpdate);
    _metricsService.stopMetricsUpdates();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _dockService.getUserDevices();
      final macros = await _dockService.getUserMacros();

      setState(() {
        // Handle response format from updated backend
        if (response['devices'] != null) {
          _devices = (response['devices'] as List)
              .map((device) => Device.fromJson(device))
              .toList();

          // Start system metrics updates for loaded devices
          _metricsService.startMetricsUpdates(_devices);

          // Listen to metrics updates and refresh UI
          _metricsService.addListener(_onMetricsUpdate);
        }
        _macros = macros;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    final deviceId = _discoveryService.currentDeviceId;
    if (deviceId != null) {
      _dockService.connectWebSocket(deviceId);
      _dockService.webSocketStream.listen((message) {
        // Handle real-time updates
        switch (message['type']) {
          case 'device_status_update':
            _updateDeviceStatus(message['data']);
            break;
          case 'command_completed':
            _showCommandResult(message['data']);
            break;
        }
      });
    } else {
      print('❌ Cannot connect WebSocket: Device ID not available');
    }
  }

  void _updateDeviceStatus(Map<String, dynamic> data) {
    final deviceId = data['device_id'];

    setState(() {
      final index = _devices.indexWhere((d) => d.id == deviceId);
      if (index != -1) {
        // Update device status
        // Note: This would require updating the Device model or creating a new instance
        _loadData(); // For now, reload all data
      }
    });
  }

  void _showCommandResult(Map<String, dynamic> data) {
    final success = data['status'] == 'completed';
    final message = data['result'] ?? data['error'] ?? 'Command executed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _onMetricsUpdate() {
    // Update devices with current system metrics
    setState(() {
      _devices = _devices.map((device) {
        final metrics = _metricsService.getMetrics(device.id);
        return device.copyWith(systemMetrics: metrics);
      }).toList();
    });
  }

  void _showMetricsDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Metrics Debug'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Test system monitoring features:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.speed, color: Colors.orange),
                title: const Text('Simulate High CPU'),
                subtitle: const Text('Test device under high load'),
                onTap: () {
                  if (_devices.isNotEmpty) {
                    _metricsService.simulateHighCpuUsage(_devices.first.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulated high CPU usage')),
                    );
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.battery_alert, color: Colors.red),
                title: const Text('Simulate Low Battery'),
                subtitle: const Text('Test battery warning indicators'),
                onTap: () {
                  if (_devices.isNotEmpty) {
                    _metricsService.simulateLowBattery(_devices.first.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulated low battery')),
                    );
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.blue),
                title: const Text('Reset Metrics'),
                subtitle: const Text('Return to normal simulation'),
                onTap: () {
                  _metricsService.startMetricsUpdates(_devices);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset system metrics')),
                  );
                },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Dock'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.devices), text: 'Devices'),
            Tab(icon: Icon(Icons.terminal), text: 'Commands'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Macros'),
            Tab(icon: Icon(Icons.computer), text: 'Terminal'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDevicesTab(),
                _buildCommandsTab(),
                _buildMacrosTab(),
                _buildTerminalTab(),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "code_editor",
            onPressed: _openBuddyCodeEditor,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.code, color: Colors.white),
            tooltip: 'Buddy Code Editor',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: "devices",
            onPressed: _showDeviceActions,
            icon: const Icon(Icons.devices),
            label: const Text('Devices'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Column(
      children: [
        // Devices list
        Expanded(
          child: _devices.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.devices, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No devices connected'),
                      SizedBox(height: 8),
                      Text(
                        'Use the Device button to add or discover devices',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return DeviceCard(
                        device: device,
                        onTap: () => _showDeviceDetails(device),
                        onCommand: () => _showCommandDialog(device),
                        onRemove: () => _removeDevice(device),
                      );
                      // TODO: Add onRemote when DeviceCard supports it
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommandsTab() {
    return Column(
      children: [
        // Enhanced Command Interface
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Command Center',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick Commands',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickCommandChip('System Info', Icons.info, () {
                        _executeQuickCommand('system_info');
                      }),
                      _buildQuickCommandChip('Memory Usage', Icons.memory, () {
                        _executeQuickCommand('memory');
                      }),
                      _buildQuickCommandChip('List Processes', Icons.list, () {
                        _executeQuickCommand('ps');
                      }),
                      _buildQuickCommandChip('Disk Usage', Icons.storage, () {
                        _executeQuickCommand('disk');
                      }),
                      _buildQuickCommandChip(
                        'Network Info',
                        Icons.network_check,
                        () {
                          _executeQuickCommand('network');
                        },
                      ),
                      _buildQuickCommandChip('CPU Info', Icons.computer, () {
                        _executeQuickCommand('system_info');
                      }),
                      _buildQuickCommandChip(
                        'Running Services',
                        Icons.settings,
                        () {
                          _executeQuickCommand('ps');
                        },
                      ),
                      _buildQuickCommandChip('Uptime', Icons.schedule, () {
                        _executeQuickCommand('system_info');
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showBulkCommandDialog(),
                          icon: const Icon(Icons.send),
                          label: const Text('Send Command to All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showCommandHistoryDialog(),
                        icon: const Icon(Icons.history),
                        label: const Text('History'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Device Command Interface
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return Card(
                child: ExpansionTile(
                  leading: Icon(
                    _getPlatformIcon(device.platform),
                    color: device.isOnline ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  title: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${device.platform} • ${device.displayStatus}'),
                      Text(
                        'IP: ${device.ipAddress}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Device Capabilities
                          if (device.capabilities.isNotEmpty) ...[
                            Text(
                              'Available Commands:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: device.capabilities.entries
                                  .where((e) => e.value == true)
                                  .map(
                                    (capability) => Chip(
                                      label: Text(
                                        capability.key.replaceAll('_', ' '),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      backgroundColor: Colors.blue.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: device.isOnline
                                      ? () => _showCommandDialog(device)
                                      : null,
                                  icon: const Icon(Icons.terminal),
                                  label: const Text('Open Terminal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: device.isOnline
                                      ? () => _showRemoteControlDialog(device)
                                      : null,
                                  icon: const Icon(Icons.control_camera),
                                  label: const Text('Remote Control'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Automation Macros',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Manage'),
                onPressed: _openMacroManagement,
              ),
            ],
          ),
        ),
        Expanded(
          child: _macros.isEmpty
              ? Center(
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
                        'MacroDroid-style Automation',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create powerful automation macros with triggers, conditions, and actions',
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Time-based triggers'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.green[600],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Location-based triggers'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.devices,
                                        color: Colors.orange[600],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Device state triggers'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.play_arrow,
                                        color: Colors.purple[600],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Powerful automation actions'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _openMacroManagement,
                                icon: const Icon(Icons.add),
                                label: const Text('Get Started'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _createSampleMacro,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Try Sample'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _macros.length,
                  itemBuilder: (context, index) {
                    final macro = _macros[index];
                    return MacroCard(
                      macro: macro,
                      onExecute: () => _executeMacro(macro),
                      onEdit: () => _editMacro(macro),
                      onDelete: () => _deleteMacro(macro),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTerminalTab() {
    return _InlineTerminalWidget(
      devices: _devices,
      onCommand: _executeTerminalCommand,
      onDeviceSelect: _selectTerminalDevice,
    );
  }

  Widget _buildQuickCommandChip(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.desktop_mac;
      case 'linux':
        return Icons.computer;
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.device_unknown;
    }
  }

  void _showDeviceActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Management',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Auto Register Current Device
            ListTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Register This Device'),
              subtitle: const Text('Add current device automatically'),
              onTap: () {
                Navigator.pop(context);
                _autoRegisterCurrentDevice();
              },
            ),

            // Network Discovery
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('Discover Network Devices'),
              subtitle: const Text('Scan network for available devices'),
              onTap: () {
                Navigator.pop(context);
                _startNetworkDiscovery();
              },
            ),

            // Manual Add Device
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add Device Manually'),
              subtitle: const Text('Enter device details manually'),
              onTap: () {
                Navigator.pop(context);
                _showManualAddDeviceDialog();
              },
            ),

            // Remote Access
            ListTile(
              leading: const Icon(Icons.desktop_access_disabled),
              title: const Text('Remote Access'),
              subtitle: const Text('Connect to remote devices'),
              onTap: () {
                Navigator.pop(context);
                _showRemoteAccessDialog();
              },
            ),

            // Terminal Access
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('Terminal Access'),
              subtitle: const Text('Open terminal on devices'),
              onTap: () {
                Navigator.pop(context);
                _showTerminalAccessDialog();
              },
            ),

            // Code Editor
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Buddy Code Editor'),
              subtitle: const Text('Cross-platform development environment'),
              onTap: () {
                Navigator.pop(context);
                _openBuddyCodeEditor();
              },
            ),

            // Debug System Metrics
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Debug System Metrics'),
              subtitle: const Text('Test system monitoring features'),
              onTap: () {
                Navigator.pop(context);
                _showMetricsDebugDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Auto register current device
  Future<void> _autoRegisterCurrentDevice() async {
    try {
      setState(() => _isLoading = true);
      await _dockService.autoRegisterDevice();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device registered successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Start network discovery
  Future<void> _startNetworkDiscovery() async {
    try {
      setState(() => _isLoading = true);
      _discoveryService.refreshDiscovery();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning network for devices...')),
      );
      // Auto-refresh after a delay
      await Future.delayed(const Duration(seconds: 3));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network scan failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Show manual add device dialog
  void _showManualAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDeviceDialog(
        onAdd: (request) async {
          try {
            await _dockService.registerDevice(request);
            _loadData();
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device added successfully')),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error adding device: $e')));
          }
        },
      ),
    );
  }

  // Show remote access options
  void _showRemoteAccessDialog() {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices available for remote access')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remote Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a device for remote access:'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    leading: Icon(
                      device.isOnline ? Icons.circle : Icons.circle_outlined,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                    title: Text(device.name),
                    subtitle: Text('${device.platform} • ${device.deviceType}'),
                    onTap: device.isOnline
                        ? () {
                            Navigator.pop(context);
                            _initiateRemoteAccess(device);
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Initiate remote access to a device
  void _initiateRemoteAccess(Device device) {
    // We need to find the current device from the registered devices
    final currentDevice = _devices.firstWhere(
      (d) =>
          d.name.contains('current') ||
          d.id.contains(_discoveryService.currentDeviceId ?? ''),
      orElse: () => _devices.first, // fallback to first device
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemoteControlScreen(
          targetDevice: device,
          currentDevice: currentDevice,
        ),
      ),
    );
  }

  void _showDeviceDetails(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailScreen(device: device),
      ),
    );
  }

  void _openMacroManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MacroManagementScreen(device: null),
      ),
    );
  }

  void _createSampleMacro() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sample Macro'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will create a sample automation macro:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Trigger: Daily at 9:00 AM'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.notification_add, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Action: Show notification'),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'This demonstrates MacroDroid-like automation capabilities.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openMacroManagement();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Visit the Macro Management screen to create powerful automations!',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCommandDialog(Device device) {
    showDialog(
      context: context,
      builder: (context) => CommandDialog(
        device: device,
        onExecute: (request) async {
          try {
            final command = await _dockService.executeCommand(request);
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Command queued: ${command.id}')),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error executing command: $e')),
            );
          }
        },
      ),
    );
  }

  void _removeDevice(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Remove ${device.name} from dock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dockService.removeDevice(device.id);
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device removed')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing device: $e')));
      }
    }
  }

  void _executeMacro(DeviceMacro macro) async {
    try {
      await _dockService.executeMacro(macro.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Executing macro: ${macro.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error executing macro: $e')));
    }
  }

  void _editMacro(DeviceMacro macro) {
    // Implementation for editing macros
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Macro editing coming soon')));
  }

  void _deleteMacro(DeviceMacro macro) {
    // Implementation for deleting macros
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Macro deletion coming soon')));
  }

  // Open remote control for a device
  void _openRemoteControl(Device device) {
    if (device.status != 'online') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${device.name} is not online. Cannot establish remote control.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RemoteControlScreen(
          targetDevice: device,
          currentDevice: _getCurrentDevice(),
        ),
      ),
    );
  }

  // Get current device info
  Device _getCurrentDevice() {
    // Return a basic current device representation
    return Device(
      id: 'current_device',
      name: 'This Device',
      platform: 'Flutter',
      ipAddress: '127.0.0.1',
      port: 0,
      status: 'online',
      lastSeen: DateTime.now().toIso8601String(),
      capabilities: {},
      metadata: {'device_type': 'mobile'},
      deviceType: 'mobile',
    );
  }

  void _showBulkCommandDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Command to All Devices'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will execute the command on all online devices.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'Enter command to execute...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (command) {
                  if (command.isNotEmpty) {
                    Navigator.of(context).pop();
                    _executeBulkCommand(command);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCommandHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Command History'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<DeviceCommand>>(
            future: _dockService.getCommandHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final commands = snapshot.data ?? [];
              if (commands.isEmpty) {
                return const Center(child: Text('No command history'));
              }

              return ListView.builder(
                itemCount: commands.length,
                itemBuilder: (context, index) {
                  final command = commands[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        command.command,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      subtitle: Text(
                        '${command.status} • ${command.commandType}',
                      ),
                      trailing: Icon(
                        command.isCompleted
                            ? Icons.check_circle
                            : command.isFailed
                            ? Icons.error
                            : command.isRunning
                            ? Icons.hourglass_empty
                            : Icons.pending,
                        color: command.isCompleted
                            ? Colors.green
                            : command.isFailed
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRemoteControlDialog(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remote Control - ${device.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Control ${device.name} remotely'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (device.capabilities['screen_share'] == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _startScreenShare(device);
                      },
                      icon: const Icon(Icons.screen_share),
                      label: const Text('Screen Share'),
                    ),
                  if (device.capabilities['file_transfer'] == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openFileTransfer(device);
                      },
                      icon: const Icon(Icons.file_copy),
                      label: const Text('File Transfer'),
                    ),
                  if (device.capabilities['input_control'] == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openRemoteControl(device);
                      },
                      icon: const Icon(Icons.mouse),
                      label: const Text('Mouse/Keyboard'),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _executeBulkCommand(String command) async {
    final onlineDevices = _devices.where((d) => d.isOnline).toList();

    if (onlineDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No online devices available')),
      );
      return;
    }

    for (final device in onlineDevices) {
      try {
        final request = CommandRequest(
          deviceId: device.id,
          commandType: 'system',
          command: command,
        );
        await _dockService.executeCommand(request);
      } catch (e) {
        print('Error executing command on ${device.name}: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Command sent to ${onlineDevices.length} devices'),
      ),
    );
  }

  void _startScreenShare(Device device) {
    // Navigate to screen share screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Screen sharing feature coming soon')),
    );
  }

  void _openFileTransfer(Device device) {
    // Navigate to file transfer screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File transfer feature coming soon')),
    );
  }

  // Show terminal access options
  void _showTerminalAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminal Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Local Terminal
            ListTile(
              leading: const Icon(Icons.computer, color: Colors.blue),
              title: const Text('Local Terminal'),
              subtitle: const Text('Open terminal on this device'),
              onTap: () {
                Navigator.pop(context);
                _openLocalTerminal();
              },
            ),

            const Divider(),

            // Remote Device Terminals
            if (_devices.isNotEmpty) ...[
              const Text('Remote Devices:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      leading: Icon(
                        device.isOnline ? Icons.circle : Icons.circle_outlined,
                        color: device.isOnline ? Colors.green : Colors.grey,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.platform} • ${device.deviceType}',
                      ),
                      onTap: device.isOnline
                          ? () {
                              Navigator.pop(context);
                              _openRemoteTerminal(device);
                            }
                          : null,
                    );
                  },
                ),
              ),
            ] else ...[
              const Text(
                'No devices available for remote terminal access',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Open local terminal
  void _openLocalTerminal() {
    // Create a local device representation
    final localDevice = Device(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Local Device',
      platform: 'Local',
      deviceType: 'desktop',
      isOnlineFlag: true,
      ipAddress: '127.0.0.1',
      port: 0,
      capabilities: {},
      metadata: {},
      status: 'online',
      lastSeen: DateTime.now().toIso8601String(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BuddyTerminalScreen(device: localDevice, isLocalTerminal: true),
      ),
    );
  }

  // Open remote terminal
  void _openRemoteTerminal(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BuddyTerminalScreen(device: device, isLocalTerminal: false),
      ),
    );
  }

  // Open Buddy Code Editor
  void _openBuddyCodeEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BuddyCodeEditorScreen(isStandalone: true),
      ),
    );
  }

  void _executeTerminalCommand(String command, Device? device) async {
    if (device == null) return;

    final request = CommandRequest(
      deviceId: device.id,
      commandType: 'terminal',
      command: command,
    );

    try {
      await _dockService.executeCommand(request);
    } catch (e) {
      print('Terminal command error: $e');
    }
  }

  void _selectTerminalDevice(Device device) {
    // Device selection logic can be handled by the inline terminal widget
  }

  void _executeQuickCommand(String commandType) {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices available. Please add a device first.'),
        ),
      );
      return;
    }

    final device = _devices.firstWhere(
      (d) => d.isOnline,
      orElse: () => _devices.first,
    );

    String command = '';
    switch (commandType) {
      case 'system_info':
        command = _getSystemInfoCommand(device.platform);
        break;
      case 'ps':
        command = device.platform.toLowerCase().contains('windows')
            ? 'tasklist'
            : 'ps aux';
        break;
      case 'network':
        command = device.platform.toLowerCase().contains('windows')
            ? 'ipconfig'
            : 'ifconfig';
        break;
      case 'disk':
        command = device.platform.toLowerCase().contains('windows')
            ? 'dir'
            : 'df -h';
        break;
      case 'memory':
        command = device.platform.toLowerCase().contains('windows')
            ? 'systeminfo | findstr Memory'
            : 'free -h';
        break;
    }

    if (command.isNotEmpty) {
      final request = CommandRequest(
        deviceId: device.id,
        commandType: 'terminal',
        command: command,
      );

      _dockService
          .executeCommand(request)
          .then((result) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Command executed: $command'),
                backgroundColor: Colors.green,
              ),
            );
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Command failed: $error'),
                backgroundColor: Colors.red,
              ),
            );
          });
    }
  }

  String _getSystemInfoCommand(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'systeminfo';
      case 'macos':
        return 'system_profiler SPSoftwareDataType';
      case 'linux':
        return 'uname -a && lsb_release -a';
      default:
        return 'uname -a';
    }
  }
}

// Inline Terminal Widget that provides full terminal functionality within the tab
class _InlineTerminalWidget extends StatefulWidget {
  final List<Device> devices;
  final Function(String, Device?) onCommand;
  final Function(Device) onDeviceSelect;

  const _InlineTerminalWidget({
    required this.devices,
    required this.onCommand,
    required this.onDeviceSelect,
  });

  @override
  State<_InlineTerminalWidget> createState() => _InlineTerminalWidgetState();
}

class _InlineTerminalWidgetState extends State<_InlineTerminalWidget>
    with TickerProviderStateMixin {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commandFocusNode = FocusNode();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  Device? _selectedDevice;
  List<TerminalBlock> _terminalBlocks = [];
  List<String> _commandHistory = [];
  List<String> _suggestions = [];
  int _historyIndex = -1;
  String _currentDirectory = '~';
  String _currentTheme = 'dark';
  bool _isExecuting = false;
  bool _showSuggestions = false;
  int _selectedSuggestionIndex = -1;

  // Warp-like features
  final List<String> _pinnedCommands = ['ls -la', 'ps aux', 'df -h', 'top'];
  bool _showCommandPalette = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.devices.isNotEmpty ? widget.devices.first : null;

    // Initialize cursor blink animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_blinkController);
    _blinkController.repeat(reverse: true);

    _initializeTerminal();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _commandFocusNode.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _initializeTerminal() {
    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.welcome,
        content: '🚀 Buddy Terminal v2.0 (Warp-inspired)',
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
      ),
    );

    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.info,
        content: 'Enhanced with AI suggestions, workflows, and modern features',
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
      ),
    );

    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.info,
        content:
            'Type "help" for commands • Ctrl+K for command palette • Tab for suggestions',
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
      ),
    );
  }

  void _addTerminalBlock(TerminalBlock block) {
    setState(() {
      _terminalBlocks.add(block);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;

    final commandBlock = TerminalBlock(
      type: TerminalBlockType.command,
      content: command,
      timestamp: DateTime.now(),
      deviceName: _selectedDevice?.name ?? 'local',
      directory: _currentDirectory,
    );

    _addTerminalBlock(commandBlock);

    // Add to command history
    if (_commandHistory.isEmpty || _commandHistory.last != command) {
      _commandHistory.add(command);
      if (_commandHistory.length > 100) _commandHistory.removeAt(0);
    }
    _historyIndex = -1;

    setState(() {
      _isExecuting = true;
    });

    // Handle built-in commands or execute on device
    if (_handleBuiltInCommand(command.trim())) {
      setState(() {
        _isExecuting = false;
      });
    } else {
      _executeOnDevice(command);
    }

    _updateSuggestions('');
  }

  bool _handleBuiltInCommand(String command) {
    final parts = command.split(' ');
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'help':
        _addTerminalBlock(
          TerminalBlock(
            type: TerminalBlockType.output,
            content: _getHelpContent(),
            timestamp: DateTime.now(),
            deviceName: _selectedDevice?.name ?? 'local',
            isSuccess: true,
          ),
        );
        return true;

      case 'clear':
        setState(() {
          _terminalBlocks.clear();
        });
        _initializeTerminal();
        return true;

      case 'theme':
        if (parts.length > 1) {
          _changeTheme(parts[1]);
        } else {
          _addTerminalBlock(
            TerminalBlock(
              type: TerminalBlockType.output,
              content: 'Available themes: dark, light, matrix, ocean, sunset',
              timestamp: DateTime.now(),
              deviceName: _selectedDevice?.name ?? 'local',
            ),
          );
        }
        return true;

      case 'devices':
        _addTerminalBlock(
          TerminalBlock(
            type: TerminalBlockType.output,
            content: _getDevicesInfo(),
            timestamp: DateTime.now(),
            deviceName: _selectedDevice?.name ?? 'local',
            isSuccess: true,
          ),
        );
        return true;

      case 'workflows':
        _showWorkflowPalette();
        return true;

      case 'history':
        _showCommandHistory();
        return true;

      default:
        return false;
    }
  }

  void _executeOnDevice(String command) async {
    try {
      if (_selectedDevice != null) {
        widget.onCommand(command, _selectedDevice);

        // Simulate command execution with typing effect
        await Future.delayed(const Duration(milliseconds: 500));

        final output = _simulateCommandOutput(command);
        _addTerminalBlock(
          TerminalBlock(
            type: TerminalBlockType.output,
            content: output,
            timestamp: DateTime.now(),
            deviceName: _selectedDevice?.name ?? 'local',
            isSuccess: !output.contains('error') && !output.contains('failed'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        _addTerminalBlock(
          TerminalBlock(
            type: TerminalBlockType.error,
            content: 'No device selected',
            timestamp: DateTime.now(),
            deviceName: 'local',
          ),
        );
      }
    } catch (e) {
      _addTerminalBlock(
        TerminalBlock(
          type: TerminalBlockType.error,
          content: 'Error executing command: $e',
          timestamp: DateTime.now(),
          deviceName: _selectedDevice?.name ?? 'local',
        ),
      );
    } finally {
      setState(() {
        _isExecuting = false;
      });
    }
  }

  String _simulateCommandOutput(String command) {
    final cmd = command.split(' ')[0].toLowerCase();

    switch (cmd) {
      case 'ls':
        return '''drwxr-xr-x  3 user user  4096 Dec  7 10:30 Documents
drwxr-xr-x  2 user user  4096 Dec  7 09:15 Downloads
drwxr-xr-x  2 user user  4096 Dec  6 14:20 Desktop
-rw-r--r--  1 user user  2048 Dec  7 11:45 buddy_app
-rw-r--r--  1 user user  1024 Dec  7 10:00 README.md''';

      case 'ps':
        return '''  PID TTY          TIME CMD
 1234 pts/0    00:00:01 flutter
 5678 pts/1    00:00:00 buddy_app
 9012 ?        00:00:10 systemd''';

      case 'whoami':
        return 'buddy_user';

      case 'pwd':
        return _currentDirectory;

      case 'date':
        return DateTime.now().toString();

      case 'uname':
        return '${_selectedDevice?.platform ?? 'Linux'} ${_selectedDevice?.name ?? 'local'} 5.15.0-94-generic';

      case 'top':
        return '''Tasks: 156 total,   2 running, 154 sleeping
%Cpu(s): 15.2 us,  2.1 sy,  0.0 ni, 82.3 id,  0.4 wa
MiB Mem :   8192.0 total,   2048.5 free,   4096.2 used
MiB Swap:   2048.0 total,   1024.0 free,   1024.0 used

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
 1234 user      20   0  800000  200000  50000 S  12.5   2.4   0:01.23 flutter
 5678 user      20   0  400000  100000  25000 S   3.1   1.2   0:00.45 buddy_app''';

      default:
        return 'Command "$command" executed successfully on ${_selectedDevice?.name ?? "local"}';
    }
  }

  void _updateSuggestions(String input) {
    if (input.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    final commonCommands = [
      'ls',
      'ls -la',
      'ls -lh',
      'cd',
      'pwd',
      'mkdir',
      'rmdir',
      'rm',
      'cp',
      'mv',
      'cat',
      'less',
      'more',
      'head',
      'tail',
      'grep',
      'find',
      'locate',
      'ps',
      'ps aux',
      'top',
      'htop',
      'kill',
      'killall',
      'df',
      'df -h',
      'du',
      'du -sh',
      'free',
      'free -h',
      'wget',
      'curl',
      'ping',
      'ssh',
      'scp',
      'rsync',
      'tar',
      'zip',
      'unzip',
      'gzip',
      'gunzip',
      'sudo',
      'su',
      'chmod',
      'chown',
      'chgrp',
      'history',
      'clear',
      'exit',
      'which',
      'whereis',
      'man',
      'git status',
      'git add',
      'git commit',
      'git push',
      'git pull',
      'npm install',
      'npm start',
      'npm run',
      'flutter run',
      'flutter build',
    ];

    final filtered = commonCommands
        .where((cmd) => cmd.toLowerCase().startsWith(input.toLowerCase()))
        .toList();

    // Add command history matches
    final historyMatches = _commandHistory
        .where((cmd) => cmd.toLowerCase().contains(input.toLowerCase()))
        .take(5)
        .toList();

    setState(() {
      _suggestions = [...filtered.take(8), ...historyMatches];
      _showSuggestions = _suggestions.isNotEmpty;
      _selectedSuggestionIndex = -1;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_showSuggestions && _suggestions.isNotEmpty) {
          setState(() {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex - 1) % _suggestions.length;
          });
        } else {
          _navigateHistory(-1);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_showSuggestions && _suggestions.isNotEmpty) {
          setState(() {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + 1) % _suggestions.length;
          });
        } else {
          _navigateHistory(1);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        if (_showSuggestions && _selectedSuggestionIndex >= 0) {
          _applySuggestion(_suggestions[_selectedSuggestionIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _showSuggestions = false;
          _showCommandPalette = false;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.keyK &&
          HardwareKeyboard.instance.isControlPressed) {
        _toggleCommandPalette();
      }
    }
  }

  void _applySuggestion(String suggestion) {
    _commandController.text = suggestion;
    _commandController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    setState(() {
      _showSuggestions = false;
    });
  }

  void _navigateHistory(int direction) {
    if (_commandHistory.isEmpty) return;

    setState(() {
      _historyIndex += direction;
      if (_historyIndex < 0) {
        _historyIndex = -1;
        _commandController.text = '';
      } else if (_historyIndex >= _commandHistory.length) {
        _historyIndex = _commandHistory.length - 1;
      }

      if (_historyIndex >= 0) {
        _commandController.text =
            _commandHistory[_commandHistory.length - 1 - _historyIndex];
        _commandController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commandController.text.length),
        );
      }
    });
  }

  String _getHelpContent() {
    return '''🚀 Buddy Terminal - Enhanced Commands:

📁 File Operations:
  ls, ls -la      - List files and directories
  cd <dir>        - Change directory
  pwd             - Print working directory
  mkdir <dir>     - Create directory
  cat <file>      - Display file contents

🔧 System Commands:
  ps, ps aux      - List running processes
  top             - System monitor
  df -h           - Disk usage
  free -h         - Memory usage
  uname -a        - System information

⚡ Terminal Features:
  clear           - Clear terminal
  history         - Show command history
  theme <name>    - Change terminal theme
  devices         - List available devices
  workflows       - Show saved workflows

🎨 Themes: dark, light, matrix, ocean, sunset
⌨️  Shortcuts: Ctrl+K (command palette), Tab (autocomplete), ↑↓ (history)''';
  }

  String _getDevicesInfo() {
    if (widget.devices.isEmpty) {
      return 'No devices available. Add devices to get started.';
    }

    String info = 'Available Devices:\n';
    for (int i = 0; i < widget.devices.length; i++) {
      final device = widget.devices[i];
      final status = device.isOnline ? '🟢 online' : '🔴 offline';
      final selected = device.id == _selectedDevice?.id ? ' (selected)' : '';
      info += '  $i: ${device.name} [${device.platform}] - $status$selected\n';
    }
    return info;
  }

  void _changeTheme(String theme) {
    setState(() {
      _currentTheme = theme;
    });
    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.info,
        content: 'Theme changed to: $theme',
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
      ),
    );
  }

  void _toggleCommandPalette() {
    setState(() {
      _showCommandPalette = !_showCommandPalette;
    });
  }

  void _showWorkflowPalette() {
    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.info,
        content:
            '🔧 Workflows feature coming soon! Save and run command sequences.',
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
      ),
    );
  }

  void _showCommandHistory() {
    if (_commandHistory.isEmpty) {
      _addTerminalBlock(
        TerminalBlock(
          type: TerminalBlockType.info,
          content: 'No command history available.',
          timestamp: DateTime.now(),
          deviceName: _selectedDevice?.name ?? 'local',
        ),
      );
      return;
    }

    String historyContent = 'Recent Commands:\n';
    for (
      int i = _commandHistory.length - 1;
      i >= 0 && i >= _commandHistory.length - 10;
      i--
    ) {
      historyContent +=
          '  ${_commandHistory.length - i}: ${_commandHistory[i]}\n';
    }

    _addTerminalBlock(
      TerminalBlock(
        type: TerminalBlockType.output,
        content: historyContent,
        timestamp: DateTime.now(),
        deviceName: _selectedDevice?.name ?? 'local',
        isSuccess: true,
      ),
    );
  }

  Color _getThemeColor() {
    switch (_currentTheme) {
      case 'light':
        return Colors.grey[100]!;
      case 'matrix':
        return Colors.black;
      case 'ocean':
        return const Color(0xFF0F3460);
      case 'sunset':
        return const Color(0xFF2D1B69);
      default:
        return Colors.black;
    }
  }

  Color _getThemeTextColor() {
    switch (_currentTheme) {
      case 'light':
        return Colors.black87;
      case 'matrix':
        return Colors.green;
      case 'ocean':
        return Colors.cyan;
      case 'sunset':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _getThemeColor(),
      child: Column(
        children: [
          // Modern terminal header
          _buildTerminalHeader(),

          // Command palette overlay
          if (_showCommandPalette) _buildCommandPalette(),

          // Terminal content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _terminalBlocks.length,
                itemBuilder: (context, index) {
                  return _buildTerminalBlock(_terminalBlocks[index]);
                },
              ),
            ),
          ),

          // Command input with suggestions
          _buildCommandInput(),
        ],
      ),
    );
  }

  Widget _buildTerminalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Icon(Icons.terminal, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Terminal',
            style: TextStyle(
              color: _getThemeTextColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // Theme switcher
          DropdownButton<String>(
            value: _currentTheme,
            dropdownColor: Colors.grey[800],
            items: ['dark', 'light', 'matrix', 'ocean', 'sunset'].map((theme) {
              return DropdownMenuItem<String>(
                value: theme,
                child: Text(theme, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (theme) {
              if (theme != null) _changeTheme(theme);
            },
          ),

          const SizedBox(width: 16),

          // Device selector
          if (widget.devices.isNotEmpty)
            DropdownButton<String>(
              value: _selectedDevice?.id,
              hint: const Text(
                'Select Device',
                style: TextStyle(color: Colors.white70),
              ),
              dropdownColor: Colors.grey[800],
              items: widget.devices.map((device) {
                return DropdownMenuItem<String>(
                  value: device.id,
                  child: Row(
                    children: [
                      Icon(
                        device.isOnline ? Icons.circle : Icons.circle_outlined,
                        color: device.isOnline ? Colors.green : Colors.grey,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (deviceId) {
                if (deviceId != null) {
                  final device = widget.devices.firstWhere(
                    (d) => d.id == deviceId,
                  );
                  setState(() {
                    _selectedDevice = device;
                  });
                  widget.onDeviceSelect(device);
                  _addTerminalBlock(
                    TerminalBlock(
                      type: TerminalBlockType.info,
                      content: 'Switched to device: ${device.name}',
                      timestamp: DateTime.now(),
                      deviceName: device.name,
                    ),
                  );
                }
              },
            ),

          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              Icons.clear,
              color: _getThemeTextColor().withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _terminalBlocks.clear();
              });
              _initializeTerminal();
            },
            tooltip: 'Clear terminal',
          ),
        ],
      ),
    );
  }

  Widget _buildCommandPalette() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search commands...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Container(
            height: 200,
            child: ListView(
              children: _pinnedCommands
                  .where(
                    (cmd) =>
                        cmd.toLowerCase().contains(_searchQuery.toLowerCase()),
                  )
                  .map(
                    (cmd) => ListTile(
                      leading: const Icon(Icons.flash_on, color: Colors.orange),
                      title: Text(
                        cmd,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        _commandController.text = cmd;
                        setState(() {
                          _showCommandPalette = false;
                        });
                        _commandFocusNode.requestFocus();
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBlock(TerminalBlock block) {
    Color blockColor;
    IconData icon;

    switch (block.type) {
      case TerminalBlockType.welcome:
        blockColor = Colors.blue;
        icon = Icons.rocket_launch;
        break;
      case TerminalBlockType.info:
        blockColor = Colors.cyan;
        icon = Icons.info;
        break;
      case TerminalBlockType.command:
        blockColor = Colors.yellow;
        icon = Icons.keyboard_arrow_right;
        break;
      case TerminalBlockType.output:
        blockColor = block.isSuccess ? Colors.green : Colors.red;
        icon = block.isSuccess ? Icons.check_circle : Icons.error;
        break;
      case TerminalBlockType.error:
        blockColor = Colors.red;
        icon = Icons.error;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block indicator
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            child: Icon(icon, color: blockColor, size: 16),
          ),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.type == TerminalBlockType.command)
                  Row(
                    children: [
                      Text(
                        '${block.deviceName}:${block.directory ?? _currentDirectory}\$ ',
                        style: TextStyle(
                          color: Colors.green,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        block.content,
                        style: TextStyle(
                          color: _getThemeTextColor(),
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    block.content,
                    style: TextStyle(
                      color: block.type == TerminalBlockType.error
                          ? Colors.red
                          : _getThemeTextColor(),
                      fontFamily: block.type == TerminalBlockType.welcome
                          ? null
                          : 'monospace',
                      fontSize: 14,
                      fontWeight: block.type == TerminalBlockType.welcome
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),

                // Timestamp
                Text(
                  _formatTimestamp(block.timestamp),
                  style: TextStyle(
                    color: _getThemeTextColor().withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Column(
        children: [
          // Suggestions
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                border: Border(bottom: BorderSide(color: Colors.grey[600]!)),
              ),
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedSuggestionIndex;
                  return Container(
                    color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.history,
                        color: Colors.white70,
                        size: 16,
                      ),
                      title: Text(
                        _suggestions[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => _applySuggestion(_suggestions[index]),
                    ),
                  );
                },
              ),
            ),

          // Command input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Prompt
                Text(
                  '${_selectedDevice?.name ?? 'local'}:$_currentDirectory\$ ',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),

                // Input field
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      _handleKeyEvent(event);
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _commandController,
                      focusNode: _commandFocusNode,
                      autofocus: true,
                      style: TextStyle(
                        color: _getThemeTextColor(),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: _isExecuting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                ),
                              )
                            : AnimatedBuilder(
                                animation: _blinkAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _blinkAnimation.value,
                                    child: Container(
                                      width: 2,
                                      height: 16,
                                      color: Colors.green,
                                    ),
                                  );
                                },
                              ),
                      ),
                      onChanged: (value) {
                        _updateSuggestions(value);
                      },
                      onSubmitted: (command) {
                        _executeCommand(command);
                        _commandController.clear();
                        _commandFocusNode.requestFocus();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
