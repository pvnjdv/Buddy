// lib/screens/dock_screen.dart
import 'package:flutter/material.dart';
import '../models/dock_models.dart';
import '../services/dock_service.dart';
import '../services/device_discovery_service.dart';
import '../services/auth_service.dart';
import '../widgets/dock_widgets.dart';
import '../screens/dock/device_detail_screen.dart';
import '../screens/dock/remote_control_screen.dart';
import '../screens/dock/buddy_terminal_screen.dart';
import '../screens/code_editor/buddy_code_editor_screen.dart';

class DockScreen extends StatefulWidget {
  const DockScreen({super.key});

  @override
  State<DockScreen> createState() => _DockScreenState();
}

class _DockScreenState extends State<DockScreen> with TickerProviderStateMixin {
  final DockService _dockService = DockService();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  late TabController _tabController;

  List<Device> _devices = [];
  List<DeviceMacro> _macros = [];
  List<DeviceCommand> _commandHistory = [];
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
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
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
                _buildSettingsTab(),
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
                        _executeQuickCommand('system', 'uname -a');
                      }),
                      _buildQuickCommandChip('Memory Usage', Icons.memory, () {
                        _executeQuickCommand('system', 'free -h');
                      }),
                      _buildQuickCommandChip('List Processes', Icons.list, () {
                        _executeQuickCommand('system', 'ps aux | head -20');
                      }),
                      _buildQuickCommandChip('Disk Usage', Icons.storage, () {
                        _executeQuickCommand('system', 'df -h');
                      }),
                      _buildQuickCommandChip(
                        'Network Info',
                        Icons.network_check,
                        () {
                          _executeQuickCommand('network', 'ip addr show');
                        },
                      ),
                      _buildQuickCommandChip('CPU Info', Icons.computer, () {
                        _executeQuickCommand('system', 'lscpu');
                      }),
                      _buildQuickCommandChip(
                        'Running Services',
                        Icons.settings,
                        () {
                          _executeQuickCommand(
                            'system',
                            'systemctl list-units --type=service --state=running',
                          );
                        },
                      ),
                      _buildQuickCommandChip('Uptime', Icons.schedule, () {
                        _executeQuickCommand('system', 'uptime');
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
                icon: const Icon(Icons.add),
                label: const Text('Create'),
                onPressed: _showCreateMacroDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _macros.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No macros created'),
                      SizedBox(height: 8),
                      Text(
                        'Create macros to automate tasks',
                        style: TextStyle(color: Colors.grey),
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

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.network_check),
                title: const Text('Network Scan'),
                subtitle: const Text('Discover devices on network'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _scanNetwork,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Command History'),
                subtitle: const Text('View executed commands'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCommandHistory,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cloud_sync),
                title: const Text('Sync Settings'),
                subtitle: const Text('Synchronize with cloud'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // Handle sync toggle
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Dock'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAbout,
              ),
            ],
          ),
        ),
      ],
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

  void _executeQuickCommand(String type, String command) {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No devices available')));
      return;
    }

    // Use the first online device
    final device = _devices.firstWhere(
      (d) => d.isOnline,
      orElse: () => _devices.first,
    );

    final request = CommandRequest(
      deviceId: device.id,
      commandType: type,
      command: command,
    );

    _dockService.executeCommand(request);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Command executed')));
  }

  void _showCreateMacroDialog() {
    // Implementation for creating macros
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Macro creation coming soon')));
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

  void _scanNetwork() async {
    try {
      final devices = await _dockService.scanNetwork();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Devices'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(device.ipAddress),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Add discovered device
                    },
                    child: const Text('Add'),
                  ),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning network: $e')));
    }
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

  void _showCommandHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Command history coming soon')),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Buddy Dock',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.devices, size: 64),
      children: const [
        Text(
          'Cross-platform device management and control system with auto-discovery.',
        ),
        SizedBox(height: 16),
        Text('Features:'),
        Text('• Automatic device registration'),
        Text('• Real-time cross-platform control'),
        Text('• Screen sharing and remote input'),
        Text('• File transfer and system management'),
      ],
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
}
