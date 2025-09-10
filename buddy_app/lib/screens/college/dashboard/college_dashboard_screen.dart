// lib/screens/college/dashboard/college_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../config/settings/theme_config.dart';
import '../../../services/app_mode_service.dart';

class CollegeDashboardScreen extends StatefulWidget {
  const CollegeDashboardScreen({super.key});

  @override
  State<CollegeDashboardScreen> createState() => _CollegeDashboardScreenState();
}

class _CollegeDashboardScreenState extends State<CollegeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppModeService _appModeService = AppModeService();

  @override
  void initState() {
    super.initState();
    final tabs = _appModeService.getDashboardTabs();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _appModeService.getDashboardTabs();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: tabs.length > 4,
          tabs: tabs
              .map((tab) => Tab(text: tab, icon: _getTabIcon(tab)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs.map((tab) => _buildTabContent(tab)).toList(),
      ),
    );
  }

  Icon _getTabIcon(String tab) {
    switch (tab.toLowerCase()) {
      case 'chats':
        return const Icon(Icons.chat_bubble_outline, size: 20);
      case 'classroom':
      case 'classroom oversight':
      case 'all classrooms':
        return const Icon(Icons.class_outlined, size: 20);
      case 'results':
      case 'results mgmt':
      case 'results dept':
      case 'results global':
        return const Icon(Icons.assessment_outlined, size: 20);
      case 'timetable':
      case 'timetable mgmt':
      case 'timetable dept':
      case 'timetable global':
        return const Icon(Icons.schedule_outlined, size: 20);
      case 'admin':
        return const Icon(Icons.admin_panel_settings_outlined, size: 20);
      default:
        return const Icon(Icons.dashboard_outlined, size: 20);
    }
  }

  Widget _buildTabContent(String tab) {
    switch (tab.toLowerCase()) {
      case 'chats':
        return _buildChatsTab();
      case 'classroom':
        return _buildClassroomTab();
      case 'classroom oversight':
        return _buildClassroomOversightTab();
      case 'all classrooms':
        return _buildAllClassroomsTab();
      case 'results':
        return _buildResultsTab();
      case 'results mgmt':
        return _buildResultsManagementTab();
      case 'results dept':
        return _buildResultsDepartmentTab();
      case 'results global':
        return _buildResultsGlobalTab();
      case 'timetable':
        return _buildTimetableTab();
      case 'timetable mgmt':
        return _buildTimetableManagementTab();
      case 'timetable dept':
        return _buildTimetableDepartmentTab();
      case 'timetable global':
        return _buildTimetableGlobalTab();
      case 'admin':
        return _buildAdminTab();
      default:
        return _buildComingSoonTab(tab);
    }
  }

  // Chats Tab
  Widget _buildChatsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Recent Conversations',
            Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('Classroom ${index + 1}'),
                    subtitle: Text('Last message preview...'),
                    trailing: Text('${index + 1}h ago'),
                    onTap: () {
                      // TODO: Open chat
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Classroom Tab (for Students)
  Widget _buildClassroomTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('My Classrooms', Icons.class_outlined),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Card(
                  child: InkWell(
                    onTap: () {
                      // TODO: Open classroom
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.book,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Subject ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teacher Name',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.assignment,
                                size: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${index + 2} assignments',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                _showJoinClassroomDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Join Classroom'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Results Tab
  Widget _buildResultsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('My Results', Icons.assessment_outlined),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                final isGraded = index % 2 == 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Assignment ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isGraded
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isGraded ? 'Graded' : 'Pending',
                                style: TextStyle(
                                  color: isGraded
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Subject ${index + 1}',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isGraded) ...[
                          Row(
                            children: [
                              Text(
                                'Score: ',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${85 + index}/100',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  // TODO: View details
                                },
                                child: const Text('View Details'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Text(
                                'Submitted on: Dec ${index + 10}',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  // TODO: View submission
                                },
                                child: const Text('View Submission'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Timetable Tab
  Widget _buildTimetableTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('My Timetable', Icons.schedule_outlined),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ];
                final day = days[index];
                final isToday = index == DateTime.now().weekday - 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isToday
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : null,
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isToday ? AppTheme.primaryColor : null,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    children: [
                      if (index < 5) // Weekdays have classes
                        ...List.generate(3, (classIndex) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${9 + classIndex * 2}:00',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(
                                      left: 8,
                                      bottom: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.borderColor,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Subject ${classIndex + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Room ${100 + classIndex}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No classes scheduled',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder tabs for different roles
  Widget _buildClassroomOversightTab() =>
      _buildComingSoonTab('Classroom Oversight');
  Widget _buildAllClassroomsTab() => _buildComingSoonTab('All Classrooms');
  Widget _buildResultsManagementTab() =>
      _buildComingSoonTab('Results Management');
  Widget _buildResultsDepartmentTab() =>
      _buildComingSoonTab('Results Department');
  Widget _buildResultsGlobalTab() => _buildComingSoonTab('Results Global');
  Widget _buildTimetableManagementTab() =>
      _buildComingSoonTab('Timetable Management');
  Widget _buildTimetableDepartmentTab() =>
      _buildComingSoonTab('Timetable Department');
  Widget _buildTimetableGlobalTab() => _buildComingSoonTab('Timetable Global');
  Widget _buildAdminTab() => _buildComingSoonTab('Admin');

  Widget _buildComingSoonTab(String tabName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '$tabName',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon!',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  void _showJoinClassroomDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Classroom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Classroom Code',
                hintText: 'Enter classroom code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Join classroom
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Joining classroom...')),
              );
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
