import 'package:flutter/material.dart';
import '../../models/dock_models.dart';
import '../../config/theme_config.dart';

class DeviceDetailScreen extends StatefulWidget {
  final ConnectedDevice device;

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
      ),
      body: Padding(
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
                    _buildInfoRow(
                      'Type',
                      widget.device.type.name.toUpperCase(),
                    ),
                    _buildInfoRow('Platform', widget.device.platform),
                    _buildInfoRow(
                      'Status',
                      widget.device.isOnline ? 'Online' : 'Offline',
                    ),
                    _buildInfoRow(
                      'IP Address',
                      widget.device.ipAddress ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      'Last Seen',
                      widget.device.lastSeen.toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.device.isOnline) ...[
              Card(
                color: AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatusRow(
                        'CPU Usage',
                        widget.device.status.cpuUsage,
                        '%',
                      ),
                      _buildStatusRow(
                        'Memory Usage',
                        widget.device.status.memoryUsage,
                        '%',
                      ),
                      _buildStatusRow(
                        'Disk Usage',
                        widget.device.status.diskUsage,
                        '%',
                      ),
                      if (widget.device.status.gpuUsage != null)
                        _buildStatusRow(
                          'GPU Usage',
                          widget.device.status.gpuUsage!,
                          '%',
                        ),
                      _buildStatusRow(
                        'Network Upload',
                        widget.device.status.networkUpload,
                        'KB/s',
                      ),
                      _buildStatusRow(
                        'Network Download',
                        widget.device.status.networkDownload,
                        'KB/s',
                      ),
                      _buildStatusRow(
                        'Battery Level',
                        widget.device.status.batteryLevel.toDouble(),
                        '%',
                      ),
                      _buildStatusRow(
                        'Temperature',
                        widget.device.status.temperature,
                        '°C',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
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

  Widget _buildStatusRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: unit == '%' ? value / 100 : value / 1000,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
