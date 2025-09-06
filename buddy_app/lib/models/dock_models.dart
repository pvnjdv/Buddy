// Device Models for Cross-Platform Control
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';

part 'dock_models.g.dart';

@JsonSerializable()
class SystemMetrics {
  @JsonKey(name: 'cpu_usage')
  final double cpuUsage; // Percentage 0-100
  @JsonKey(name: 'memory_usage')
  final double memoryUsage; // Percentage 0-100
  @JsonKey(name: 'memory_total')
  final int memoryTotal; // Total RAM in MB
  @JsonKey(name: 'memory_used')
  final int memoryUsed; // Used RAM in MB
  @JsonKey(name: 'storage_total')
  final int storageTotal; // Total storage in GB
  @JsonKey(name: 'storage_used')
  final int storageUsed; // Used storage in GB
  @JsonKey(name: 'storage_usage')
  final double storageUsage; // Percentage 0-100
  @JsonKey(name: 'temperature_cpu')
  final double? temperatureCpu; // CPU temperature in Celsius
  @JsonKey(name: 'temperature_gpu')
  final double? temperatureGpu; // GPU temperature in Celsius
  @JsonKey(name: 'battery_level')
  final int? batteryLevel; // Battery percentage 0-100
  @JsonKey(name: 'battery_charging')
  final bool? batteryCharging; // Whether device is charging
  @JsonKey(name: 'network_upload')
  final double networkUpload; // Upload speed in Mbps
  @JsonKey(name: 'network_download')
  final double networkDownload; // Download speed in Mbps
  @JsonKey(name: 'process_count')
  final int processCount; // Number of running processes
  @JsonKey(name: 'uptime_hours')
  final double uptimeHours; // System uptime in hours
  @JsonKey(name: 'last_updated')
  final DateTime lastUpdated; // When metrics were last updated

  SystemMetrics({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.storageTotal,
    required this.storageUsed,
    required this.storageUsage,
    this.temperatureCpu,
    this.temperatureGpu,
    this.batteryLevel,
    this.batteryCharging,
    required this.networkUpload,
    required this.networkDownload,
    required this.processCount,
    required this.uptimeHours,
    required this.lastUpdated,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) =>
      _$SystemMetricsFromJson(json);
  Map<String, dynamic> toJson() => _$SystemMetricsToJson(this);

  // Helper getters for formatted display
  String get memoryDisplay =>
      '${(memoryUsed / 1024).toStringAsFixed(1)} / ${(memoryTotal / 1024).toStringAsFixed(1)} GB';
  String get storageDisplay => '$storageUsed / $storageTotal GB';
  String get uptimeDisplay {
    if (uptimeHours < 1) {
      return '${(uptimeHours * 60).round()}m';
    } else if (uptimeHours < 24) {
      return '${uptimeHours.toStringAsFixed(1)}h';
    } else {
      return '${(uptimeHours / 24).toStringAsFixed(1)}d';
    }
  }

  Color getCpuColor() {
    if (cpuUsage < 30) return Colors.green;
    if (cpuUsage < 70) return Colors.orange;
    return Colors.red;
  }

  Color getMemoryColor() {
    if (memoryUsage < 60) return Colors.green;
    if (memoryUsage < 80) return Colors.orange;
    return Colors.red;
  }

  Color getStorageColor() {
    if (storageUsage < 70) return Colors.green;
    if (storageUsage < 90) return Colors.orange;
    return Colors.red;
  }

  Color getTemperatureColor(double? temp) {
    if (temp == null) return Colors.grey;
    if (temp < 60) return Colors.green;
    if (temp < 80) return Colors.orange;
    return Colors.red;
  }

  bool get isHighPerformance => cpuUsage > 80 || memoryUsage > 90;
  bool get isLowBattery => batteryLevel != null && batteryLevel! < 20;
  bool get isOverheating =>
      (temperatureCpu != null && temperatureCpu! > 85) ||
      (temperatureGpu != null && temperatureGpu! > 90);
}

@JsonSerializable()
class Device {
  final String id;
  final String name;
  final String platform;
  @JsonKey(name: 'ip_address')
  final String ipAddress;
  final int port;
  final String status;
  @JsonKey(name: 'last_seen')
  final String lastSeen; // Keep as String for now, can parse later
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> metadata;
  @JsonKey(name: 'device_type')
  final String? deviceType;
  @JsonKey(name: 'is_online')
  final bool? isOnlineFlag;
  @JsonKey(name: 'system_metrics')
  final SystemMetrics? systemMetrics; // Real-time system information

  Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.status,
    required this.lastSeen,
    required this.capabilities,
    required this.metadata,
    this.deviceType,
    this.isOnlineFlag,
    this.systemMetrics,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  bool get isOnline => isOnlineFlag ?? (status == 'online');

