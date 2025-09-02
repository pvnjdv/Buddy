// Device Models for Cross-Platform Control
import 'package:json_annotation/json_annotation.dart';

part 'dock_models.g.dart';

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
  final DateTime lastSeen;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> metadata;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

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
    required this.createdAt,
    this.updatedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  bool get isOnline => status == 'online';

  String get deviceType => metadata['device_type'] ?? 'unknown';

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
