// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dock_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  id: json['id'] as String,
  name: json['name'] as String,
  platform: json['platform'] as String,
  ipAddress: json['ip_address'] as String,
  port: (json['port'] as num).toInt(),
  status: json['status'] as String,
  lastSeen: json['last_seen'] as String,
  capabilities: json['capabilities'] as Map<String, dynamic>,
  metadata: json['metadata'] as Map<String, dynamic>,
  deviceType: json['device_type'] as String?,
  isOnlineFlag: json['is_online'] as bool?,
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'platform': instance.platform,
  'ip_address': instance.ipAddress,
  'port': instance.port,
  'status': instance.status,
  'last_seen': instance.lastSeen,
  'capabilities': instance.capabilities,
  'metadata': instance.metadata,
  'device_type': instance.deviceType,
  'is_online': instance.isOnlineFlag,
};

DeviceCommand _$DeviceCommandFromJson(Map<String, dynamic> json) =>
    DeviceCommand(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      commandType: json['command_type'] as String,
      command: json['command'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
      status: json['status'] as String,
      result: json['result'] as String?,
      errorMessage: json['error_message'] as String?,
      executedAt: json['executed_at'] == null
          ? null
          : DateTime.parse(json['executed_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DeviceCommandToJson(DeviceCommand instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'command_type': instance.commandType,
      'command': instance.command,
      'parameters': instance.parameters,
      'status': instance.status,
      'result': instance.result,
      'error_message': instance.errorMessage,
      'executed_at': instance.executedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

DeviceMacro _$DeviceMacroFromJson(Map<String, dynamic> json) => DeviceMacro(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  deviceId: json['device_id'] as String,
  commands: (json['commands'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList(),
  isActive: json['is_active'] as bool,
  executionCount: (json['execution_count'] as num).toInt(),
  lastExecuted: json['last_executed'] == null
      ? null
      : DateTime.parse(json['last_executed'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$DeviceMacroToJson(DeviceMacro instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'device_id': instance.deviceId,
      'commands': instance.commands,
      'is_active': instance.isActive,
      'execution_count': instance.executionCount,
      'last_executed': instance.lastExecuted?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

DeviceRegisterRequest _$DeviceRegisterRequestFromJson(
  Map<String, dynamic> json,
) => DeviceRegisterRequest(
  name: json['name'] as String,
  platform: json['platform'] as String,
  ipAddress: json['ip_address'] as String,
  port: (json['port'] as num?)?.toInt() ?? 8000,
  capabilities: json['capabilities'] as Map<String, dynamic>? ?? const {},
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$DeviceRegisterRequestToJson(
  DeviceRegisterRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'platform': instance.platform,
  'ip_address': instance.ipAddress,
  'port': instance.port,
  'capabilities': instance.capabilities,
  'metadata': instance.metadata,
};

CommandRequest _$CommandRequestFromJson(Map<String, dynamic> json) =>
    CommandRequest(
      deviceId: json['device_id'] as String,
      commandType: json['command_type'] as String,
      command: json['command'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$CommandRequestToJson(CommandRequest instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'command_type': instance.commandType,
      'command': instance.command,
      'parameters': instance.parameters,
    };

DevicesResponse _$DevicesResponseFromJson(Map<String, dynamic> json) =>
    DevicesResponse(
      devices: (json['devices'] as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DevicesResponseToJson(DevicesResponse instance) =>
    <String, dynamic>{'devices': instance.devices};

MacroRequest _$MacroRequestFromJson(Map<String, dynamic> json) => MacroRequest(
  name: json['name'] as String,
  description: json['description'] as String,
  deviceId: json['device_id'] as String,
  commands: (json['commands'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .toList(),
);

Map<String, dynamic> _$MacroRequestToJson(MacroRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'device_id': instance.deviceId,
      'commands': instance.commands,
    };

SystemActionRequest _$SystemActionRequestFromJson(Map<String, dynamic> json) =>
    SystemActionRequest(
      action: json['action'] as String,
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      force: json['force'] as bool? ?? false,
    );

Map<String, dynamic> _$SystemActionRequestToJson(
  SystemActionRequest instance,
) => <String, dynamic>{
  'action': instance.action,
  'delay': instance.delay,
  'force': instance.force,
};
