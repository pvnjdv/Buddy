// lib/services/databases/college_database.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/college_models.dart';

class CollegeDatabase {
  static Database? _database;
  static final CollegeDatabase _instance = CollegeDatabase._internal();
  factory CollegeDatabase() => _instance;
  CollegeDatabase._internal();

  static Future<CollegeDatabase> initialize() async {
    if (_database == null) {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'buddy_college.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      );
    }
    return _instance;
  }

  static Future<void> _createTables(Database db, int version) async {
    // Institutions table
    await db.execute('''
      CREATE TABLE institutions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT UNIQUE NOT NULL,
        address TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        settings TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // College users table (separate from main users)
    await db.execute('''
      CREATE TABLE college_users (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        institution_id TEXT NOT NULL,
        role TEXT NOT NULL,
        employee_id TEXT,
        student_id TEXT,
        department TEXT,
        designation TEXT,
        permissions TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (institution_id) REFERENCES institutions (id)
      )
    ''');

    // Classrooms table
    await db.execute('''
      CREATE TABLE classrooms (
        id TEXT PRIMARY KEY,
        institution_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        teacher_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        semester TEXT,
        section TEXT,
        student_ids TEXT NOT NULL,
        class_code TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (institution_id) REFERENCES institutions (id),
        FOREIGN KEY (teacher_id) REFERENCES college_users (id)
      )
    ''');

    // Assignments table
    await db.execute('''
      CREATE TABLE assignments (
        id TEXT PRIMARY KEY,
        classroom_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        total_marks INTEGER NOT NULL,
        attachments TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_published INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id)
      )
    ''');

    // Results table
    await db.execute('''
      CREATE TABLE results (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        assignment_id TEXT NOT NULL,
        classroom_id TEXT NOT NULL,
        marks_obtained INTEGER NOT NULL,
        feedback TEXT,
        submitted_at TEXT NOT NULL,
        graded_at TEXT,
        status TEXT NOT NULL DEFAULT 'submitted',
        FOREIGN KEY (student_id) REFERENCES college_users (id),
        FOREIGN KEY (assignment_id) REFERENCES assignments (id),
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id)
      )
    ''');

    // Timetable table
    await db.execute('''
      CREATE TABLE timetable (
        id TEXT PRIMARY KEY,
        institution_id TEXT NOT NULL,
        classroom_id TEXT NOT NULL,
        day TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        subject TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        room TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (institution_id) REFERENCES institutions (id),
        FOREIGN KEY (classroom_id) REFERENCES classrooms (id),
        FOREIGN KEY (teacher_id) REFERENCES college_users (id)
      )
    ''');

    // Access codes table
    await db.execute('''
      CREATE TABLE access_codes (
        id TEXT PRIMARY KEY,
        institution_id TEXT NOT NULL,
        code TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        is_used INTEGER NOT NULL DEFAULT 0,
        used_by TEXT,
        used_at TEXT,
        FOREIGN KEY (institution_id) REFERENCES institutions (id),
        FOREIGN KEY (created_by) REFERENCES college_users (id)
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_college_users_institution ON college_users(institution_id)',
    );
    await db.execute(
      'CREATE INDEX idx_college_users_role ON college_users(role)',
    );
    await db.execute(
      'CREATE INDEX idx_classrooms_teacher ON classrooms(teacher_id)',
    );
    await db.execute(
      'CREATE INDEX idx_assignments_classroom ON assignments(classroom_id)',
    );
    await db.execute('CREATE INDEX idx_results_student ON results(student_id)');
    await db.execute(
      'CREATE INDEX idx_results_assignment ON results(assignment_id)',
    );
    await db.execute(
      'CREATE INDEX idx_timetable_classroom ON timetable(classroom_id)',
    );
    await db.execute(
      'CREATE INDEX idx_timetable_teacher ON timetable(teacher_id)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle database upgrades
  }

