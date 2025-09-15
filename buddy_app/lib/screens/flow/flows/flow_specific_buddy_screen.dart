import 'package:flutter/material.dart';
import '../../../models/flow_models.dart';

class FlowSpecificBuddyScreen extends StatefulWidget {
  final ProjectFlow flow;

  const FlowSpecificBuddyScreen({super.key, required this.flow});

  @override
  State<FlowSpecificBuddyScreen> createState() =>
      _FlowSpecificBuddyScreenState();
}

class _FlowSpecificBuddyScreenState extends State<FlowSpecificBuddyScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFlowContext();
  }

  void _initializeFlowContext() {
    // Add initial context message about the flow
    final contextMessage = ChatMessage(
      id: 'context_${DateTime.now().millisecondsSinceEpoch}',
      content:
          'Hi! I\'m here to help you with "${widget.flow.title}". '
          'This is a flow-specific chat where I have full context about your project. '
          'Ask me anything about the checkpoints, requirements, or how to proceed!',
      sender: 'buddy',
      timestamp: DateTime.now(),
      flowId: widget.flow.id,
    );

    setState(() {
      _messages.add(contextMessage);
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: messageText,
      sender: 'user',
      timestamp: DateTime.now(),
      flowId: widget.flow.id,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();

    try {
      // Create flow-specific context for Buddy
      final flowContext = _buildFlowContext();

      // For now, use a simple response - in a real app, integrate with your chat service
      final response =
          'I understand you\'re asking about "${widget.flow.title}". '
          'Based on your current progress (${widget.flow.progressPercentage.toInt()}%), '
          'I can help you with the next steps. Your question: "$messageText" - '
          'Context: ${flowContext['current_checkpoint']?['title'] ?? 'No current checkpoint'}';

      final buddyMessage = ChatMessage(
        id: 'buddy_${DateTime.now().millisecondsSinceEpoch}',
        content: response,
        sender: 'buddy',
        timestamp: DateTime.now(),
        flowId: widget.flow.id,
      );

      setState(() {
        _messages.add(buddyMessage);
      });
    } catch (e) {
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Sorry, I encountered an error: $e',
        sender: 'buddy',
        timestamp: DateTime.now(),
        flowId: widget.flow.id,
      );

      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildFlowContext() {
    return {
      'flow_id': widget.flow.id,
      'flow_title': widget.flow.title,
      'flow_description': widget.flow.description,
      'estimated_duration': widget.flow.estimatedDuration,
      'difficulty': widget.flow.difficulty.name,
      'status': widget.flow.status.name,
      'tags': widget.flow.tags,
      'progress_percentage': widget.flow.progressPercentage,
      'completed_checkpoints': widget.flow.completedCheckpoints.length,
      'total_checkpoints': widget.flow.checkpoints.length,
      'current_checkpoint_index': widget.flow.currentCheckpointIndex,
      'current_checkpoint':
          widget.flow.currentCheckpointIndex < widget.flow.checkpoints.length
          ? {
              'title': widget
                  .flow
                  .checkpoints[widget.flow.currentCheckpointIndex]
                  .title,
              'description': widget
                  .flow
                  .checkpoints[widget.flow.currentCheckpointIndex]
                  .description,
              'requirements': widget
                  .flow
                  .checkpoints[widget.flow.currentCheckpointIndex]
                  .requirements,
              'deliverables': widget
                  .flow
                  .checkpoints[widget.flow.currentCheckpointIndex]
                  .deliverables,
              'estimated_time': widget
                  .flow
                  .checkpoints[widget.flow.currentCheckpointIndex]
                  .estimatedTime,
            }
          : null,
      'checkpoints': widget.flow.checkpoints
          .map(
            (cp) => {
              'id': cp.id,
              'title': cp.title,
              'description': cp.description,
              'is_completed': cp.isCompleted,
              'requirements': cp.requirements,
              'deliverables': cp.deliverables,
              'estimated_time': cp.estimatedTime,
            },
          )
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buddy Assistant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              widget.flow.title,
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B263B),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF667EEA).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.psychology,
                  color: Color(0xFF667EEA),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Flow Context',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF2D3748)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Flow context banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Flow-Specific Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${widget.flow.progressPercentage.toInt()}% • '
                    '${widget.flow.completedCheckpoints.length}/${widget.flow.checkpoints.length} checkpoints',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A202C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Color(0xFF667EEA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Buddy is thinking...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Message input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A202C),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Ask about this flow...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.sender == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF667EEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF667EEA)
                    : const Color(0xFF1A202C),
                borderRadius: BorderRadius.circular(16),
                border: !isUser
                    ? Border.all(
                        color: const Color(0xFF4A5568).withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2D3748),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String id;
  final String content;
  final String sender;
  final DateTime timestamp;
  final String? flowId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.flowId,
  });
}
