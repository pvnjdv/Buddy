import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../../../models/flow_models.dart';
import '../../../models/collaboration_models.dart';
import '../../../services/flow_service.dart';
import '../../../services/ai/buddy_service.dart';
import '../../../services/collaboration/team_collaboration_service.dart';
import '../../../services/auth/auth_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Checkpoint completed! 🎉'
                  : 'Checkpoint marked as incomplete',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not update checkpoint.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating checkpoint: $e')));
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
                backgroundColor: Colors.green,
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
          const SnackBar(
            content: Text('Work contribution added successfully'),
            backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
        ),
      );
    }
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
              backgroundColor: Colors.green,
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
                backgroundColor: Colors.purple,
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
                backgroundColor: Colors.blue,
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
            backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
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
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      member.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blue),
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
              backgroundColor: Colors.blue,
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

  Widget _metric(String label, int value, IconData icon, Color color) {
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
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(_flow.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
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
          // Add Team Member
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showInviteCollaboratorDialog,
            tooltip: 'Add Team Member',
          ),
        ],
      ),
      body: _buildTimelineView(progressPercentage),
      floatingActionButton: _buildCollaborationFAB(),
    );
  }

  Widget? _buildCollaborationFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCollaborationOptionsDialog,
      backgroundColor: Colors.purple,
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
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_flow.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${progressPercentage.toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(progressPercentage),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
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

    return Card(
      margin: EdgeInsets.only(
        bottom: 12,
        left: depth * 16.0, // Indent nested checkpoints
      ),
      elevation: isCurrent ? 4 : (depth > 0 ? 0.5 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? const BorderSide(color: Colors.blue, width: 2)
            : depth > 0
            ? BorderSide(color: Colors.grey.shade300, width: 1)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Depth indicator
                    if (depth > 0) ...[
                      SizedBox(width: (depth - 1) * 12.0),
                      Icon(
                        Icons.subdirectory_arrow_right,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Checkbox
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => _toggleCheckpoint(checkpoint),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                          color: isCompleted
                              ? Colors.green
                              : Colors.transparent,
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : hasChildren
                            ? Icon(
                                Icons.folder,
                                color: Colors.grey.shade600,
                                size: 12,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Title and type
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    color: isCompleted
                                        ? Colors.grey[600]
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              _buildCheckpointTypeChip(checkpoint.type),
                            ],
                          ),
                          if (isCurrent) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Help button
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _getCheckpointHelp(checkpoint),
                          icon: const Icon(
                            Icons.help_outline,
                            color: Colors.blue,
                          ),
                          tooltip: 'Get basic help from Buddy',
                        ),
                        IconButton(
                          onPressed: () =>
                              _getEnhancedCheckpointHelp(checkpoint),
                          icon: const Icon(
                            Icons.smart_toy,
                            color: Colors.purple,
                          ),
                          tooltip: 'Ask Buddy anything',
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  checkpoint.description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),

                const SizedBox(height: 12),

                // Requirements and Deliverables
                if (checkpoint.requirements.isNotEmpty) ...[
                  _buildListSection(
                    'Requirements',
                    checkpoint.requirements,
                    Icons.list,
                  ),
                  const SizedBox(height: 8),
                ],

                if (checkpoint.deliverables.isNotEmpty) ...[
                  _buildListSection(
                    'Deliverables',
                    checkpoint.deliverables,
                    Icons.delivery_dining,
                  ),
                  const SizedBox(height: 8),
                ],

                // Estimated time
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Estimated: ${checkpoint.estimatedTime}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (checkpoint.completedAt != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Completed: ${_formatDate(checkpoint.completedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Collaboration Features Section
                if (checkpoint.workContributions.isNotEmpty ||
                    checkpoint.assignedTo != null ||
                    checkpoint.aiAssistance != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people_alt,
                              size: 16,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Collaboration',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Assignment info
                        if (checkpoint.assignedTo != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_ind,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Assigned to: ${checkpoint.assignedTo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Work contributions summary
                        if (checkpoint.workContributions.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.work, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '${checkpoint.workContributions.length} contributors, ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${checkpoint.workContributions.fold(0.0, (sum, c) => sum + c.hoursWorked)}h total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // AI assistance indicator
                        if (checkpoint.aiAssistance != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                size: 14,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI assistance available',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Action buttons
                Row(
                  children: [
                    if (checkpoint.workContributions.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showWorkContributions(checkpoint),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text(
                            'View Work',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(
                              color: Colors.green.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),

                    if (checkpoint.workContributions.isNotEmpty)
                      const SizedBox(width: 8),

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addWorkContribution(checkpoint),
                        icon: const Icon(Icons.add_task, size: 16),
                        label: const Text(
                          'Add Work',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // New: Notes / Assign / Alarms actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCheckpointNotes(checkpoint),
                        icon: const Icon(Icons.note_alt, size: 16),
                        label: const Text(
                          'Notes',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAssignments(checkpoint),
                        icon: const Icon(Icons.assignment_ind, size: 16),
                        label: const Text(
                          'Assign',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCheckpointAlarms(checkpoint),
                        icon: const Icon(Icons.alarm, size: 16),
                        label: const Text(
                          'Alarms',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                // Render nested children if they exist
                if (hasChildren) ...[
                  const SizedBox(height: 8),
                  ...checkpoint.children
                      .map(
                        (child) => _buildCheckpointCard(
                          child,
                          false,
                          depth: depth + 1,
                        ),
                      )
                      .toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 2),
            child: Text(
              '• $item',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tag, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage < 25) return Colors.red;
    if (percentage < 50) return Colors.orange;
    if (percentage < 75) return Colors.blue;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
