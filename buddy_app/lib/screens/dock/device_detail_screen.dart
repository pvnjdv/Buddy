import 'package:flutter/material.dart';
import '../../models/dock_models.dart';
import '../../config/settings/theme_config.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.device.name),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showRenameDialog(),
            icon: const Icon(Icons.edit),
            tooltip: 'Rename Device',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppTheme.surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Name', widget.device.name),
                    _buildInfoRow('Platform', widget.device.platform),
                    _buildInfoRow('Status', widget.device.displayStatus),
                    _buildInfoRow('IP Address', widget.device.ipAddress),
                    _buildInfoRow('Port', widget.device.port.toString()),
                    _buildInfoRow(
                      'Device Type',
                      widget.device.deviceTypeDisplay,
                    ),
                    _buildInfoRow(
                      'Last Seen',
                      _formatDateTime(widget.device.lastSeenDateTime),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.device.capabilities.isNotEmpty) ...[
              Card(
                color: AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capabilities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.device.capabilities.keys.map((
                          capability,
                        ) {
                          return Chip(
                            label: Text(capability),
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.device.metadata.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metadata',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...widget.device.metadata.entries.map((entry) {
                        return _buildInfoRow(entry.key, entry.value.toString());
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Command Actions Section
            if (widget.device.isOnline) ...[
              Card(
                color: AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showQuickCommands(),
                              icon: const Icon(Icons.terminal),
                              label: const Text('Terminal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showSystemInfo(),
                              icon: const Icon(Icons.info),
                              label: const Text('System Info'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (widget.device.capabilities['file_transfer'] ==
                              true)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showFileTransfer(),
                                icon: const Icon(Icons.folder),
                                label: const Text('Files'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.device.capabilities['file_transfer'] ==
                              true)
                            const SizedBox(width: 8),
                          if (widget.device.capabilities['screen_share'] ==
                              true)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showScreenShare(),
                                icon: const Icon(Icons.screen_share),
                                label: const Text('Screen'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Dock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

  void _showQuickCommands() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Terminal - ${widget.device.name}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickCommandChip('System Info', 'uname -a'),
                  _buildQuickCommandChip('Memory', 'free -h'),
                  _buildQuickCommandChip('Disk Usage', 'df -h'),
                  _buildQuickCommandChip('Processes', 'ps aux | head -10'),
                  _buildQuickCommandChip('Network', 'ip addr show'),
                  _buildQuickCommandChip('Uptime', 'uptime'),
                  _buildQuickCommandChip('CPU Info', 'lscpu'),
                  _buildQuickCommandChip(
                    'Services',
                    'systemctl list-units --state=running | head -10',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Command',
                  hintText: 'Type your command here...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _executeCustomCommand(),
                  ),
                ),
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontFamily: 'monospace',
                ),
                onSubmitted: (command) => _executeCustomCommand(command),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSystemInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'System Information',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.device.metadata['memory_total'] != null) ...[
                  _buildInfoRow(
                    'Memory',
                    '${(widget.device.metadata['memory_total'] / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                  ),
                ],
                if (widget.device.metadata['cpu_count'] != null) ...[
                  _buildInfoRow(
                    'CPU Cores',
                    widget.device.metadata['cpu_count'].toString(),
                  ),
                ],
                if (widget.device.metadata['architecture'] != null) ...[
                  _buildInfoRow(
                    'Architecture',
                    widget.device.metadata['architecture'],
                  ),
                ],
                if (widget.device.metadata['platform_version'] != null) ...[
                  _buildInfoRow(
                    'OS Version',
                    widget.device.metadata['platform_version'],
                  ),
                ],
                if (widget.device.metadata['battery_percent'] != null) ...[
                  _buildInfoRow(
                    'Battery',
                    '${widget.device.metadata['battery_percent'].toStringAsFixed(1)}%',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showFileTransfer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File transfer feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showScreenShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Screen sharing feature coming soon'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Widget _buildQuickCommandChip(String label, String command) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _executeCommand(command),
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      labelStyle: TextStyle(color: AppTheme.primaryColor),
      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
    );
  }

  void _executeCommand(String command) {
    // Here you would integrate with the DockService to execute the command
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Executing: $command'),
        backgroundColor: Colors.green,
      ),
    );
    // TODO: Implement actual command execution
  }

  void _executeCustomCommand([String? command]) {
    if (command != null && command.isNotEmpty) {
      Navigator.of(context).pop(); // Close bottom sheet
      _executeCommand(command);
    }
  }

  void _showRenameDialog() {
    final TextEditingController nameController = TextEditingController(
      text: widget.device.name,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Rename Device',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Device Name',
            labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          style: TextStyle(color: AppTheme.textPrimaryColor),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != widget.device.name) {
                Navigator.of(context).pop();
                await _renameDevice(newName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDevice(String newName) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renaming device to "$newName"...'),
          backgroundColor: Colors.blue,
        ),
      );

      // TODO: Implement actual device rename API call
      // For now, just show success message
      await Future.delayed(const Duration(milliseconds: 500));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device renamed to "$newName"'),
          backgroundColor: Colors.green,
        ),
      );

      // Update the app bar title
      setState(() {
        // Note: This is a UI update only. In real implementation,
        // you would update the device object and call the backend API
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to rename device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
