import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../models/collaboration_models.dart';
import '../../config/settings/theme_config.dart';

class CollaborationIntegrationDemo extends StatefulWidget {
  const CollaborationIntegrationDemo({super.key});

  @override
  State<CollaborationIntegrationDemo> createState() =>
      _CollaborationIntegrationDemoState();
}

class _CollaborationIntegrationDemoState
    extends State<CollaborationIntegrationDemo> {
  List<ChatMessage> _demoMessages = [];
  List<ProjectFlow> _demoFlows = [];

  @override
  void initState() {
    super.initState();
    _loadDemoData();
  }

  void _loadDemoData() {
    // Demo collaboration request message
    final collaborationRequest = ChatMessage(
      id: '1',
      senderId: 'friend_123',
      receiverId: 'current_user',
      content: 'Collaboration Request',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: MessageType.collaboration_request,
      status: MessageStatus.delivered,
      collaborationData: CollaborationData(
        projectId: '1',
        projectTitle: 'AI-Powered Mobile App',
        invitationId: 'inv_123',
        role: CollaborationRole.contributor,
        message:
            'Hey! Would you like to work together on this exciting AI project?',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        response: null,
      ),
    );

    // Demo collaboration response message
    final collaborationResponse = ChatMessage(
      id: '2',
      senderId: 'current_user',
      receiverId: 'friend_123',
      content: 'Collaboration Response',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      type: MessageType.collaboration_response,
      status: MessageStatus.delivered,
      collaborationData: CollaborationData(
        projectId: '1',
        projectTitle: 'AI-Powered Mobile App',
        invitationId: 'inv_123',
        role: CollaborationRole.contributor,
        message: '',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        response: 'accepted',
      ),
    );

    // Demo flow with collaboration
    final collaborativeFlow = ProjectFlow(
      id: '1',
      title: 'AI-Powered Mobile App',
      description: 'Building an innovative mobile app with AI capabilities',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      collaboration: ProjectCollaborationInfo(
        collaborationId: 'collab_1',
        members: [
          CollaborationMember(
            id: 'member_1',
            userId: 'current_user',
            userName: 'You',
            role: CollaborationRole.owner,
            joinedAt: DateTime.now().subtract(const Duration(days: 5)),
            lastActive: DateTime.now(),
          ),
          CollaborationMember(
            id: 'member_2',
            userId: 'friend_123',
            userName: 'John Doe',
            role: CollaborationRole.contributor,
            joinedAt: DateTime.now().subtract(const Duration(hours: 1)),
            lastActive: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ],
        isOwner: true,
        myRole: CollaborationRole.owner,
        totalMembers: 2,
        lastActivity: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    );

    setState(() {
      _demoMessages = [collaborationRequest, collaborationResponse];
      _demoFlows = [collaborativeFlow];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaboration Integration Demo'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: AppTheme.primaryColor,
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.chat), text: 'Chat Messages'),
                  Tab(icon: Icon(Icons.view_list), text: 'Flow List'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(children: [_buildChatDemo(), _buildFlowDemo()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDemo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo: Collaboration requests appear as special message types in chat',
                  style: TextStyle(color: Colors.blue[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _demoMessages.length,
            itemBuilder: (context, index) {
              final message = _demoMessages[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildMessageDemo(message),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlowDemo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo: Collaborative flows show member count and role indicators',
                  style: TextStyle(color: Colors.green[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _demoFlows.length,
            itemBuilder: (context, index) {
              final flow = _demoFlows[index];
              return _buildFlowCard(flow);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageDemo(ChatMessage message) {
    final isCurrentUser = message.senderId == 'current_user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: isCurrentUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!isCurrentUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              'J',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: message.type == MessageType.collaboration_request
                    ? Colors.blue
                    : (message.type == MessageType.collaboration_response
                          ? Colors.green
                          : Colors.transparent),
                width:
                    message.type == MessageType.collaboration_request ||
                        message.type == MessageType.collaboration_response
                    ? 1
                    : 0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.type == MessageType.collaboration_request)
                  _buildCollaborationRequestDemo(message),
                if (message.type == MessageType.collaboration_response)
                  _buildCollaborationResponseDemo(message),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollaborationRequestDemo(ChatMessage message) {
    final data = message.collaborationData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.handshake, color: Colors.blue, size: 18),
            const SizedBox(width: 6),
            Text(
              'Collaboration Request',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Project: ${data.projectTitle}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Text(
          'Role: ${data.role.name.toUpperCase()}',
          style: const TextStyle(fontSize: 13),
        ),
        if (data.message != null && data.message!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            data.message!,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collaboration accepted!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Accept'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collaboration declined')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Decline'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollaborationResponseDemo(ChatMessage message) {
    final data = message.collaborationData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              data.isAccepted ? Icons.check_circle : Icons.cancel,
              color: data.isAccepted ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Collaboration ${data.isAccepted ? 'Accepted' : 'Declined'}',
              style: TextStyle(
                color: data.isAccepted ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Project: ${data.projectTitle}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFlowCard(ProjectFlow flow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Icon(Icons.work, color: AppTheme.primaryColor, size: 20),
              if (flow.collaboration != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          flow.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              flow.description,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (flow.collaboration != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    '${flow.collaboration!.totalMembers} members',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.workspace_premium, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    flow.collaboration!.myRole.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                flow.collaboration != null
                    ? 'Opening collaborative project: ${flow.title}'
                    : 'Opening project: ${flow.title}',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Now';
    }
  }
}
