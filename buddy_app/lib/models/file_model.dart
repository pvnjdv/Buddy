// lib/models/file_model.dart
class FileModel {
  String path;
  String content;
  String language;
  bool isModified;
  DateTime lastModified;
  int? cursorPosition;
  List<int>? selections;

  FileModel({
    required this.path,
    this.content = '',
    this.language = 'text',
    this.isModified = false,
    DateTime? lastModified,
    this.cursorPosition,
    this.selections,
  }) : lastModified = lastModified ?? DateTime.now();

  String get fileName {
    return path.split('/').last;
  }

  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get fileType {
    switch (extension) {
      case 'dart':
        return 'Dart';
      case 'js':
        return 'JavaScript';
      case 'ts':
        return 'TypeScript';
      case 'py':
        return 'Python';
      case 'java':
        return 'Java';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'C++';
      case 'c':
        return 'C';
      case 'h':
        return 'C Header';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'scss':
        return 'SCSS';
      case 'json':
        return 'JSON';
      case 'xml':
        return 'XML';
      case 'md':
        return 'Markdown';
      case 'txt':
        return 'Text';
      case 'yml':
      case 'yaml':
        return 'YAML';
      case 'sh':
        return 'Shell';
      case 'bat':
        return 'Batch';
      default:
        return 'Unknown';
    }
  }

  bool get isExecutable {
    return [
      'dart',
      'py',
      'js',
      'ts',
      'java',
      'cpp',
      'c',
      'sh',
    ].contains(extension);
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'content': content,
      'language': language,
      'isModified': isModified,
      'lastModified': lastModified.toIso8601String(),
      'cursorPosition': cursorPosition,
      'selections': selections,
    };
  }

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      path: json['path'],
      content: json['content'] ?? '',
      language: json['language'] ?? 'text',
      isModified: json['isModified'] ?? false,
      lastModified: DateTime.parse(json['lastModified']),
      cursorPosition: json['cursorPosition'],
      selections: json['selections']?.cast<int>(),
    );
  }

  FileModel copy() {
    return FileModel(
      path: path,
      content: content,
      language: language,
      isModified: isModified,
      lastModified: lastModified,
      cursorPosition: cursorPosition,
      selections: selections,
    );
  }
}
