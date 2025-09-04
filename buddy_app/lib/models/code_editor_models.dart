// lib/models/code_editor_models.dart
import 'package:flutter/material.dart';

// Main project model
class CodeProject {
  final String id;
  final String name;
  final String path;
  final String type; // flutter, android, python, web, etc.
  final String language;
  final String mainFile;
  final bool isRemote;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> config;
  final List<String> dependencies;

  CodeProject({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.language,
    required this.mainFile,
    this.isRemote = false,
    DateTime? createdAt,
    DateTime? lastModified,
    this.config = const {},
    this.dependencies = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now();

  factory CodeProject.fromJson(Map<String, dynamic> json) {
    return CodeProject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? '',
      language: json['language'] ?? '',
      mainFile: json['mainFile'] ?? '',
      isRemote: json['isRemote'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastModified:
          DateTime.tryParse(json['lastModified'] ?? '') ?? DateTime.now(),
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      dependencies: List<String>.from(json['dependencies'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'language': language,
      'mainFile': mainFile,
      'isRemote': isRemote,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'config': config,
      'dependencies': dependencies,
    };
  }

  CodeProject copyWith({
    String? id,
    String? name,
    String? path,
    String? type,
    String? language,
    String? mainFile,
    bool? isRemote,
    DateTime? createdAt,
    DateTime? lastModified,
    Map<String, dynamic>? config,
    List<String>? dependencies,
  }) {
    return CodeProject(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      language: language ?? this.language,
      mainFile: mainFile ?? this.mainFile,
      isRemote: isRemote ?? this.isRemote,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      config: config ?? this.config,
      dependencies: dependencies ?? this.dependencies,
    );
  }
}

// File model for individual code files
class CodeFile {
  final String path;
  final String name;
  final String language;
  String content;
  bool isModified;
  final DateTime lastModified;
  final int? line;
  final int? column;
  final Map<String, dynamic> metadata;

  CodeFile({
    required this.path,
    required this.name,
    required this.language,
    this.content = '',
    this.isModified = false,
    DateTime? lastModified,
    this.line,
    this.column,
    this.metadata = const {},
  }) : lastModified = lastModified ?? DateTime.now();

  factory CodeFile.fromJson(Map<String, dynamic> json) {
    return CodeFile(
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      language: json['language'] ?? '',
      content: json['content'] ?? '',
      isModified: json['isModified'] ?? false,
      lastModified:
          DateTime.tryParse(json['lastModified'] ?? '') ?? DateTime.now(),
      line: json['line'],
      column: json['column'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'language': language,
      'content': content,
      'isModified': isModified,
      'lastModified': lastModified.toIso8601String(),
      'line': line,
      'column': column,
      'metadata': metadata,
    };
  }

  String get extension => name.split('.').last.toLowerCase();

  IconData get icon {
    switch (extension) {
      case 'dart':
        return Icons.code;
      case 'py':
        return Icons.code; // Changed from Icons.python which doesn't exist
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'java':
      case 'kt':
        return Icons.code;
      case 'swift':
        return Icons.phone_iphone;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'json':
        return Icons.data_object;
      case 'md':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      case 'gradle':
        return Icons.build;
      case 'xml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get color {
    switch (extension) {
      case 'dart':
        return Colors.blue;
      case 'py':
        return Colors.green;
      case 'js':
      case 'ts':
        return Colors.yellow;
      case 'java':
      case 'kt':
        return Colors.orange;
      case 'swift':
        return Colors.red;
      case 'yaml':
      case 'yml':
        return Colors.purple;
      case 'json':
        return Colors.teal;
      case 'md':
        return Colors.grey;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}

// Project file tree item
class ProjectItem {
  final String name;
  final String path;
  final bool isDirectory;
  bool isExpanded;
  final List<ProjectItem> children;
  final DateTime lastModified;
  final int? size;

  ProjectItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isExpanded = false,
    this.children = const [],
    DateTime? lastModified,
    this.size,
  }) : lastModified = lastModified ?? DateTime.now();

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      isDirectory: json['isDirectory'] ?? false,
      isExpanded: json['isExpanded'] ?? false,
      children:
          (json['children'] as List?)
              ?.map((child) => ProjectItem.fromJson(child))
              .toList() ??
          [],
      lastModified:
          DateTime.tryParse(json['lastModified'] ?? '') ?? DateTime.now(),
      size: json['size'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'isExpanded': isExpanded,
      'children': children.map((child) => child.toJson()).toList(),
      'lastModified': lastModified.toIso8601String(),
      'size': size,
    };
  }
}

// Project template for quick creation
class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String type;
  final String language;
  final List<String> platforms; // android, ios, web, desktop
  final Map<String, String> files; // path -> content
  final List<String> dependencies;
  final Map<String, dynamic> config;
  final String? icon;

  ProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.language,
    required this.platforms,
    this.files = const {},
    this.dependencies = const [],
    this.config = const {},
    this.icon,
  });

  factory ProjectTemplate.fromJson(Map<String, dynamic> json) {
    return ProjectTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      language: json['language'] ?? '',
      platforms: List<String>.from(json['platforms'] ?? []),
      files: Map<String, String>.from(json['files'] ?? {}),
      dependencies: List<String>.from(json['dependencies'] ?? []),
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'language': language,
      'platforms': platforms,
      'files': files,
      'dependencies': dependencies,
      'config': config,
      'icon': icon,
    };
  }
}

// Build configuration
class BuildConfig {
  final String name;
  final String command;
  final List<String> args;
  final String? workingDirectory;
  final Map<String, String> environment;
  final bool isDefault;

