import 'dart:io';

class ProjectStructure {
  final String name;
  final String path;
  final bool isDirectory;
  final List<ProjectStructure> children;
  final bool isExpanded;

  const ProjectStructure({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
  });

  ProjectStructure copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<ProjectStructure>? children,
    bool? isExpanded,
  }) {
    return ProjectStructure(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  static Future<ProjectStructure> fromDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    final name = directory.path.split('/').last;

    if (!await directory.exists()) {
      return ProjectStructure(
        name: name,
        path: directoryPath,
        isDirectory: true,
        children: [],
      );
    }

    final entities = await directory.list().toList();
    final children = <ProjectStructure>[];

    for (final entity in entities) {
      if (entity is Directory) {
        // Skip hidden directories and common build/cache directories
        final dirName = entity.path.split('/').last;
        if (!dirName.startsWith('.') &&
            !['build', 'node_modules', '.git', 'cache'].contains(dirName)) {
          children.add(await fromDirectory(entity.path));
        }
      } else if (entity is File) {
        final fileName = entity.path.split('/').last;
        // Skip hidden files and common cache files
        if (!fileName.startsWith('.') &&
            !fileName.endsWith('.lock') &&
            !fileName.endsWith('.log')) {
          children.add(
            ProjectStructure(
              name: fileName,
              path: entity.path,
              isDirectory: false,
            ),
          );
        }
      }
    }

    // Sort: directories first, then files, both alphabetically
    children.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return ProjectStructure(
      name: name,
      path: directoryPath,
      isDirectory: true,
      children: children,
    );
  }
}
