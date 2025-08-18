import '../../flow_service.dart';
import '../../../models/flow_models.dart';
import '../buddy_orchestrator.dart';

class NotesSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.startsWith('note:') ||
        l.startsWith('create note') ||
        l.startsWith('add note');
  }

  Future<AgentResult> execute(String p) async {
    var text = p.trim();
    if (text.toLowerCase().startsWith('note:')) {
      text = text.substring(5).trim();
    } else if (text.toLowerCase().startsWith('create note')) {
      text = text.substring('create note'.length).trim();
    } else if (text.toLowerCase().startsWith('add note')) {
      text = text.substring('add note'.length).trim();
    }

    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text.isEmpty
          ? 'New Note'
          : (text.length > 60 ? text.substring(0, 60) : text),
      content: text.length > 60 ? text.substring(60) : '',
      labels: const [],
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
      message: 'Note created: ${created.title}',
      extra: {'note': created.toJson()},
    );
  }
}
