import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import 'create_note_screen.dart';
import 'create_alarm_screen.dart';

class NotesAlarmsScreen extends StatefulWidget {
  const NotesAlarmsScreen({super.key});

  @override
  State<NotesAlarmsScreen> createState() => _NotesAlarmsScreenState();
}

class _NotesAlarmsScreenState extends State<NotesAlarmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Note> _notes = [];
  List<FlowAlarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notes = await FlowService.getNotes();
      final alarms = await FlowService.getAlarms();
      setState(() {
        _notes = notes;
        _alarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notes & Alarms'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.note), text: 'Notes'),
            Tab(icon: Icon(Icons.alarm), text: 'Alarms'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNotesTab(), _buildAlarmsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreationOptions,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return _buildEmptyNotesState();
    }

    // Separate pinned and regular notes
    final pinnedNotes = _notes
        .where((note) => note.isPinned && !note.isArchived)
        .toList();
    final regularNotes = _notes
        .where((note) => !note.isPinned && !note.isArchived)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinnedNotes.isNotEmpty) ...[
              const Text(
                'PINNED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              _buildNotesGrid(pinnedNotes),
              const SizedBox(height: 24),
            ],
            if (regularNotes.isNotEmpty) ...[
              if (pinnedNotes.isNotEmpty)
                const Text(
                  'OTHERS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
              const SizedBox(height: 8),
              _buildNotesGrid(regularNotes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesGrid(List<Note> notes) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: notes.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildNoteCard(notes[index]);
      },
    );
  }

  Widget _buildNoteCard(Note note) {
    return Card(
      color: Color(int.parse(note.color.replaceFirst('#', '0xFF'))),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _editNote(note),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.isPinned)
                      const Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Colors.black54,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (note.type == NoteType.text && note.content.isNotEmpty) ...[
                Text(
                  note.content,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.type == NoteType.checklist &&
                  note.checklist.isNotEmpty) ...[
                ...note.checklist.take(5).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.isCompleted
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (note.checklist.length > 5)
                  Text(
                    '+${note.checklist.length - 5} more items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
              if (note.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: note.labels.take(3).map((label) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alarms.isEmpty) {
      return _buildEmptyAlarmsState();
    }

    // Separate active and inactive alarms
    final activeAlarms = _alarms.where((alarm) => alarm.isActive).toList();
    final inactiveAlarms = _alarms.where((alarm) => !alarm.isActive).toList();

    // Sort by scheduled time
    activeAlarms.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    inactiveAlarms.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeAlarms.isNotEmpty) ...[
            const Text(
              'ACTIVE ALARMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...activeAlarms.map((alarm) => _buildAlarmCard(alarm)),
            const SizedBox(height: 24),
          ],
          if (inactiveAlarms.isNotEmpty) ...[
            const Text(
              'INACTIVE ALARMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...inactiveAlarms.map((alarm) => _buildAlarmCard(alarm)),
          ],
        ],
      ),
    );
  }

  Widget _buildAlarmCard(FlowAlarm alarm) {
    final now = DateTime.now();
    final isPast = alarm.scheduledTime.isBefore(now);
    final timeUntil = alarm.scheduledTime.difference(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _editAlarm(alarm),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getAlarmTypeIcon(alarm.type),
                    color: alarm.isActive ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alarm.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: alarm.isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  if (!alarm.isActive)
                    const Icon(Icons.pause_circle_outline, color: Colors.grey),
                ],
              ),
              if (alarm.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  alarm.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: alarm.isActive ? Colors.black54 : Colors.grey,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: isPast ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatAlarmTime(alarm.scheduledTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: isPast ? Colors.red : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (alarm.isActive && !isPast) ...[
                    const Text(' • '),
                    Text(
                      _formatTimeUntil(timeUntil),
                      style: const TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ],
                ],
              ),
              if (alarm.repeat != AlarmRepeat.none) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _getRepeatText(alarm.repeat),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Notes Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first note',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlarmsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alarm, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Alarms Set',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your first alarm',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showCreationOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create New',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Create Note'),
                onTap: () {
                  Navigator.pop(context);
                  _createNote();
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm_add),
                title: const Text('Set Alarm'),
                onTap: () {
                  Navigator.pop(context);
                  _createAlarm();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNote() async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _editNote(Note note) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => CreateNoteScreen(note: note)),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _createAlarm() async {
    final result = await Navigator.push<FlowAlarm>(
      context,
      MaterialPageRoute(builder: (context) => const CreateAlarmScreen()),
    );

    if (result != null) {
      _loadData();
    }
  }

  Future<void> _editAlarm(FlowAlarm alarm) async {
    final result = await Navigator.push<FlowAlarm>(
      context,
      MaterialPageRoute(builder: (context) => CreateAlarmScreen(alarm: alarm)),
    );

    if (result != null) {
      _loadData();
    }
  }

  IconData _getAlarmTypeIcon(AlarmType type) {
    switch (type) {
      case AlarmType.reminder:
        return Icons.notifications;
      case AlarmType.deadline:
        return Icons.event;
      case AlarmType.meeting:
        return Icons.people;
      case AlarmType.task:
        return Icons.task_alt;
      case AlarmType.custom:
        return Icons.alarm;
    }
  }

  String _formatAlarmTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final alarmDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeString = TimeOfDay.fromDateTime(dateTime).format(context);

    if (alarmDate == today) {
      return 'Today at $timeString';
    } else if (alarmDate == tomorrow) {
      return 'Tomorrow at $timeString';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $timeString';
    }
  }

  String _formatTimeUntil(Duration duration) {
    if (duration.inDays > 0) {
      return 'in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'very soon';
    }
  }

  String _getRepeatText(AlarmRepeat repeat) {
    switch (repeat) {
      case AlarmRepeat.none:
        return 'No repeat';
      case AlarmRepeat.daily:
        return 'Daily';
      case AlarmRepeat.weekly:
        return 'Weekly';
      case AlarmRepeat.monthly:
        return 'Monthly';
      case AlarmRepeat.custom:
        return 'Custom';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
