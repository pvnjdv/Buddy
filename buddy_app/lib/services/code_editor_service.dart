// lib/services/code_editor_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/code_editor_models.dart';

class CodeEditorService {
  static final CodeEditorService _instance = CodeEditorService._internal();
  factory CodeEditorService() => _instance;
  CodeEditorService._internal();

  final StreamController<CodeFile> _fileChangedController =
      StreamController.broadcast();
  final StreamController<CodeProject> _projectChangedController =
      StreamController.broadcast();
  final StreamController<String> _outputController =
      StreamController.broadcast();

  Stream<CodeFile> get onFileChanged => _fileChangedController.stream;
  Stream<CodeProject> get onProjectChanged => _projectChangedController.stream;
  Stream<String> get onOutput => _outputController.stream;

  EditorPreferences _preferences = EditorPreferences();
  CodeProject? _currentProject;
  String _currentLanguage = 'dart';

  // Project templates
  final Map<String, ProjectTemplate> _templates = {
    'flutter_app': ProjectTemplate(
      id: 'flutter_app',
      name: 'Flutter Application',
      description: 'Cross-platform mobile app with Flutter',
      type: 'flutter',
      language: 'dart',
      platforms: ['android', 'ios', 'web', 'desktop'],
      dependencies: ['flutter'],
      config: {
        'flutter': {'version': 'stable'},
        'platforms': ['android', 'ios'],
      },
      icon: 'flutter',
    ),
    'python_app': ProjectTemplate(
      id: 'python_app',
      name: 'Python Application',
      description: 'Python application with modern tooling',
      type: 'python',
      language: 'python',
      platforms: ['desktop'],
      dependencies: ['requests', 'flask'],
      config: {
        'python': {'version': '3.9+'},
        'requirements': 'requirements.txt',
      },
      icon: 'python',
    ),
    'node_app': ProjectTemplate(
      id: 'node_app',
      name: 'Node.js Application',
      description: 'Modern Node.js application',
      type: 'nodejs',
      language: 'javascript',
      platforms: ['web', 'desktop'],
      dependencies: ['express', 'nodemon'],
      config: {
        'node': {'version': '16+'},
        'package': 'package.json',
      },
      icon: 'nodejs',
    ),
    'android_native': ProjectTemplate(
      id: 'android_native',
      name: 'Android Native App',
      description: 'Native Android application with Kotlin',
      type: 'android',
      language: 'kotlin',
      platforms: ['android'],
      dependencies: ['androidx.core', 'androidx.appcompat'],
      config: {
        'android': {'minSdkVersion': 21, 'targetSdkVersion': 33},
        'gradle': {'version': '7.0+'},
      },
      icon: 'android',
    ),
  };

  Future<void> initialize() async {
    try {
      await _loadPreferences();
      _outputController.add('Buddy Code Editor initialized successfully');
    } catch (e) {
      _outputController.add('Error initializing editor: $e');
    }
  }

  void dispose() {
    _fileChangedController.close();
    _projectChangedController.close();
    _outputController.close();
  }

  // Project Management
  Future<CodeProject> createProject({
    required String name,
    required String basePath,
    required String template,
    Map<String, dynamic> config = const {},
  }) async {
    try {
      final projectTemplate = _templates[template];
      if (projectTemplate == null) {
        throw Exception('Template not found: $template');
      }

      final projectId = DateTime.now().millisecondsSinceEpoch.toString();
      final projectPath = path.join(basePath, name);

      // Create project directory
      final projectDir = Directory(projectPath);
      if (await projectDir.exists()) {
        throw Exception('Project directory already exists');
      }
      await projectDir.create(recursive: true);

      // Create project structure based on template
      await _createProjectStructure(projectPath, projectTemplate);

      // Create project configuration
      final project = CodeProject(
        id: projectId,
        name: name,
        path: projectPath,
        type: projectTemplate.type,
        language: projectTemplate.language,
        mainFile: _getMainFile(projectTemplate),
        config: {...projectTemplate.config, ...config},
        dependencies: projectTemplate.dependencies,
      );

      // Save project configuration
      await _saveProjectConfig(project);

      // Initialize version control
      await _initializeGit(projectPath);

      // Install dependencies
      await _installDependencies(project);

      _currentProject = project;
      _projectChangedController.add(project);
      _outputController.add('Project created successfully: $name');

      return project;
    } catch (e) {
      _outputController.add('Error creating project: $e');
      rethrow;
    }
  }

