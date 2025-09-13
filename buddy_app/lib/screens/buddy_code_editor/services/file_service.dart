import 'dart:io';
import '../models/editor_file.dart';
import '../models/project_structure.dart';

class FileService {
  static Future<EditorFile> readFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final name = filePath.split('/').last;
      final extension = name.split('.').length > 1 ? name.split('.').last : '';
      final language = EditorFile.getLanguageFromExtension(extension);
      final lastModified = await file.lastModified();

      return EditorFile(
        name: name,
        path: filePath,
        content: content,
        language: language,
        lastModified: lastModified,
      );
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  static Future<void> saveFile(EditorFile file) async {
    try {
      final ioFile = File(file.path);
      await ioFile.writeAsString(file.content);
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  static Future<EditorFile> createNewFile(
    String directoryPath,
    String fileName,
  ) async {
    try {
      final filePath = '$directoryPath/$fileName';
      final file = File(filePath);

      // Create the file if it doesn't exist
      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString('');
      }

      final extension = fileName.split('.').length > 1
          ? fileName.split('.').last
          : '';
      final language = EditorFile.getLanguageFromExtension(extension);

      return EditorFile(
        name: fileName,
        path: filePath,
        content: '',
        language: language,
        isNew: true,
        isModified: false,
        lastModified: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to create file: $e');
    }
  }

  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  static Future<void> renameFile(String oldPath, String newPath) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
      }
    } catch (e) {
      throw Exception('Failed to rename file: $e');
    }
  }

  static Future<Directory> createDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      return await directory.create(recursive: true);
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  static Future<void> deleteDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to delete directory: $e');
    }
  }

  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  static Future<ProjectStructure> getProjectStructure(
    String projectPath,
  ) async {
    try {
      return await ProjectStructure.fromDirectory(projectPath);
    } catch (e) {
      throw Exception('Failed to get project structure: $e');
    }
  }

  static String getFileTemplate(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return '''void main() {
  print('Hello, Buddy!');
}''';
      case 'javascript':
        return '''console.log('Hello, Buddy!');''';
      case 'typescript':
        return '''console.log('Hello, Buddy!');''';
      case 'python':
        return '''print("Hello, Buddy!")''';
      case 'java':
        return '''public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Buddy!");
    }
}''';
      case 'html':
        return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Buddy Project</title>
</head>
<body>
    <h1>Hello, Buddy!</h1>
</body>
</html>''';
      case 'css':
        return '''/* Buddy Styles */
body {
    font-family: system-ui, -apple-system, sans-serif;
    margin: 0;
    padding: 0;
}''';
      case 'json':
        return '''{
  "name": "buddy-project",
  "version": "1.0.0",
  "description": "Created with Buddy"
}''';
      default:
        return '';
    }
  }
}
