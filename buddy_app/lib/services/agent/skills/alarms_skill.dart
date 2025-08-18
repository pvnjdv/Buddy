import '../../../models/flow_models.dart';
import '../../flow_service.dart';
import '../buddy_orchestrator.dart';

class AlarmsSkill {
  bool matches(String p) {
    final l = p.toLowerCase();
    return l.startsWith('alarm:') ||
        l.startsWith('remind me to') ||
        l.startsWith('set a reminder to') ||
        l.startsWith('reminder:');
  }

  Future<AgentResult> execute(String p) async {
    var text = p.trim();
    if (text.toLowerCase().startsWith('alarm:')) {
      text = text.substring(6).trim();
    } else if (text.toLowerCase().startsWith('remind me to')) {
      text = text.substring('remind me to'.length).trim();
    } else if (text.toLowerCase().startsWith('set a reminder to')) {
      text = text.substring('set a reminder to'.length).trim();
    } else if (text.toLowerCase().startsWith('reminder:')) {
      text = text.substring('reminder:'.length).trim();
    }

    // Parse simple time phrases
    DateTime scheduled = DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final lower = text.toLowerCase();
    if (lower.contains('tomorrow')) {
      var d = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final hm = _extractTimeHM(lower);
      if (hm != null) d = DateTime(d.year, d.month, d.day, hm[0], hm[1]);
      scheduled = d;
      text = text.replaceAll('tomorrow', '').trim();
    } else if (lower.contains('today')) {
      final hm = _extractTimeHM(lower);
      final h = hm != null ? hm[0] : now.hour;
      final m = hm != null ? hm[1] : now.minute;
      scheduled = DateTime(now.year, now.month, now.day, h, m);
      text = text.replaceAll('today', '').trim();
    } else {
      final inRegex = RegExp(
        r'in (\d+) (minute|minutes|hour|hours|day|days|week|weeks)',
      );
      final m = inRegex.firstMatch(lower);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        final unit = m.group(2)!;
        Duration d;
        switch (unit) {
          case 'minute':
          case 'minutes':
            d = Duration(minutes: n);
            break;
          case 'hour':
          case 'hours':
            d = Duration(hours: n);
            break;
          case 'day':
          case 'days':
            d = Duration(days: n);
            break;
          default:
            d = Duration(days: 7 * n);
        }
        scheduled = now.add(d);
        text = text.replaceAll(inRegex, '').trim();
      }
    }

    final alarm = FlowAlarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text.isEmpty
          ? 'Reminder'
          : text[0].toUpperCase() + text.substring(1),
      description: '',
      scheduledTime: scheduled,
      isActive: true,
      type: AlarmType.reminder,
      repeat: AlarmRepeat.none,
      createdAt: DateTime.now(),
    );

    final created = await FlowService.createAlarm(alarm);
    return AgentResult(
      handled: true,
      message: 'Reminder set for ${created.scheduledTime}.',
      extra: {'alarm': created.toJson()},
    );
  }

  List<int>? _extractTimeHM(String s) {
    final ampm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)');
    final m1 = ampm.firstMatch(s);
    if (m1 != null) {
      var h = int.parse(m1.group(1)!);
      final min = int.tryParse(m1.group(2) ?? '0') ?? 0;
      final ap = m1.group(3)!.toLowerCase();
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return [h, min];
    }
    final hhmm = RegExp(r'\b(\d{1,2}):(\d{2})\b');
    final m2 = hhmm.firstMatch(s);
    if (m2 != null) {
      return [int.parse(m2.group(1)!), int.parse(m2.group(2)!)];
    }
    return null;
  }
}
