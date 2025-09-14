import 'package:flutter/material.dart';
import '../../../models/flow_models.dart';
import '../../../services/flow_service.dart';
import '../../../config/settings/theme_config.dart';
import 'create_alarm_screen.dart';

class EnhancedAlarmsScreen extends StatefulWidget {
  const EnhancedAlarmsScreen({super.key});

  @override
  State<EnhancedAlarmsScreen> createState() => _EnhancedAlarmsScreenState();
}

class _EnhancedAlarmsScreenState extends State<EnhancedAlarmsScreen> {
  List<FlowAlarm> _alarms = [];
  List<FlowAlarm> _filteredAlarms = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, active, completed, overdue
  String _sortBy = 'due'; // due, created, title

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    try {
      final alarms = await FlowService.getAlarms();
      setState(() {
        _alarms = alarms;
        _filteredAlarms = alarms;
        _isLoading = false;
      });
      _filterAlarms();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading alarms: $e')));
    }
  }

  void _filterAlarms() {
    final now = DateTime.now();
    setState(() {
      _filteredAlarms = _alarms.where((alarm) {
        switch (_filterType) {
          case 'active':
            return alarm.isActive && alarm.scheduledTime.isAfter(now);
          case 'completed':
            return !alarm.isActive;
          case 'overdue':
            return alarm.isActive && alarm.scheduledTime.isBefore(now);
          case 'all':
          default:
            return true;
        }
      }).toList();

      // Sort alarms
      switch (_sortBy) {
        case 'created':
          _filteredAlarms.sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
              a.createdAt ?? DateTime.now(),
            ),
          );
          break;
        case 'title':
          _filteredAlarms.sort((a, b) => a.title.compareTo(b.title));
          break;
        case 'due':
        default:
          _filteredAlarms.sort(
            (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
          );
      }
    });
  }

  void _toggleAlarm(FlowAlarm alarm) async {
    try {
      final updatedAlarm = alarm.copyWith(isActive: !alarm.isActive);
      await FlowService.updateAlarm(updatedAlarm);
      _loadAlarms();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating alarm: $e')));
    }
  }

  void _deleteAlarm(FlowAlarm alarm) async {
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
        await FlowService.deleteAlarm(alarm.id);
        _loadAlarms();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting alarm: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Filter and sort bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Filter chips
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              'All',
                              'all',
                              _getAlarmCount('all'),
                            ),
                            _buildFilterChip(
                              'Active',
                              'active',
                              _getAlarmCount('active'),
                            ),
                            _buildFilterChip(
                              'Completed',
                              'completed',
                              _getAlarmCount('completed'),
                            ),
                            _buildFilterChip(
                              'Overdue',
                              'overdue',
                              _getAlarmCount('overdue'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Sort button
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      onSelected: (value) => setState(() {
                        _sortBy = value;
                        _filterAlarms();
                      }),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'due',
                          child: Text('Sort by Due Date'),
                        ),
                        const PopupMenuItem(
                          value: 'created',
                          child: Text('Sort by Created'),
                        ),
                        const PopupMenuItem(
                          value: 'title',
                          child: Text('Sort by Title'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Alarms list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAlarms.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadAlarms,
                    child: _buildAlarmsList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAlarm,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.alarm_add, color: Colors.white),
        label: const Text('New Alarm', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => setState(() {
          _filterType = value;
          _filterAlarms();
        }),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildAlarmsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAlarms.length,
      itemBuilder: (context, index) {
        final alarm = _filteredAlarms[index];
        final isOverdue =
            alarm.isActive && alarm.scheduledTime.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _editAlarm(alarm),
            onLongPress: () => _showAlarmOptions(alarm),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status checkbox
                  Checkbox(
                    value: !alarm.isActive,
                    onChanged: (_) => _toggleAlarm(alarm),
                    activeColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Alarm icon with status indicator
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.withValues(alpha: 0.1)
                          : alarm.isActive
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOverdue
                          ? Icons.alarm_off
                          : alarm.isActive
                          ? Icons.alarm_on
                          : Icons.alarm,
                      color: isOverdue
                          ? Colors.red
                          : alarm.isActive
                          ? AppTheme.primaryColor
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Alarm details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          alarm.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                            decoration: !alarm.isActive
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Description
                        if (alarm.description?.isNotEmpty == true) ...[
                          Text(
                            alarm.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                              decoration: !alarm.isActive
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Due date and time with status
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: isOverdue
                                  ? Colors.red
                                  : AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(alarm.scheduledTime),
                              style: TextStyle(
                                fontSize: 13,
                                color: isOverdue
                                    ? Colors.red
                                    : AppTheme.textSecondaryColor,
                                fontWeight: isOverdue
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (isOverdue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (alarm.repeat != null &&
                                alarm.repeat != AlarmRepeat.none) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                alarm.repeat!.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // More options button
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onPressed: () => _showAlarmOptions(alarm),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filterType == 'completed'
                ? Icons.check_circle_outline
                : _filterType == 'overdue'
                ? Icons.alarm_off
                : Icons.alarm_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateTitle(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtitle(),
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (_filterType == 'all') ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createAlarm,
              icon: const Icon(Icons.alarm_add),
              label: const Text('Create Alarm'),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmptyStateTitle() {
    switch (_filterType) {
      case 'active':
        return 'No active alarms';
      case 'completed':
        return 'No completed alarms';
      case 'overdue':
        return 'No overdue alarms';
      default:
        return 'No alarms yet';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_filterType) {
      case 'active':
        return 'Create alarms to get reminders for important tasks';
      case 'completed':
        return 'Completed alarms will appear here';
      case 'overdue':
        return 'Good! No overdue alarms';
      default:
        return 'Stay on top of important tasks and deadlines';
    }
  }

  void _showAlarmOptions(FlowAlarm alarm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(alarm.isActive ? Icons.alarm_off : Icons.alarm_on),
              title: Text(
                alarm.isActive ? 'Mark as Complete' : 'Mark as Active',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleAlarm(alarm);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editAlarm(alarm);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicateAlarm(alarm);
              },
            ),
            if (alarm.scheduledTime.isBefore(DateTime.now()) && alarm.isActive)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Reschedule'),
                onTap: () {
                  Navigator.pop(context);
                  _rescheduleAlarm(alarm);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteAlarm(alarm);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createAlarm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateAlarmScreen()),
    ).then((_) => _loadAlarms());
  }

  void _editAlarm(FlowAlarm alarm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateAlarmScreen(alarm: alarm)),
    ).then((_) => _loadAlarms());
  }

  void _duplicateAlarm(FlowAlarm alarm) async {
    try {
      final duplicatedAlarm = alarm.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${alarm.title} (Copy)',
        createdAt: DateTime.now(),
        scheduledTime: alarm.scheduledTime.add(const Duration(hours: 1)),
      );
      await FlowService.createAlarm(duplicatedAlarm);
      _loadAlarms();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error duplicating alarm: $e')));
    }
  }

  void _rescheduleAlarm(FlowAlarm alarm) async {
    final newDateTime = await showDatePicker(
      context: context,
      initialDate: alarm.scheduledTime.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDateTime != null) {
      final newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(alarm.scheduledTime),
      );

      if (newTime != null) {
        final newScheduledTime = DateTime(
          newDateTime.year,
          newDateTime.month,
          newDateTime.day,
          newTime.hour,
          newTime.minute,
        );

        try {
          await FlowService.updateAlarm(
            alarm.copyWith(scheduledTime: newScheduledTime),
          );
          _loadAlarms();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Alarm rescheduled')));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rescheduling alarm: $e')),
          );
        }
      }
    }
  }

  int _getAlarmCount(String type) {
    final now = DateTime.now();
    switch (type) {
      case 'active':
        return _alarms
            .where(
              (alarm) => alarm.isActive && alarm.scheduledTime.isAfter(now),
            )
            .length;
      case 'completed':
        return _alarms.where((alarm) => !alarm.isActive).length;
      case 'overdue':
        return _alarms
            .where(
              (alarm) => alarm.isActive && alarm.scheduledTime.isBefore(now),
            )
            .length;
      case 'all':
      default:
        return _alarms.length;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Today
      return 'Today, ${_formatTime(dateTime)}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1) {
      // Tomorrow
      return 'Tomorrow, ${_formatTime(dateTime)}';
    } else if (difference.inDays < 0 && difference.inDays > -7) {
      // Past week
      return '${(-difference.inDays)} days ago, ${_formatTime(dateTime)}';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      // Next week
      return '${difference.inDays} days from now, ${_formatTime(dateTime)}';
    } else {
      // Full date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}, ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
