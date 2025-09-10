// lib/models/project_model.dart
import 'file_model.dart';

class ProjectModel {
  String name;
  String path;
  String description;
  String projectType;
  List<String> openFiles;
  Map<String, dynamic> settings;
  DateTime createdAt;
  DateTime lastAccessed;

  ProjectModel({
    required this.name,
    required this.path,
    this.description = '',
    this.projectType = 'general',
    List<String>? openFiles,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? lastAccessed,
  }) : openFiles = openFiles ?? [],
       settings = settings ?? {},
       createdAt = createdAt ?? DateTime.now(),
       lastAccessed = lastAccessed ?? DateTime.now();

  String get displayName => name.isEmpty ? path.split('/').last : name;

  List<String> get supportedLanguages {
    switch (projectType) {
      case 'flutter':
        return ['dart', 'yaml', 'json', 'xml'];
      case 'web':
        return ['html', 'css', 'js', 'ts', 'json'];
      case 'python':
        return ['py', 'txt', 'json', 'yaml'];
      case 'java':
        return ['java', 'xml', 'properties'];
      case 'nodejs':
        return ['js', 'ts', 'json', 'md'];
      default:
        return ['txt', 'md', 'json'];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'description': description,
      'projectType': projectType,
      'openFiles': openFiles,
      'settings': settings,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessed': lastAccessed.toIso8601String(),
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      name: json['name'],
      path: json['path'],
      description: json['description'] ?? '',
      projectType: json['projectType'] ?? 'general',
      openFiles: (json['openFiles'] as List?)?.cast<String>() ?? [],
      settings: json['settings'] ?? {},
      createdAt: DateTime.parse(json['createdAt']),
      lastAccessed: DateTime.parse(json['lastAccessed']),
    );
  }

  void updateLastAccessed() {
    lastAccessed = DateTime.now();
  }

  void addOpenFile(String filePath) {
    if (!openFiles.contains(filePath)) {
      openFiles.add(filePath);
    }
  }

  void removeOpenFile(String filePath) {
    openFiles.remove(filePath);
  }

  ProjectModel copy() {
    return ProjectModel(
      name: name,
      path: path,
      description: description,
      projectType: projectType,
      openFiles: List.from(openFiles),
      settings: Map.from(settings),
      createdAt: createdAt,
      lastAccessed: lastAccessed,
    );
  }
}
