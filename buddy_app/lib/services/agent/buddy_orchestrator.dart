import 'dart:async';
import '../../models/flow_models.dart';
import 'skills/flow_skill.dart';
import 'skills/notes_skill.dart';
import 'skills/alarms_skill.dart';
import 'skills/meetings_skill.dart';
import 'skills/contacts_skill.dart';

class AgentResult {
  final bool handled;
  final String message;
  final ProjectFlow? flow;
  final Map<String, dynamic>? extra;

  AgentResult({
    required this.handled,
    required this.message,
    this.flow,
    this.extra,
  });

  static AgentResult notHandled() => AgentResult(handled: false, message: '');
}

class BuddyOrchestrator {
  final FlowSkill _flow = FlowSkill();
  final NotesSkill _notes = NotesSkill();
  final AlarmsSkill _alarms = AlarmsSkill();
  final MeetingsSkill _meetings = MeetingsSkill();
  final ContactsSkill _contacts = ContactsSkill();

  Future<AgentResult> handle(String prompt) async {
    final p = prompt.trim();
    if (_flow.matches(p)) return await _flow.execute(p);
    if (_notes.matches(p)) return await _notes.execute(p);
    if (_alarms.matches(p)) return await _alarms.execute(p);
    if (_meetings.matches(p)) return await _meetings.execute(p);
    if (_contacts.matches(p)) return await _contacts.execute(p);
    return AgentResult.notHandled();
  }
}
