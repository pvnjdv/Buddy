// lib/services/college/college_service.dart
import '../../models/college_models.dart';
import '../databases/college_database.dart';

class CollegeService {
  static final CollegeService _instance = CollegeService._internal();
  factory CollegeService() => _instance;
  CollegeService._internal();

  static CollegeDatabase? _database;

  static Future<void> initialize() async {
    _database = await CollegeDatabase.initialize();
  }

  // Institution management
  Future<Institution?> getInstitutionByCode(String code) async {
    if (_database == null) return null;
    return await _database!.getInstitutionByCode(code);
  }

  Future<Institution?> createInstitution(Institution institution) async {
    if (_database == null) return null;
    return await _database!.createInstitution(institution);
  }

  Future<List<Institution>> getAllInstitutions() async {
    if (_database == null) return [];
    return await _database!.getAllInstitutions();
  }

  // User role management
  Future<CollegeUser?> getCollegeUser(
    String userId,
    String institutionId,
  ) async {
    if (_database == null) return null;
    return await _database!.getCollegeUser(userId, institutionId);
  }

  Future<CollegeUser?> createCollegeUser(CollegeUser collegeUser) async {
    if (_database == null) return null;
    return await _database!.createCollegeUser(collegeUser);
  }

  Future<List<CollegeUser>> getUsersByInstitution(String institutionId) async {
    if (_database == null) return [];
    return await _database!.getUsersByInstitution(institutionId);
  }

  Future<List<CollegeUser>> getUsersByRole(
    String institutionId,
    UserRole role,
  ) async {
    if (_database == null) return [];
    return await _database!.getUsersByRole(institutionId, role);
  }

  // Classroom management
  Future<Classroom?> createClassroom(Classroom classroom) async {
    if (_database == null) return null;
    return await _database!.createClassroom(classroom);
  }

  Future<List<Classroom>> getClassroomsByTeacher(String teacherId) async {
    if (_database == null) return [];
    return await _database!.getClassroomsByTeacher(teacherId);
  }

  Future<List<Classroom>> getClassroomsByStudent(String studentId) async {
    if (_database == null) return [];
    return await _database!.getClassroomsByStudent(studentId);
  }

  Future<List<Classroom>> getClassroomsByInstitution(
    String institutionId,
  ) async {
    if (_database == null) return [];
    return await _database!.getClassroomsByInstitution(institutionId);
  }

  Future<Classroom?> getClassroomByCode(String classCode) async {
    if (_database == null) return null;
    return await _database!.getClassroomByCode(classCode);
  }

  Future<bool> joinClassroom(String classroomId, String studentId) async {
    if (_database == null) return false;
    return await _database!.joinClassroom(classroomId, studentId);
  }

  // Assignment management
  Future<Assignment?> createAssignment(Assignment assignment) async {
    if (_database == null) return null;
    return await _database!.createAssignment(assignment);
  }

  Future<List<Assignment>> getAssignmentsByClassroom(String classroomId) async {
    if (_database == null) return [];
    return await _database!.getAssignmentsByClassroom(classroomId);
  }

  Future<Assignment?> updateAssignment(Assignment assignment) async {
    if (_database == null) return null;
    return await _database!.updateAssignment(assignment);
  }

  // Result management
  Future<Result?> submitResult(Result result) async {
    if (_database == null) return null;
    return await _database!.submitResult(result);
  }

  Future<List<Result>> getResultsByStudent(String studentId) async {
    if (_database == null) return [];
    return await _database!.getResultsByStudent(studentId);
  }

  Future<List<Result>> getResultsByAssignment(String assignmentId) async {
    if (_database == null) return [];
    return await _database!.getResultsByAssignment(assignmentId);
  }

  Future<List<Result>> getResultsByClassroom(String classroomId) async {
    if (_database == null) return [];
    return await _database!.getResultsByClassroom(classroomId);
  }

  Future<List<CollegeUser>> getClassroomMembers(String classroomId) async {
    if (_database == null) return [];
    return await _database!.getClassroomMembers(classroomId);
  }

  Future<Result?> gradeResult(
    String resultId,
    int marks,
    String feedback,
  ) async {
    if (_database == null) return null;
    return await _database!.gradeResult(resultId, marks, feedback);
  }

  // Timetable management
  Future<Timetable?> createTimetableEntry(Timetable timetable) async {
    if (_database == null) return null;
    return await _database!.createTimetableEntry(timetable);
  }

  Future<List<Timetable>> getTimetableByClassroom(String classroomId) async {
    if (_database == null) return [];
    return await _database!.getTimetableByClassroom(classroomId);
  }

  Future<List<Timetable>> getTimetableByTeacher(String teacherId) async {
    if (_database == null) return [];
    return await _database!.getTimetableByTeacher(teacherId);
  }

  Future<List<Timetable>> getTimetableByInstitution(
    String institutionId,
  ) async {
    if (_database == null) return [];
    return await _database!.getTimetableByInstitution(institutionId);
  }

  // Access code generation for Principal
  Future<String> generateAccessCode(String institutionId, UserRole role) async {
    // Generate unique access code for the institution and role
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final roleCode = role
        .toString()
        .split('.')
        .last
        .substring(0, 2)
        .toUpperCase();
    return '${institutionId.substring(0, 4)}$roleCode$timestamp'.substring(
      0,
      8,
    );
  }

  Future<bool> validateAccessCode(String code, String institutionId) async {
    if (_database == null) return false;
    return await _database!.validateAccessCode(code, institutionId);
  }

  // Analytics for HOD/Principal
  Future<Map<String, dynamic>> getInstitutionAnalytics(
    String institutionId,
  ) async {
    if (_database == null) return {};

    final students = await getUsersByRole(institutionId, UserRole.student);
    final teachers = await getUsersByRole(institutionId, UserRole.teacher);
    final classrooms = await getClassroomsByInstitution(institutionId);

    return {
      'totalStudents': students.length,
      'totalTeachers': teachers.length,
      'totalClassrooms': classrooms.length,
      'activeUsers':
          students.where((u) => u.isActive).length +
          teachers.where((u) => u.isActive).length,
    };
  }

  Future<Map<String, dynamic>> getDepartmentAnalytics(
    String institutionId,
    String department,
  ) async {
    if (_database == null) return {};

    final allUsers = await getUsersByInstitution(institutionId);
    final deptUsers = allUsers
        .where((u) => u.department == department)
        .toList();

    return {
      'totalUsers': deptUsers.length,
      'students': deptUsers.where((u) => u.role == UserRole.student).length,
      'teachers': deptUsers.where((u) => u.role == UserRole.teacher).length,
    };
  }
}
