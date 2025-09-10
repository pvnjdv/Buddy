// lib/models/college_models.dart

enum UserRole { normal, student, teacher, hod, principal }

enum AppMode { normal, college }

class Institution {
  final String id;
  final String name;
  final String code;
  final String address;
  final String email;
  final String phone;
  final DateTime createdAt;
  final Map<String, dynamic> settings;

  Institution({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.email,
    required this.phone,
    required this.createdAt,
    this.settings = const {},
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      settings: json['settings'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'email': email,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings,
    };
  }
}

class CollegeUser {
  final String id;
  final String userId; // Reference to main user
  final String institutionId;
  final UserRole role;
  final String employeeId;
  final String studentId;
  final String department;
  final String designation;
  final Map<String, dynamic> permissions;
  final DateTime joinedAt;
  final bool isActive;

  CollegeUser({
    required this.id,
    required this.userId,
    required this.institutionId,
    required this.role,
    this.employeeId = '',
    this.studentId = '',
    this.department = '',
    this.designation = '',
    this.permissions = const {},
    required this.joinedAt,
    this.isActive = true,
  });

  factory CollegeUser.fromJson(Map<String, dynamic> json) {
    return CollegeUser(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      institutionId: json['institutionId'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.normal,
      ),
      employeeId: json['employeeId'] ?? '',
      studentId: json['studentId'] ?? '',
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      permissions: json['permissions'] ?? {},
      joinedAt: DateTime.parse(
        json['joinedAt'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'institutionId': institutionId,
      'role': role.toString().split('.').last,
      'employeeId': employeeId,
      'studentId': studentId,
      'department': department,
      'designation': designation,
      'permissions': permissions,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}

class Classroom {
  final String id;
  final String institutionId;
  final String name;
  final String description;
  final String teacherId;
  final String subject;
  final String semester;
  final String section;
  final List<String> studentIds;
  final String classCode;
  final DateTime createdAt;
  final bool isActive;

  Classroom({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.description,
    required this.teacherId,
    required this.subject,
    required this.semester,
    required this.section,
    this.studentIds = const [],
    required this.classCode,
    required this.createdAt,
    this.isActive = true,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'] ?? '',
      institutionId: json['institutionId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      teacherId: json['teacherId'] ?? '',
      subject: json['subject'] ?? '',
      semester: json['semester'] ?? '',
      section: json['section'] ?? '',
      studentIds: List<String>.from(json['studentIds'] ?? []),
      classCode: json['classCode'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institutionId': institutionId,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'subject': subject,
      'semester': semester,
      'section': section,
      'studentIds': studentIds,
      'classCode': classCode,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}

class Assignment {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final DateTime dueDate;
  final int totalMarks;
  final List<String> attachments;
  final DateTime createdAt;
  final bool isPublished;

  Assignment({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.totalMarks,
    this.attachments = const [],
    required this.createdAt,
    this.isPublished = false,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] ?? '',
      classroomId: json['classroomId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: DateTime.parse(
        json['dueDate'] ?? DateTime.now().toIso8601String(),
      ),
      totalMarks: json['totalMarks'] ?? 0,
      attachments: List<String>.from(json['attachments'] ?? []),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isPublished: json['isPublished'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classroomId': classroomId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'totalMarks': totalMarks,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'isPublished': isPublished,
    };
  }
}

class Result {
  final String id;
  final String studentId;
  final String assignmentId;
  final String classroomId;
  final int marksObtained;
  final String feedback;
  final DateTime submittedAt;
  final DateTime gradedAt;
  final String status; // submitted, graded, late

  Result({
    required this.id,
    required this.studentId,
    required this.assignmentId,
    required this.classroomId,
    required this.marksObtained,
    this.feedback = '',
    required this.submittedAt,
    required this.gradedAt,
    this.status = 'submitted',
  });

  factory Result.fromJson(Map<String, dynamic> json) {
    return Result(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      assignmentId: json['assignmentId'] ?? '',
      classroomId: json['classroomId'] ?? '',
      marksObtained: json['marksObtained'] ?? 0,
      feedback: json['feedback'] ?? '',
      submittedAt: DateTime.parse(
        json['submittedAt'] ?? DateTime.now().toIso8601String(),
      ),
      gradedAt: DateTime.parse(
        json['gradedAt'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'submitted',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'assignmentId': assignmentId,
      'classroomId': classroomId,
      'marksObtained': marksObtained,
      'feedback': feedback,
      'submittedAt': submittedAt.toIso8601String(),
      'gradedAt': gradedAt.toIso8601String(),
      'status': status,
    };
  }
}

class Timetable {
  final String id;
  final String institutionId;
  final String classroomId;
  final String day;
  final String startTime;
  final String endTime;
  final String subject;
  final String teacherId;
  final String room;
  final DateTime createdAt;

  Timetable({
    required this.id,
    required this.institutionId,
    required this.classroomId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacherId,
    required this.room,
    required this.createdAt,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      id: json['id'] ?? '',
      institutionId: json['institutionId'] ?? '',
      classroomId: json['classroomId'] ?? '',
      day: json['day'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      subject: json['subject'] ?? '',
      teacherId: json['teacherId'] ?? '',
      room: json['room'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institutionId': institutionId,
      'classroomId': classroomId,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'teacherId': teacherId,
      'room': room,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