  String get deviceTypeDisplay =>
      deviceType ?? metadata['device_type'] ?? 'unknown';

  String get displayStatus {
    switch (status) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'busy':
        return 'Busy';
      default:
        return status.toUpperCase();
    }
  }

  DateTime get lastSeenDateTime {
    try {
      return DateTime.parse(lastSeen);
    } catch (e) {
      return DateTime.now();
    }
  }

  Device copyWith({
    String? id,
    String? name,
    String? platform,
    String? ipAddress,
    int? port,
    String? status,
    String? lastSeen,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? metadata,
    String? deviceType,
    bool? isOnline,
    SystemMetrics? systemMetrics,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
      deviceType: deviceType ?? this.deviceType,
      isOnlineFlag: isOnline ?? this.isOnlineFlag,
      systemMetrics: systemMetrics ?? this.systemMetrics,
    );
  }
}

@JsonSerializable()
class DeviceCommand {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'command_type')
  final String commandType;
  final String command;
  final Map<String, dynamic> parameters;
  final String status;
  final String? result;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'executed_at')
  final DateTime? executedAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  DeviceCommand({
    required this.id,
    required this.deviceId,
    required this.commandType,
    required this.command,
    required this.parameters,
    required this.status,
    this.result,
    this.errorMessage,
    this.executedAt,
    this.completedAt,
    required this.createdAt,
  });

  factory DeviceCommand.fromJson(Map<String, dynamic> json) =>
      _$DeviceCommandFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceCommandToJson(this);

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';
  bool get isPending => status == 'pending';
}

@JsonSerializable()
class DeviceMacro {
  final String id;
  final String name;
  final String? description;
  @JsonKey(name: 'device_id')
  final String deviceId;
  final List<Map<String, dynamic>> commands;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'execution_count')
  final int executionCount;
  @JsonKey(name: 'last_executed')
  final DateTime? lastExecuted;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  DeviceMacro({
    required this.id,
    required this.name,
    this.description,
    required this.deviceId,
    required this.commands,
    required this.isActive,
    required this.executionCount,
    this.lastExecuted,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeviceMacro.fromJson(Map<String, dynamic> json) =>
      _$DeviceMacroFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceMacroToJson(this);
}

// Request models
@JsonSerializable()
class DeviceRegisterRequest {
  final String name;
  final String platform;
  @JsonKey(name: 'ip_address')
  final String ipAddress;
  final int port;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> metadata;

  DeviceRegisterRequest({
    required this.name,
    required this.platform,
    required this.ipAddress,
    this.port = 8000,
    this.capabilities = const {},
    this.metadata = const {},
  });

  factory DeviceRegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceRegisterRequestToJson(this);
}

@JsonSerializable()
class CommandRequest {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'command_type')
  final String commandType;
  final String command;
  final Map<String, dynamic> parameters;

  CommandRequest({
    required this.deviceId,
    required this.commandType,
    required this.command,
    this.parameters = const {},
  });

  factory CommandRequest.fromJson(Map<String, dynamic> json) =>
      _$CommandRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CommandRequestToJson(this);
}

// Response wrappers
@JsonSerializable()
class DevicesResponse {
  final List<Device> devices;

  DevicesResponse({required this.devices});

  factory DevicesResponse.fromJson(Map<String, dynamic> json) =>
      _$DevicesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DevicesResponseToJson(this);
}

@JsonSerializable()
class MacroRequest {
  final String name;
  final String description;
  @JsonKey(name: 'device_id')
  final String deviceId;
  final List<Map<String, dynamic>> commands;

  MacroRequest({
    required this.name,
    required this.description,
    required this.deviceId,
    required this.commands,
  });

  factory MacroRequest.fromJson(Map<String, dynamic> json) =>
      _$MacroRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MacroRequestToJson(this);
}

@JsonSerializable()
class SystemActionRequest {
  final String action;
  final int delay;
  final bool force;

  SystemActionRequest({
    required this.action,
    this.delay = 0,
    this.force = false,
  });

  factory SystemActionRequest.fromJson(Map<String, dynamic> json) =>
      _$SystemActionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SystemActionRequestToJson(this);
}

// Simplified device type enum
enum DeviceType { desktop, laptop, mobile, tablet, server, iot, unknown }

// Platform constants
class DevicePlatforms {
  static const String windows = 'Windows';
  static const String macos = 'macOS';
  static const String linux = 'Linux';
  static const String android = 'Android';
  static const String ios = 'iOS';

  static List<String> get all => [windows, macos, linux, android, ios];
}

// Command types
class CommandTypes {
  static const String system = 'system';
  static const String app = 'app';
  static const String file = 'file';
  static const String network = 'network';

  static List<String> get all => [system, app, file, network];
}
