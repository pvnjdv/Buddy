// lib/models/terminal_models.dart
import 'package:flutter/material.dart';

class TerminalSession {
  final String id;
  final String deviceId;
  final String name;
  final bool isActive;
  final String workingDirectory;
  final List<TerminalOutput> output;
  final DateTime createdAt;
  final Map<String, String> environmentVariables;

  TerminalSession({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.isActive,
    required this.workingDirectory,
    List<TerminalOutput>? output,
    DateTime? createdAt,
    Map<String, String>? environmentVariables,
  }) : output = output ?? [],
       createdAt = createdAt ?? DateTime.now(),
       environmentVariables = environmentVariables ?? {};

  TerminalSession copyWith({
    String? name,
    bool? isActive,
    String? workingDirectory,
    List<TerminalOutput>? output,
    Map<String, String>? environmentVariables,
  }) {
    return TerminalSession(
      id: id,
      deviceId: deviceId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      output: output ?? this.output,
      createdAt: createdAt,
      environmentVariables: environmentVariables ?? this.environmentVariables,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': name,
      'is_active': isActive,
      'working_directory': workingDirectory,
      'output': output.map((o) => o.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'environment_variables': environmentVariables,
    };
  }

  factory TerminalSession.fromJson(Map<String, dynamic> json) {
    return TerminalSession(
      id: json['id'],
      deviceId: json['device_id'],
      name: json['name'],
      isActive: json['is_active'] ?? false,
      workingDirectory: json['working_directory'] ?? '~',
      output:
          (json['output'] as List?)
              ?.map((o) => TerminalOutput.fromJson(o))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      environmentVariables: Map<String, String>.from(
        json['environment_variables'] ?? {},
      ),
    );
  }
}

class TerminalOutput {
  final String text;
  final DateTime timestamp;
  final bool isError;
  final bool isSuccess;
  final bool isWarning;
  final bool isCommand;
  final String? commandId;

  TerminalOutput({
    required this.text,
    DateTime? timestamp,
    this.isError = false,
    this.isSuccess = false,
    this.isWarning = false,
    this.isCommand = false,
    this.commandId,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'is_error': isError,
      'is_success': isSuccess,
      'is_warning': isWarning,
      'is_command': isCommand,
      'command_id': commandId,
    };
  }

  factory TerminalOutput.fromJson(Map<String, dynamic> json) {
    return TerminalOutput(
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isError: json['is_error'] ?? false,
      isSuccess: json['is_success'] ?? false,
      isWarning: json['is_warning'] ?? false,
      isCommand: json['is_command'] ?? false,
      commandId: json['command_id'],
    );
  }
}

class TerminalCommand {
  final String id;
  final String name;
  final String description;
  final String command;
  final String category;
  final IconData icon;
  final bool requiresConfirmation;
  final Map<String, dynamic> parameters;
  final List<String> supportedPlatforms;

  TerminalCommand({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    required this.category,
    required this.icon,
    this.requiresConfirmation = false,
    Map<String, dynamic>? parameters,
    List<String>? supportedPlatforms,
  }) : parameters = parameters ?? {},
       supportedPlatforms = supportedPlatforms ?? ['all'];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'command': command,
      'category': category,
      'icon': icon.codePoint,
      'requires_confirmation': requiresConfirmation,
      'parameters': parameters,
      'supported_platforms': supportedPlatforms,
    };
  }

  factory TerminalCommand.fromJson(Map<String, dynamic> json) {
    return TerminalCommand(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      command: json['command'],
      category: json['category'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      requiresConfirmation: json['requires_confirmation'] ?? false,
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      supportedPlatforms: List<String>.from(
        json['supported_platforms'] ?? ['all'],
      ),
    );
  }
}

class TerminalExecutionResult {
  final bool success;
  final String output;
  final String? error;
  final int exitCode;
  final String? workingDirectory;
  final Duration executionTime;
  final Map<String, String> environmentVariables;

  TerminalExecutionResult({
    required this.success,
    required this.output,
    this.error,
    required this.exitCode,
    this.workingDirectory,
    required this.executionTime,
    Map<String, String>? environmentVariables,
  }) : environmentVariables = environmentVariables ?? {};

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'output': output,
      'error': error,
      'exit_code': exitCode,
      'working_directory': workingDirectory,
      'execution_time_ms': executionTime.inMilliseconds,
      'environment_variables': environmentVariables,
    };
  }

  factory TerminalExecutionResult.fromJson(Map<String, dynamic> json) {
    return TerminalExecutionResult(
      success: json['success'],
      output: json['output'] ?? '',
      error: json['error'],
      exitCode: json['exit_code'] ?? 0,
      workingDirectory: json['working_directory'],
      executionTime: Duration(milliseconds: json['execution_time_ms'] ?? 0),
      environmentVariables: Map<String, String>.from(
        json['environment_variables'] ?? {},
      ),
    );
  }
}

class TerminalScript {
  final String id;
  final String name;
  final String description;
  final List<String> commands;
  final Map<String, dynamic> parameters;
  final String category;
  final bool isAutomated;
  final Duration estimatedDuration;

  TerminalScript({
    required this.id,
    required this.name,
    required this.description,
    required this.commands,
    Map<String, dynamic>? parameters,
    required this.category,
    this.isAutomated = false,
    Duration? estimatedDuration,
  }) : parameters = parameters ?? {},
       estimatedDuration = estimatedDuration ?? const Duration(seconds: 30);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'commands': commands,
      'parameters': parameters,
      'category': category,
      'is_automated': isAutomated,
      'estimated_duration_ms': estimatedDuration.inMilliseconds,
    };
  }

  factory TerminalScript.fromJson(Map<String, dynamic> json) {
    return TerminalScript(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      commands: List<String>.from(json['commands']),
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      category: json['category'],
      isAutomated: json['is_automated'] ?? false,
      estimatedDuration: Duration(
        milliseconds: json['estimated_duration_ms'] ?? 30000,
      ),
    );
  }
}

class TerminalWorkflow {
  final String id;
  final String name;
  final String description;
  final List<TerminalScript> scripts;
  final Map<String, dynamic> configuration;
  final bool isScheduled;
  final DateTime? scheduledTime;

  TerminalWorkflow({
    required this.id,
    required this.name,
    required this.description,
    required this.scripts,
    Map<String, dynamic>? configuration,
    this.isScheduled = false,
    this.scheduledTime,
  }) : configuration = configuration ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'scripts': scripts.map((s) => s.toJson()).toList(),
      'configuration': configuration,
      'is_scheduled': isScheduled,
      'scheduled_time': scheduledTime?.toIso8601String(),
    };
  }

  factory TerminalWorkflow.fromJson(Map<String, dynamic> json) {
    return TerminalWorkflow(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      scripts: (json['scripts'] as List)
          .map((s) => TerminalScript.fromJson(s))
          .toList(),
      configuration: Map<String, dynamic>.from(json['configuration'] ?? {}),
      isScheduled: json['is_scheduled'] ?? false,
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'])
          : null,
    );
  }
}
