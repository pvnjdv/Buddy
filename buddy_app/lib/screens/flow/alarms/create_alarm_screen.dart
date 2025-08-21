import 'package:flutter/material.dart';
import '../../../models/flow_models.dart';
import '../../../services/flow_service.dart';

class CreateAlarmScreen extends StatefulWidget {
  final FlowAlarm? alarm; // For editing existing alarms
  final String? flowId; // For linking to a specific flow
  final String? checkpointId; // For linking to a specific checkpoint

  const CreateAlarmScreen({
    super.key,
    this.alarm,
    this.flowId,
    this.checkpointId,
  });

  @override
  State<CreateAlarmScreen> createState() => _CreateAlarmScreenState();
}

class _CreateAlarmScreenState extends State<CreateAlarmScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  AlarmType _alarmType = AlarmType.reminder;
  AlarmRepeat _repeatType = AlarmRepeat.none;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.alarm != null) {
      _initializeFromAlarm(widget.alarm!);
    } else {
      // Set default time to 1 hour from now
      final now = DateTime.now().add(const Duration(hours: 1));
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay.fromDateTime(now);
    }
  }

  void _initializeFromAlarm(FlowAlarm alarm) {
    _titleController.text = alarm.title;
    _descriptionController.text = alarm.description;
    _selectedDate = DateTime(
      alarm.scheduledTime.year,
      alarm.scheduledTime.month,
      alarm.scheduledTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(alarm.scheduledTime);
    _alarmType = alarm.type;
    _repeatType = alarm.repeat;
    _isActive = alarm.isActive;
  }

  DateTime get _scheduledDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.alarm != null ? 'Edit Alarm' : 'Create Alarm'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveAlarm,
            child: Text(
              widget.alarm != null ? 'Update' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alarm Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Enter alarm title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter alarm description (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date & Time Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Selector
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(_selectedDate)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectDate,
                    ),

                    const Divider(),

                    // Time Selector
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Time'),
                      subtitle: Text(_selectedTime.format(context)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectTime,
                    ),

                    const SizedBox(height: 16),

                    // Scheduled Time Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scheduled for ${_formatDateTime(_scheduledDateTime)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Alarm Type Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alarm Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: AlarmType.values.map((type) {
                        return ChoiceChip(
                          label: Text(_getAlarmTypeLabel(type)),
                          selected: _alarmType == type,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _alarmType = type);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Repeat Options Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Repeat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: AlarmRepeat.values.map((repeat) {
                        return ChoiceChip(
                          label: Text(_getRepeatLabel(repeat)),
                          selected: _repeatType == repeat,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _repeatType = repeat);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Enable/disable this alarm'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Link Information (if applicable)
            if (widget.flowId != null || widget.checkpointId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Linked To',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.flowId != null)
                        Row(
                          children: [
                            const Icon(Icons.timeline, size: 16),
                            const SizedBox(width: 8),
                            Text('Flow: ${widget.flowId}'),
                          ],
                        ),
                      if (widget.checkpointId != null)
                        Row(
                          children: [
                            const Icon(Icons.flag, size: 16),
                            const SizedBox(width: 8),
                            Text('Checkpoint: ${widget.checkpointId}'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Delete Button (for editing)
            if (widget.alarm != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteAlarm,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete Alarm',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final timeString = TimeOfDay.fromDateTime(dateTime).format(context);
    final dateString = _formatDate(dateTime);
    return '$dateString at $timeString';
  }

  String _getAlarmTypeLabel(AlarmType type) {
    switch (type) {
      case AlarmType.reminder:
        return 'Reminder';
      case AlarmType.deadline:
        return 'Deadline';
      case AlarmType.meeting:
        return 'Meeting';
      case AlarmType.task:
        return 'Task';
      case AlarmType.custom:
        return 'Custom';
    }
  }

  String _getRepeatLabel(AlarmRepeat repeat) {
    switch (repeat) {
      case AlarmRepeat.none:
        return 'None';
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

  Future<void> _saveAlarm() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an alarm title')),
      );
      return;
    }

    if (_scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final alarm = FlowAlarm(
        id:
            widget.alarm?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        scheduledTime: _scheduledDateTime,
        isActive: _isActive,
        type: _alarmType,
        repeat: _repeatType,
        flowId: widget.flowId,
        checkpointId: widget.checkpointId,
        createdAt: widget.alarm?.createdAt ?? DateTime.now(),
      );

      if (widget.alarm != null) {
        await FlowService.updateAlarm(alarm);
      } else {
        await FlowService.createAlarm(alarm);
      }

      if (mounted) {
        Navigator.pop(context, alarm);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving alarm: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAlarm() async {
    if (widget.alarm == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: const Text('Are you sure you want to delete this alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FlowService.deleteAlarm(widget.alarm!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting alarm: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
