import '../../flow_service.dart';
import '../../../models/flow_models.dart';
import '../buddy_orchestrator.dart';

class MeetingsSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.contains('schedule meeting') || l.startsWith('meeting:');
  }

  Future<AgentResult> execute(String p) async {
    // Create a draft meeting note
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Meeting: ${p.length > 40 ? p.substring(0, 40) : p}',
      content: p,
      labels: const ['meeting'],
      color: NoteColors.white,
      isPinned: false,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      type: NoteType.text,
    );
    final created = await FlowService.createNote(note);
    return AgentResult(
      handled: true,
      message: 'Meeting draft created in Notes.',
      extra: {'meeting_note': created.toJson()},
    );
  }
}