  // Institution methods
  Future<Institution?> getInstitutionByCode(String code) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'institutions',
      where: 'code = ?',
      whereArgs: [code],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Institution.fromJson({
        ...map,
        'settings': map['settings'] ?? '{}',
        'createdAt': map['created_at'],
      });
    }
    return null;
  }

  Future<Institution?> createInstitution(Institution institution) async {
    final db = _database!;
    await db.insert('institutions', {
      'id': institution.id,
      'name': institution.name,
      'code': institution.code,
      'address': institution.address,
      'email': institution.email,
      'phone': institution.phone,
      'settings': '{}',
      'created_at': institution.createdAt.toIso8601String(),
    });
    return institution;
  }

  Future<List<Institution>> getAllInstitutions() async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query('institutions');
    return maps
        .map(
          (map) => Institution.fromJson({
            ...map,
            'settings': map['settings'] ?? '{}',
            'createdAt': map['created_at'],
          }),
        )
        .toList();
  }

  // College user methods
  Future<CollegeUser?> getCollegeUser(
    String userId,
    String institutionId,
  ) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'college_users',
      where: 'user_id = ? AND institution_id = ?',
      whereArgs: [userId, institutionId],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return CollegeUser.fromJson({
        ...map,
        'userId': map['user_id'],
        'institutionId': map['institution_id'],
        'employeeId': map['employee_id'],
        'studentId': map['student_id'],
        'permissions': map['permissions'] ?? '{}',
        'joinedAt': map['joined_at'],
        'isActive': map['is_active'] == 1,
      });
    }
    return null;
  }

  Future<CollegeUser?> createCollegeUser(CollegeUser collegeUser) async {
    final db = _database!;
    await db.insert('college_users', {
      'id': collegeUser.id,
      'user_id': collegeUser.userId,
      'institution_id': collegeUser.institutionId,
      'role': collegeUser.role.toString().split('.').last,
      'employee_id': collegeUser.employeeId,
      'student_id': collegeUser.studentId,
      'department': collegeUser.department,
      'designation': collegeUser.designation,
      'permissions': '{}',
      'joined_at': collegeUser.joinedAt.toIso8601String(),
      'is_active': collegeUser.isActive ? 1 : 0,
    });
    return collegeUser;
  }

  Future<List<CollegeUser>> getUsersByInstitution(String institutionId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'college_users',
      where: 'institution_id = ?',
      whereArgs: [institutionId],
    );

    return maps
        .map(
          (map) => CollegeUser.fromJson({
            ...map,
            'userId': map['user_id'],
            'institutionId': map['institution_id'],
            'employeeId': map['employee_id'],
            'studentId': map['student_id'],
            'permissions': map['permissions'] ?? '{}',
            'joinedAt': map['joined_at'],
            'isActive': map['is_active'] == 1,
          }),
        )
        .toList();
  }

  Future<List<CollegeUser>> getUsersByRole(
    String institutionId,
    UserRole role,
  ) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'college_users',
      where: 'institution_id = ? AND role = ?',
      whereArgs: [institutionId, role.toString().split('.').last],
    );

    return maps
        .map(
          (map) => CollegeUser.fromJson({
            ...map,
            'userId': map['user_id'],
            'institutionId': map['institution_id'],
            'employeeId': map['employee_id'],
            'studentId': map['student_id'],
            'permissions': map['permissions'] ?? '{}',
            'joinedAt': map['joined_at'],
            'isActive': map['is_active'] == 1,
          }),
        )
        .toList();
  }

  // Classroom methods
  Future<Classroom?> createClassroom(Classroom classroom) async {
    final db = _database!;
    await db.insert('classrooms', {
      'id': classroom.id,
      'institution_id': classroom.institutionId,
      'name': classroom.name,
      'description': classroom.description,
      'teacher_id': classroom.teacherId,
      'subject': classroom.subject,
      'semester': classroom.semester,
      'section': classroom.section,
      'student_ids': classroom.studentIds.join(','),
      'class_code': classroom.classCode,
      'created_at': classroom.createdAt.toIso8601String(),
      'is_active': classroom.isActive ? 1 : 0,
    });
    return classroom;
  }

  Future<List<Classroom>> getClassroomsByTeacher(String teacherId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'classrooms',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );

    return maps
        .map(
          (map) => Classroom.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'teacherId': map['teacher_id'],
            'studentIds': map['student_ids']
                .split(',')
                .where((id) => id.isNotEmpty)
                .toList(),
            'classCode': map['class_code'],
            'createdAt': map['created_at'],
            'isActive': map['is_active'] == 1,
          }),
        )
        .toList();
  }

  Future<List<Classroom>> getClassroomsByStudent(String studentId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'classrooms',
      where: 'student_ids LIKE ?',
      whereArgs: ['%$studentId%'],
    );

    return maps
        .map(
          (map) => Classroom.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'teacherId': map['teacher_id'],
            'studentIds': map['student_ids']
                .split(',')
                .where((id) => id.isNotEmpty)
                .toList(),
            'classCode': map['class_code'],
            'createdAt': map['created_at'],
            'isActive': map['is_active'] == 1,
          }),
        )
        .toList();
  }

  Future<List<Classroom>> getClassroomsByInstitution(
    String institutionId,
  ) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'classrooms',
      where: 'institution_id = ?',
      whereArgs: [institutionId],
    );

    return maps
        .map(
          (map) => Classroom.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'teacherId': map['teacher_id'],
            'studentIds': map['student_ids']
                .split(',')
                .where((id) => id.isNotEmpty)
                .toList(),
            'classCode': map['class_code'],
            'createdAt': map['created_at'],
            'isActive': map['is_active'] == 1,
          }),
        )
        .toList();
  }

  Future<Classroom?> getClassroomByCode(String classCode) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'classrooms',
      where: 'class_code = ?',
      whereArgs: [classCode],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Classroom.fromJson({
        ...map,
        'institutionId': map['institution_id'],
        'teacherId': map['teacher_id'],
        'studentIds': map['student_ids']
            .split(',')
            .where((id) => id.isNotEmpty)
            .toList(),
        'classCode': map['class_code'],
        'createdAt': map['created_at'],
        'isActive': map['is_active'] == 1,
      });
    }
    return null;
  }

  Future<bool> joinClassroom(String classroomId, String studentId) async {
    final db = _database!;

    // Get current classroom
    final classroom = await db.query(
      'classrooms',
      where: 'id = ?',
      whereArgs: [classroomId],
    );

    if (classroom.isNotEmpty) {
      final currentStudents = classroom.first['student_ids'].toString();
      final studentsList = currentStudents
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList();

      if (!studentsList.contains(studentId)) {
        studentsList.add(studentId);
        await db.update(
          'classrooms',
          {'student_ids': studentsList.join(',')},
          where: 'id = ?',
          whereArgs: [classroomId],
        );
        return true;
      }
    }
    return false;
  }

  // Assignment methods
  Future<Assignment?> createAssignment(Assignment assignment) async {
    final db = _database!;
    await db.insert('assignments', {
      'id': assignment.id,
      'classroom_id': assignment.classroomId,
      'title': assignment.title,
      'description': assignment.description,
      'due_date': assignment.dueDate.toIso8601String(),
      'total_marks': assignment.totalMarks,
      'attachments': assignment.attachments.join(','),
      'created_at': assignment.createdAt.toIso8601String(),
      'is_published': assignment.isPublished ? 1 : 0,
    });
    return assignment;
  }

  Future<List<Assignment>> getAssignmentsByClassroom(String classroomId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'assignments',
      where: 'classroom_id = ?',
      whereArgs: [classroomId],
      orderBy: 'due_date ASC',
    );

    return maps
        .map(
          (map) => Assignment.fromJson({
            ...map,
            'classroomId': map['classroom_id'],
            'dueDate': map['due_date'],
            'totalMarks': map['total_marks'],
            'attachments': map['attachments']
                .split(',')
                .where((att) => att.isNotEmpty)
                .toList(),
            'createdAt': map['created_at'],
            'isPublished': map['is_published'] == 1,
          }),
        )
        .toList();
  }

  Future<Assignment?> updateAssignment(Assignment assignment) async {
    final db = _database!;
    await db.update(
      'assignments',
      {
        'title': assignment.title,
        'description': assignment.description,
        'due_date': assignment.dueDate.toIso8601String(),
        'total_marks': assignment.totalMarks,
        'attachments': assignment.attachments.join(','),
        'is_published': assignment.isPublished ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
    return assignment;
  }

  // Result methods
  Future<Result?> submitResult(Result result) async {
    final db = _database!;
    await db.insert('results', {
      'id': result.id,
      'student_id': result.studentId,
      'assignment_id': result.assignmentId,
      'classroom_id': result.classroomId,
      'marks_obtained': result.marksObtained,
      'feedback': result.feedback,
      'submitted_at': result.submittedAt.toIso8601String(),
      'graded_at': result.gradedAt.toIso8601String(),
      'status': result.status,
    });
    return result;
  }

  Future<List<Result>> getResultsByStudent(String studentId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'results',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'submitted_at DESC',
    );

    return maps
        .map(
          (map) => Result.fromJson({
            ...map,
            'studentId': map['student_id'],
            'assignmentId': map['assignment_id'],
            'classroomId': map['classroom_id'],
            'marksObtained': map['marks_obtained'],
            'submittedAt': map['submitted_at'],
            'gradedAt': map['graded_at'],
          }),
        )
        .toList();
  }

  Future<List<Result>> getResultsByAssignment(String assignmentId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'results',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      orderBy: 'submitted_at ASC',
    );

    return maps
        .map(
          (map) => Result.fromJson({
            ...map,
            'studentId': map['student_id'],
            'assignmentId': map['assignment_id'],
            'classroomId': map['classroom_id'],
            'marksObtained': map['marks_obtained'],
            'submittedAt': map['submitted_at'],
            'gradedAt': map['graded_at'],
          }),
        )
        .toList();
  }

  Future<Result?> gradeResult(
    String resultId,
    int marks,
    String feedback,
  ) async {
    final db = _database!;
    await db.update(
      'results',
      {
        'marks_obtained': marks,
        'feedback': feedback,
        'graded_at': DateTime.now().toIso8601String(),
        'status': 'graded',
      },
      where: 'id = ?',
      whereArgs: [resultId],
    );

    final maps = await db.query(
      'results',
      where: 'id = ?',
      whereArgs: [resultId],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Result.fromJson({
        ...map,
        'studentId': map['student_id'],
        'assignmentId': map['assignment_id'],
        'classroomId': map['classroom_id'],
        'marksObtained': map['marks_obtained'],
        'submittedAt': map['submitted_at'],
        'gradedAt': map['graded_at'],
      });
    }
    return null;
  }

  // Timetable methods
  Future<Timetable?> createTimetableEntry(Timetable timetable) async {
    final db = _database!;
    await db.insert('timetable', {
      'id': timetable.id,
      'institution_id': timetable.institutionId,
      'classroom_id': timetable.classroomId,
      'day': timetable.day,
      'start_time': timetable.startTime,
      'end_time': timetable.endTime,
      'subject': timetable.subject,
      'teacher_id': timetable.teacherId,
      'room': timetable.room,
      'created_at': timetable.createdAt.toIso8601String(),
    });
    return timetable;
  }

  Future<List<Timetable>> getTimetableByClassroom(String classroomId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable',
      where: 'classroom_id = ?',
      whereArgs: [classroomId],
      orderBy: 'day, start_time',
    );

    return maps
        .map(
          (map) => Timetable.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'classroomId': map['classroom_id'],
            'startTime': map['start_time'],
            'endTime': map['end_time'],
            'teacherId': map['teacher_id'],
            'createdAt': map['created_at'],
          }),
        )
        .toList();
  }

  Future<List<Timetable>> getTimetableByTeacher(String teacherId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'day, start_time',
    );

    return maps
        .map(
          (map) => Timetable.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'classroomId': map['classroom_id'],
            'startTime': map['start_time'],
            'endTime': map['end_time'],
            'teacherId': map['teacher_id'],
            'createdAt': map['created_at'],
          }),
        )
        .toList();
  }

  Future<List<Timetable>> getTimetableByInstitution(
    String institutionId,
  ) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable',
      where: 'institution_id = ?',
      whereArgs: [institutionId],
      orderBy: 'day, start_time',
    );

    return maps
        .map(
          (map) => Timetable.fromJson({
            ...map,
            'institutionId': map['institution_id'],
            'classroomId': map['classroom_id'],
            'startTime': map['start_time'],
            'endTime': map['end_time'],
            'teacherId': map['teacher_id'],
            'createdAt': map['created_at'],
          }),
        )
        .toList();
  }

  // Access code validation
  Future<bool> validateAccessCode(String code, String institutionId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'access_codes',
      where: 'code = ? AND institution_id = ? AND is_used = 0',
      whereArgs: [code, institutionId],
    );

    return maps.isNotEmpty;
  }

  // Get results by classroom
  Future<List<Result>> getResultsByClassroom(String classroomId) async {
    final db = _database!;
    final List<Map<String, dynamic>> maps = await db.query(
      'results',
      where: 'classroom_id = ?',
      whereArgs: [classroomId],
      orderBy: 'submitted_at DESC',
    );

    return maps
        .map(
          (map) => Result.fromJson({
            ...map,
            'studentId': map['student_id'],
            'assignmentId': map['assignment_id'],
            'classroomId': map['classroom_id'],
            'marksObtained': map['marks_obtained'],
            'submittedAt': map['submitted_at'],
            'gradedAt': map['graded_at'],
          }),
        )
        .toList();
  }

  // Get classroom members
  Future<List<CollegeUser>> getClassroomMembers(String classroomId) async {
    final db = _database!;

    // First get the classroom to find student IDs
    final classroomMaps = await db.query(
      'classrooms',
      where: 'id = ?',
      whereArgs: [classroomId],
    );

    if (classroomMaps.isEmpty) return [];

    final classroom = classroomMaps.first;
    final studentIds = (classroom['student_ids'] as String).split(',');

    if (studentIds.isEmpty) return [];

    // Get the college users for these student IDs
    final placeholders = studentIds.map((_) => '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'college_users',
      where: 'id IN ($placeholders)',
      whereArgs: studentIds,
    );

    return maps
        .map(
          (map) => CollegeUser.fromJson({
            ...map,
            'userId': map['user_id'],
            'institutionId': map['institution_id'],
            'employeeId': map['employee_id'],
            'studentId': map['student_id'],
            'joinedAt': map['joined_at'],
            'isActive': map['is_active'] == 1,
            'permissions': map['permissions'],
          }),
        )
        .toList();
  }
}
