import 'dart:async';
import '../../models/flow_models.dart';
import 'skills/flow_skill.dart';
import 'skills/notes_skill.dart';
import 'skills/alarms_skill.dart';
import 'skills/meetings_skill.dart';
import 'skills/contacts_skill.dart';
import 'skills/github_skill.dart';
import 'skills/system_skill.dart';
import 'skills/app_control_skill.dart';
import '../ai/ai_thinking_service.dart';

class AgentResult {
  final bool handled;
  final String message;
  final ProjectFlow? flow;
  final Note? note;
  final FlowAlarm? alarm;
  final Map<String, dynamic>? extra;

  AgentResult({
    required this.handled,
    required this.message,
    this.flow,
    this.note,
    this.alarm,
    this.extra,
  });

  static AgentResult notHandled() => AgentResult(handled: false, message: '');

  static AgentResult custom({
    required String message,
    required bool handled,
    ProjectFlow? flow,
    Note? note,
    FlowAlarm? alarm,
    Map<String, dynamic>? extra,
  }) => AgentResult(
    handled: handled,
    message: message,
    flow: flow,
    note: note,
    alarm: alarm,
    extra: extra,
  );
}

class BuddyOrchestrator {
  final FlowSkill _flow = FlowSkill();
  final NotesSkill _notes = NotesSkill();
  final AlarmsSkill _alarms = AlarmsSkill();
  final MeetingsSkill _meetings = MeetingsSkill();
  final ContactsSkill _contacts = ContactsSkill();
  final GitHubSkill _github = GitHubSkill();
  final SystemSkill _system = SystemSkill();
  final AppControlSkill _appControl = AppControlSkill();

  Future<AgentResult> handle(String prompt) async {
    final p = prompt.trim();

    // Enhanced AI thinking process - comprehensive analysis
    final analysis = AIThinkingService.analyzeIntent(p);
    final strategy = AIThinkingService.generateResponseStrategy(analysis);

    print('🤖 Buddy AI analyzing: "$p"');
    print('🧠 Advanced Analysis:');
    print(
      '   Primary intent: ${analysis['primary_intent']} (${(analysis['primary_confidence'] * 100).toInt()}%)',
    );
    print(
      '   Complexity: ${analysis['complexity_score'].toStringAsFixed(1)}/10',
    );
    print('   Processing strategy: ${strategy['response_type']}');
    print('   Execution priority: ${strategy['execution_priority']}/10');

    // Show reasoning chain for transparency
    final reasoning = analysis['reasoning_chain'] as List<String>;
    for (final step in reasoning) {
      print('   $step');
    }

    // Handle multi-step processing if required
    if (strategy['multi_step_required'] == true) {
      print('📋 Multi-step execution plan:');
      final plan = strategy['execution_plan'] as List<Map<String, dynamic>>;
      for (final step in plan) {
        print(
          '   Step ${step['step']}: ${step['description']} (${step['estimated_duration']})',
        );
      }
    }

    // Try skills in intelligent order based on analysis
    final primaryIntent = analysis['primary_intent'] as String;

    // Priority-based skill routing
    switch (primaryIntent) {
      case 'flow_creation':
        if (_flow.matches(p)) return await _flow.execute(p);
        break;
      case 'github_operations':
        if (_github.matches(p)) return await _github.execute(p);
        break;
      case 'system_control':
        if (_system.matches(p)) return await _system.execute(p);
        break;
      case 'app_navigation':
        if (_appControl.matches(p)) return await _appControl.execute(p);
        break;
      case 'communication':
        if (_meetings.matches(p)) return await _meetings.execute(p);
        if (_contacts.matches(p)) return await _contacts.execute(p);
        break;
      case 'task_management':
        if (_alarms.matches(p)) return await _alarms.execute(p);
        if (_notes.matches(p)) return await _notes.execute(p);
        break;
    }

    // Fallback to original order for edge cases
    if (_flow.matches(p)) return await _flow.execute(p);
    if (_github.matches(p)) return await _github.execute(p);
    if (_system.matches(p)) return await _system.execute(p);
    if (_appControl.matches(p)) return await _appControl.execute(p);
    if (_meetings.matches(p)) return await _meetings.execute(p);
    if (_contacts.matches(p)) return await _contacts.execute(p);
    if (_alarms.matches(p)) return await _alarms.execute(p);
    if (_notes.matches(p)) return await _notes.execute(p);

    // Enhanced not handled response with suggestions
    final suggestions = _generateSuggestions(analysis);
    return AgentResult.custom(
      message:
          'I understand you want to ${analysis['primary_intent']}, but I need more specific information. ${suggestions.join(' ')}',
      handled: false,
      extra: {
        'analysis': analysis,
        'strategy': strategy,
        'suggestions': suggestions,
      },
    );
  }

  List<String> _generateSuggestions(Map<String, dynamic> analysis) {
    final suggestions = <String>[];
    final primaryIntent = analysis['primary_intent'] as String;

    switch (primaryIntent) {
      case 'flow_creation':
        suggestions.add('Try: "Create a flow for mobile app development"');
        break;
      case 'github_operations':
        suggestions.add(
          'Try: "Clone repository from GitHub" or "Commit changes to my project"',
        );
        break;
      case 'system_control':
        suggestions.add(
          'Try: "Show running processes" or "Kill process with PID 1234"',
        );
        break;
      case 'app_navigation':
        suggestions.add(
          'Try: "Navigate to flows screen" or "Show me the notes section"',
        );
        break;
      case 'communication':
        suggestions.add('Try: "Schedule a meeting" or "Show my contacts"');
        break;
      case 'task_management':
        suggestions.add(
          'Try: "Set reminder for tomorrow" or "Create a note about project ideas"',
        );
        break;
      default:
        suggestions.add(
          'Try asking me to create a flow, manage your notes, or navigate the app.',
        );
    }

    return suggestions;
  }
}
