import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/flow_models.dart';

/// Service for integrating with VS Code across different platforms
class VSCodeIntegrationService {
  static const String _githubApiUrl = 'https://api.github.com';
  static const String _vscodeDevUrl = 'https://vscode.dev';

  // GitHub token for creating temporary repos (should be in secure storage)
  static String? _githubToken;

  /// Initialize the service with GitHub token
  static void initialize({String? githubToken}) {
    if (githubToken != null && githubToken.isNotEmpty) {
      _githubToken = githubToken;
    }
  }

  /// Open project in appropriate VS Code based on platform
  static Future<VSCodeSession> openProject(ProjectFlow project) async {
    try {
      if (kIsWeb) {
        return await _openInVSCodeDev(project);
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        return await _openInMobileVSCode(project);
      } else if (!kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        return await _openInDesktopVSCode(project);
      } else {
        // Fallback to web version for unsupported platforms
        return await _openInVSCodeDev(project);
      }
    } catch (e) {
      // If platform detection fails, fallback to web version
      return await _openInVSCodeDev(project);
    }
  }

  /// Open project in vscode.dev (web version)
  static Future<VSCodeSession> _openInVSCodeDev(ProjectFlow project) async {
    try {
      // Try to create temporary GitHub repository
      final repoInfo = await _createTempGitHubRepo(project);

      // Upload project files
      await _uploadProjectFiles(repoInfo.fullName, project);

      // Generate vscode.dev URL
      final vscodeUrl = '$_vscodeDevUrl/github/${repoInfo.fullName}';

      return VSCodeSession(
        sessionId: repoInfo.fullName,
        sessionType: VSCodeSessionType.web,
        projectId: project.id,
        vscodeUrl: vscodeUrl,
        repoUrl: repoInfo.htmlUrl,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      // Fallback: Create session with plain vscode.dev (no GitHub integration)
      final fallbackUrl = '$_vscodeDevUrl/';

      return VSCodeSession(
        sessionId:
            'fallback_${project.id}_${DateTime.now().millisecondsSinceEpoch}',
        sessionType: VSCodeSessionType.web,
        projectId: project.id,
        vscodeUrl: fallbackUrl,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Open project in mobile WebView with vscode.dev
  static Future<VSCodeSession> _openInMobileVSCode(ProjectFlow project) async {
    // Same as web, but we'll handle it differently in the UI
    final session = await _openInVSCodeDev(project);
    return session.copyWith(sessionType: VSCodeSessionType.mobileWebView);
  }

  /// Open project in native VS Code (Linux/Windows/Mac)
  static Future<VSCodeSession> _openInDesktopVSCode(ProjectFlow project) async {
    try {
      // Create local project directory
      final projectDir = await _createLocalProject(project);

      // Try to open in native VS Code
      bool nativeOpened = false;
      if (Platform.isLinux || Platform.isMacOS) {
        nativeOpened = await _tryOpenNativeVSCode(projectDir.path);
      }

      // Fallback to vscode.dev if native not available
      if (!nativeOpened) {
        return await _openInVSCodeDev(project);
      }

      return VSCodeSession(
        sessionId: projectDir.path,
        sessionType: VSCodeSessionType.desktop,
        projectId: project.id,
        localPath: projectDir.path,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      // Fallback to web version
      return await _openInVSCodeDev(project);
    }
  }

  /// Create temporary GitHub repository for project
  static Future<GitHubRepoInfo> _createTempGitHubRepo(
    ProjectFlow project,
  ) async {
    if (_githubToken == null || _githubToken!.isEmpty) {
      throw VSCodeIntegrationException(
        'GitHub token not configured or is empty',
      );
    }

    final repoName =
        'buddy-temp-${project.id}-${DateTime.now().millisecondsSinceEpoch}';

    final response = await http.post(
      Uri.parse('$_githubApiUrl/user/repos'),
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': repoName,
        'description':
            'Temporary repository for Buddy project: ${project.title}',
        'private': true,
        'auto_init': true,
        'delete_branch_on_merge': true,
      }),
    );

    if (response.statusCode != 201) {
      throw VSCodeIntegrationException(
        'Failed to create GitHub repo: ${response.statusCode} - ${response.body}',
      );
    }

    final repoData = jsonDecode(response.body);
    return GitHubRepoInfo.fromJson(repoData);
  }

  /// Upload project files to GitHub repository
  static Future<void> _uploadProjectFiles(
    String repoFullName,
    ProjectFlow project,
  ) async {
    if (_githubToken == null || _githubToken!.isEmpty) {
      throw VSCodeIntegrationException(
        'GitHub token not configured or is empty',
      );
    }

    // Convert project structure to files
    final projectFiles = await _convertProjectToFiles(project);

    // Upload each file to GitHub
    for (final file in projectFiles) {
      await _uploadFileToGitHub(repoFullName, file);
    }

    // Create README with project info
    await _createProjectReadme(repoFullName, project);
  }

  /// Upload single file to GitHub
  static Future<void> _uploadFileToGitHub(
    String repoFullName,
    ProjectFile file,
  ) async {
    if (_githubToken == null || _githubToken!.isEmpty) {
      throw VSCodeIntegrationException(
        'GitHub token not configured or is empty',
      );
    }
    final encodedContent = base64Encode(utf8.encode(file.content));

    final response = await http.put(
      Uri.parse('$_githubApiUrl/repos/$repoFullName/contents/${file.path}'),
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': 'Add ${file.path}',
        'content': encodedContent,
        'branch': 'main',
      }),
    );

    if (response.statusCode != 201) {
      throw VSCodeIntegrationException(
        'Failed to upload file ${file.path}: ${response.statusCode}',
      );
    }
  }

  /// Create local project directory for desktop VS Code
  static Future<Directory> _createLocalProject(ProjectFlow project) async {
    // Use platform-specific temporary directory
    String tempPath;
    if (Platform.isLinux || Platform.isMacOS) {
      tempPath = '/tmp';
    } else if (Platform.isWindows) {
      tempPath = Platform.environment['TEMP'] ?? 'C:\\temp';
    } else {
      throw UnsupportedError('Platform not supported for local projects');
    }

    final projectDir = Directory('$tempPath/buddy_projects/${project.id}');

    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
    await projectDir.create(recursive: true);

    // Convert and write project files
    final projectFiles = await _convertProjectToFiles(project);
    for (final file in projectFiles) {
      final filePath = '${projectDir.path}/${file.path}';
      final fileDir = Directory(
        filePath.substring(0, filePath.lastIndexOf('/')),
      );
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }

      final fileHandle = File(filePath);
      await fileHandle.writeAsString(file.content);
    }

    return projectDir;
  }

