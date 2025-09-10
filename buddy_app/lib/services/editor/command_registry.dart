import 'dart:async';

/// Central command registry used by editor, palette, extensions.
class CommandRegistry {
  static final CommandRegistry I = CommandRegistry._();
  CommandRegistry._();

  final Map<String, CommandEntry> _commands = {};
  final StreamController<List<CommandEntry>> _changeController =
      StreamController.broadcast();

  Stream<List<CommandEntry>> get onChanged => _changeController.stream;

  bool register(CommandEntry entry) {
    if (_commands.containsKey(entry.id)) return false;
    _commands[entry.id] = entry;
    _changeController.add(_commands.values.toList());
    return true;
  }

  bool unregister(String id) {
    final removed = _commands.remove(id) != null;
    if (removed) _changeController.add(_commands.values.toList());
    return removed;
  }

  Future<void> run(String id) async {
    final cmd = _commands[id];
    if (cmd == null) return;
    await cmd.handler(CommandContext(execute: run));
  }

  List<CommandEntry> all({String? filter}) {
    final list = _commands.values.toList();
    if (filter == null || filter.isEmpty) return list;
    final f = filter.toLowerCase();
    return list
        .where(
          (c) =>
              c.id.toLowerCase().contains(f) ||
              c.title.toLowerCase().contains(f),
        )
        .toList();
  }
}

class CommandContext {
  final Future<void> Function(String id) execute;
  CommandContext({required this.execute});
}

class CommandEntry {
  final String id;
  final String title;
  final Future<void> Function(CommandContext ctx) handler;
  final String? category;
  CommandEntry({
    required this.id,
    required this.title,
    required this.handler,
    this.category,
  });
}
