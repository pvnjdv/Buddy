// lib/services/system_metrics_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/dock_models.dart';

class SystemMetricsService extends ChangeNotifier {
  static final SystemMetricsService _instance =
      SystemMetricsService._internal();
  factory SystemMetricsService() => _instance;
  SystemMetricsService._internal();

  Timer? _metricsTimer;
  final Map<String, SystemMetrics> _deviceMetrics = {};
  final Random _random = Random();

  // Get metrics for a specific device
  SystemMetrics? getMetrics(String deviceId) {
    return _deviceMetrics[deviceId];
  }

  // Update system metrics for a specific device
  void updateDeviceMetrics(String deviceId, String platform, bool isOnline) {
    if (!isOnline) {
      _deviceMetrics.remove(deviceId);
      notifyListeners();
      return;
    }

    // Generate realistic system metrics based on platform
    final metrics = _generateMetrics(platform);
    _deviceMetrics[deviceId] = metrics;
    notifyListeners();
  }

  SystemMetrics _generateMetrics(String platform) {
    final isMobile =
        platform.toLowerCase().contains('mobile') ||
        platform.toLowerCase().contains('android') ||
        platform.toLowerCase().contains('ios');

    return SystemMetrics(
      cpuUsage: _generateCpuUsage(),
      memoryUsage: _generateMemoryUsage(),
      storageUsage: _generateStorageUsage(),
      temperatureCpu: !isMobile ? _generateTemperature() : null,
      batteryLevel: isMobile ? _generateBatteryLevel() : null,
      batteryCharging: isMobile ? _random.nextBool() : null,
      networkDownload: _generateNetworkSpeed(true),
      networkUpload: _generateNetworkSpeed(false),
      processCount: _generateProcessCount(isMobile),
      uptimeHours: _generateUptime().toDouble(),
      memoryTotal: _generateMemoryTotal(isMobile).toInt(),
      memoryUsed: 0, // Will be calculated
      storageTotal: _generateStorageTotal(isMobile).toInt(),
      storageUsed: 0, // Will be calculated
      lastUpdated: DateTime.now(),
    );
  }

  double _generateCpuUsage() {
    // Realistic CPU usage patterns
    final baseUsage = 15 + _random.nextDouble() * 30; // 15-45% base
    final spike = _random.nextDouble() < 0.3
        ? _random.nextDouble() * 40
        : 0; // 30% chance of spike
    return (baseUsage + spike).clamp(5.0, 95.0);
  }

  double _generateMemoryUsage() {
    // Memory tends to be more stable
    return 40 + _random.nextDouble() * 35; // 40-75%
  }

  double _generateStorageUsage() {
    // Storage changes slowly
    return 30 + _random.nextDouble() * 50; // 30-80%
  }

  double _generateTemperature() {
    // CPU temperature simulation
    final baseTemp = 35 + _random.nextDouble() * 20; // 35-55°C normal
    final load = _random.nextDouble() < 0.2
        ? _random.nextDouble() * 15
        : 0; // Load spike
    return (baseTemp + load).clamp(30.0, 85.0);
  }

  int _generateBatteryLevel() {
    // Battery simulation with realistic patterns
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour <= 22) {
      // Daytime - battery drains
      return 20 + _random.nextInt(70); // 20-90%
    } else {
      // Nighttime - usually charging
      return 60 + _random.nextInt(40); // 60-100%
    }
  }

  double _generateNetworkSpeed(bool isDownload) {
    // Network speed simulation
    final baseSpeed = isDownload
        ? 10 + _random.nextDouble() * 90
        : 1 + _random.nextDouble() * 25;
    final burst = _random.nextDouble() < 0.2 ? _random.nextDouble() * 50 : 0;
    return baseSpeed + burst;
  }

  int _generateProcessCount(bool isMobile) {
    if (isMobile) {
      return 80 + _random.nextInt(50); // 80-130 for mobile
    } else {
      return 150 + _random.nextInt(200); // 150-350 for desktop
    }
  }

  int _generateUptime() {
    // Random uptime between 1 hour and 7 days
    return 1 + _random.nextInt(168);
  }

  double _generateMemoryTotal(bool isMobile) {
    if (isMobile) {
      // Mobile devices: 4-12 GB
      final sizes = [4.0, 6.0, 8.0, 12.0];
      return sizes[_random.nextInt(sizes.length)];
    } else {
      // Desktop/laptop: 8-64 GB
      final sizes = [8.0, 16.0, 32.0, 64.0];
      return sizes[_random.nextInt(sizes.length)];
    }
  }

  double _generateStorageTotal(bool isMobile) {
    if (isMobile) {
      // Mobile storage: 64-512 GB
      final sizes = [64.0, 128.0, 256.0, 512.0];
      return sizes[_random.nextInt(sizes.length)];
    } else {
      // Desktop storage: 256GB - 2TB
      final sizes = [256.0, 512.0, 1024.0, 2048.0];
      return sizes[_random.nextInt(sizes.length)];
    }
  }

  // Start periodic updates for all devices
  void startMetricsUpdates(List<Device> devices) {
    stopMetricsUpdates();

    // Initial update
    for (final device in devices) {
      updateDeviceMetrics(device.id, device.platform, device.isOnline);
    }

    // Periodic updates every 3 seconds
    _metricsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      for (final device in devices) {
        updateDeviceMetrics(device.id, device.platform, device.isOnline);
      }
    });
  }

  void stopMetricsUpdates() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  // Simulate system events
  void simulateHighCpuUsage(String deviceId) {
    final current = _deviceMetrics[deviceId];
    if (current != null) {
      _deviceMetrics[deviceId] = SystemMetrics(
        cpuUsage: 80 + _random.nextDouble() * 15, // 80-95%
        memoryUsage: current.memoryUsage,
        storageUsage: current.storageUsage,
        temperatureCpu: current.temperatureCpu != null
            ? current.temperatureCpu! + 10
            : null,
        batteryLevel: current.batteryLevel,
        batteryCharging: current.batteryCharging,
        networkDownload: current.networkDownload,
        networkUpload: current.networkUpload,
        processCount: current.processCount + 20,
        uptimeHours: current.uptimeHours,
        memoryTotal: current.memoryTotal,
        memoryUsed: current.memoryUsed,
        storageTotal: current.storageTotal,
        storageUsed: current.storageUsed,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void simulateLowBattery(String deviceId) {
    final current = _deviceMetrics[deviceId];
    if (current != null && current.batteryLevel != null) {
      _deviceMetrics[deviceId] = SystemMetrics(
        cpuUsage: current.cpuUsage,
        memoryUsage: current.memoryUsage,
        storageUsage: current.storageUsage,
        temperatureCpu: current.temperatureCpu,
        batteryLevel: 5 + _random.nextInt(15), // 5-20%
        batteryCharging: false,
        networkDownload: current.networkDownload,
        networkUpload: current.networkUpload,
        processCount: current.processCount,
        uptimeHours: current.uptimeHours,
        memoryTotal: current.memoryTotal,
        memoryUsed: current.memoryUsed,
        storageTotal: current.storageTotal,
        storageUsed: current.storageUsed,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopMetricsUpdates();
    super.dispose();
  }
}
