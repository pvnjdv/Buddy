// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MacroTrigger _$MacroTriggerFromJson(Map<String, dynamic> json) => MacroTrigger(
  id: json['id'] as String,
  type: $enumDecode(_$TriggerTypeEnumMap, json['type']),
  name: json['name'] as String,
  configuration: json['configuration'] as Map<String, dynamic>,
  enabled: json['enabled'] as bool? ?? true,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MacroTriggerToJson(MacroTrigger instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$TriggerTypeEnumMap[instance.type]!,
      'name': instance.name,
      'configuration': instance.configuration,
      'enabled': instance.enabled,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$TriggerTypeEnumMap = {
  TriggerType.time: 'time',
  TriggerType.location: 'location',
  TriggerType.deviceState: 'device_state',
  TriggerType.appLaunch: 'app_launch',
  TriggerType.network: 'network',
  TriggerType.sensor: 'sensor',
  TriggerType.battery: 'battery',
  TriggerType.notification: 'notification',
  TriggerType.calendar: 'calendar',
  TriggerType.fileSystem: 'file_system',
  TriggerType.manual: 'manual',
  TriggerType.webhook: 'webhook',
  TriggerType.deviceConnect: 'device_connect',
  TriggerType.systemEvent: 'system_event',
};

MacroCondition _$MacroConditionFromJson(Map<String, dynamic> json) =>
    MacroCondition(
      id: json['id'] as String,
      type: $enumDecode(_$ConditionTypeEnumMap, json['type']),
      name: json['name'] as String,
      configuration: json['configuration'] as Map<String, dynamic>,
      inverted: json['inverted'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$MacroConditionToJson(MacroCondition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConditionTypeEnumMap[instance.type]!,
      'name': instance.name,
      'configuration': instance.configuration,
      'inverted': instance.inverted,
      'enabled': instance.enabled,
    };

const _$ConditionTypeEnumMap = {
  ConditionType.timeRange: 'time_range',
  ConditionType.location: 'location',
  ConditionType.deviceState: 'device_state',
  ConditionType.appRunning: 'app_running',
  ConditionType.networkStatus: 'network_status',
  ConditionType.batteryLevel: 'battery_level',
  ConditionType.variableValue: 'variable_value',
  ConditionType.dayOfWeek: 'day_of_week',
  ConditionType.orientation: 'orientation',
  ConditionType.proximity: 'proximity',
};

MacroAction _$MacroActionFromJson(Map<String, dynamic> json) => MacroAction(
  id: json['id'] as String,
  type: $enumDecode(_$ActionTypeEnumMap, json['type']),
  name: json['name'] as String,
  configuration: json['configuration'] as Map<String, dynamic>,
  order: (json['order'] as num).toInt(),
  enabled: json['enabled'] as bool? ?? true,
  continueOnError: json['continue_on_error'] as bool? ?? false,
);

Map<String, dynamic> _$MacroActionToJson(MacroAction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ActionTypeEnumMap[instance.type]!,
      'name': instance.name,
      'configuration': instance.configuration,
      'order': instance.order,
      'enabled': instance.enabled,
      'continue_on_error': instance.continueOnError,
    };

const _$ActionTypeEnumMap = {
  ActionType.systemAction: 'system_action',
  ActionType.appControl: 'app_control',
  ActionType.notification: 'notification',
  ActionType.fileOperation: 'file_operation',
  ActionType.networkRequest: 'network_request',
  ActionType.deviceControl: 'device_control',
  ActionType.soundControl: 'sound_control',
  ActionType.displayControl: 'display_control',
  ActionType.textAction: 'text_action',
  ActionType.wait: 'wait',
  ActionType.conditional: 'conditional',
  ActionType.variable: 'variable',
  ActionType.loop: 'loop',
};

MacroVariable _$MacroVariableFromJson(Map<String, dynamic> json) =>
    MacroVariable(
      name: json['name'] as String,
      type: json['type'] as String,
      value: json['value'],
      persistent: json['persistent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MacroVariableToJson(MacroVariable instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'value': instance.value,
      'persistent': instance.persistent,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

DeviceMacro _$DeviceMacroFromJson(Map<String, dynamic> json) => DeviceMacro(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  deviceId: json['device_id'] as String,
  triggers: (json['triggers'] as List<dynamic>)
      .map((e) => MacroTrigger.fromJson(e as Map<String, dynamic>))
      .toList(),
  conditions: (json['conditions'] as List<dynamic>)
      .map((e) => MacroCondition.fromJson(e as Map<String, dynamic>))
      .toList(),
  actions: (json['actions'] as List<dynamic>)
      .map((e) => MacroAction.fromJson(e as Map<String, dynamic>))
      .toList(),
  enabled: json['enabled'] as bool? ?? true,
  category: json['category'] as String? ?? 'general',
  tags:
      (json['tags'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  executionCount: (json['execution_count'] as num?)?.toInt() ?? 0,
  lastExecuted: json['last_executed'] == null
      ? null
      : DateTime.parse(json['last_executed'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  runInBackground: json['run_in_background'] as bool? ?? false,
  maxExecutionsPerDay: (json['max_executions_per_day'] as num?)?.toInt(),
);

Map<String, dynamic> _$DeviceMacroToJson(DeviceMacro instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'device_id': instance.deviceId,
      'triggers': instance.triggers,
      'conditions': instance.conditions,
      'actions': instance.actions,
      'enabled': instance.enabled,
      'category': instance.category,
      'tags': instance.tags,
      'execution_count': instance.executionCount,
      'last_executed': instance.lastExecuted?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'run_in_background': instance.runInBackground,
      'max_executions_per_day': instance.maxExecutionsPerDay,
    };

MacroExecution _$MacroExecutionFromJson(Map<String, dynamic> json) =>
    MacroExecution(
      id: json['id'] as String,
      macroId: json['macro_id'] as String,
      deviceId: json['device_id'] as String,
      triggerType: $enumDecode(_$TriggerTypeEnumMap, json['trigger_type']),
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      executionLog:
          (json['execution_log'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      errorMessage: json['error_message'] as String?,
      actionsCompleted: (json['actions_completed'] as num?)?.toInt() ?? 0,
      totalActions: (json['total_actions'] as num).toInt(),
    );

Map<String, dynamic> _$MacroExecutionToJson(MacroExecution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'macro_id': instance.macroId,
      'device_id': instance.deviceId,
      'trigger_type': _$TriggerTypeEnumMap[instance.triggerType]!,
      'status': instance.status,
      'started_at': instance.startedAt.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'execution_log': instance.executionLog,
      'error_message': instance.errorMessage,
      'actions_completed': instance.actionsCompleted,
      'total_actions': instance.totalActions,
    };

MacroTemplate _$MacroTemplateFromJson(Map<String, dynamic> json) =>
    MacroTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      template: json['template'] as Map<String, dynamic>,
      useCount: (json['use_count'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MacroTemplateToJson(MacroTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'tags': instance.tags,
      'template': instance.template,
      'use_count': instance.useCount,
      'rating': instance.rating,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
    };
