// Device Models for Cross-Platform Control
class ConnectedDevice {
  final String id;
  final String name;
  final DeviceType type;
  final String platform; // Windows, macOS, Linux, Android, iOS
  final bool isOnline;
  final DeviceStatus status;
  final DateTime lastSeen;
  final String? ipAddress;
  final Map<String, dynamic> capabilities;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.platform,
    required this.isOnline,
    required this.status,
    required this.lastSeen,
    this.ipAddress,
    this.capabilities = const {},
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      type: DeviceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DeviceType.unknown,
      ),
      platform: json['platform'] ?? 'Unknown',
      isOnline: json['is_online'] ?? false,
      status: DeviceStatus.fromJson(json['status'] ?? {}),
      lastSeen: DateTime.parse(
        json['last_seen'] ?? DateTime.now().toIso8601String(),
      ),
      ipAddress: json['ip_address'],
      capabilities: json['capabilities'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'platform': platform,
      'is_online': isOnline,
      'status': status.toJson(),
      'last_seen': lastSeen.toIso8601String(),
      'ip_address': ipAddress,
      'capabilities': capabilities,
    };
  }
}

enum DeviceType { desktop, laptop, mobile, tablet, server, iot, unknown }

class DeviceStatus {
  final double cpuUsage; // 0-100
  final double memoryUsage; // 0-100
  final double? gpuUsage; // 0-100, null if no GPU
  final double diskUsage; // 0-100
  final double networkUpload; // KB/s
  final double networkDownload; // KB/s
  final int batteryLevel; // 0-100, -1 if no battery
  final bool isCharging;
  final double temperature; // Celsius
  final List<RunningProcess> topProcesses;
  final Map<String, dynamic> customMetrics;

  DeviceStatus({
    required this.cpuUsage,
    required this.memoryUsage,
    this.gpuUsage,
    required this.diskUsage,
    required this.networkUpload,
    required this.networkDownload,
    required this.batteryLevel,
    required this.isCharging,
    required this.temperature,
    required this.topProcesses,
    this.customMetrics = const {},
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      cpuUsage: (json['cpu_usage'] ?? 0.0).toDouble(),
      memoryUsage: (json['memory_usage'] ?? 0.0).toDouble(),
      gpuUsage: json['gpu_usage']?.toDouble(),
      diskUsage: (json['disk_usage'] ?? 0.0).toDouble(),
      networkUpload: (json['network_upload'] ?? 0.0).toDouble(),
      networkDownload: (json['network_download'] ?? 0.0).toDouble(),
      batteryLevel: json['battery_level'] ?? -1,
      isCharging: json['is_charging'] ?? false,
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      topProcesses:
          (json['top_processes'] as List<dynamic>?)
              ?.map((p) => RunningProcess.fromJson(p))
              .toList() ??
          [],
      customMetrics: json['custom_metrics'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'gpu_usage': gpuUsage,
      'disk_usage': diskUsage,
      'network_upload': networkUpload,
      'network_download': networkDownload,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'temperature': temperature,
      'top_processes': topProcesses.map((p) => p.toJson()).toList(),
      'custom_metrics': customMetrics,
    };
  }
}

class RunningProcess {
  final String name;
  final int pid;
  final double cpuUsage;
  final double memoryUsage; // MB
  final String status;
  final DateTime startTime;

  RunningProcess({
    required this.name,
    required this.pid,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.status,
    required this.startTime,
  });

