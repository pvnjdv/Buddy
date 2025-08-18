import '../buddy_orchestrator.dart';

class ContactsSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.startsWith('message ') ||
        l.startsWith('talk to ') ||
        l.startsWith('send to ');
  }

  Future<AgentResult> execute(String p) async {
    // Minimal parse: message John Hi there
    final parts = p.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final name = parts[1];
      final msg = p.substring(p.indexOf(name) + name.length).trim();
      // Open chat UI prefilling the message would be implemented in UI layer.
      return AgentResult(
        handled: true,
        message: 'Ready to message $name: "$msg". Opening chat composer...',
        extra: {'contact': name, 'draft': msg},
      );
    }
    return AgentResult(
      handled: true,
      message: 'Whom should I message and what?',
      extra: {},
    );
  }
}
