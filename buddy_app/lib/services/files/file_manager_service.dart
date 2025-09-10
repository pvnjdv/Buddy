// lib/services/file_manager_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';

class FileManagerService {
  static final FileManagerService _instance = FileManagerService._internal();
  factory FileManagerService() => _instance;
  FileManagerService._internal();

  final String baseUrl = ApiConfig.baseUrl;
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // File operations
  Future<FileOperationResult> createFile(
    String filePath, {
    String content = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({
          'operation': 'create',
          'path': filePath,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to create file: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error creating file: $e',
      );
    }
  }

  Future<FileOperationResult> readFile(String filePath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({'operation': 'read', 'path': filePath}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to read file: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error reading file: $e',
      );
    }
  }

  Future<FileOperationResult> writeFile(String filePath, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({
          'operation': 'write',
          'path': filePath,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to write file: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error writing file: $e',
      );
    }
  }

  Future<FileOperationResult> deleteFile(String filePath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({'operation': 'delete', 'path': filePath}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to delete file: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error deleting file: $e',
      );
    }
  }

  Future<FileOperationResult> renameFile(String oldPath, String newPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({
          'operation': 'rename',
          'path': oldPath,
          'new_path': newPath,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to rename file: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error renaming file: $e',
      );
    }
  }

  Future<FileOperationResult> createDirectory(String dirPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({'operation': 'mkdir', 'path': dirPath}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to create directory: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error creating directory: $e',
      );
    }
  }

  Future<FileOperationResult> listDirectory(String dirPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/file-operation'),
        headers: _headers,
        body: jsonEncode({'operation': 'list', 'path': dirPath}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FileOperationResult.fromJson(data);
      } else {
        throw Exception('Failed to list directory: ${response.statusCode}');
      }
    } catch (e) {
      return FileOperationResult(
        success: false,
        message: 'Error listing directory: $e',
      );
    }
  }

  // Local file operations (for mobile/desktop)
  Future<List<FileSystemEntity>> getLocalFiles(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        return directory.listSync(recursive: false);
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error getting local files: $e');
      return [];
    }
  }

  Future<bool> createLocalFile(String filePath, {String content = ''}) async {
    try {
      final file = File(filePath);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      debugPrint('Error creating local file: $e');
      return false;
    }
  }

  Future<String?> readLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('Error reading local file: $e');
      return null;
    }
  }

  Future<bool> writeLocalFile(String filePath, String content) async {
    try {
      final file = File(filePath);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      debugPrint('Error writing local file: $e');
      return false;
    }
  }

  Future<bool> deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting local file: $e');
      return false;
    }
  }

  // Utility methods
  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  String getFileName(String filePath) {
    return path.basename(filePath);
  }

  String getDirectoryName(String filePath) {
    return path.dirname(filePath);
  }

  bool isImageFile(String filePath) {
    final extension = getFileExtension(filePath);
    return [
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension);
  }

  bool isTextFile(String filePath) {
    final extension = getFileExtension(filePath);
    return [
      '.txt',
      '.dart',
      '.py',
      '.js',
      '.ts',
      '.java',
      '.cpp',
      '.c',
      '.h',
      '.json',
      '.xml',
      '.html',
      '.css',
      '.md',
      '.yaml',
      '.yml',
      '.rs',
      '.go',
      '.php',
      '.rb',
      '.sh',
      '.bat',
      '.ps1',
      '.sql',
    ].contains(extension);
  }

  String getLanguageFromExtension(String filePath) {
    final extension = getFileExtension(filePath);
    switch (extension) {
      case '.dart':
        return 'dart';
      case '.py':
        return 'python';
      case '.js':
        return 'javascript';
      case '.ts':
        return 'typescript';
      case '.java':
        return 'java';
      case '.cpp':
      case '.cc':
      case '.cxx':
        return 'cpp';
      case '.c':
        return 'c';
      case '.go':
        return 'go';
      case '.rs':
        return 'rust';
      case '.php':
        return 'php';
      case '.rb':
        return 'ruby';
      case '.sh':
        return 'shell';
      case '.html':
        return 'html';
      case '.css':
        return 'css';
      case '.json':
        return 'json';
      case '.xml':
        return 'xml';
      case '.yaml':
      case '.yml':
        return 'yaml';
      case '.md':
        return 'markdown';
      case '.sql':
        return 'sql';
      default:
        return 'text';
    }
  }
}

class FileOperationResult {
  final bool success;
  final String message;
  final String? content;
  final List<FileItem>? files;

  FileOperationResult({
    required this.success,
    required this.message,
    this.content,
    this.files,
  });

  factory FileOperationResult.fromJson(Map<String, dynamic> json) {
    return FileOperationResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      content: json['content'],
      files: json['files'] != null
          ? (json['files'] as List).map((f) => FileItem.fromJson(f)).toList()
          : null,
    );
  }
}

class FileItem {
  final String name;
  final String path;
  final String type; // 'file' or 'directory'
  final int size;
  final double modified;

  FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.modified,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'file',
      size: json['size'] ?? 0,
      modified: (json['modified'] ?? 0).toDouble(),
    );
  }

  bool get isDirectory => type == 'directory';
  bool get isFile => type == 'file';

  DateTime get modifiedDate =>
      DateTime.fromMillisecondsSinceEpoch((modified * 1000).round());
}
