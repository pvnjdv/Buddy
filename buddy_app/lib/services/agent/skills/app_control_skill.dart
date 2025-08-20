import '../buddy_orchestrator.dart';

class AppControlSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.contains('navigate to') ||
        l.contains('open screen') ||
        l.contains('go to') ||
        l.contains('show me') ||
        l.contains('display') ||
        l.contains('switch to') ||
        l.contains('app control') ||
        l.contains('ui control');
  }

  Future<AgentResult> execute(String p) async {
    final l = p.toLowerCase();

    try {
      if (l.contains('flow') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToFlows();
      } else if (l.contains('note') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToNotes();
      } else if (l.contains('chat') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToChats();
      } else if (l.contains('alarm') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToAlarms();
      } else if (l.contains('contact') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToContacts();
      } else if (l.contains('setting') &&
          (l.contains('navigate') ||
              l.contains('go to') ||
              l.contains('open'))) {
        return await _navigateToSettings();
      } else {
        return AgentResult(
          handled: true,
          message:
              'I can help you navigate the app:\n'
              '• "go to flows" - Open Flows screen\n'
              '• "open notes" - Open Notes screen\n'
              '• "navigate to chats" - Open Chat screen\n'
              '• "show alarms" - Open Alarms screen\n'
              '• "go to contacts" - Open Contacts screen\n'
              '• "open settings" - Open Settings screen',
          extra: {'action': 'app_control_help'},
        );
      }
    } catch (e) {
      return AgentResult(
        handled: true,
        message: 'App control operation failed: $e',
        extra: {'error': e.toString()},
      );
    }
  }

  Future<AgentResult> _navigateToFlows() async {
    return AgentResult(
      handled: true,
      message: 'Opening Flows screen...',
      extra: {'action': 'navigate', 'screen': 'flows', 'route': '/flows'},
    );
  }

  Future<AgentResult> _navigateToNotes() async {
    return AgentResult(
      handled: true,
      message: 'Opening Notes screen...',
      extra: {'action': 'navigate', 'screen': 'notes', 'route': '/notes'},
    );
  }

  Future<AgentResult> _navigateToChats() async {
    return AgentResult(
      handled: true,
      message: 'Opening Chats screen...',
      extra: {'action': 'navigate', 'screen': 'chats', 'route': '/chats'},
    );
  }

  Future<AgentResult> _navigateToAlarms() async {
    return AgentResult(
      handled: true,
      message: 'Opening Alarms screen...',
      extra: {'action': 'navigate', 'screen': 'alarms', 'route': '/alarms'},
    );
  }

  Future<AgentResult> _navigateToContacts() async {
    return AgentResult(
      handled: true,
      message: 'Opening Contacts screen...',
      extra: {'action': 'navigate', 'screen': 'contacts', 'route': '/contacts'},
    );
  }

  Future<AgentResult> _navigateToSettings() async {
    return AgentResult(
      handled: true,
      message: 'Opening Settings screen...',
      extra: {'action': 'navigate', 'screen': 'settings', 'route': '/settings'},
    );
  }
}
