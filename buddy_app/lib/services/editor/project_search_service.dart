import 'dart:isolate';
import 'dart:io';
import 'dart:async';

class ProjectSearchResult {
  final String file;
  final int line;
  final String snippet;
  ProjectSearchResult(this.file, this.line, this.snippet);
}

class ProjectSearchService {
  Isolate? _iso;
  SendPort? _send;
  final _pending = <int, void Function(List<ProjectSearchResult>)>{};
  int _reqId = 0;

  Future<void> start(String root) async {
    if (_iso != null) return;
    final rcv = ReceivePort();
    _iso = await Isolate.spawn(_entry, rcv.sendPort);
    _send = await rcv.first as SendPort;
    final ackPort = ReceivePort();
    _send!.send({'cmd': 'index', 'root': root, 'reply': ackPort.sendPort});
    await ackPort.first; // wait for ack
  }

  Future<List<ProjectSearchResult>> search(String term) async {
    if (_send == null) return [];
    final id = ++_reqId;
    final comp = Completer<List<ProjectSearchResult>>();
    _pending[id] = (res) => comp.complete(res);
    final rcv = ReceivePort();
    rcv.listen((msg) {
      if (msg is List && msg.isNotEmpty && msg.first is Map) {
        final results = msg
            .map(
              (m) => ProjectSearchResult(
                m['file'] as String,
                m['line'] as int,
                m['snippet'] as String,
              ),
            )
            .toList();
        if (_pending.remove(id) case final cb?) cb(results);
        rcv.close();
      }
    });
    _send!.send({
      'cmd': 'search',
      'term': term,
      'id': id,
      'reply': rcv.sendPort,
    });
    return comp.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  static void _entry(SendPort sp) {
    final rcv = ReceivePort();
    sp.send(rcv.sendPort);
    final index = <String, List<String>>{}; // file -> lines
    rcv.listen((msg) async {
      final cmd = msg['cmd'];
      if (cmd == 'index') {
        final root = msg['root'] as String;
        await for (final entity in Directory(root).list(recursive: true)) {
          if (entity is File) {
            final p = entity.path;
            if (_skip(p)) continue;
            try {
              final lines = await entity.readAsLines();
              index[p] = lines;
            } catch (_) {}
          }
        }
        (msg['reply'] as SendPort).send(true);
      } else if (cmd == 'search') {
        final term = (msg['term'] as String).toLowerCase();
        final results = <Map<String, dynamic>>[];
        for (final e in index.entries) {
          for (var i = 0; i < e.value.length; i++) {
            final line = e.value[i];
            if (line.toLowerCase().contains(term)) {
              results.add({
                'file': e.key,
                'line': i + 1,
                'snippet': line.trim(),
              });
              if (results.length >= 200) break; // cap
            }
          }
          if (results.length >= 200) break;
        }
        (msg['reply'] as SendPort).send(results);
      }
    });
  }
}

bool _skip(String p) {
  return p.contains('/.git/') ||
      p.contains('/build/') ||
      p.contains('node_modules') ||
      p.contains('.dart_tool');
}
