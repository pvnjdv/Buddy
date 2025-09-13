class EditorFile {
  final String name;
  final String path;
  final String content;
  final String language;
  final bool isModified;
  final bool isNew;
  final DateTime lastModified;

  const EditorFile({
    required this.name,
    required this.path,
    required this.content,
    required this.language,
    this.isModified = false,
    this.isNew = false,
    required this.lastModified,
  });

  EditorFile copyWith({
    String? name,
    String? path,
    String? content,
    String? language,
    bool? isModified,
    bool? isNew,
    DateTime? lastModified,
  }) {
    return EditorFile(
      name: name ?? this.name,
      path: path ?? this.path,
      content: content ?? this.content,
      language: language ?? this.language,
      isModified: isModified ?? this.isModified,
      isNew: isNew ?? this.isNew,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  static String getLanguageFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'dart':
        return 'dart';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'cs':
        return 'csharp';
      case 'php':
        return 'php';
      case 'rb':
        return 'ruby';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'kt':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'scss':
      case 'sass':
        return 'scss';
      case 'json':
        return 'json';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'sql':
        return 'sql';
      case 'sh':
      case 'bash':
        return 'bash';
      default:
        return 'plaintext';
    }
  }
}
