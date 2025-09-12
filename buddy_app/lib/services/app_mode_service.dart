// lib/services/app_mode_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/college_models.dart';
import 'college/college_service.dart';

class AppModeService extends ChangeNotifier {
  static final AppModeService _instance = AppModeService._internal();
  factory AppModeService() => _instance;
  AppModeService._internal();

  AppMode _currentMode = AppMode.normal;
  UserRole _currentRole = UserRole.normal;
  Institution? _currentInstitution;
  CollegeUser? _currentCollegeUser;

  AppMode get currentMode => _currentMode;
  UserRole get currentRole => _currentRole;
  Institution? get currentInstitution => _currentInstitution;
  CollegeUser? get currentCollegeUser => _currentCollegeUser;

  bool get isCollegeMode => _currentMode == AppMode.college;
  bool get isNormalMode => _currentMode == AppMode.normal;

  Future<UserRole> getCurrentUserRole() async {
    return _currentRole;
  }

  static Future<void> initialize() async {
    await _instance._loadSavedMode();
  }

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('app_mode') ?? 'normal';
    final roleString = prefs.getString('user_role') ?? 'normal';
    final institutionId = prefs.getString('institution_id');

    _currentMode = AppMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == modeString,
      orElse: () => AppMode.normal,
    );

    _currentRole = UserRole.values.firstWhere(
      (role) => role.toString().split('.').last == roleString,
      orElse: () => UserRole.normal,
    );

    if (institutionId != null && _currentMode == AppMode.college) {
      // Load institution and college user data
      await _loadCollegeData(institutionId);
    }

    notifyListeners();
  }

  Future<void> _loadCollegeData(String institutionId) async {
    try {
      final collegeService = CollegeService();

      // Load institution
      final institutions = await collegeService.getAllInstitutions();
      _currentInstitution = institutions.firstWhere(
        (inst) => inst.id == institutionId,
        orElse: () => institutions.first,
      );

      // Load college user (using current user ID - you'll need to get this from auth service)
      // For now, using a placeholder
      _currentCollegeUser = await collegeService.getCollegeUser(
        'current_user_id',
        institutionId,
      );
    } catch (e) {
      print('Error loading college data: $e');
    }
  }

  Future<void> switchToCollegeMode({
    required UserRole role,
    required Institution institution,
    CollegeUser? collegeUser,
  }) async {
    _currentMode = AppMode.college;
    _currentRole = role;
    _currentInstitution = institution;
    _currentCollegeUser = collegeUser;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', 'college');
    await prefs.setString('user_role', role.toString().split('.').last);
    await prefs.setString('institution_id', institution.id);

    notifyListeners();
  }

  Future<void> switchToNormalMode() async {
    _currentMode = AppMode.normal;
    _currentRole = UserRole.normal;
    _currentInstitution = null;
    _currentCollegeUser = null;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', 'normal');
    await prefs.setString('user_role', 'normal');
    await prefs.remove('institution_id');

    notifyListeners();
  }

  Future<bool> joinInstitution(String institutionCode, UserRole role) async {
    try {
      final collegeService = CollegeService();

      // Validate institution code
      final institution = await collegeService.getInstitutionByCode(
        institutionCode,
      );
      if (institution == null) {
        return false;
      }

      // Create college user record
      final collegeUser = CollegeUser(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user_id', // Replace with actual user ID
        institutionId: institution.id,
        role: role,
        joinedAt: DateTime.now(),
      );

      final createdUser = await collegeService.createCollegeUser(collegeUser);
      if (createdUser != null) {
        await switchToCollegeMode(
          role: role,
          institution: institution,
          collegeUser: createdUser,
        );
        return true;
      }
    } catch (e) {
      print('Error joining institution: $e');
    }
    return false;
  }

  Future<void> updateModeBasedOnProfession(String? profession) async {
    if (profession == null) return;

    UserRole role;
    switch (profession.toLowerCase()) {
      case 'student':
        role = UserRole.student;
        break;
      case 'teacher':
        role = UserRole.teacher;
        break;
      case 'hod':
        role = UserRole.hod;
        break;
      case 'principal':
        role = UserRole.principal;
        break;
      default:
        role = UserRole.normal;
    }

    // If user has an educational role, automatically enable college mode
    if (role != UserRole.normal) {
      // For now, just set the role. College mode will be enabled when user joins an institution
      _currentRole = role;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role.toString().split('.').last);
      notifyListeners();
    }
  }

  String getRoleDisplayName() {
    switch (_currentRole) {
      case UserRole.normal:
        return 'General User';
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.hod:
        return 'Head of Department';
      case UserRole.principal:
        return 'Principal';
    }
  }

  List<String> getRoleBasedTabs() {
    if (_currentMode == AppMode.normal) {
      return ['Buddy', 'Flow', 'Dock'];
    }

    switch (_currentRole) {
      case UserRole.student:
        return ['Dashboard', 'AI', 'Flow', 'Dock'];
      case UserRole.teacher:
        return ['Dashboard', 'AI', 'Flow', 'Dock'];
      case UserRole.hod:
        return ['Dashboard', 'AI', 'Flow', 'Dock'];
      case UserRole.principal:
        return ['Dashboard', 'AI', 'Flow', 'Dock'];
      default:
        return ['Buddy', 'Flow', 'Dock'];
    }
  }

  List<String> getDashboardTabs() {
    switch (_currentRole) {
      case UserRole.student:
        return ['Chats', 'Classroom', 'Results', 'Timetable'];
      case UserRole.teacher:
        return ['Chats', 'Classroom', 'Results Mgmt', 'Timetable Mgmt'];
      case UserRole.hod:
        return [
          'Chats',
          'Classroom Oversight',
          'Results Dept',
          'Timetable Dept',
        ];
      case UserRole.principal:
        return [
          'Chats',
          'All Classrooms',
          'Results Global',
          'Timetable Global',
          'Admin',
        ];
      default:
        return ['Chats'];
    }
  }

  bool hasPermission(String permission) {
    if (_currentCollegeUser == null) return false;

    final permissions = _currentCollegeUser!.permissions;
    return permissions[permission] == true;
  }

  bool canCreateClassroom() {
    return _currentRole == UserRole.teacher ||
        _currentRole == UserRole.hod ||
        _currentRole == UserRole.principal;
  }

  bool canViewAllClassrooms() {
    return _currentRole == UserRole.hod || _currentRole == UserRole.principal;
  }

  bool canManageUsers() {
    return _currentRole == UserRole.principal;
  }

  bool canViewDepartmentData() {
    return _currentRole == UserRole.hod || _currentRole == UserRole.principal;
  }

  bool canViewInstitutionData() {
    return _currentRole == UserRole.principal;
  }
}
