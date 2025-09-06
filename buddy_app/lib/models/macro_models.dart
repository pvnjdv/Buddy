// MacroDroid-style Macro Automation Models
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'macro_models.g.dart';

// Macro Trigger Types (What starts the macro)
enum TriggerType {
  @JsonValue('time')
  time,
  @JsonValue('location')
  location,
  @JsonValue('device_state')
  deviceState,
  @JsonValue('app_launch')
  appLaunch,
  @JsonValue('network')
  network,
  @JsonValue('sensor')
  sensor,
  @JsonValue('battery')
  battery,
  @JsonValue('notification')
  notification,
  @JsonValue('calendar')
  calendar,
  @JsonValue('file_system')
  fileSystem,
  @JsonValue('manual')
  manual,
  @JsonValue('webhook')
  webhook,
  @JsonValue('device_connect')
  deviceConnect,
  @JsonValue('system_event')
  systemEvent,
}

// Macro Action Types (What the macro does)
enum ActionType {
  @JsonValue('system_action')
  systemAction,
  @JsonValue('app_control')
  appControl,
  @JsonValue('notification')
  notification,
  @JsonValue('file_operation')
  fileOperation,
  @JsonValue('network_request')
  networkRequest,
  @JsonValue('device_control')
  deviceControl,
  @JsonValue('sound_control')
  soundControl,
  @JsonValue('display_control')
  displayControl,
  @JsonValue('text_action')
  textAction,
  @JsonValue('wait')
  wait,
  @JsonValue('conditional')
  conditional,
  @JsonValue('variable')
  variable,
  @JsonValue('loop')
  loop,
}

// Condition Types (What must be true for the macro to run)
enum ConditionType {
  @JsonValue('time_range')
  timeRange,
  @JsonValue('location')
  location,
  @JsonValue('device_state')
  deviceState,
  @JsonValue('app_running')
  appRunning,
  @JsonValue('network_status')
  networkStatus,
  @JsonValue('battery_level')
  batteryLevel,
  @JsonValue('variable_value')
  variableValue,
  @JsonValue('day_of_week')
  dayOfWeek,
  @JsonValue('orientation')
  orientation,
  @JsonValue('proximity')
  proximity,
}

@JsonSerializable()
class MacroTrigger {
  final String id;
  final TriggerType type;
  final String name;
  final Map<String, dynamic> configuration;
  final bool enabled;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  MacroTrigger({
    required this.id,
    required this.type,
    required this.name,
    required this.configuration,
    this.enabled = true,
    required this.createdAt,
  });

  factory MacroTrigger.fromJson(Map<String, dynamic> json) =>
      _$MacroTriggerFromJson(json);
  Map<String, dynamic> toJson() => _$MacroTriggerToJson(this);

  // Helper getters for common configurations
  String? get timeConfiguration => configuration['time'] as String?;
  Map<String, double>? get locationConfiguration =>
      configuration['location'] as Map<String, double>?;
  String? get deviceStateConfiguration =>
      configuration['device_state'] as String?;
  String? get appConfiguration => configuration['app'] as String?;
}

@JsonSerializable()
class MacroCondition {
  final String id;
  final ConditionType type;
  final String name;
  final Map<String, dynamic> configuration;
  final bool inverted; // NOT condition
  final bool enabled;

  MacroCondition({
    required this.id,
    required this.type,
    required this.name,
    required this.configuration,
    this.inverted = false,
    this.enabled = true,
  });

  factory MacroCondition.fromJson(Map<String, dynamic> json) =>
      _$MacroConditionFromJson(json);
  Map<String, dynamic> toJson() => _$MacroConditionToJson(this);
}

@JsonSerializable()
class MacroAction {
  final String id;
  final ActionType type;
  final String name;
  final Map<String, dynamic> configuration;
  final int order;
  final bool enabled;
  @JsonKey(name: 'continue_on_error')
  final bool continueOnError;

  MacroAction({
    required this.id,
    required this.type,
    required this.name,
    required this.configuration,
    required this.order,
    this.enabled = true,
    this.continueOnError = false,
  });

  factory MacroAction.fromJson(Map<String, dynamic> json) =>
      _$MacroActionFromJson(json);
  Map<String, dynamic> toJson() => _$MacroActionToJson(this);

  // Helper getters for common configurations
  String? get command => configuration['command'] as String?;
  String? get appName => configuration['app_name'] as String?;
  String? get message => configuration['message'] as String?;
  String? get filePath => configuration['file_path'] as String?;
  int? get delayMs => configuration['delay_ms'] as int?;
  Map<String, dynamic>? get deviceControl =>
      configuration['device_control'] as Map<String, dynamic>?;
}

@JsonSerializable()
class MacroVariable {
  final String name;
  final String type; // string, number, boolean, array, object
  dynamic value;
  final bool persistent; // Survives app restart
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  DateTime updatedAt;