  BuildConfig({
    required this.name,
    required this.command,
    this.args = const [],
    this.workingDirectory,
    this.environment = const {},
    this.isDefault = false,
  });

  factory BuildConfig.fromJson(Map<String, dynamic> json) {
    return BuildConfig(
      name: json['name'] ?? '',
      command: json['command'] ?? '',
      args: List<String>.from(json['args'] ?? []),
      workingDirectory: json['workingDirectory'],
      environment: Map<String, String>.from(json['environment'] ?? {}),
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'command': command,
      'args': args,
      'workingDirectory': workingDirectory,
      'environment': environment,
      'isDefault': isDefault,
    };
  }
}

// Sync configuration for VS Code integration
class SyncConfig {
  final bool enabled;
  final String? vsCodePath;
  final List<String> syncExtensions;
  final Map<String, dynamic> settings;
  final bool autoSync;
  final int syncInterval; // in seconds

  SyncConfig({
    this.enabled = true,
    this.vsCodePath,
    this.syncExtensions = const [],
    this.settings = const {},
    this.autoSync = true,
    this.syncInterval = 30,
  });

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      enabled: json['enabled'] ?? true,
      vsCodePath: json['vsCodePath'],
      syncExtensions: List<String>.from(json['syncExtensions'] ?? []),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      autoSync: json['autoSync'] ?? true,
      syncInterval: json['syncInterval'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'vsCodePath': vsCodePath,
      'syncExtensions': syncExtensions,
      'settings': settings,
      'autoSync': autoSync,
      'syncInterval': syncInterval,
    };
  }
}

// Search result model
class SearchResult {
  final String filePath;
  final String fileName;
  final int line;
  final int column;
  final String content;
  final String matchedText;
  final int startIndex;
  final int endIndex;