  factory RunningProcess.fromJson(Map<String, dynamic> json) {
    return RunningProcess(
      name: json['name'] ?? '',
      pid: json['pid'] ?? 0,
      cpuUsage: (json['cpu_usage'] ?? 0.0).toDouble(),
      memoryUsage: (json['memory_usage'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'running',
      startTime: DateTime.parse(
        json['start_time'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pid': pid,
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'status': status,
      'start_time': startTime.toIso8601String(),
    };
  }
}

// Macro and Automation Models
class DockMacro {
  final String id;
  final String name;
  final String description;
  final String targetDeviceId; // '*' for all devices
  final List<MacroStep> steps;
  final MacroTrigger? trigger;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastExecuted;
  final MacroExecution? currentExecution;

  DockMacro({
    required this.id,
    required this.name,
    required this.description,
    required this.targetDeviceId,
    required this.steps,
    this.trigger,
    required this.isEnabled,
    required this.createdAt,
    this.lastExecuted,
    this.currentExecution,
  });

  factory DockMacro.fromJson(Map<String, dynamic> json) {
    return DockMacro(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      targetDeviceId: json['target_device_id'] ?? '',
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((s) => MacroStep.fromJson(s))
              .toList() ??
          [],
      trigger: json['trigger'] != null
          ? MacroTrigger.fromJson(json['trigger'])
          : null,
      isEnabled: json['is_enabled'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastExecuted: json['last_executed'] != null
          ? DateTime.parse(json['last_executed'])
          : null,
      currentExecution: json['current_execution'] != null
          ? MacroExecution.fromJson(json['current_execution'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'target_device_id': targetDeviceId,
      'steps': steps.map((s) => s.toJson()).toList(),
      'trigger': trigger?.toJson(),
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'last_executed': lastExecuted?.toIso8601String(),
      'current_execution': currentExecution?.toJson(),
    };
  }
}

class MacroStep {
  final String id;
  final MacroAction action;
  final Map<String, dynamic> parameters;
  final Duration? delay;
  final String? condition; // JavaScript expression
  final int order;

  MacroStep({
    required this.id,
    required this.action,
    required this.parameters,
    this.delay,
    this.condition,
    required this.order,
  });

  factory MacroStep.fromJson(Map<String, dynamic> json) {
    return MacroStep(
      id: json['id'] ?? '',
      action: MacroAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => MacroAction.unknown,
      ),
      parameters: json['parameters'] ?? {},
      delay: json['delay'] != null
          ? Duration(milliseconds: json['delay'])
          : null,
      condition: json['condition'],
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'parameters': parameters,
      'delay': delay?.inMilliseconds,
      'condition': condition,
      'order': order,
    };
  }
}

enum MacroAction {
  runCommand,
  openApp,
  closeApp,
  sendKeys,
  mouseClick,
  fileOperation,
  systemControl,
  networkRequest,
  waitFor,
  conditional,
  loop,
  unknown,
}

class MacroTrigger {
  final TriggerType type;
  final Map<String, dynamic> conditions;
  final bool isEnabled;

  MacroTrigger({
    required this.type,
    required this.conditions,
    required this.isEnabled,
  });

  factory MacroTrigger.fromJson(Map<String, dynamic> json) {
    return MacroTrigger(
      type: TriggerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TriggerType.manual,
      ),
      conditions: json['conditions'] ?? {},
      isEnabled: json['is_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'conditions': conditions,
      'is_enabled': isEnabled,
    };
  }
}

enum TriggerType {
  manual,
  schedule,
  deviceEvent,
  systemMetric,
  flowEvent,
  buddyCommand,
}

class MacroExecution {
  final String id;
  final String macroId;
  final DateTime startTime;
  final DateTime? endTime;
  final ExecutionStatus status;
  final int currentStepIndex;
  final String? error;
  final Map<String, dynamic> logs;
  final double progress; // 0.0 to 1.0

  MacroExecution({
    required this.id,
    required this.macroId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.currentStepIndex,
    this.error,
    this.logs = const {},
    required this.progress,
  });

  factory MacroExecution.fromJson(Map<String, dynamic> json) {
    return MacroExecution(
      id: json['id'] ?? '',
      macroId: json['macro_id'] ?? '',
      startTime: DateTime.parse(
        json['start_time'] ?? DateTime.now().toIso8601String(),
      ),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      status: ExecutionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionStatus.pending,
      ),
      currentStepIndex: json['current_step_index'] ?? 0,
      error: json['error'],
      logs: json['logs'] ?? {},
      progress: (json['progress'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'macro_id': macroId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status.name,
      'current_step_index': currentStepIndex,
      'error': error,
      'logs': logs,
      'progress': progress,
    };
  }
}

enum ExecutionStatus { pending, running, paused, completed, failed, cancelled }

// Intelligent Automation Models
class AutomationRule {
  final String id;
  final String name;
  final String description;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final bool isEnabled;
  final int priority;
  final DateTime createdAt;
  final DateTime? lastTriggered;

  AutomationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.conditions,
    required this.actions,
    required this.isEnabled,
    required this.priority,
    required this.createdAt,
    this.lastTriggered,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      conditions:
          (json['conditions'] as List<dynamic>?)
              ?.map((c) => AutomationCondition.fromJson(c))
              .toList() ??
          [],
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map((a) => AutomationAction.fromJson(a))
              .toList() ??
          [],
      isEnabled: json['is_enabled'] ?? false,
      priority: json['priority'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastTriggered: json['last_triggered'] != null
          ? DateTime.parse(json['last_triggered'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'is_enabled': isEnabled,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'last_triggered': lastTriggered?.toIso8601String(),
    };
  }
}

class AutomationCondition {
  final String type; // device_metric, time, flow_event, etc.
  final String target; // device_id, flow_id, etc.
  final String operator; // >, <, ==, contains, etc.
  final dynamic value;
  final Map<String, dynamic> metadata;

  AutomationCondition({
    required this.type,
    required this.target,
    required this.operator,
    required this.value,
    this.metadata = const {},
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      type: json['type'] ?? '',
      target: json['target'] ?? '',
      operator: json['operator'] ?? '',
      value: json['value'],
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'target': target,
      'operator': operator,
      'value': value,
      'metadata': metadata,
    };
  }
}

class AutomationAction {
  final String type; // execute_macro, create_flow, send_notification, etc.
  final String target;
  final Map<String, dynamic> parameters;

  AutomationAction({
    required this.type,
    required this.target,
    required this.parameters,
  });

  factory AutomationAction.fromJson(Map<String, dynamic> json) {
    return AutomationAction(
      type: json['type'] ?? '',
      target: json['target'] ?? '',
      parameters: json['parameters'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'target': target, 'parameters': parameters};
  }
}
