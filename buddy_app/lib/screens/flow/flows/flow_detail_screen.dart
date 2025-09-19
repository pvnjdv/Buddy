import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/flow_models.dart';
import '../../../models/collaboration_models.dart';
import '../../../models/project_model.dart';
import '../../../services/flow_service.dart';
import '../../../services/ai/buddy_service.dart';
import '../../../services/collaboration/team_collaboration_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../buddy_code_editor/buddy_code_editor_screen.dart';
import 'flow_specific_buddy_screen.dart';

class FlowDetailScreen extends StatefulWidget {
  final ProjectFlow flow;

  const FlowDetailScreen({super.key, required this.flow});

  @override
  State<FlowDetailScreen> createState() => _FlowDetailScreenState();
}

class _FlowDetailScreenState extends State<FlowDetailScreen> {
  late ProjectFlow _flow;
  bool _isLoading = false;
  StreamSubscription? _flowWsSub;

  @override
  void initState() {
    super.initState();
    _flow = widget.flow;
    _initFlowSocket();
  }

  Future<void> _initFlowSocket() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      FlowService.connectFlowSocket(token: token, flowId: _flow.id.toString());
      _flowWsSub = FlowService.flowSocketStream?.listen(_onFlowWsEvent);
    } catch (_) {}
  }

  void _onFlowWsEvent(dynamic event) {
    try {
      final payload = event is String ? jsonDecode(event) : event;
      if (payload is Map && payload['type'] == 'flow_update') {
        final data = payload['data'] as Map?;
        if (data == null) return;
        final updatedIds =
            (data['updated_checkpoint_ids'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toSet();
        final newIndex = data['current_checkpoint_index'] as int?;
        final statusStr = data['status']?.toString();
        FlowStatus? newStatus;
        if (statusStr != null) {
          newStatus = FlowStatus.values.firstWhere(
            (e) =>
                e.name == statusStr ||
                e.toString().split('.').last == statusStr,
            orElse: () => _flow.status,
          );
        }
        // Build updated checkpoints list
        final updatedCps = _flow.checkpoints.map((cp) {
          if (updatedIds.contains(cp.id)) {
            return cp.copyWith(isCompleted: true, completedAt: DateTime.now());
          }
          return cp;
        }).toList();

        setState(() {
          _flow = _flow.copyWith(
            checkpoints: updatedCps,
            currentCheckpointIndex: newIndex ?? _flow.currentCheckpointIndex,
            status: newStatus ?? _flow.status,
          );
        });
      }
    } catch (e) {
      // ignore malformed events
    }
  }

  @override
  void dispose() {
    _flowWsSub?.cancel();
    FlowService.disconnectFlowSocket();
    super.dispose();
  }

  Future<void> _toggleCheckpoint(FlowCheckpoint checkpoint) async {
    setState(() => _isLoading = true);

    try {
      final newStatus = !checkpoint.isCompleted;
      final updatedFlow = await FlowService.updateCheckpointStatus(
        _flow.id,
        checkpoint.id,
        newStatus,
      );

      // Update progress with Buddy
      await BuddyService.updateFlowProgress(
        _flow.id,
        checkpoint.order,
        newStatus,
      );

      if (updatedFlow != null) {
        setState(() => _flow = updatedFlow);

        // Enhanced success feedback with animation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.undo,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  newStatus
                      ? 'Checkpoint completed! 🎉'
                      : 'Checkpoint marked as incomplete',
                ),
              ],
            ),
            backgroundColor: newStatus
                ? const Color(0xFF2D5016).withOpacity(
                    0.9,
                  ) // Dark green for success
                : const Color(
                    0xFF8B4513,
                  ).withOpacity(0.9), // Dark orange for incomplete
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Add haptic feedback if available
        // HapticFeedback.lightImpact();
      } else {
        throw Exception('Failed to update checkpoint');
      }
    } catch (e) {
      // Enhanced error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error updating checkpoint: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: const Color(
            0xFF7F1D1D,
          ).withOpacity(0.9), // Dark red for errors
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _toggleCheckpoint(checkpoint),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCheckpointHelp(FlowCheckpoint checkpoint) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Getting help from Buddy...'),
          ],
        ),
      ),
    );

    try {
      final help = await BuddyService.getCheckpointHelp(
        flowId: _flow.id.toString(),
        checkpointName: checkpoint.title,
      );
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.help, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Help: ${checkpoint.title}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(help['response'] ?? 'No help available.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/buddy');
              },
              child: const Text('Ask More'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting help: $e')));
    }
  }

  // Add work contribution to checkpoint
  Future<void> _addWorkContribution(FlowCheckpoint checkpoint) async {
    final TextEditingController hoursController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    ContributionType selectedType = ContributionType.development;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.work, color: Colors.green),
              const SizedBox(width: 8),
              Text('Add Work Contribution'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(
                  labelText: 'Hours Worked',
                  prefixIcon: Icon(Icons.access_time),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ContributionType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Work Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: ContributionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Work Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _submitWorkContribution(
                checkpoint,
                hoursController.text,
                selectedType,
                descriptionController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF2D5016,
                ), // Dark green for dark theme
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitWorkContribution(
    FlowCheckpoint checkpoint,
    String hours,
    ContributionType type,
    String description,
  ) async {
    if (hours.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      final contribution = WorkContribution(
        userId: 'current_user_id', // Replace with actual user ID
        userName: 'Current User', // Replace with actual user name
        hoursWorked: double.parse(hours),
        workDescription: description,
        contributedAt: DateTime.now(),
        type: type,
      );

      final success = await TeamCollaborationService.addWorkContribution(
        flowId: _flow.id,
        checkpointId: checkpoint.id,
        contribution: contribution,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Work contribution added successfully'),
            backgroundColor: const Color(
              0xFF2D5016,
            ).withOpacity(0.9), // Dark green for dark theme
          ),
        );
        // Refresh the flow data to show new contribution
        // TODO: Implement flow refresh
      } else {
        throw Exception('Failed to add work contribution');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding contribution: $e'),
          backgroundColor: const Color(
            0xFF7F1D1D,
          ).withOpacity(0.9), // Dark red for dark theme
        ),
      );
    }
  }

  // Open code editor for checkpoint
  void _openCodeEditor(FlowCheckpoint checkpoint) {
    // Create a ProjectModel from the flow
    final project = ProjectModel(
      name: _flow.title,
      path: _flow.localPath ?? _flow.repositoryUrl ?? '/tmp/${_flow.id}',
      description: _flow.description,
      projectType: 'general', // Could be enhanced to detect project type
    );

    // Navigate to the code editor
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BuddyCodeEditorScreen(project: project),
      ),
    );
  }

  // Show work contributions for checkpoint
  void _showWorkContributions(FlowCheckpoint checkpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.group_work, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Work Contributions'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<WorkContribution>>(
            future: TeamCollaborationService.getCheckpointContributions(
              _flow.id,
              checkpoint.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final contributions = snapshot.data ?? [];
              if (contributions.isEmpty) {
                return const Center(child: Text('No work contributions yet'));
              }

              return ListView.builder(
                itemCount: contributions.length,
                itemBuilder: (context, index) {
                  final contrib = contributions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Text(
                        contrib.userName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    title: Text(contrib.userName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contrib.workDescription),
                        Text(
                          '${contrib.hoursWorked}h • ${contrib.type.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${contrib.contributedAt.day}/${contrib.contributedAt.month}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addWorkContribution(checkpoint);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFF2D5016,
              ), // Dark green for dark theme
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Work'),
          ),
        ],
      ),
    );
  }

  // Enhanced AI assistance with tracking
  Future<void> _getEnhancedCheckpointHelp(FlowCheckpoint checkpoint) async {
    final TextEditingController queryController = TextEditingController();
    AIAssistanceType selectedType = AIAssistanceType.guidance;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.purple),
              const SizedBox(width: 8),
              Text('AI Buddy Assistance'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AIAssistanceType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Assistance Type',
                  prefixIcon: Icon(Icons.help_center),
                ),
                items: AIAssistanceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: queryController,
                decoration: InputDecoration(
                  labelText: 'Your Question',
                  hintText: 'Ask Buddy about ${checkpoint.title}...',
                  prefixIcon: const Icon(Icons.chat),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _requestAIAssistance(
                checkpoint,
                queryController.text,
                selectedType,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF4C1D95,
                ), // Dark purple for dark theme
                foregroundColor: Colors.white,
              ),
              child: const Text('Ask Buddy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAIAssistance(
    FlowCheckpoint checkpoint,
    String query,
    AIAssistanceType type,
  ) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your question')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Buddy is thinking...'),
          ],
        ),
      ),
    );

    try {
      final help = await BuddyService.getCheckpointHelp(
        flowId: _flow.id.toString(),
        checkpointName: '${checkpoint.title}: $query',
      );

      Navigator.of(context).pop(); // Close loading dialog

      final assistance = AIBuddyAssistance(
        assistanceId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        query: query,
        response: help['response'] ?? 'No response available.',
        requestedAt: DateTime.now(),
        type: type,
      );

      // Record the assistance
      await TeamCollaborationService.recordAIAssistance(
        flowId: _flow.id,
        checkpointId: checkpoint.id,
        assistance: assistance,
      );

      _showAIAssistanceResponse(assistance, checkpoint);
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting help: $e')));
    }
  }

  void _showAIAssistanceResponse(
    AIBuddyAssistance assistance,
    FlowCheckpoint checkpoint,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.purple),
            const SizedBox(width: 8),
            Text('Buddy\'s Response'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Question: ${assistance.query}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
              Text(assistance.response),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/buddy');
            },
            child: const Text('Continue Chat'),
          ),
          IconButton(
            onPressed: () => _showAIAssistanceHistory(checkpoint),
            icon: const Icon(Icons.history),
            tooltip: 'View assistance history',
          ),
        ],
      ),
    );
  }

  void _showAIAssistanceHistory(FlowCheckpoint checkpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.purple),
            const SizedBox(width: 8),
            Text('AI Assistance History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<AIBuddyAssistance>>(
            future: TeamCollaborationService.getAIAssistanceHistory(
              _flow.id,
              checkpoint.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Center(
                  child: Text('No AI assistance history yet'),
                );
              }

              return ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final assistance = history[index];
                  return ExpansionTile(
                    leading: Icon(
                      Icons.smart_toy,
                      color: Colors.purple,
                      size: 20,
                    ),
                    title: Text(
                      assistance.query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${assistance.type.name} • ${assistance.requestedAt.day}/${assistance.requestedAt.month}',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(assistance.response),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInviteCollaboratorDialog() {
    final TextEditingController mobileController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    CollaborationRole selectedRole = CollaborationRole.contributor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text('Invite Collaborator'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '+1234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CollaborationRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.workspace_premium),
                ),
                items: CollaborationRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText: 'Would you like to collaborate on this project?',
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _sendCollaborationInvite(
                mobileController.text,
                selectedRole,
                messageController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA), // App accent color
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCollaborationInvite(
    String mobile,
    CollaborationRole role,
    String message,
  ) async {
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a mobile number')),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      // Send collaboration request via TeamCollaborationService
      final success = await TeamCollaborationService.sendCollaborationInvite(
        receiverMobile: mobile,
        flow: _flow,
        role: role,
        message: message.isNotEmpty ? message : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collaboration invite sent to $mobile'),
            backgroundColor: const Color(
              0xFF2D5016,
            ).withOpacity(0.9), // Dark green for dark theme
            action: SnackBarAction(
              label: 'View Chat',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushNamed('/chats');
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to send invitation');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invite: $e'),
          backgroundColor: const Color(
            0xFF7F1D1D,
          ).withOpacity(0.9), // Dark red for dark theme
        ),
      );
    }
  }

  void _showCollaborationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('Collaboration Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Project Visibility'),
              subtitle: Text(
                _flow.collaboration != null ? 'Collaborative' : 'Private',
              ),
            ),
            const Divider(),
            const Text(
              'Collaborative projects allow team members to work together, track progress, and share insights.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showViewMembersDialog() {
    if (_flow.collaboration == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Team Members (${_flow.collaboration!.totalMembers})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...(_flow.collaboration!.members.map((member) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(
                      0xFF667EEA,
                    ).withOpacity(0.1), // App accent color
                    child: Text(
                      member.userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: const Color(0xFF667EEA),
                      ), // App accent color
                    ),
                  ),
                  title: Text(member.userName),
                  subtitle: Text(member.role.name.toUpperCase()),
                  trailing: member.role == CollaborationRole.owner
                      ? const Icon(Icons.star, color: Colors.amber, size: 20)
                      : null,
                );
              }).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showInviteCollaboratorDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA), // App accent color
              foregroundColor: Colors.white,
            ),
            child: const Text('Invite More'),
          ),
        ],
      ),
    );
  }

  // --- Dashboard & Scaffold ---
  Future<void> _openDashboard() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final data = await FlowService.getFlowDashboard(_flow.id);
      Navigator.of(context).pop();
      final dashboard = FlowDashboard.fromJson(data);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _buildDashboardSheet(dashboard),
      );
    } catch (e) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
    }
  }

  Future<void> _scaffoldProject() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await FlowService.scaffoldFlow(_flow.id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Scaffold request queued.')));
    } catch (e) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to scaffold: $e')));
    }
  }

  Widget _buildDashboardSheet(FlowDashboard d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  d.flow.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: d.progress.percentage / 100.0),
            const SizedBox(height: 8),
            Text(
              'Progress: ${d.progress.completed}/${d.progress.total} (${d.progress.percentage.toStringAsFixed(1)}%)',
            ),
            const SizedBox(height: 12),
            if (d.participants.isNotEmpty) ...[
              const Text(
                'Participants',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: d.participants
                    .map((p) => Chip(label: Text(p)))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Team Stats Section
            const Text(
              'Team Statistics',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric(
                  'Hours Worked',
                  d.teamStats.totalHoursWorked.toStringAsFixed(1),
                  Icons.access_time,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _metric(
                  'Contributors',
                  d.teamStats.totalContributors,
                  Icons.people,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric(
                  'AI Sessions',
                  d.teamStats.aiAssistanceSessions,
                  Icons.smart_toy,
                  Colors.purple,
                ),
                const SizedBox(width: 12),
                _metric(
                  'Team Members',
                  d.teamStats.teamMembers,
                  Icons.group,
                  Colors.blue,
                ),
              ],
            ),
            if (d.teamStats.lastActivity != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last Activity: ${_formatDateTime(d.teamStats.lastActivity!)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            // Repository Information Section
            if (_flow.repositoryUrl != null || _flow.localPath != null) ...[
              const Text(
                'Repository',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'GitHub Repository',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_flow.repositoryUrl != null) ...[
                      InkWell(
                        onTap: () async {
                          // Open repository URL in browser
                          final Uri url = Uri.parse(_flow.repositoryUrl!);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _flow.repositoryUrl!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_flow.localPath != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.folder,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Local: ${_flow.localPath!}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _metric('Notes', d.notesCount, Icons.note_alt, Colors.indigo),
                const SizedBox(width: 12),
                _metric(
                  'Assignments',
                  d.assignmentsCount,
                  Icons.assignment_ind,
                  Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Upcoming',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (d.upcomingAlarms.isEmpty)
              const Text('No upcoming alarms')
            else
              ...d.upcomingAlarms.map(
                (a) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.alarm),
                  title: Text(a.title),
                  subtitle: Text(a.at.toLocal().toString()),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Insights',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...d.insights.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(child: Text(i)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, dynamic value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('$value'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // --- Checkpoint Notes / Assignments / Alarms ---
  Future<void> _showCheckpointNotes(FlowCheckpoint cp) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final items = await FlowService.getCheckpointNotes(_flow.id, cp.id);
      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Notes'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(context);
                    _addCheckpointNote(cp);
                  },
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No notes yet'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.note),
                      title: Text(items[i]['title']?.toString() ?? ''),
                      subtitle: Text(
                        (items[i]['content']?.toString() ?? '')
                            .split('\n')
                            .first,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load notes: $e')));
    }
  }

  Future<void> _addCheckpointNote(FlowCheckpoint cp) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FlowService.createCheckpointNote(
                  _flow.id,
                  cp.id,
                  title: titleCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note added')));
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignments(FlowCheckpoint cp) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final items = await FlowService.getCheckpointAssignments(_flow.id, cp.id);
      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Assignments'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(context);
                    _assignCheckpoint(cp);
                  },
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No assignments'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.assignment_ind),
                      title: Text(
                        items[i]['assignee_name']?.toString() ??
                            items[i]['assignee_id']?.toString() ??
                            '',
                      ),
                      subtitle: Text(
                        'Assigned at: ' +
                            (items[i]['assigned_at']?.toString() ?? ''),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load assignments: $e')));
    }
  }

  Future<void> _assignCheckpoint(FlowCheckpoint cp) async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Checkpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(labelText: 'Assignee ID'),
            ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Assignee Name (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FlowService.assignCheckpoint(
                  _flow.id,
                  cp.id,
                  assigneeId: idCtrl.text.trim(),
                  assigneeName: nameCtrl.text.trim().isEmpty
                      ? null
                      : nameCtrl.text.trim(),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Assigned')));
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckpointAlarms(FlowCheckpoint cp) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final items = await FlowService.getCheckpointAlarms(_flow.id, cp.id);
      Navigator.of(context).pop();
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Alarms'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_alarm),
                  onPressed: () {
                    Navigator.pop(context);
                    _addCheckpointAlarm(cp);
                  },
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No alarms'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text(items[i]['title']?.toString() ?? ''),
                      subtitle: Text(
                        items[i]['scheduled_time']?.toString() ?? '',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load alarms: $e')));
    }
  }

  Future<void> _addCheckpointAlarm(FlowCheckpoint cp) async {
    final titleCtrl = TextEditingController();
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      picked == null
                          ? 'No time selected'
                          : picked!.toLocal().toString(),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      final dt = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t?.hour ?? 9,
                        t?.minute ?? 0,
                      );
                      setState(() => picked = dt);
                    },
                    child: const Text('Pick time'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (picked == null) return;
                try {
                  await FlowService.createCheckpointAlarm(
                    _flow.id,
                    cp.id,
                    title: titleCtrl.text.trim().isEmpty
                        ? 'Reminder'
                        : titleCtrl.text.trim(),
                    scheduledTime: picked!,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alarm created')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = _flow.progressPercentage;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(_flow.title),
        backgroundColor: const Color(0xFF1A202C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Flow-specific Buddy Chat
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                size: 20,
                color: Colors.white,
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FlowSpecificBuddyScreen(flow: _flow),
              ),
            ),
            tooltip: 'Flow-specific Buddy Chat',
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: _openDashboard,
            tooltip: 'Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: _scaffoldProject,
            tooltip: 'Scaffold Project',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Add refresh logic here
                await Future.delayed(const Duration(seconds: 1));
                setState(() {});
              },
              color: const Color(0xFF667EEA),
              child: _buildTimelineView(progressPercentage),
            ),
      floatingActionButton: _buildCollaborationFAB(),
    );
  }

  Widget? _buildCollaborationFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCollaborationOptionsDialog,
      backgroundColor: const Color(0xFF667EEA),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.groups),
      label: const Text('Collaborate'),
      tooltip: 'Collaboration options',
    );
  }

  void _showCollaborationOptionsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.groups, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Collaboration Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCollaborationOption(
              icon: Icons.person_add,
              title: 'Invite Team Member',
              subtitle: 'Add new collaborators to this project',
              onTap: () {
                Navigator.of(context).pop();
                _showInviteCollaboratorDialog();
              },
            ),
            _buildCollaborationOption(
              icon: Icons.people,
              title: 'View Team Members',
              subtitle: 'See all project collaborators',
              onTap: () {
                Navigator.of(context).pop();
                _showViewMembersDialog();
              },
            ),
            _buildCollaborationOption(
              icon: Icons.settings,
              title: 'Collaboration Settings',
              subtitle: 'Configure team permissions and project visibility',
              onTap: () {
                Navigator.of(context).pop();
                _showCollaborationSettings();
              },
            ),
            _buildCollaborationOption(
              icon: Icons.chat,
              title: 'Team Chat',
              subtitle: 'Chat with Buddy about this project',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/buddy');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaborationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView(double progressPercentage) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flow Info Card
          Card(
            elevation: 0,
            color: const Color(0xFF1A202C).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF4A5568).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _flow.description,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3748).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A5568).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Overall Progress',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${progressPercentage.toInt()}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Enhanced Progress Bar with Milestones
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF4A5568).withOpacity(0.3),
                            border: Border.all(
                              color: const Color(0xFF4A5568).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Animated gradient progress fill
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: LinearProgressIndicator(
                                  value: progressPercentage / 100,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.transparent,
                                  ),
                                  minHeight: 22,
                                ),
                              ),
                              // Gradient overlay
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width *
                                      (progressPercentage / 100) *
                                      0.85, // Account for padding
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _getProgressColor(
                                          progressPercentage,
                                        ).withOpacity(0.8),
                                        _getProgressColor(progressPercentage),
                                        _getProgressColor(
                                          progressPercentage,
                                        ).withOpacity(0.9),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getProgressColor(
                                          progressPercentage,
                                        ).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Milestone markers
                              ..._buildMilestoneMarkers(),
                              // Progress percentage overlay
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Text(
                                    '${progressPercentage.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress milestones text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_flow.completedCheckpoints.length} of ${_flow.checkpoints.length} checkpoints',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              _getProgressMotivation(progressPercentage),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getProgressColor(
                                  progressPercentage,
                                ).withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Metadata
                  Row(
                    children: [
                      _buildInfoChip(Icons.schedule, _flow.estimatedDuration),
                      const SizedBox(width: 8),
                      _buildDifficultyChip(_flow.difficulty),
                      const SizedBox(width: 8),
                      _buildStatusChip(_flow.status),
                    ],
                  ),

                  if (_flow.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: _flow.tags
                          .map((tag) => _buildTag(tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Checkpoints Section
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Checkpoints (${_flow.completedCheckpoints.length}/${_flow.checkpoints.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Checkpoints List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _flow.checkpoints.length,
            itemBuilder: (context, index) {
              final checkpoint = _flow.checkpoints[index];
              final isCurrentCheckpoint = index == _flow.currentCheckpointIndex;
              return _buildCheckpointCard(
                checkpoint,
                isCurrentCheckpoint,
                depth: 0,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard(
    FlowCheckpoint checkpoint,
    bool isCurrent, {
    int depth = 0,
  }) {
    final isCompleted = checkpoint.isCompleted;
    final hasChildren = checkpoint.children.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(
        bottom: 16,
        left: depth * 20.0, // Increased indent for better hierarchy
      ),
      child: Card(
        elevation: isCurrent ? 8 : (depth > 0 ? 2 : 4),
        shadowColor: isCurrent
            ? Colors.blue.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrent
              ? BorderSide(color: Colors.blue.withOpacity(0.5), width: 2)
              : depth > 0
              ? BorderSide(
                  color: Colors.grey.shade300.withOpacity(0.5),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            // Add tap animation or expansion
            setState(() {
              // Could add expansion state here
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isCurrent
                  ? LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.05),
                        Colors.blue.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with enhanced styling
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced checkbox with animation
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => _toggleCheckpoint(checkpoint),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                  ? Colors.blue
                                  : Colors.grey,
                              width: 2.5,
                            ),
                            color: isCompleted
                                ? Colors.green
                                : Colors.transparent,
                            boxShadow: isCompleted
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    key: ValueKey('check'),
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : hasChildren
                                ? Icon(
                                    Icons.folder,
                                    key: const ValueKey('folder'),
                                    color: isCurrent
                                        ? Colors.blue
                                        : Colors.grey.shade600,
                                    size: 14,
                                  )
                                : Icon(
                                    Icons.radio_button_unchecked,
                                    key: const ValueKey('unchecked'),
                                    color: isCurrent
                                        ? Colors.blue
                                        : Colors.grey,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Title and type with better spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    checkpoint.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: isCompleted
                                          ? Colors.grey[500]
                                          : isCurrent
                                          ? Colors.blue[900]
                                          : Colors.black87,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildCheckpointTypeChip(checkpoint.type),
                              ],
                            ),
                            if (isCurrent) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blue, Colors.blueAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'CURRENT TASK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Enhanced action buttons
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => _getCheckpointHelp(checkpoint),
                              icon: Icon(
                                Icons.help_outline,
                                color: Colors.blue[600],
                                size: 20,
                              ),
                              tooltip: 'Get basic help from Buddy',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () =>
                                  _getEnhancedCheckpointHelp(checkpoint),
                              icon: Icon(
                                Icons.smart_toy,
                                color: Colors.purple[600],
                                size: 20,
                              ),
                              tooltip: 'Ask Buddy anything',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.purple.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Enhanced description with better typography
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      checkpoint.description,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Requirements and Deliverables with improved layout
                  if (checkpoint.requirements.isNotEmpty) ...[
                    _buildEnhancedListSection(
                      'Requirements',
                      checkpoint.requirements,
                      Icons.list,
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (checkpoint.deliverables.isNotEmpty) ...[
                    _buildEnhancedListSection(
                      'Deliverables',
                      checkpoint.deliverables,
                      Icons.delivery_dining,
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Enhanced time information
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated: ${checkpoint.estimatedTime}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (checkpoint.completedAt != null) ...[
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Completed ${_formatDate(checkpoint.completedAt!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Enhanced collaboration section
                  if (checkpoint.workContributions.isNotEmpty ||
                      checkpoint.assignedTo != null ||
                      checkpoint.aiAssistance != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.1),
                            Colors.purple.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_alt,
                                size: 18,
                                color: Colors.purple[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Collaboration Hub',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Assignment info
                          if (checkpoint.assignedTo != null) ...[
                            _buildCollaborationItem(
                              Icons.assignment_ind,
                              'Assigned to: ${checkpoint.assignedTo}',
                              Colors.blue,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Work contributions summary
                          if (checkpoint.workContributions.isNotEmpty) ...[
                            _buildCollaborationItem(
                              Icons.work,
                              '${checkpoint.workContributions.length} contributors, ${checkpoint.workContributions.fold(0.0, (sum, c) => sum + c.hoursWorked)}h total',
                              Colors.green,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // AI assistance indicator
                          if (checkpoint.aiAssistance != null) ...[
                            _buildCollaborationItem(
                              Icons.smart_toy,
                              'AI assistance available',
                              Colors.purple,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Enhanced action buttons with better layout
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Primary actions row
                        Row(
                          children: [
                            if (checkpoint.workContributions.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _showWorkContributions(checkpoint),
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('View Work'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),

                            if (checkpoint.workContributions.isNotEmpty)
                              const SizedBox(width: 8),

                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _addWorkContribution(checkpoint),
                                icon: const Icon(Icons.add_task, size: 16),
                                label: const Text('Add Work'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openCodeEditor(checkpoint),
                                icon: const Icon(Icons.code, size: 16),
                                label: const Text('Code Editor'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667EEA),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Secondary actions row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showCheckpointNotes(checkpoint),
                                icon: const Icon(Icons.note_alt, size: 16),
                                label: const Text('Notes'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber[800],
                                  side: BorderSide(
                                    color: Colors.amber.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showAssignments(checkpoint),
                                icon: const Icon(Icons.assignment, size: 16),
                                label: const Text('Assign'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal[800],
                                  side: BorderSide(
                                    color: Colors.teal.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showCheckpointAlarms(checkpoint),
                                icon: const Icon(Icons.alarm, size: 16),
                                label: const Text('Alarms'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red[800],
                                  side: BorderSide(
                                    color: Colors.red.withOpacity(0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Children checkpoints
                  if (hasChildren) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sub-tasks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...checkpoint.children.map(
                            (child) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildCheckpointCard(
                                child,
                                false,
                                depth: depth + 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedListSection(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4A5568).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[300]),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(FlowDifficulty difficulty) {
    Color color;
    String label;

    switch (difficulty) {
      case FlowDifficulty.easy:
        color = Colors.green;
        label = 'Easy';
        break;
      case FlowDifficulty.medium:
        color = Colors.orange;
        label = 'Medium';
        break;
      case FlowDifficulty.hard:
        color = Colors.red;
        label = 'Hard';
        break;
      case FlowDifficulty.expert:
        color = Colors.purple;
        label = 'Expert';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusChip(FlowStatus status) {
    Color color;
    String label;

    switch (status) {
      case FlowStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case FlowStatus.completed:
        color = Colors.blue;
        label = 'Completed';
        break;
      case FlowStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        break;
      case FlowStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCheckpointTypeChip(CheckpointType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          color: type.color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4A5568).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(tag, style: TextStyle(color: Colors.grey[300], fontSize: 10)),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage < 25) return Colors.red;
    if (percentage < 50) return Colors.orange;
    if (percentage < 75) return Colors.blue;
    return Colors.green;
  }

  List<Widget> _buildMilestoneMarkers() {
    final progressPercentage = _flow.progressPercentage;
    final milestones = [25.0, 50.0, 75.0, 100.0];
    final completedMilestones = milestones
        .where((m) => m <= progressPercentage)
        .toList();

    return milestones.map((milestone) {
      final isCompleted = completedMilestones.contains(milestone);
      final position = milestone / 100.0;

      return Positioned(
        left:
            (MediaQuery.of(context).size.width * position * 0.85) -
            6, // Center the marker
        top: 0,
        bottom: 0,
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.white
                  : const Color(0xFF4A5568).withOpacity(0.5),
              border: Border.all(
                color: isCompleted
                    ? _getProgressColor(progressPercentage)
                    : Colors.grey[500]!,
                width: 2,
              ),
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: _getProgressColor(
                          progressPercentage,
                        ).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 6,
                    color: _getProgressColor(progressPercentage),
                  )
                : null,
          ),
        ),
      );
    }).toList();
  }

  String _getProgressMotivation(double percentage) {
    if (percentage >= 100) return '🎉 Complete!';
    if (percentage >= 75) return 'Almost there!';
    if (percentage >= 50) return 'Halfway done!';
    if (percentage >= 25) return 'Great start!';
    return 'Let\'s begin!';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