  /// Try to open project in native VS Code
  static Future<bool> _tryOpenNativeVSCode(String projectPath) async {
    try {
      // Try different VS Code command variations
      final commands = ['code', 'code-insiders', 'codium'];

      for (final command in commands) {
        try {
          final result = await Process.run(command, [projectPath]);
          if (result.exitCode == 0) {
            return true;
          }
        } catch (e) {
          // Command not found, try next
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Convert ProjectFlow to list of files
  static Future<List<ProjectFile>> _convertProjectToFiles(
    ProjectFlow project,
  ) async {
    final files = <ProjectFile>[];

    // Create main project structure based on detected language/framework
    if (project.tags.contains('flutter') || project.tags.contains('dart')) {
      files.addAll(await _createFlutterProject(project));
    } else if (project.tags.contains('react') ||
        project.tags.contains('javascript')) {
      files.addAll(await _createReactProject(project));
    } else if (project.tags.contains('python')) {
      files.addAll(await _createPythonProject(project));
    } else {
      files.addAll(await _createGenericProject(project));
    }

    return files;
  }

  /// Create Flutter project structure
  static Future<List<ProjectFile>> _createFlutterProject(
    ProjectFlow project,
  ) async {
    return [
      ProjectFile(path: 'pubspec.yaml', content: _generatePubspecYaml(project)),
      ProjectFile(path: 'lib/main.dart', content: _generateMainDart(project)),
      ProjectFile(
        path: 'lib/screens/home_screen.dart',
        content: _generateHomeScreen(project),
      ),
      ProjectFile(path: 'README.md', content: _generateReadme(project)),
      ProjectFile(path: '.gitignore', content: _generateGitignore('flutter')),
    ];
  }

  /// Create React project structure
  static Future<List<ProjectFile>> _createReactProject(
    ProjectFlow project,
  ) async {
    return [
      ProjectFile(path: 'package.json', content: _generatePackageJson(project)),
      ProjectFile(path: 'src/App.js', content: _generateAppJs(project)),
      ProjectFile(path: 'src/index.js', content: _generateIndexJs(project)),
      ProjectFile(
        path: 'public/index.html',
        content: _generateIndexHtml(project),
      ),
      ProjectFile(path: 'README.md', content: _generateReadme(project)),
    ];
  }

  /// Create Python project structure
  static Future<List<ProjectFile>> _createPythonProject(
    ProjectFlow project,
  ) async {
    return [
      ProjectFile(path: 'main.py', content: _generateMainPy(project)),
      ProjectFile(
        path: 'requirements.txt',
        content: _generateRequirements(project),
      ),
      ProjectFile(path: 'README.md', content: _generateReadme(project)),
    ];
  }

  /// Create generic project structure
  static Future<List<ProjectFile>> _createGenericProject(
    ProjectFlow project,
  ) async {
    return [
      ProjectFile(path: 'README.md', content: _generateReadme(project)),
      ProjectFile(path: 'index.html', content: _generateBasicHtml(project)),
    ];
  }

  /// Create project README with Buddy integration
  static Future<void> _createProjectReadme(
    String repoFullName,
    ProjectFlow project,
  ) async {
    if (_githubToken == null || _githubToken!.isEmpty) {
      throw VSCodeIntegrationException(
        'GitHub token not configured or is empty',
      );
    }
    final readmeContent =
        '''
# ${project.title}

${project.description}

## Project Information
- **Buddy Project ID**: ${project.id}
- **Difficulty**: ${project.difficulty.name}
- **Estimated Duration**: ${project.estimatedDuration}
- **Progress**: ${project.progressPercentage.toStringAsFixed(1)}%

## Checkpoints
${project.checkpoints.map((c) => '- ${c.isCompleted ? '✅' : '⏳'} ${c.title}').join('\n')}

## Tags
${project.tags.map((tag) => '`$tag`').join(' ')}

---
*This project was created using Buddy App - AI-powered project management*
*Sync changes back to Buddy App to update project progress*
''';

    final encodedContent = base64Encode(utf8.encode(readmeContent));

    await http.put(
      Uri.parse('$_githubApiUrl/repos/$repoFullName/contents/README.md'),
      headers: {
        'Authorization': 'Bearer $_githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': 'Update README with Buddy project info',
        'content': encodedContent,
        'branch': 'main',
      }),
    );
  }

  /// Monitor changes and sync back to Buddy
  static Future<void> startSyncMonitoring(VSCodeSession session) async {
    // Implementation for monitoring GitHub repo changes
    // and syncing back to Buddy App
  }

  /// Cleanup temporary resources
  static Future<void> cleanup(VSCodeSession session) async {
    if (session.sessionType == VSCodeSessionType.web ||
        session.sessionType == VSCodeSessionType.mobileWebView) {
      // Delete temporary GitHub repo
      if (session.sessionId != null) {
        await _deleteTempGitHubRepo(session.sessionId!);
      }
    } else if (session.sessionType == VSCodeSessionType.desktop) {
      // Clean up local project directory
      if (session.localPath != null) {
        final dir = Directory(session.localPath!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }
  }

  /// Delete temporary GitHub repository
  static Future<void> _deleteTempGitHubRepo(String repoFullName) async {
    if (_githubToken == null || _githubToken!.isEmpty) return;

    try {
      await http.delete(
        Uri.parse('$_githubApiUrl/repos/$repoFullName'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
    } catch (e) {
      // Log error but don't throw - cleanup is best effort
      print('Failed to delete temp repo $repoFullName: $e');
    }
  }

  // Template generators
  static String _generatePubspecYaml(ProjectFlow project) {
    return '''
name: ${project.title.toLowerCase().replaceAll(' ', '_')}
description: ${project.description}
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"

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

  static String _generateMainDart(ProjectFlow project) {
    return '''
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${project.title}',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}
''';
  }

  static String _generateHomeScreen(ProjectFlow project) {
    return '''
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${project.title}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${project.title}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),
            Text('${project.description}'),
            SizedBox(height: 40),
            Text(
              'Project Checkpoints:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ${project.checkpoints.map((c) => "Text('${c.isCompleted ? '✅' : '⏳'} ${c.title}'),").join('\n            ')}
          ],
        ),
      ),
    );
  }
}
''';
  }

  static String _generateReadme(ProjectFlow project) {
    return '''
# ${project.title}

${project.description}

## Getting Started

This project was created using Buddy App.

### Checkpoints
${project.checkpoints.map((c) => '- ${c.isCompleted ? '✅' : '⏳'} ${c.title}: ${c.description}').join('\n')}

### Tags
${project.tags.join(', ')}

## Development

Follow the checkpoints above to complete this project step by step.
''';
  }

  static String _generateGitignore(String projectType) {
    switch (projectType) {
      case 'flutter':
        return '''
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history
.svn/
migrate_working_dir/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# Visual Studio Code related
.vscode/

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

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Android Studio will place build artifacts here
/android/app/debug
/android/app/profile
/android/app/release
''';
      default:
        return '''
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
/coverage

# Production
/build

# Misc
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local

npm-debug.log*
yarn-debug.log*
yarn-error.log*
''';
    }
  }

  static String _generatePackageJson(ProjectFlow project) {
    return '''
{
  "name": "${project.title.toLowerCase().replaceAll(' ', '-')}",
  "version": "0.1.0",
  "description": "${project.description}",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^5.16.4",
    "@testing-library/react": "^13.3.0",
    "@testing-library/user-event": "^13.5.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "web-vitals": "^2.1.4"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
''';
  }

  static String _generateAppJs(ProjectFlow project) {
    return '''
import React from 'react';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>${project.title}</h1>
        <p>${project.description}</p>
        
        <div className="checkpoints">
          <h2>Project Checkpoints:</h2>
          <ul>
            ${project.checkpoints.map((c) => "<li>${c.isCompleted ? '✅' : '⏳'} ${c.title}</li>").join('\n            ')}
          </ul>
        </div>
      </header>
    </div>
  );
}

export default App;
''';
  }

  static String _generateIndexJs(ProjectFlow project) {
    return '''
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

reportWebVitals();
''';
  }

  static String _generateIndexHtml(ProjectFlow project) {
    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="${project.description}" />
    <title>${project.title}</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
''';
  }

