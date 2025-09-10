// lib/screens/code_editor/project_templates_screen.dart
import 'package:flutter/material.dart';
import '../../models/code_editor_models.dart';
import '../../services/code_editor_service.dart';
import 'buddy_editor_screen.dart';

class ProjectTemplatesScreen extends StatefulWidget {
  const ProjectTemplatesScreen({super.key});

  @override
  State<ProjectTemplatesScreen> createState() => _ProjectTemplatesScreenState();
}

class _ProjectTemplatesScreenState extends State<ProjectTemplatesScreen> {
  final CodeEditorService _editorService = CodeEditorService();
  List<ProjectTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      await _editorService.initialize();
      setState(() {
        _templates = _editorService.getAvailableTemplates();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Templates'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTemplates,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildTemplateGrid(),
    );
  }

  Widget _buildTemplateGrid() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a Project Template',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start your development journey with pre-configured project templates',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        // Templates Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final template = _templates[index];
              return _buildTemplateCard(template);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(ProjectTemplate template) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _selectTemplate(template),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Language
              Row(
                children: [
                  _getTemplateIcon(template),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getLanguageColor(template.language),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      template.language.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Name
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              Expanded(
                child: Text(
                  template.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Platforms
              Wrap(
                spacing: 4,
                children: template.platforms.take(3).map((platform) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(platform, style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getTemplateIcon(ProjectTemplate template) {
    IconData icon;
    Color color;

    switch (template.type) {
      case 'flutter':
        icon = Icons.flutter_dash;
        color = Colors.blue;
        break;
      case 'python':
        icon = Icons.code;
        color = Colors.green;
        break;
      case 'nodejs':
        icon = Icons.javascript;
        color = Colors.yellow[700] ?? Colors.yellow;
        break;
      case 'android':
        icon = Icons.android;
        color = Colors.green;
        break;
      case 'ios':
        icon = Icons.phone_iphone;
        color = Colors.black;
        break;
      case 'web':
        icon = Icons.web;
        color = Colors.purple;
        break;
      case 'desktop':
        icon = Icons.desktop_windows;
        color = Colors.grey;
        break;
      default:
        icon = Icons.folder;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getLanguageColor(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return Colors.blue;
      case 'python':
        return Colors.green;
      case 'javascript':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'typescript':
        return Colors.blue[700] ?? Colors.blue;
      case 'java':
        return Colors.orange;
      case 'kotlin':
        return Colors.purple;
      case 'swift':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _selectTemplate(ProjectTemplate template) {
    showDialog(
      context: context,
      builder: (context) => _ProjectCreationDialog(
        template: template,
        onProjectCreated: (project) {
          Navigator.pop(context); // Close dialog
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BuddyEditorScreen()),
          );
        },
      ),
    );
  }
}

class _ProjectCreationDialog extends StatefulWidget {
  final ProjectTemplate template;
  final Function(CodeProject) onProjectCreated;

  const _ProjectCreationDialog({
    required this.template,
    required this.onProjectCreated,
  });

  @override
  State<_ProjectCreationDialog> createState() => _ProjectCreationDialogState();
}

class _ProjectCreationDialogState extends State<_ProjectCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final CodeEditorService _editorService = CodeEditorService();

  bool _isCreating = false;
  List<String> _selectedPlatforms = [];

  @override
  void initState() {
    super.initState();
    _selectedPlatforms = List.from(widget.template.platforms);
    _pathController.text =
        '/storage/emulated/0/BuddyProjects'; // Default Android path
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create ${widget.template.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'my_awesome_app',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project name';
                  }
                  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value)) {
                    return 'Invalid name format';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Project Path
              TextFormField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: 'Project Path',
                  hintText: '/path/to/projects',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project path';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Platforms
              const Text(
                'Target Platforms:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.template.platforms.map((platform) {
                  return FilterChip(
                    label: Text(platform),
                    selected: _selectedPlatforms.contains(platform),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPlatforms.add(platform);
                        } else {
                          _selectedPlatforms.remove(platform);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Template Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.template.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (widget.template.dependencies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Dependencies:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.template.dependencies.join(', '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createProject,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlatforms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one platform')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final project = await _editorService.createProject(
        name: _nameController.text,
        basePath: _pathController.text,
        template: widget.template.id,
        config: {
          'platforms': _selectedPlatforms,
          'autoSync': true,
          'enableTesting': true,
        },
      );

      widget.onProjectCreated(project);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create project: $e')));
        setState(() => _isCreating = false);
      }
    }
  }
}