  SearchResult({
    required this.filePath,
    required this.fileName,
    required this.line,
    required this.column,
    required this.content,
    required this.matchedText,
    required this.startIndex,
    required this.endIndex,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      filePath: json['filePath'] ?? '',
      fileName: json['fileName'] ?? '',
      line: json['line'] ?? 0,
      column: json['column'] ?? 0,
      content: json['content'] ?? '',
      matchedText: json['matchedText'] ?? '',
      startIndex: json['startIndex'] ?? 0,
      endIndex: json['endIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'line': line,
      'column': column,
      'content': content,
      'matchedText': matchedText,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }
}

// Git status models
class GitStatus {
  final String branch;
  final List<GitChange> changes;
  final bool hasRemote;
  final int aheadBy;
  final int behindBy;

  GitStatus({
    required this.branch,
    required this.changes,
    this.hasRemote = false,
    this.aheadBy = 0,
    this.behindBy = 0,
  });

  factory GitStatus.fromJson(Map<String, dynamic> json) {
    return GitStatus(
      branch: json['branch'] ?? '',
      changes:
          (json['changes'] as List?)
              ?.map((change) => GitChange.fromJson(change))
              .toList() ??
          [],
      hasRemote: json['hasRemote'] ?? false,
      aheadBy: json['aheadBy'] ?? 0,
      behindBy: json['behindBy'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch': branch,
      'changes': changes.map((change) => change.toJson()).toList(),
      'hasRemote': hasRemote,
      'aheadBy': aheadBy,
      'behindBy': behindBy,
    };
  }
}

class GitChange {
  final String filePath;
  final String fileName;
  final GitChangeType type;
  final bool isStaged;

  GitChange({
    required this.filePath,
    required this.fileName,
    required this.type,
    this.isStaged = false,
  });

  factory GitChange.fromJson(Map<String, dynamic> json) {
    return GitChange(
      filePath: json['filePath'] ?? '',
      fileName: json['fileName'] ?? '',
      type: GitChangeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GitChangeType.modified,
      ),
      isStaged: json['isStaged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'type': type.name,
      'isStaged': isStaged,
    };
  }

  IconData get icon {
    switch (type) {
      case GitChangeType.added:
        return Icons.add;
      case GitChangeType.modified:
        return Icons.edit;
      case GitChangeType.deleted:
        return Icons.delete;
      case GitChangeType.renamed:
        return Icons.drive_file_rename_outline;
      case GitChangeType.copied:
        return Icons.copy;
      case GitChangeType.untracked:
        return Icons.help_outline;
    }
  }

  Color get color {
    switch (type) {
      case GitChangeType.added:
        return Colors.green;
      case GitChangeType.modified:
        return Colors.orange;
      case GitChangeType.deleted:
        return Colors.red;
      case GitChangeType.renamed:
        return Colors.blue;
      case GitChangeType.copied:
        return Colors.purple;
      case GitChangeType.untracked:
        return Colors.grey;
    }
  }
}

enum GitChangeType { added, modified, deleted, renamed, copied, untracked }

// Editor preferences
class EditorPreferences {
  final String fontFamily;
  final double fontSize;
  final bool enableWordWrap;
  final bool showLineNumbers;
  final bool enableAutoComplete;
  final bool enableSyntaxHighlighting;
  final String theme;
  final int tabSize;
  final bool insertSpaces;
  final bool enableAutoSave;
  final int autoSaveInterval; // in seconds

  EditorPreferences({
    this.fontFamily = 'Courier New',
    this.fontSize = 14.0,
    this.enableWordWrap = true,
    this.showLineNumbers = true,
    this.enableAutoComplete = true,
    this.enableSyntaxHighlighting = true,
    this.theme = 'dark',
    this.tabSize = 2,
    this.insertSpaces = true,
    this.enableAutoSave = true,
    this.autoSaveInterval = 30,
  });

  factory EditorPreferences.fromJson(Map<String, dynamic> json) {
    return EditorPreferences(
      fontFamily: json['fontFamily'] ?? 'Courier New',
      fontSize: (json['fontSize'] ?? 14.0).toDouble(),
      enableWordWrap: json['enableWordWrap'] ?? true,
      showLineNumbers: json['showLineNumbers'] ?? true,
      enableAutoComplete: json['enableAutoComplete'] ?? true,
      enableSyntaxHighlighting: json['enableSyntaxHighlighting'] ?? true,
      theme: json['theme'] ?? 'dark',
      tabSize: json['tabSize'] ?? 2,
      insertSpaces: json['insertSpaces'] ?? true,
      enableAutoSave: json['enableAutoSave'] ?? true,
      autoSaveInterval: json['autoSaveInterval'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'enableWordWrap': enableWordWrap,
      'showLineNumbers': showLineNumbers,
      'enableAutoComplete': enableAutoComplete,
      'enableSyntaxHighlighting': enableSyntaxHighlighting,
      'theme': theme,
      'tabSize': tabSize,
      'insertSpaces': insertSpaces,
      'enableAutoSave': enableAutoSave,
      'autoSaveInterval': autoSaveInterval,
    };
  }

  EditorPreferences copyWith({
    String? fontFamily,
    double? fontSize,
    bool? enableWordWrap,
    bool? showLineNumbers,
    bool? enableAutoComplete,
    bool? enableSyntaxHighlighting,
    String? theme,
    int? tabSize,
    bool? insertSpaces,
    bool? enableAutoSave,
    int? autoSaveInterval,
  }) {
    return EditorPreferences(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      enableWordWrap: enableWordWrap ?? this.enableWordWrap,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      enableAutoComplete: enableAutoComplete ?? this.enableAutoComplete,
      enableSyntaxHighlighting:
          enableSyntaxHighlighting ?? this.enableSyntaxHighlighting,
      theme: theme ?? this.theme,
      tabSize: tabSize ?? this.tabSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      enableAutoSave: enableAutoSave ?? this.enableAutoSave,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
    );
  }
}