  static String _generateMainPy(ProjectFlow project) {
    return '''
"""
${project.title}
${project.description}

This project was created using Buddy App.
"""

def main():
    print("${project.title}")
    print("${project.description}")
    
    checkpoints = [
        ${project.checkpoints.map((c) => "{'title': '${c.title}', 'completed': ${c.isCompleted}}").join(',\n        ')}
    ]
    
    print("\\nProject Checkpoints:")
    for checkpoint in checkpoints:
        status = "✅" if checkpoint['completed'] else "⏳"
        print(f"{status} {checkpoint['title']}")

if __name__ == "__main__":
    main()
''';
  }

  static String _generateRequirements(ProjectFlow project) {
    return '''
# ${project.title} - Requirements
# Generated by Buddy App

# Add your project dependencies here
requests>=2.25.1
''';
  }

  static String _generateBasicHtml(ProjectFlow project) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${project.title}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .checkpoint { margin: 10px 0; }
        .completed { color: green; }
        .pending { color: orange; }
    </style>
</head>
<body>
    <h1>${project.title}</h1>
    <p>${project.description}</p>
    
    <h2>Project Checkpoints</h2>
    <div class="checkpoints">
        ${project.checkpoints.map((c) => '<div class="checkpoint ${c.isCompleted ? 'completed' : 'pending'}">'
        '${c.isCompleted ? '✅' : '⏳'} ${c.title}</div>').join('\n        ')}
    </div>
    