  Future<CodeProject> openProject(String projectPath) async {
    try {
      final configFile = File(path.join(projectPath, '.buddy', 'project.json'));
      if (!await configFile.exists()) {
        // Try to detect project type
        return await _detectAndImportProject(projectPath);
      }

      final configContent = await configFile.readAsString();
      final project = CodeProject.fromJson(jsonDecode(configContent));

      _currentProject = project;
      _projectChangedController.add(project);
      _outputController.add('Project opened: ${project.name}');

      return project;
    } catch (e) {
      _outputController.add('Error opening project: $e');
      rethrow;
    }
  }

  Future<List<ProjectItem>> getProjectFiles(String projectPath) async {
    try {
      final projectDir = Directory(projectPath);
      if (!await projectDir.exists()) {
        return [];
      }

      return await _buildFileTree(projectDir, projectPath);
    } catch (e) {
      _outputController.add('Error loading project files: $e');
      return [];
    }
  }

  // File Operations
  Future<CodeFile> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final content = await file.readAsString();
      final fileName = path.basename(filePath);
      final language = _detectLanguage(fileName);

      final codeFile = CodeFile(
        path: filePath,
        name: fileName,
        language: language,
        content: content,
        lastModified: await file.lastModified(),
      );

      _fileChangedController.add(codeFile);
      return codeFile;
    } catch (e) {
      _outputController.add('Error opening file: $e');
      rethrow;
    }
  }

  Future<void> saveFile(CodeFile file) async {
    try {
      final fileObj = File(file.path);
      await fileObj.writeAsString(file.content);
      file.isModified = false;
      file.lastModified;

      _fileChangedController.add(file);
      _outputController.add('File saved: ${file.name}');
    } catch (e) {
      _outputController.add('Error saving file: $e');
      rethrow;
    }
  }

  Future<CodeFile> createFile({
    required String dirPath,
    required String fileName,
    String content = '',
  }) async {
    try {
      final filePath = path.join(dirPath, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        throw Exception('File already exists: $fileName');
      }

      await file.create(recursive: true);
      await file.writeAsString(content);

      final language = _detectLanguage(fileName);
      final codeFile = CodeFile(
        path: filePath,
        name: fileName,
        language: language,
        content: content,
      );

      _fileChangedController.add(codeFile);
      _outputController.add('File created: $fileName');

      return codeFile;
    } catch (e) {
      _outputController.add('Error creating file: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _outputController.add('File deleted: ${path.basename(filePath)}');
      }
    } catch (e) {
      _outputController.add('Error deleting file: $e');
      rethrow;
    }
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
        _outputController.add(
          'File renamed: ${path.basename(oldPath)} → ${path.basename(newPath)}',
        );
      }
    } catch (e) {
      _outputController.add('Error renaming file: $e');
      rethrow;
    }
  }

  // Build and Run Operations
  Future<String> buildProject(
    CodeProject project, {
    String? buildConfig,
  }) async {
    try {
      _outputController.add('Building project: ${project.name}');

      final result = await _executeBuildCommand(project, buildConfig);

      if (result.exitCode == 0) {
        _outputController.add('Build completed successfully');
      } else {
        _outputController.add(
          'Build failed with exit code: ${result.exitCode}',
        );
      }

      return result.stdout + result.stderr;
    } catch (e) {
      _outputController.add('Error building project: $e');
      rethrow;
    }
  }

  Future<Process> runProject(CodeProject project, {String? runConfig}) async {
    try {
      _outputController.add('Running project: ${project.name}');

      final command = _getRunCommand(project, runConfig);
      final process = await Process.start(
        command.first,
        command.skip(1).toList(),
        workingDirectory: project.path,
      );

      // Stream output
      process.stdout.transform(utf8.decoder).listen((data) {
        _outputController.add(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _outputController.add('[ERROR] $data');
      });

      return process;
    } catch (e) {
      _outputController.add('Error running project: $e');
      rethrow;
    }
  }

  Future<String> testProject(CodeProject project) async {
    try {
      _outputController.add('Testing project: ${project.name}');

      final result = await _executeTestCommand(project);

      if (result.exitCode == 0) {
        _outputController.add('All tests passed');
      } else {
        _outputController.add(
          'Tests failed with exit code: ${result.exitCode}',
        );
      }

      return result.stdout + result.stderr;
    } catch (e) {
      _outputController.add('Error testing project: $e');
      rethrow;
    }
  }

  // Search Operations
  Future<List<SearchResult>> searchInProject({
    required String projectPath,
    required String query,
    bool caseSensitive = false,
    bool useRegex = false,
    List<String> includeExtensions = const [],
    List<String> excludeDirectories = const [
      '.git',
      'node_modules',
      '.dart_tool',
    ],
  }) async {
    try {
      final results = <SearchResult>[];
      final projectDir = Directory(projectPath);

      await for (final entity in projectDir.list(recursive: true)) {
        if (entity is File) {
          final filePath = entity.path;
          final relativePath = path.relative(filePath, from: projectPath);

          // Skip excluded directories
          if (excludeDirectories.any((dir) => relativePath.contains(dir))) {
            continue;
          }

          // Filter by extensions
          if (includeExtensions.isNotEmpty) {
            final ext = path.extension(filePath).toLowerCase();
            if (!includeExtensions.contains(ext)) {
              continue;
            }
          }

          try {
            final content = await entity.readAsString();
            final lines = content.split('\n');

            for (int i = 0; i < lines.length; i++) {
              final line = lines[i];
              final matches = _findMatches(
                line,
                query,
                caseSensitive,
                useRegex,
              );

              for (final match in matches) {
                results.add(
                  SearchResult(
                    filePath: filePath,
                    fileName: path.basename(filePath),
                    line: i + 1,
                    column: match['start'] + 1,
                    content: line,
                    matchedText: match['text'],
                    startIndex: match['start'],
                    endIndex: match['end'],
                  ),
                );
              }
            }
          } catch (e) {
            // Skip files that can't be read as text
            continue;
          }
        }
      }

      return results;
    } catch (e) {
      _outputController.add('Error searching project: $e');
      return [];
    }
  }

  Future<int> replaceInProject({
    required String projectPath,
    required String searchQuery,
    required String replaceText,
    bool caseSensitive = false,
    bool useRegex = false,
    List<String> includeExtensions = const [],
  }) async {
    try {
      int totalReplacements = 0;
      final searchResults = await searchInProject(
        projectPath: projectPath,
        query: searchQuery,
        caseSensitive: caseSensitive,
        useRegex: useRegex,
        includeExtensions: includeExtensions,
      );

      final fileGroups = <String, List<SearchResult>>{};
      for (final result in searchResults) {
        fileGroups.putIfAbsent(result.filePath, () => []).add(result);
      }

      for (final entry in fileGroups.entries) {
        final filePath = entry.key;
        final results = entry.value;

        final file = File(filePath);
        final content = await file.readAsString();
        final lines = content.split('\n');

        // Sort results by line number in descending order to avoid index issues
        results.sort((a, b) => b.line.compareTo(a.line));

        for (final result in results) {
          final lineIndex = result.line - 1;
          if (lineIndex < lines.length) {
            final line = lines[lineIndex];
            final newLine = _performReplace(
              line,
              searchQuery,
              replaceText,
              caseSensitive,
              useRegex,
            );
            lines[lineIndex] = newLine;
            totalReplacements++;
          }
        }

        await file.writeAsString(lines.join('\n'));
      }

      _outputController.add('Replaced $totalReplacements occurrences');
      return totalReplacements;
    } catch (e) {
      _outputController.add('Error replacing in project: $e');
      return 0;
    }
  }

  // Git Operations
  Future<GitStatus> getGitStatus(String projectPath) async {
    try {
      final result = await Process.run('git', [
        'status',
        '--porcelain=v1',
        '--branch',
      ], workingDirectory: projectPath);

      if (result.exitCode != 0) {
        throw Exception('Git command failed: ${result.stderr}');
      }

      return _parseGitStatus(result.stdout);
    } catch (e) {
      _outputController.add('Error getting git status: $e');
      rethrow;
    }
  }

  Future<void> gitAdd(String projectPath, List<String> files) async {
    try {
      await Process.run('git', [
        'add',
        ...files,
      ], workingDirectory: projectPath);
      _outputController.add('Files staged for commit');
    } catch (e) {
      _outputController.add('Error staging files: $e');
      rethrow;
    }
  }

  Future<void> gitCommit(String projectPath, String message) async {
    try {
      await Process.run('git', [
        'commit',
        '-m',
        message,
      ], workingDirectory: projectPath);
      _outputController.add('Changes committed');
    } catch (e) {
      _outputController.add('Error committing changes: $e');
      rethrow;
    }
  }

  Future<void> gitPush(String projectPath) async {
    try {
      await Process.run('git', ['push'], workingDirectory: projectPath);
      _outputController.add('Changes pushed to remote');
    } catch (e) {
      _outputController.add('Error pushing changes: $e');
      rethrow;
    }
  }

  // Preferences
  EditorPreferences get preferences => _preferences;

  // Current state getters
  CodeProject? get currentProject => _currentProject;
  String get currentLanguage => _currentLanguage;

  Future<void> updatePreferences(EditorPreferences newPreferences) async {
    _preferences = newPreferences;
    await _savePreferences();
  }

  void setLanguage(String language) {
    _currentLanguage = language;
  }

  // Templates
  List<ProjectTemplate> getAvailableTemplates() {
    return _templates.values.toList();
  }

  ProjectTemplate? getTemplate(String templateId) {
    return _templates[templateId];
  }

  // Helper methods
  Future<void> _createProjectStructure(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create basic project structure based on template
    switch (template.type) {
      case 'flutter':
        await _createFlutterProject(projectPath, template);
        break;
      case 'python':
        await _createPythonProject(projectPath, template);
        break;
      case 'nodejs':
        await _createNodeJSProject(projectPath, template);
        break;
      case 'android':
        await _createAndroidProject(projectPath, template);
        break;
      default:
        await _createGenericProject(projectPath, template);
    }
  }

  Future<void> _createFlutterProject(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create Flutter project structure
    final dirs = ['lib', 'test', 'android/app/src/main', 'ios/Runner'];
    for (final dir in dirs) {
      await Directory(path.join(projectPath, dir)).create(recursive: true);
    }

    // Create main.dart
    final mainFile = File(path.join(projectPath, 'lib', 'main.dart'));
    await mainFile.writeAsString(_getFlutterMainContent());

    // Create pubspec.yaml
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    await pubspecFile.writeAsString(_getFlutterPubspecContent(template));
  }

  Future<void> _createPythonProject(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create Python project structure
    final dirs = ['src', 'tests', 'docs'];
    for (final dir in dirs) {
      await Directory(path.join(projectPath, dir)).create(recursive: true);
    }

    // Create main.py
    final mainFile = File(path.join(projectPath, 'src', 'main.py'));
    await mainFile.writeAsString(_getPythonMainContent());

    // Create requirements.txt
    final reqFile = File(path.join(projectPath, 'requirements.txt'));
    await reqFile.writeAsString(template.dependencies.join('\n'));
  }

  Future<void> _createNodeJSProject(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create Node.js project structure
    final dirs = ['src', 'test', 'public'];
    for (final dir in dirs) {
      await Directory(path.join(projectPath, dir)).create(recursive: true);
    }

    // Create index.js
    final mainFile = File(path.join(projectPath, 'src', 'index.js'));
    await mainFile.writeAsString(_getNodeJSMainContent());

    // Create package.json
    final packageFile = File(path.join(projectPath, 'package.json'));
    await packageFile.writeAsString(_getNodeJSPackageContent(template));
  }

  Future<void> _createAndroidProject(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create Android project structure
    final dirs = [
      'app/src/main/java',
      'app/src/main/res/layout',
      'app/src/main/res/values',
    ];
    for (final dir in dirs) {
      await Directory(path.join(projectPath, dir)).create(recursive: true);
    }

    // Create MainActivity.kt
    final mainFile = File(
      path.join(projectPath, 'app/src/main/java', 'MainActivity.kt'),
    );
    await mainFile.writeAsString(_getAndroidMainContent());

    // Create build.gradle
    final gradleFile = File(path.join(projectPath, 'app', 'build.gradle'));
    await gradleFile.writeAsString(_getAndroidGradleContent(template));
  }

  Future<void> _createGenericProject(
    String projectPath,
    ProjectTemplate template,
  ) async {
    // Create basic project structure
    final dirs = ['src', 'test', 'docs'];
    for (final dir in dirs) {
      await Directory(path.join(projectPath, dir)).create(recursive: true);
    }

    // Create README.md
    final readmeFile = File(path.join(projectPath, 'README.md'));
    await readmeFile.writeAsString(
      '# ${path.basename(projectPath)}\n\nProject created with Buddy Code Editor',
    );
  }

  String _getMainFile(ProjectTemplate template) {
    switch (template.type) {
      case 'flutter':
        return 'lib/main.dart';
      case 'python':
        return 'src/main.py';
      case 'nodejs':
        return 'src/index.js';
      case 'android':
        return 'app/src/main/java/MainActivity.kt';
      default:
        return 'README.md';
    }
  }

  Future<List<ProjectItem>> _buildFileTree(
    Directory dir,
    String basePath,
  ) async {
    final items = <ProjectItem>[];

    try {
      final entities = await dir.list().toList();
      entities.sort((a, b) => a.path.compareTo(b.path));

      for (final entity in entities) {
        final name = path.basename(entity.path);
        final relativePath = path.relative(entity.path, from: basePath);

        // Skip hidden files and common build directories
        if (name.startsWith('.') ||
            ['build', 'node_modules', '.dart_tool'].contains(name)) {
          continue;
        }

        if (entity is Directory) {
          final children = await _buildFileTree(entity, basePath);
          items.add(
            ProjectItem(
              name: name,
              path: relativePath,
              isDirectory: true,
              children: children,
              lastModified: await entity.stat().then((stat) => stat.modified),
            ),
          );
        } else if (entity is File) {
          final stat = await entity.stat();
          items.add(
            ProjectItem(
              name: name,
              path: relativePath,
              isDirectory: false,
              lastModified: stat.modified,
              size: stat.size,
            ),
          );
        }
      }
    } catch (e) {
      // Handle permission errors gracefully
    }

    return items;
  }

  String _detectLanguage(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
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
      case '.kt':
        return 'kotlin';
      case '.swift':
        return 'swift';
      case '.yaml':
      case '.yml':
        return 'yaml';
      case '.json':
        return 'json';
      case '.md':
        return 'markdown';
      case '.html':
        return 'html';
      case '.css':
        return 'css';
      case '.xml':
        return 'xml';
      default:
        return 'text';
    }
  }

  Future<ProcessResult> _executeBuildCommand(
    CodeProject project,
    String? buildConfig,
  ) async {
    final commands = _getBuildCommand(project, buildConfig);
    return await Process.run(
      commands.first,
      commands.skip(1).toList(),
      workingDirectory: project.path,
    );
  }

  List<String> _getBuildCommand(CodeProject project, String? buildConfig) {
    switch (project.type) {
      case 'flutter':
        return ['flutter', 'build', buildConfig ?? 'apk'];
      case 'python':
        return ['python', '-m', 'py_compile', project.mainFile];
      case 'nodejs':
        return ['npm', 'run', 'build'];
      case 'android':
        return ['./gradlew', 'assembleDebug'];
      default:
        return ['echo', 'No build command defined'];
    }
  }

  List<String> _getRunCommand(CodeProject project, String? runConfig) {
    switch (project.type) {
      case 'flutter':
        return ['flutter', 'run'];
      case 'python':
        return ['python', project.mainFile];
      case 'nodejs':
        return ['npm', 'start'];
      case 'android':
        return ['./gradlew', 'installDebug'];
      default:
        return ['echo', 'No run command defined'];
    }
  }

  Future<ProcessResult> _executeTestCommand(CodeProject project) async {
    final commands = _getTestCommand(project);
    return await Process.run(
      commands.first,
      commands.skip(1).toList(),
      workingDirectory: project.path,
    );
  }

  List<String> _getTestCommand(CodeProject project) {
    switch (project.type) {
      case 'flutter':
        return ['flutter', 'test'];
      case 'python':
        return ['python', '-m', 'pytest'];
      case 'nodejs':
        return ['npm', 'test'];
      case 'android':
        return ['./gradlew', 'test'];
      default:
        return ['echo', 'No test command defined'];
    }
  }

  List<Map<String, dynamic>> _findMatches(
    String text,
    String query,
    bool caseSensitive,
    bool useRegex,
  ) {
    final matches = <Map<String, dynamic>>[];

    if (useRegex) {
      try {
        final regex = RegExp(query, caseSensitive: caseSensitive);
        final regexMatches = regex.allMatches(text);
        for (final match in regexMatches) {
          matches.add({
            'text': match.group(0) ?? '',
            'start': match.start,
            'end': match.end,
          });
        }
      } catch (e) {
        // Invalid regex, fall back to literal search
        return _findLiteralMatches(text, query, caseSensitive);
      }
    } else {
      return _findLiteralMatches(text, query, caseSensitive);
    }

    return matches;
  }

  List<Map<String, dynamic>> _findLiteralMatches(
    String text,
    String query,
    bool caseSensitive,
  ) {
    final matches = <Map<String, dynamic>>[];
    final searchText = caseSensitive ? text : text.toLowerCase();
    final searchQuery = caseSensitive ? query : query.toLowerCase();

    int startIndex = 0;
    while (true) {
      final index = searchText.indexOf(searchQuery, startIndex);
      if (index == -1) break;

      matches.add({
        'text': text.substring(index, index + query.length),
        'start': index,
        'end': index + query.length,
      });

      startIndex = index + 1;
    }

    return matches;
  }

  String _performReplace(
    String text,
    String searchQuery,
    String replaceText,
    bool caseSensitive,
    bool useRegex,
  ) {
    if (useRegex) {
      try {
        final regex = RegExp(searchQuery, caseSensitive: caseSensitive);
        return text.replaceAll(regex, replaceText);
      } catch (e) {
        // Invalid regex, fall back to literal replace
        return _performLiteralReplace(
          text,
          searchQuery,
          replaceText,
          caseSensitive,
        );
      }
    } else {
      return _performLiteralReplace(
        text,
        searchQuery,
        replaceText,
        caseSensitive,
      );
    }
  }

  String _performLiteralReplace(
    String text,
    String searchQuery,
    String replaceText,
    bool caseSensitive,
  ) {
    if (caseSensitive) {
      return text.replaceAll(searchQuery, replaceText);
    } else {
      return text.replaceAll(
        RegExp(RegExp.escape(searchQuery), caseSensitive: false),
        replaceText,
      );
    }
  }

  GitStatus _parseGitStatus(String output) {
    final lines = output.split('\n');
    String branch = 'main';
    final changes = <GitChange>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        // Branch information
        final branchInfo = line.substring(3);
        final parts = branchInfo.split('...');
        branch = parts.first;
      } else if (line.isNotEmpty && line.length >= 2) {
        // File status
        final status = line.substring(0, 2);
        final filePath = line.substring(3);
        final fileName = path.basename(filePath);

        GitChangeType type;
        bool isStaged = false;

        switch (status[0]) {
          case 'A':
            type = GitChangeType.added;
            isStaged = true;
            break;
          case 'M':
            type = GitChangeType.modified;
            isStaged = true;
            break;
          case 'D':
            type = GitChangeType.deleted;
            isStaged = true;
            break;
          case 'R':
            type = GitChangeType.renamed;
            isStaged = true;
            break;
          case 'C':
            type = GitChangeType.copied;
            isStaged = true;
            break;
          default:
            if (status[1] == 'M') {
              type = GitChangeType.modified;
            } else if (status[1] == 'D') {
              type = GitChangeType.deleted;
            } else {
              type = GitChangeType.untracked;
            }
        }

        changes.add(
          GitChange(
            filePath: filePath,
            fileName: fileName,
            type: type,
            isStaged: isStaged,
          ),
        );
      }
    }

    return GitStatus(branch: branch, changes: changes);
  }

  Future<void> _saveProjectConfig(CodeProject project) async {
    final configDir = Directory(path.join(project.path, '.buddy'));
    await configDir.create(recursive: true);

    final configFile = File(path.join(configDir.path, 'project.json'));
    await configFile.writeAsString(jsonEncode(project.toJson()));
  }

  Future<CodeProject> _detectAndImportProject(String projectPath) async {
    // Try to detect project type based on files
    final projectDir = Directory(projectPath);
    final entities = await projectDir.list().toList();

    String type = 'generic';
    String language = 'text';
    String mainFile = 'README.md';

    for (final entity in entities) {
      final name = path.basename(entity.path);

      if (name == 'pubspec.yaml') {
        type = 'flutter';
        language = 'dart';
        mainFile = 'lib/main.dart';
        break;
      } else if (name == 'package.json') {
        type = 'nodejs';
        language = 'javascript';
        mainFile = 'index.js';
        break;
      } else if (name == 'requirements.txt' || name == 'setup.py') {
        type = 'python';
        language = 'python';
        mainFile = 'main.py';
        break;
      } else if (name == 'build.gradle' || name == 'build.gradle.kts') {
        type = 'android';
        language = 'kotlin';
        mainFile = 'app/src/main/java/MainActivity.kt';
        break;
      }
    }

    final project = CodeProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: path.basename(projectPath),
      path: projectPath,
      type: type,
      language: language,
      mainFile: mainFile,
    );

    await _saveProjectConfig(project);
    return project;
  }

  Future<void> _initializeGit(String projectPath) async {
    try {
      await Process.run('git', ['init'], workingDirectory: projectPath);

      // Create .gitignore
      final gitignoreFile = File(path.join(projectPath, '.gitignore'));
      await gitignoreFile.writeAsString(_getGitignoreContent());

      // Initial commit
      await Process.run('git', ['add', '.'], workingDirectory: projectPath);
      await Process.run('git', [
        'commit',
        '-m',
        'Initial commit',
      ], workingDirectory: projectPath);
    } catch (e) {
      // Git initialization failed, but project can still be created
      _outputController.add('Git initialization failed: $e');
    }
  }

  Future<void> _installDependencies(CodeProject project) async {
    try {
      switch (project.type) {
        case 'flutter':
          await Process.run('flutter', [
            'pub',
            'get',
          ], workingDirectory: project.path);
          break;
        case 'nodejs':
          await Process.run('npm', ['install'], workingDirectory: project.path);
          break;
        case 'python':
          // Create virtual environment and install dependencies
          await Process.run('python', [
            '-m',
            'venv',
            'venv',
          ], workingDirectory: project.path);
          break;
      }
    } catch (e) {
      _outputController.add('Dependency installation failed: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      // Load preferences from local storage or use defaults
      _preferences = EditorPreferences();
    } catch (e) {
      _preferences = EditorPreferences();
    }
  }

  Future<void> _savePreferences() async {
    try {
      // Save preferences to local storage
    } catch (e) {
      _outputController.add('Failed to save preferences: $e');
    }
  }

  // Content templates
  String _getFlutterMainContent() {
    return '''import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
''';
  }

  String _getFlutterPubspecContent(ProjectTemplate template) {
    return '''name: ${path.basename(template.name.toLowerCase().replaceAll(' ', '_'))}
description: A new Flutter project created with Buddy Code Editor.

version: 1.0.0+1

environment:
  sdk: ">=2.17.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
''';
  }

  String _getPythonMainContent() {
    return '''#!/usr/bin/env python3
"""
Main module for the application.
Created with Buddy Code Editor.
"""

def main():
    """Main function."""
    print("Hello from Buddy Code Editor!")
    print("Your Python application is ready!")

if __name__ == "__main__":
    main()
''';
  }

  String _getNodeJSMainContent() {
    return '''const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from Buddy Code Editor!');
});

app.listen(port, () => {
  console.log(\`Server running at http://localhost:\${port}\`);
});
''';
  }

  String _getNodeJSPackageContent(ProjectTemplate template) {
    return '''{
  "name": "${template.name.toLowerCase().replaceAll(' ', '-')}",
  "version": "1.0.0",
  "description": "Node.js application created with Buddy Code Editor",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.0",
    "jest": "^28.0.0"
  }
}
''';
  }

  String _getAndroidMainContent() {
    return '''package com.example.myapp

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }
}
''';
  }

  String _getAndroidGradleContent(ProjectTemplate template) {
    return '''android {
    compileSdk 33

    defaultConfig {
        applicationId "com.example.myapp"
        minSdk 21
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.8.0'
    implementation 'androidx.appcompat:appcompat:1.5.0'
    implementation 'com.google.android.material:material:1.6.0'
}
''';
  }

  String _getGitignoreContent() {
    return '''# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history
.svn/

# IDE
.vscode/
.idea/

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
/build/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Python
__pycache__/
*.py[cod]
*\$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Android
*.iml
.gradle
/local.properties
/.idea/caches
/.idea/libraries
/.idea/modules.xml
/.idea/workspace.xml
/.idea/navEditor.xml
/.idea/assetWizardSettings.xml
.externalNativeBuild
.cxx
local.properties

# Buddy Code Editor
.buddy/
''';
  }
}
