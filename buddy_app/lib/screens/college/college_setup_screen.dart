// lib/screens/college/college_setup_screen.dart
import 'package:flutter/material.dart';
import '../../config/settings/theme_config.dart';
import '../../services/app_mode_service.dart';
import '../../services/college/college_service.dart';
import '../../models/college_models.dart';
import 'college_home_screen.dart';

class CollegeSetupScreen extends StatefulWidget {
  const CollegeSetupScreen({super.key});

  @override
  State<CollegeSetupScreen> createState() => _CollegeSetupScreenState();
}

class _CollegeSetupScreenState extends State<CollegeSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final TextEditingController _institutionCodeController =
      TextEditingController();
  final TextEditingController _accessCodeController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  Institution? _selectedInstitution;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _institutionCodeController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('College Mode Setup'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildRoleSelectionPage(),
                _buildInstitutionPage(),
                _buildConfirmationPage(),
              ],
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                    child: const Text('Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNextButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(_currentPage == 2 ? 'Complete Setup' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionPage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Role',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your role to get customized features and permissions.',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildRoleCard(
                  role: UserRole.student,
                  title: 'Student',
                  description:
                      'Access classrooms, submit assignments, view results and timetable',
                  icon: Icons.school,
                  features: [
                    'Join Classrooms',
                    'Submit Assignments',
                    'View Results',
                    'Check Timetable',
                  ],
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  role: UserRole.teacher,
                  title: 'Teacher / Professor',
                  description:
                      'Create classrooms, manage assignments, grade submissions',
                  icon: Icons.person_outline,
                  features: [
                    'Create Classrooms',
                    'Manage Assignments',
                    'Grade Students',
                    'Track Progress',
                  ],
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  role: UserRole.hod,
                  title: 'HOD (Head of Department)',
                  description:
                      'Oversee department activities, approve projects, manage resources',
                  icon: Icons.admin_panel_settings_outlined,
                  features: [
                    'Department Overview',
                    'Approve Projects',
                    'Resource Management',
                    'Analytics',
                  ],
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  role: UserRole.principal,
                  title: 'Principal / Institution Head',
                  description:
                      'Institution-wide management, admin controls, generate access codes',
                  icon: Icons.business,
                  features: [
                    'Institution Management',
                    'User Administration',
                    'Global Analytics',
                    'Access Control',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
    required List<String> features,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features
                  .map(
                    (feature) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : AppTheme.borderColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionPage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join Your Institution',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your institution code to connect with your college or university.',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institution Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _institutionCodeController,
                  decoration: InputDecoration(
                    hintText: 'Enter institution code (e.g., 101010)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.school),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For testing, use code: 101010\nGet the official code from your institution administrator.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedInstitution != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Institution Found!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedInstitution!.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  Text(
                    _selectedInstitution!.address,
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationPage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm Setup',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your selection and complete the setup.',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Role', _getRoleDisplayName(_selectedRole)),
                const SizedBox(height: 8),
                if (_selectedInstitution != null) ...[
                  _buildSummaryRow('Institution', _selectedInstitution!.name),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Institution Code',
                    _selectedInstitution!.code,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'After setup, you can switch between Normal Mode and College Mode anytime from your profile settings.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher / Professor';
      case UserRole.hod:
        return 'HOD (Head of Department)';
      case UserRole.principal:
        return 'Principal / Institution Head';
      default:
        return 'Unknown';
    }
  }

  void _handleNextButton() async {
    if (_currentPage == 0) {
      // Role selection page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentPage == 1) {
      // Institution page
      await _validateInstitution();
    } else {
      // Confirmation page
      await _completeSetup();
    }
  }

  Future<void> _validateInstitution() async {
    final code = _institutionCodeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter an institution code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final collegeService = CollegeService();

      // For testing, create a dummy institution if code is 101010
      if (code == '101010') {
        _selectedInstitution = Institution(
          id: 'test_institution',
          name: 'Test University',
          code: '101010',
          address: '123 Education Street, Learning City',
          email: 'admin@testuniversity.edu',
          phone: '+1234567890',
          createdAt: DateTime.now(),
        );
      } else {
        _selectedInstitution = await collegeService.getInstitutionByCode(code);
      }

      if (_selectedInstitution != null) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _showError(
          'Institution not found. Please check the code and try again.',
        );
      }
    } catch (e) {
      _showError('Failed to validate institution: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeSetup() async {
    if (_selectedInstitution == null) {
      _showError('Institution not selected');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appModeService = AppModeService();

      // For testing, we'll just switch to college mode without creating a real user
      await appModeService.switchToCollegeMode(
        role: _selectedRole,
        institution: _selectedInstitution!,
      );

      if (mounted) {
        // Navigate to college home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CollegeHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError('Failed to complete setup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