    <footer>
        <p><em>Created with Buddy App</em></p>
    </footer>
</body>
</html>
''';
  }
}

/// VS Code session information
class VSCodeSession {
  final String? sessionId;
  final VSCodeSessionType sessionType;
  final String projectId;
  final String? vscodeUrl;
  final String? repoUrl;
  final String? localPath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastSyncAt;

  VSCodeSession({
    this.sessionId,
    required this.sessionType,
    required this.projectId,
    this.vscodeUrl,
    this.repoUrl,
    this.localPath,
    required this.isActive,
    required this.createdAt,
    this.lastSyncAt,
  });

  VSCodeSession copyWith({
    String? sessionId,
    VSCodeSessionType? sessionType,
    String? projectId,
    String? vscodeUrl,
    String? repoUrl,
    String? localPath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastSyncAt,
  }) {
    return VSCodeSession(
      sessionId: sessionId ?? this.sessionId,
      sessionType: sessionType ?? this.sessionType,
      projectId: projectId ?? this.projectId,
      vscodeUrl: vscodeUrl ?? this.vscodeUrl,
      repoUrl: repoUrl ?? this.repoUrl,
      localPath: localPath ?? this.localPath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Types of VS Code sessions
enum VSCodeSessionType {
  web, // vscode.dev in browser
  mobileWebView, // vscode.dev in mobile WebView
  desktop, // Native VS Code application
}

/// GitHub repository information
class GitHubRepoInfo {
  final String name;
  final String fullName;
  final String htmlUrl;
  final String cloneUrl;
  final bool isPrivate;

  GitHubRepoInfo({
    required this.name,
    required this.fullName,
    required this.htmlUrl,
    required this.cloneUrl,
    required this.isPrivate,
  });

  factory GitHubRepoInfo.fromJson(Map<String, dynamic> json) {
    return GitHubRepoInfo(
      name: json['name'],
      fullName: json['full_name'],
      htmlUrl: json['html_url'],
      cloneUrl: json['clone_url'],
      isPrivate: json['private'] ?? false,
    );
  }
}

/// Project file representation
class ProjectFile {
  final String path;
  final String content;

  ProjectFile({required this.path, required this.content});
}

/// VS Code integration exceptions
class VSCodeIntegrationException implements Exception {
  final String message;

  VSCodeIntegrationException(this.message);

  @override
  String toString() => 'VSCodeIntegrationException: $message';
}
