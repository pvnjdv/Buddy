// lib/screens/dock_screen.dart
import 'package:flutter/material.dart';
import '../models/dock_models.dart';
import '../services/dock_service.dart';
import '../services/device_discovery_service.dart';
import '../services/auth_service.dart';
import '../widgets/dock_widgets.dart';
import 'dock/device_detail_screen.dart';
import 'dock/remote_control_screen.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Column(
      children: [
        // Auto-discovery status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.green.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.radar, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              const Text(
                '🔍 Auto-discovering devices...',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _discoveryService.refreshDiscovery();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshing device discovery...'),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Refresh Discovery',
              ),
            ],
          ),
        ),
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
                        'Tap + to add a device',
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Commands',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickCommandChip('System Info', Icons.info, () {
                        _executeQuickCommand('system', 'uname -a');
                      }),
                      _buildQuickCommandChip('List Processes', Icons.list, () {
                        _executeQuickCommand('system', 'ps aux');
                      }),
                      _buildQuickCommandChip('Disk Usage', Icons.storage, () {
                        _executeQuickCommand('system', 'df -h');
                      }),
                      _buildQuickCommandChip(
                        'Network Info',
                        Icons.network_check,
                        () {
                          _executeQuickCommand('network', 'ipconfig');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    _getPlatformIcon(device.platform),
                    color: device.isOnline ? Colors.green : Colors.grey,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    '${device.platform} • ${device.displayStatus}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: device.isOnline
                        ? () => _showCommandDialog(device)
                        : null,
                    child: const Text('Execute'),
                  ),
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

  void _showAddDeviceDialog() {
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
      lastSeen: DateTime.now(),
      capabilities: {},
      metadata: {'device_type': 'mobile'},
      createdAt: DateTime.now(),
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
}