  MacroVariable({
    required this.name,
    required this.type,
    required this.value,
    this.persistent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MacroVariable.fromJson(Map<String, dynamic> json) =>
      _$MacroVariableFromJson(json);
  Map<String, dynamic> toJson() => _$MacroVariableToJson(this);
}

@JsonSerializable()
class DeviceMacro {
  final String id;
  final String name;
  final String description;
  @JsonKey(name: 'device_id')
  final String deviceId;
  final List<MacroTrigger> triggers;
  final List<MacroCondition> conditions;
  final List<MacroAction> actions;
  final bool enabled;
  final String category;
  final Map<String, String> tags;
  @JsonKey(name: 'execution_count')
  final int executionCount;
  @JsonKey(name: 'last_executed')
  final DateTime? lastExecuted;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'run_in_background')
  final bool runInBackground;
  @JsonKey(name: 'max_executions_per_day')
  final int? maxExecutionsPerDay;

  DeviceMacro({
    required this.id,
    required this.name,
    required this.description,
    required this.deviceId,
    required this.triggers,
    required this.conditions,
    required this.actions,
    this.enabled = true,
    this.category = 'general',
    this.tags = const {},
    this.executionCount = 0,
    this.lastExecuted,
    required this.createdAt,
    required this.updatedAt,
    this.runInBackground = false,
    this.maxExecutionsPerDay,
  });

  factory DeviceMacro.fromJson(Map<String, dynamic> json) =>
      _$DeviceMacroFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceMacroToJson(this);

  // Helper methods
  bool get hasConditions => conditions.isNotEmpty;
  bool get hasMultipleTriggers => triggers.length > 1;
  int get totalSteps => triggers.length + conditions.length + actions.length;

  String get statusText {
    if (!enabled) return 'Disabled';
    if (lastExecuted == null) return 'Never run';
    final timeSince = DateTime.now().difference(lastExecuted!);
    if (timeSince.inMinutes < 1) return 'Just ran';
    if (timeSince.inHours < 1) return '${timeSince.inMinutes}m ago';
    if (timeSince.inDays < 1) return '${timeSince.inHours}h ago';
    return '${timeSince.inDays}d ago';
  }
}

@JsonSerializable()
class MacroExecution {
  final String id;
  @JsonKey(name: 'macro_id')
  final String macroId;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'trigger_type')
  final TriggerType triggerType;
  final String status; // 'running', 'completed', 'failed', 'cancelled'
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'execution_log')
  final List<Map<String, dynamic>> executionLog;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'actions_completed')
  final int actionsCompleted;
  @JsonKey(name: 'total_actions')
  final int totalActions;

  MacroExecution({
    required this.id,
    required this.macroId,
    required this.deviceId,
    required this.triggerType,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.executionLog = const [],
    this.errorMessage,
    this.actionsCompleted = 0,
    required this.totalActions,
  });

  factory MacroExecution.fromJson(Map<String, dynamic> json) =>
      _$MacroExecutionFromJson(json);
  Map<String, dynamic> toJson() => _$MacroExecutionToJson(this);

  double get progressPercentage {
    if (totalActions == 0) return 0.0;
    return (actionsCompleted / totalActions) * 100;
  }

  Duration? get executionDuration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }
}

@JsonSerializable()
class MacroTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> tags;
  final Map<String, dynamic> template;
  @JsonKey(name: 'use_count')
  final int useCount;
  final double rating;
  @JsonKey(name: 'created_by')
  final String createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  MacroTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.tags,
    required this.template,
    this.useCount = 0,
    this.rating = 0.0,
    required this.createdBy,
    required this.createdAt,
  });

  factory MacroTemplate.fromJson(Map<String, dynamic> json) =>
      _$MacroTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$MacroTemplateToJson(this);
}

// Macro Categories
class MacroCategories {
  static const String automation = 'automation';
  static const String productivity = 'productivity';
  static const String entertainment = 'entertainment';
  static const String security = 'security';
  static const String communication = 'communication';
  static const String system = 'system';
  static const String development = 'development';
  static const String general = 'general';

  static List<String> get all => [
    automation,
    productivity,
    entertainment,
    security,
    communication,
    system,
    development,
    general,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case automation:
        return 'Automation';
      case productivity:
        return 'Productivity';
      case entertainment:
        return 'Entertainment';
      case security:
        return 'Security';
      case communication:
        return 'Communication';
      case system:
        return 'System';
      case development:
        return 'Development';
      case general:
        return 'General';
      default:
        return category;
    }
  }

  static IconData getIcon(String category) {
    switch (category) {
      case automation:
        return Icons.settings_input_component;
      case productivity:
        return Icons.work;
      case entertainment:
        return Icons.play_circle;
      case security:
        return Icons.security;
      case communication:
        return Icons.message;
      case system:
        return Icons.computer;
      case development:
        return Icons.code;
      case general:
        return Icons.category;
      default:
        return Icons.category;
    }
  }
}
