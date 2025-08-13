import 'package:flutter/material.dart';
import '../../models/dock_models.dart';
import '../../config/theme_config.dart';

class MacroEditorScreen extends StatefulWidget {
  final DockMacro? macro;

  const MacroEditorScreen({super.key, this.macro});

  @override
  State<MacroEditorScreen> createState() => _MacroEditorScreenState();
}

class _MacroEditorScreenState extends State<MacroEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _targetDeviceId = '*';
  List<MacroStep> _steps = [];
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.macro != null) {
      _nameController.text = widget.macro!.name;
      _descriptionController.text = widget.macro!.description;
      _targetDeviceId = widget.macro!.targetDeviceId;
      _steps = List.from(widget.macro!.steps);
      _isEnabled = widget.macro!.isEnabled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.macro != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Macro' : 'Create Macro'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveMacro,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    Card(
                      color: AppTheme.surfaceColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Macro Name',
                                hintText: 'Enter macro name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a macro name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                hintText: 'Enter macro description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _targetDeviceId,
                              decoration: InputDecoration(
                                labelText: 'Target Device',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '*',
                                  child: Text('All Devices'),
                                ),
                                DropdownMenuItem(
                                  value: 'desktop',
                                  child: Text('Desktop Devices'),
                                ),
                                DropdownMenuItem(
                                  value: 'mobile',
                                  child: Text('Mobile Devices'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _targetDeviceId = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(
                                'Enabled',
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              subtitle: Text(
                                'Macro can be executed',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              value: _isEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _isEnabled = value;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Steps Section
                    Card(
                      color: AppTheme.surfaceColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Steps (${_steps.length})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _addStep,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Step'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_steps.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.list_alt,
                                      size: 48,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Steps Added',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add steps to define what this macro will do',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _steps.length,
                                itemBuilder: (context, index) {
                                  return _buildStepCard(index);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int index) {
    final step = _steps[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.action.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      if (step.parameters['description'] != null &&
                          step.parameters['description'].toString().isNotEmpty)
                        Text(
                          step.parameters['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleStepAction(value, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18),
                          SizedBox(width: 8),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (step.delay != null && step.delay!.inMilliseconds > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Delay: ${step.delay!.inMilliseconds}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addStep() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildStepSelector(),
    );
  }

  Widget _buildStepSelector() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add Step',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionTile(
                  MacroAction.runCommand,
                  'Run Command',
                  Icons.terminal,
                ),
                _buildActionTile(MacroAction.openApp, 'Open App', Icons.launch),
                _buildActionTile(
                  MacroAction.closeApp,
                  'Close App',
                  Icons.close,
                ),
                _buildActionTile(
                  MacroAction.sendKeys,
                  'Send Keys',
                  Icons.keyboard,
                ),
                _buildActionTile(
                  MacroAction.mouseClick,
                  'Mouse Click',
                  Icons.mouse,
                ),
                _buildActionTile(
                  MacroAction.waitFor,
                  'Wait/Delay',
                  Icons.schedule,
                ),
                _buildActionTile(
                  MacroAction.systemControl,
                  'System Control',
                  Icons.settings,
                ),
                _buildActionTile(
                  MacroAction.fileOperation,
                  'File Operation',
                  Icons.file_copy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(MacroAction action, String title, IconData icon) {
    return InkWell(
      onTap: () => _createStep(action),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _createStep(MacroAction action) {
    Navigator.pop(context);

    final step = MacroStep(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      parameters: {'description': _getDefaultDescription(action)},
      delay: null,
      condition: null,
      order: _steps.length,
    );

    setState(() {
      _steps.add(step);
    });
  }

  String _getDefaultDescription(MacroAction action) {
    switch (action) {
      case MacroAction.runCommand:
        return 'Execute a command';
      case MacroAction.openApp:
        return 'Open an application';
      case MacroAction.closeApp:
        return 'Close an application';
      case MacroAction.sendKeys:
        return 'Send keyboard input';
      case MacroAction.mouseClick:
        return 'Click at coordinates';
      case MacroAction.waitFor:
        return 'Wait for specified time';
      case MacroAction.systemControl:
        return 'Control system settings';
      case MacroAction.fileOperation:
        return 'Perform file operation';
      default:
        return 'Perform action';
    }
  }

  void _handleStepAction(String action, int index) {
    switch (action) {
      case 'edit':
        _editStep(index);
        break;
      case 'duplicate':
        _duplicateStep(index);
        break;
      case 'delete':
        _deleteStep(index);
        break;
    }
  }

  void _editStep(int index) {
    // TODO: Implement step editing
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Step editing coming soon!')));
  }

  void _duplicateStep(int index) {
    final originalStep = _steps[index];
    final duplicatedStep = MacroStep(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: originalStep.action,
      parameters: Map.from(originalStep.parameters)
        ..['description'] =
            '${originalStep.parameters['description'] ?? ''} (Copy)',
      delay: originalStep.delay,
      condition: originalStep.condition,
      order: _steps.length,
    );

    setState(() {
      _steps.insert(index + 1, duplicatedStep);
    });
  }

  void _deleteStep(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Step'),
        content: const Text('Are you sure you want to delete this step?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _steps.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveMacro() {
    if (_formKey.currentState!.validate()) {
      if (_steps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one step')),
        );
        return;
      }

      // TODO: Save macro using DockService
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.macro != null
                ? 'Macro updated successfully'
                : 'Macro created successfully',
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
      );

      Navigator.pop(context, true);
    }
  }
}
