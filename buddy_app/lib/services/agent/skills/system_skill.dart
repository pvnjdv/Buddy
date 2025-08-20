import '../buddy_orchestrator.dart';
import 'dart:io';

class SystemSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.contains('system') ||
        l.contains('process') ||
        l.contains('device') ||
        l.contains('cpu') ||
        l.contains('memory') ||
        l.contains('disk') ||
        l.contains('kill process') ||
        l.contains('list processes') ||
        l.contains('dock') ||
        l.contains('device info') ||
        l.contains('schedule command');
  }

  Future<AgentResult> execute(String p) async {
    final l = p.toLowerCase();

    try {
      if (l.contains('list processes') || l.contains('show processes')) {
        return await _listProcesses();
      } else if (l.contains('kill process')) {
        return await _killProcess(p);
      } else if (l.contains('system info') || l.contains('device info')) {
        return await _getSystemInfo();
      } else if (l.contains('cpu') ||
          l.contains('memory') ||
          l.contains('disk')) {
        return await _getResourceUsage();
      } else if (l.contains('schedule command')) {
        return await _scheduleCommand(p);
      } else if (l.contains('dock')) {
        return await _dockFeatures(p);
      } else {
        return AgentResult(
          handled: true,
          message:
              'I can help you with system operations:\n'
              '• List processes: "show processes"\n'
              '• Kill process: "kill process [name/pid]"\n'
              '• System info: "device info"\n'
              '• Resource usage: "cpu memory disk"\n'
              '• Schedule commands: "schedule command [cmd]"\n'
              '• Dock features: "dock"',
          extra: {'action': 'system_help'},
        );
      }
    } catch (e) {
      return AgentResult(
        handled: true,
        message: 'System operation failed: $e',
        extra: {'error': e.toString()},
      );
    }
  }

  Future<AgentResult> _listProcesses() async {
    ProcessResult result;

    if (Platform.isLinux || Platform.isMacOS) {
      result = await Process.run('ps', ['aux']);
    } else if (Platform.isWindows) {
      result = await Process.run('tasklist', []);
    } else {
      return AgentResult(
        handled: true,
        message: 'Process listing not supported on this platform.',
        extra: {'error': 'unsupported_platform'},
      );
    }

    if (result.exitCode == 0) {
      final processes = result.stdout.toString();
      final lines = processes.split('\n');
      final topProcesses = lines.take(20).join('\n'); // Show top 20 processes

      return AgentResult(
        handled: true,
        message: 'Running processes (top 20):\n$topProcesses',
        extra: {'action': 'list_processes', 'output': processes},
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Failed to list processes: ${result.stderr}',
        extra: {'error': result.stderr},
      );
    }
  }

  Future<AgentResult> _killProcess(String prompt) async {
    // Extract process name or PID
    final pidRegex = RegExp(r'\b(\d{2,})\b');
    final nameRegex = RegExp(
      r'kill process ([a-zA-Z][a-zA-Z0-9_-]*)',
      caseSensitive: false,
    );

    String? target;
    bool isPid = false;

    final pidMatch = pidRegex.firstMatch(prompt);
    final nameMatch = nameRegex.firstMatch(prompt);

    if (pidMatch != null) {
      target = pidMatch.group(1);
      isPid = true;
    } else if (nameMatch != null) {
      target = nameMatch.group(1);
    }

    if (target == null) {
      return AgentResult(
        handled: true,
        message:
            'Please specify a process name or PID to kill. Example: "kill process chrome" or "kill process 1234"',
        extra: {'action': 'kill_process_help'},
      );
    }

    ProcessResult result;

    if (Platform.isLinux || Platform.isMacOS) {
      if (isPid) {
        result = await Process.run('kill', [target]);
      } else {
        result = await Process.run('pkill', [target]);
      }
    } else if (Platform.isWindows) {
      if (isPid) {
        result = await Process.run('taskkill', ['/PID', target, '/F']);
      } else {
        result = await Process.run('taskkill', ['/IM', '$target.exe', '/F']);
      }
    } else {
      return AgentResult(
        handled: true,
        message: 'Process killing not supported on this platform.',
        extra: {'error': 'unsupported_platform'},
      );
    }

    if (result.exitCode == 0) {
      return AgentResult(
        handled: true,
        message: 'Process $target terminated successfully.',
        extra: {'action': 'kill_process', 'target': target, 'is_pid': isPid},
      );
    } else {
      return AgentResult(
        handled: true,
        message: 'Failed to kill process $target: ${result.stderr}',
        extra: {
          'action': 'kill_process',
          'error': result.stderr,
          'target': target,
        },
      );
    }
  }

  Future<AgentResult> _getSystemInfo() async {
    final info = <String, dynamic>{};

    info['platform'] = Platform.operatingSystem;
    info['version'] = Platform.operatingSystemVersion;
    info['dart_version'] = Platform.version;

    if (Platform.isLinux || Platform.isMacOS) {
      // Get hostname
      final hostnameResult = await Process.run('hostname', []);
      if (hostnameResult.exitCode == 0) {
        info['hostname'] = hostnameResult.stdout.toString().trim();
      }

      // Get uptime
      final uptimeResult = await Process.run('uptime', []);
      if (uptimeResult.exitCode == 0) {
        info['uptime'] = uptimeResult.stdout.toString().trim();
      }
    }

    final message =
        'System Information:\n'
        'Platform: ${info['platform']}\n'
        'Version: ${info['version']}\n'
        'Hostname: ${info['hostname'] ?? 'Unknown'}\n'
        'Uptime: ${info['uptime'] ?? 'Unknown'}\n'
        'Dart Version: ${info['dart_version']}';

    return AgentResult(
      handled: true,
      message: message,
      extra: {'action': 'system_info', 'info': info},
    );
  }

  Future<AgentResult> _getResourceUsage() async {
    final usage = <String, dynamic>{};

    if (Platform.isLinux) {
      // Get CPU and memory usage
      final topResult = await Process.run('top', ['-bn1']);
      if (topResult.exitCode == 0) {
        final output = topResult.stdout.toString();
        usage['top_output'] = output;
      }

      // Get disk usage
      final dfResult = await Process.run('df', ['-h']);
      if (dfResult.exitCode == 0) {
        usage['disk_usage'] = dfResult.stdout.toString();
      }
    } else if (Platform.isMacOS) {
      // Similar commands for macOS
      final topResult = await Process.run('top', ['-l1']);
      if (topResult.exitCode == 0) {
        usage['top_output'] = topResult.stdout.toString();
      }
    }

    return AgentResult(
      handled: true,
      message:
          'Resource usage information collected. Check the extra data for details.',
      extra: {'action': 'resource_usage', 'usage': usage},
    );
  }

  Future<AgentResult> _scheduleCommand(String prompt) async {
    // Extract command to schedule
    final cmdMatch = RegExp(
      r'schedule command (.+)',
      caseSensitive: false,
    ).firstMatch(prompt);

    if (cmdMatch == null) {
      return AgentResult(
        handled: true,
        message:
            'Please specify a command to schedule. Example: "schedule command ls -la"',
        extra: {'action': 'schedule_help'},
      );
    }

    final command = cmdMatch.group(1)!;

    // For now, just simulate scheduling - in a real implementation,
    // you'd integrate with system scheduler (cron, Task Scheduler, etc.)
    return AgentResult(
      handled: true,
      message:
          'Command scheduling is not yet fully implemented. Command to schedule: "$command"',
      extra: {
        'action': 'schedule_command',
        'command': command,
        'status': 'simulated',
      },
    );
  }

  Future<AgentResult> _dockFeatures(String prompt) async {
    final features = [
      '🖥️ Device Management: List and control connected devices',
      '📊 Process Monitor: Real-time process monitoring and control',
      '⚡ Resource Dashboard: CPU, Memory, Disk usage visualization',
      '⏰ Task Scheduler: Schedule commands and macros',
      '🔧 System Tools: Quick access to system utilities',
      '📱 App Launcher: Launch applications and manage services',
    ];

    return AgentResult(
      handled: true,
      message: 'Buddy Dock Features:\n${features.join('\n')}',
      extra: {
        'action': 'dock_features',
        'features': features,
        'status': 'available',
      },
    );
  }
}
