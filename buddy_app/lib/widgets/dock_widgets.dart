// lib/widgets/dock_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dock_models.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onCommand;
  final VoidCallback onRemove;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onCommand,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: device.isOnline ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with device info and status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: device.isOnline
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getPlatformIcon(device.platform),
                      color: device.isOnline ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                              ),
                            ),
                            // Performance indicator
                            if (device.systemMetrics?.isHighPerformance == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.speed,
                                      size: 12,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'HIGH',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${device.platform} • ${device.displayStatus}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            if (device.systemMetrics?.uptimeHours != null)
                              Text(
                                'Up: ${device.systemMetrics!.uptimeDisplay}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge with additional indicators
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: device.isOnline ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          device.isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Warning indicators
                      if (device.systemMetrics != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (device.systemMetrics!.isOverheating)
                              Icon(
                                Icons.thermostat,
                                size: 14,
                                color: Colors.red[600],
                              ),
                            if (device.systemMetrics!.isLowBattery)
                              Icon(
                                Icons.battery_alert,
                                size: 14,
                                color: Colors.red[600],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // System metrics section (only if available and online)
              if (device.isOnline && device.systemMetrics != null) ...[
                const SizedBox(height: 16),
                _buildSystemMetrics(context, device.systemMetrics!),
              ],

              // Network info section
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${device.ipAddress}:${device.port}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Last seen: ${_formatDateTime(device.lastSeenDateTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              // Capabilities section
              if (device.capabilities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: device.capabilities.keys.take(4).map((capability) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        capability,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Action buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.terminal, size: 18),
                      label: const Text('Command'),
                      onPressed: device.isOnline ? onCommand : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: device.isOnline
                            ? Colors.blue
                            : Colors.grey[300],
                        foregroundColor: device.isOnline
                            ? Colors.white
                            : Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                    child: const Icon(Icons.delete, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMetrics(BuildContext context, SystemMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Top row: CPU, Memory, Storage
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'CPU',
                  '${metrics.cpuUsage.toStringAsFixed(1)}%',
                  metrics.cpuUsage / 100,
                  metrics.getCpuColor(),
                  Icons.memory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'RAM',
                  '${metrics.memoryUsage.toStringAsFixed(1)}%',
                  metrics.memoryUsage / 100,
                  metrics.getMemoryColor(),
                  Icons.storage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'Disk',
                  '${metrics.storageUsage.toStringAsFixed(1)}%',
                  metrics.storageUsage / 100,
                  metrics.getStorageColor(),
                  Icons.storage,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom row: Temperature, Battery, Network
          Row(
            children: [
              // Temperature
              if (metrics.temperatureCpu != null)
                Expanded(
                  child: _buildMetricItem(
                    'CPU°C',
                    '${metrics.temperatureCpu!.toStringAsFixed(0)}°',
                    (metrics.temperatureCpu! / 100).clamp(0.0, 1.0),
                    metrics.getTemperatureColor(metrics.temperatureCpu),
                    Icons.thermostat,
                  ),
                ),

              // Battery (if available)
              if (metrics.batteryLevel != null) ...[
                if (metrics.temperatureCpu != null) const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricItem(
                    'Battery',
                    '${metrics.batteryLevel}%',
                    metrics.batteryLevel! / 100,
                    metrics.batteryLevel! < 20
                        ? Colors.red
                        : metrics.batteryLevel! < 50
                        ? Colors.orange
                        : Colors.green,
                    metrics.batteryCharging == true
                        ? Icons.battery_charging_full
                        : Icons.battery_std,
                  ),
                ),
              ],

              // Network speed
              if (metrics.networkDownload > 0 || metrics.networkUpload > 0) ...[
                if (metrics.temperatureCpu != null ||
                    metrics.batteryLevel != null)
                  const SizedBox(width: 12),
                Expanded(child: _buildNetworkMetric(metrics)),
              ],
            ],
          ),

          // Additional info row
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Memory: ${metrics.memoryDisplay}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                'Processes: ${metrics.processCount}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                'Storage: ${metrics.storageDisplay}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 3,
        ),
      ],
    );
  }

  Widget _buildNetworkMetric(SystemMetrics metrics) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.network_check, size: 14, color: Colors.blue[600]),
            const SizedBox(width: 4),
            Text(
              'Network',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '↓${metrics.networkDownload.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.green[600],
          ),
        ),
        Text(
          '↑${metrics.networkUpload.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blue[600],
          ),
        ),
      ],
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class MacroCard extends StatelessWidget {
  final DeviceMacro macro;
  final VoidCallback onExecute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MacroCard({
    super.key,
    required this.macro,
    required this.onExecute,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: macro.isActive
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: macro.isActive ? Colors.purple : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        macro.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (macro.description != null)
                        Text(
                          macro.description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
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
                    color: macro.isActive ? Colors.purple : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    macro.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.play_circle, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${macro.executionCount} executions',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.code, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${macro.commands.length} commands',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const Spacer(),
                if (macro.lastExecuted != null)
                  Text(
                    'Last: ${_formatDateTime(macro.lastExecuted!)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Execute'),
                    onPressed: macro.isActive ? onExecute : null,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Icon(Icons.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class AddDeviceDialog extends StatefulWidget {
  final Function(DeviceRegisterRequest) onAdd;

  const AddDeviceDialog({super.key, required this.onAdd});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8000');

  String _selectedPlatform = DevicePlatforms.windows;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Device'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  prefixIcon: Icon(Icons.device_hub),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a device name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPlatform,
                decoration: const InputDecoration(
                  labelText: 'Platform',
                  prefixIcon: Icon(Icons.computer),
                ),
                items: DevicePlatforms.all.map((platform) {
                  return DropdownMenuItem(
                    value: platform,
                    child: Text(platform),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlatform = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  prefixIcon: Icon(Icons.wifi),
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a port number';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Please enter a valid port number (1-65535)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final request = DeviceRegisterRequest(
                name: _nameController.text,
                platform: _selectedPlatform,
                ipAddress: _ipController.text,
                port: int.parse(_portController.text),
                capabilities: {
                  'system_control': true,
                  'file_operations': true,
                  'app_management': true,
                },
                metadata: {
                  'device_type': _selectedPlatform.toLowerCase(),
                  'registered_via': 'mobile_app',
                },
              );
              widget.onAdd(request);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class CommandDialog extends StatefulWidget {
  final Device device;
  final Function(CommandRequest) onExecute;

  const CommandDialog({
    super.key,
    required this.device,
    required this.onExecute,
  });

  @override
  State<CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<CommandDialog> {
  final _commandController = TextEditingController();
  String _selectedType = CommandTypes.system;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Execute Command - ${widget.device.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Command Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: CommandTypes.all.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                labelText: 'Command',
                prefixIcon: Icon(Icons.terminal),
                hintText: 'Enter command to execute',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickCommand(
                    'List Files',
                    'ls -la',
                    Icons.folder,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickCommand(
                    'System Info',
                    'uname -a',
                    Icons.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildQuickCommand('Processes', 'ps aux', Icons.list),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickCommand(
                    'Disk Usage',
                    'df -h',
                    Icons.storage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _commandController.text.isNotEmpty
              ? () {
                  final request = CommandRequest(
                    deviceId: widget.device.id,
                    commandType: _selectedType,
                    command: _commandController.text,
                  );
                  widget.onExecute(request);
                }
              : null,
          child: const Text('Execute'),
        ),
      ],
    );
  }

  Widget _buildQuickCommand(String label, String command, IconData icon) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _commandController.text = command;
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

class DeviceDetailsScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Name', widget.device.name),
                  _buildInfoRow('Platform', widget.device.platform),
                  _buildInfoRow('Status', widget.device.displayStatus),
                  _buildInfoRow(
                    'IP Address',
                    '${widget.device.ipAddress}:${widget.device.port}',
                  ),
                  _buildInfoRow('Device Type', widget.device.deviceTypeDisplay),
                  _buildInfoRow(
                    'Last Seen',
                    _formatDateTime(widget.device.lastSeenDateTime),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Capabilities',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (widget.device.capabilities.isEmpty)
                    const Text('No capabilities defined')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.device.capabilities.keys.map((
                        capability,
                      ) {
                        return Chip(
                          label: Text(capability),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2,
                    children: [
                      _buildActionButton('System Info', Icons.info, () {}),
                      _buildActionButton('Files', Icons.folder, () {}),
                      _buildActionButton('Apps', Icons.apps, () {}),
                      _buildActionButton('Terminal', Icons.terminal, () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
