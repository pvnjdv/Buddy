// lib/screens/college/classroom_detail_screen.dart
import 'package:flutter/material.dart';
import '../../config/settings/theme_config.dart';
import '../../models/college_models.dart';
import '../../services/college/college_service.dart';
import '../../services/app_mode_service.dart';
import 'create_assignment_screen.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final Classroom classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final CollegeService _collegeService = CollegeService();
  final AppModeService _appModeService = AppModeService();

  List<Assignment> _assignments = [];
  List<Result> _results = [];
  List<CollegeUser> _classmates = [];
  UserRole? _currentUserRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _currentUserRole = await _appModeService.getCurrentUserRole();

      // Load assignments
      _assignments = await _collegeService.getAssignmentsByClassroom(
        widget.classroom.id,
      );

      // Load results if student
      if (_currentUserRole == UserRole.student) {
        _results = await _collegeService.getResultsByClassroom(
          widget.classroom.id,
        );
      }

      // Load classmates/students
      _classmates = await _collegeService.getClassroomMembers(
        widget.classroom.id,
      );
    } catch (e) {
      print('Error loading classroom data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.classroom.name),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Stream', icon: Icon(Icons.home)),
            Tab(text: 'Assignments', icon: Icon(Icons.assignment)),
            Tab(text: 'People', icon: Icon(Icons.people)),
            Tab(text: 'Grades', icon: Icon(Icons.grade)),
          ],
        ),
        actions: [
          if (_currentUserRole == UserRole.teacher ||
              _currentUserRole == UserRole.hod)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create_assignment',
                  child: ListTile(
                    leading: Icon(Icons.assignment_add),
                    title: Text('Create Assignment'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_announcement',
                  child: ListTile(
                    leading: Icon(Icons.announcement),
                    title: Text('Add Announcement'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'classroom_settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Classroom Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStreamTab(),
                _buildAssignmentsTab(),
                _buildPeopleTab(),
                _buildGradesTab(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildStreamTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Classroom Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classroom.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.classroom.description,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.people,
                      '${_classmates.length} students',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.assignment,
                      '${_assignments.length} assignments',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // Recent assignments
          ..._assignments
              .take(3)
              .map(
                (assignment) => _buildActivityCard(
                  title: assignment.title,
                  subtitle:
                      'Assignment • Due ${_formatDate(assignment.dueDate)}',
                  icon: Icons.assignment,
                  onTap: () => _openAssignment(assignment),
                ),
              ),

          if (_assignments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment,
                    size: 64,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No assignments yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  Text(
                    'Check back later for new assignments',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          return _buildAssignmentCard(assignment);
        },
      ),
    );
  }

  Widget _buildPeopleTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Teacher section
          Text(
            'Teacher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildPersonCard(
            name: 'Teacher', // Will be replaced with actual teacher name
            role: 'Teacher',
            avatar: Icons.person,
            isTeacher: true,
          ),
          const SizedBox(height: 24),

          // Students section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Students (${_classmates.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              if (_currentUserRole == UserRole.teacher ||
                  _currentUserRole == UserRole.hod)
                IconButton(
                  onPressed: () => _showInviteStudentsDialog(),
                  icon: const Icon(Icons.person_add),
                ),
            ],
          ),
          const SizedBox(height: 12),

          ..._classmates.map(
            (student) => _buildPersonCard(
              name:
                  'Student ${student.id}', // Will be replaced with actual student name
              role: 'Student',
              avatar: Icons.school,
              isTeacher: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesTab() {
    if (_currentUserRole == UserRole.student) {
      return _buildStudentGradesView();
    } else {
      return _buildTeacherGradesView();
    }
  }

  Widget _buildStudentGradesView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final result = _results[index];
          return _buildGradeCard(result);
        },
      ),
    );
  }

  Widget _buildTeacherGradesView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.grade, size: 64, color: AppTheme.textSecondaryColor),
              const SizedBox(height: 16),
              Text(
                'Grade Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage student grades and view analytics',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openGradeBook(),
                icon: const Icon(Icons.book),
                label: const Text('Open Grade Book'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActivityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final isOverdue = assignment.dueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    assignment.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : 'Active',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assignment.description,
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${_formatDate(assignment.dueDate)}',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${assignment.totalMarks} points',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewAssignmentDetails(assignment),
                    child: const Text('View Details'),
                  ),
                ),
                if (_currentUserRole == UserRole.student) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isOverdue
                          ? null
                          : () => _submitAssignment(assignment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard({
    required String name,
    required String role,
    required IconData avatar,
    required bool isTeacher,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTeacher
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            avatar,
            color: isTeacher ? Colors.white : AppTheme.primaryColor,
          ),
        ),
        title: Text(name),
        subtitle: Text(role),
        trailing: isTeacher
            ? Icon(Icons.star, color: AppTheme.primaryColor)
            : null,
      ),
    );
  }

  Widget _buildGradeCard(Result result) {
    // Get assignment to find total marks
    final assignment = _assignments.firstWhere(
      (a) => a.id == result.assignmentId,
      orElse: () => Assignment(
        id: '',
        classroomId: '',
        title: 'Unknown Assignment',
        description: '',
        dueDate: DateTime.now(),
        totalMarks: 100,
        createdAt: DateTime.now(),
      ),
    );

    final percentage = (result.marksObtained / assignment.totalMarks) * 100;
    final grade = _getGrade(percentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: ${result.marksObtained}/${assignment.totalMarks}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Percentage: ${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getGradeColor(grade),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    grade,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (result.feedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(result.feedback),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_currentUserRole != UserRole.teacher &&
        _currentUserRole != UserRole.hod) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () => _showCreateDialog(),
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'create_assignment':
        _createAssignment();
        break;
      case 'add_announcement':
        _addAnnouncement();
        break;
      case 'classroom_settings':
        _openClassroomSettings();
        break;
    }
  }

  void _openAssignment(Assignment assignment) {
    // Navigate to assignment detail screen
    print('Opening assignment: ${assignment.title}');
  }

  void _viewAssignmentDetails(Assignment assignment) {
    // Navigate to assignment detail screen
    print('Viewing assignment details: ${assignment.title}');
  }

  void _submitAssignment(Assignment assignment) {
    // Navigate to assignment submission screen
    print('Submitting assignment: ${assignment.title}');
  }

  void _openGradeBook() {
    // Navigate to grade book screen
    print('Opening grade book');
  }

  void _showInviteStudentsDialog() {
    // Show dialog to invite students
    print('Showing invite students dialog');
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment_add),
              title: const Text('Create Assignment'),
              onTap: () {
                Navigator.pop(context);
                _createAssignment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Add Announcement'),
              onTap: () {
                Navigator.pop(context);
                _addAnnouncement();
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('Create Quiz'),
              onTap: () {
                Navigator.pop(context);
                _createQuiz();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateAssignmentScreen(classroom: widget.classroom),
      ),
    ).then((newAssignment) {
      if (newAssignment != null) {
        _loadData(); // Refresh the data
      }
    });
  }

  void _addAnnouncement() {
    // Navigate to add announcement screen
    print('Adding announcement');
  }

  void _createQuiz() {
    // Navigate to create quiz screen
    print('Creating quiz');
  }

  void _openClassroomSettings() {
    // Navigate to classroom settings screen
    print('Opening classroom settings');
  }
}
