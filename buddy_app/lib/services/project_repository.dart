import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/code_editor_models.dart';

class ProjectRepository {
  static final ProjectRepository I = ProjectRepository._();
  ProjectRepository._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final dir = Directory(p.join(dbPath, 'buddy'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final filePath = p.join(dir.path, 'projects.db');
    _db = await openDatabase(
      filePath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE projects(
          id TEXT PRIMARY KEY,
          name TEXT,
          path TEXT,
          type TEXT,
          language TEXT,
          mainFile TEXT,
          isRemote INTEGER,
          createdAt TEXT,
          lastModified TEXT,
          config TEXT)
        ''');
        await db.execute('''CREATE TABLE files(
          path TEXT PRIMARY KEY,
          projectId TEXT,
          name TEXT,
          language TEXT,
          lastModified TEXT,
          FOREIGN KEY(projectId) REFERENCES projects(id) ON DELETE CASCADE)
        ''');
      },
    );
  }

  Future<void> upsertProject(CodeProject project) async {
    await init();
    await _db!.insert('projects', {
      'id': project.id,
      'name': project.name,
      'path': project.path,
      'type': project.type,
      'language': project.language,
      'mainFile': project.mainFile,
      'isRemote': project.isRemote ? 1 : 0,
      'createdAt': project.createdAt.toIso8601String(),
      'lastModified': project.lastModified.toIso8601String(),
      'config': project.config.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CodeProject>> listProjects() async {
    await init();
    final rows = await _db!.query('projects', orderBy: 'lastModified DESC');
    return rows
        .map(
          (r) => CodeProject(
            id: r['id'] as String,
            name: r['name'] as String,
            path: r['path'] as String,
            type: r['type'] as String,
            language: r['language'] as String,
            mainFile: r['mainFile'] as String,
            isRemote: (r['isRemote'] as int) == 1,
            createdAt: DateTime.parse(r['createdAt'] as String),
            lastModified: DateTime.parse(r['lastModified'] as String),
            config: {},
          ),
        )
        .toList();
  }

  Future<void> removeProject(String id) async {
    await init();
    await _db!.delete('projects', where: 'id=?', whereArgs: [id]);
  }

  Future<void> trackFile(CodeFile file, String projectId) async {
    await init();
    await _db!.insert('files', {
      'path': file.path,
      'projectId': projectId,
      'name': file.name,
      'language': file.language,
      'lastModified': file.lastModified.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CodeFile>> listProjectFiles(String projectId) async {
    await init();
    final rows = await _db!.query(
      'files',
      where: 'projectId=?',
      whereArgs: [projectId],
    );
    return rows
        .map(
          (r) => CodeFile(
            path: r['path'] as String,
            name: r['name'] as String,
            language: r['language'] as String,
            content: '',
            lastModified: DateTime.parse(r['lastModified'] as String),
          ),
        )
        .toList();
  }
}
