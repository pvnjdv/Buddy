// lib/services/file_manager.dart
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../models/file_model.dart';
import '../../models/project_model.dart';

class FileManager {
  static const String _encoding = 'utf-8';

  Future<FileModel> loadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }

      final content = await file.readAsString(
        encoding: Encoding.getByName(_encoding)!,
      );
      final stats = await file.stat();

      return FileModel(
        path: filePath,
        content: content,
        language: _detectLanguage(filePath),
        lastModified: stats.modified,
      );
    } catch (e) {
      throw FileSystemException('Failed to load file: $e', filePath);
    }
  }

  Future<void> saveFile(FileModel fileModel) async {
    try {
      final file = File(fileModel.path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        fileModel.content,
        encoding: Encoding.getByName(_encoding)!,
      );
      fileModel.isModified = false;
      fileModel.lastModified = DateTime.now();
    } catch (e) {
      throw FileSystemException('Failed to save file: $e', fileModel.path);
    }
  }

  Future<void> createFile(String filePath, {String content = ''}) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        content,
        encoding: Encoding.getByName(_encoding)!,
      );
    } catch (e) {
      throw FileSystemException('Failed to create file: $e', filePath);
    }
  }

  Future<void> createDirectory(String dirPath) async {
    try {
      final directory = Directory(dirPath);
      await directory.create(recursive: true);
    } catch (e) {
      throw FileSystemException('Failed to create directory: $e', dirPath);
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileSystemException('Failed to delete file: $e', filePath);
    }
  }

  Future<void> deleteDirectory(String dirPath) async {
    try {
      final directory = Directory(dirPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      throw FileSystemException('Failed to delete directory: $e', dirPath);
    }
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
      } else {
        final directory = Directory(oldPath);
        if (await directory.exists()) {
          await directory.rename(newPath);
        }
      }
    } catch (e) {
      throw FileSystemException('Failed to rename: $e', oldPath);
    }
  }

  Future<void> copyFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);
      await destinationFile.parent.create(recursive: true);
      await sourceFile.copy(destinationPath);
    } catch (e) {
      throw FileSystemException('Failed to copy file: $e', sourcePath);
    }
  }

  Future<List<FileSystemEntity>> listDirectory(
    String dirPath, {
    bool recursive = false,
    bool showHidden = false,
  }) async {
    try {
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        return [];
      }

      final entities = await directory.list(recursive: recursive).toList();

      if (!showHidden) {
        entities.removeWhere(
          (entity) => path.basename(entity.path).startsWith('.'),
        );
      }

      // Sort: directories first, then files, alphabetically
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        return path
            .basename(a.path)
            .toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase());
      });

      return entities;
    } catch (e) {
      throw FileSystemException('Failed to list directory: $e', dirPath);
    }
  }

  Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  Future<bool> directoryExists(String dirPath) async {
    return await Directory(dirPath).exists();
  }

  Future<FileStat> getFileStats(String filePath) async {
    try {
      final file = File(filePath);
      return await file.stat();
    } catch (e) {
      throw FileSystemException('Failed to get file stats: $e', filePath);
    }
  }

  Future<ProjectModel> loadProject(String projectPath) async {
    try {
      final projectFile = File(path.join(projectPath, '.buddy_project.json'));
      if (await projectFile.exists()) {
        final content = await projectFile.readAsString();
        final json = jsonDecode(content);
        return ProjectModel.fromJson(json);
      } else {
        // Create a new project
        final projectName = path.basename(projectPath);
        final project = ProjectModel(
          name: projectName,
          path: projectPath,
          projectType: _detectProjectType(projectPath),
        );
        await saveProject(project);
        return project;
      }
    } catch (e) {
      throw FileSystemException('Failed to load project: $e', projectPath);
    }
  }

  Future<void> saveProject(ProjectModel project) async {
    try {
      final projectFile = File(path.join(project.path, '.buddy_project.json'));
      await projectFile.parent.create(recursive: true);
      final json = jsonEncode(project.toJson());
      await projectFile.writeAsString(
        json,
        encoding: Encoding.getByName(_encoding)!,
      );
    } catch (e) {
      throw FileSystemException('Failed to save project: $e', project.path);
    }
  }

  Future<List<String>> searchInFiles(
    String dirPath,
    String query, {
    List<String> fileExtensions = const [],
    bool caseSensitive = false,
    bool useRegex = false,
  }) async {
    final results = <String>[];

    try {
      final entities = await listDirectory(dirPath, recursive: true);

      for (final entity in entities) {
        if (entity is File) {
          final filePath = entity.path;
          final ext = path.extension(filePath).toLowerCase();

          if (fileExtensions.isNotEmpty && !fileExtensions.contains(ext)) {
            continue;
          }

          try {
            final content = await entity.readAsString();
            bool matches = false;

            if (useRegex) {
              final regex = RegExp(query, caseSensitive: caseSensitive);
              matches = regex.hasMatch(content);
            } else {
              final searchContent = caseSensitive
                  ? content
                  : content.toLowerCase();
              final searchQuery = caseSensitive ? query : query.toLowerCase();
              matches = searchContent.contains(searchQuery);
            }

            if (matches) {
              results.add(filePath);
            }
          } catch (e) {
            // Skip files that can't be read
            continue;
          }
        }
      }
    } catch (e) {
      throw FileSystemException('Failed to search in files: $e', dirPath);
    }

    return results;
  }

  String _detectLanguage(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.dart':
        return 'dart';
      case '.js':
        return 'javascript';
      case '.ts':
        return 'typescript';
      case '.py':
        return 'python';
      case '.java':
        return 'java';
      case '.cpp':
      case '.cc':
      case '.cxx':
        return 'cpp';
      case '.c':
        return 'c';
      case '.h':
        return 'c';
      case '.html':
        return 'html';
      case '.css':
        return 'css';
      case '.scss':
        return 'scss';
      case '.json':
        return 'json';
      case '.xml':
        return 'xml';
      case '.md':
        return 'markdown';
      case '.yml':
      case '.yaml':
        return 'yaml';
      case '.sh':
        return 'shell';
      case '.bat':
        return 'batch';
      default:
        return 'text';
    }
  }

  String _detectProjectType(String projectPath) {
    final files = Directory(projectPath).listSync();
    final fileNames = files.map((f) => path.basename(f.path)).toSet();

    if (fileNames.contains('pubspec.yaml')) {
      return 'flutter';
    } else if (fileNames.contains('package.json')) {
      return 'nodejs';
    } else if (fileNames.contains('pom.xml') ||
        fileNames.contains('build.gradle')) {
      return 'java';
    } else if (fileNames.contains('requirements.txt') ||
        fileNames.contains('setup.py')) {
      return 'python';
    } else if (fileNames.contains('index.html')) {
      return 'web';
    } else {
      return 'general';
    }
  }

  Future<String> getFileContent(String filePath) async {
    try {
      final file = File(filePath);
      return await file.readAsString(encoding: Encoding.getByName(_encoding)!);
    } catch (e) {
      throw FileSystemException('Failed to read file content: $e', filePath);
    }
  }

  Future<void> writeFileContent(String filePath, String content) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        content,
        encoding: Encoding.getByName(_encoding)!,
      );
    } catch (e) {
      throw FileSystemException('Failed to write file content: $e', filePath);
    }
  }

  String getRelativePath(String basePath, String filePath) {
    return path.relative(filePath, from: basePath);
  }

  String joinPaths(String path1, String path2) {
    return path.join(path1, path2);
  }

  String getFileName(String filePath) {
    return path.basename(filePath);
  }

  String getDirectoryName(String filePath) {
    return path.dirname(filePath);
  }

  String getFileExtension(String filePath) {
    return path.extension(filePath);
  }

  String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }
}
