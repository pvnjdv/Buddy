import 'package:flutter/material.dart';
import '../../models/flow_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onLongPress;
  final Function(bool)? onCollaborationResponse;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
    this.onCollaborationResponse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isCurrentUser ? 64 : 16,
          right: isCurrentUser ? 16 : 64,
        ),
        child: Row(
          mainAxisAlignment: isCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isCurrentUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF25D366),
                child: Text(
                  message.senderId[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCurrentUser ? const Color(0xFFDCF8C6) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                    bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.type == MessageType.collaboration_request)
                      _buildCollaborationRequest(),
                    if (message.type == MessageType.collaboration_response)
                      _buildCollaborationResponse(),
                    if (message.type != MessageType.text &&
                        message.type != MessageType.collaboration_request &&
                        message.type != MessageType.collaboration_response)
                      _buildMediaContent(),
                    if (message.content.isNotEmpty &&
                        message.type != MessageType.collaboration_request &&
                        message.type != MessageType.collaboration_response)
                      Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2D3748),
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _getStatusIcon(),
                            size: 16,
                            color: _getStatusColor(),
                          ),
                        ],
                      ],
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

  Widget _buildMediaContent() {
    switch (message.type) {
      case MessageType.image:
        return Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          margin: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              message.content,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                );
              },
            ),
          ),
        );
      case MessageType.video:
        return Container(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 150),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
          ),
        );
      case MessageType.audio:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              const Text('Audio Message'),
            ],
          ),
        );
      case MessageType.document:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              const Text('Document'),
            ],
          ),
        );
      case MessageType.text:
      case MessageType.collaboration_request:
      case MessageType.collaboration_response:
        return const SizedBox.shrink();
    }
  }

  IconData _getStatusIcon() {
    switch (message.status) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
    }
  }

  Color _getStatusColor() {
    switch (message.status) {
      case MessageStatus.sent:
        return Colors.grey[600]!;
      case MessageStatus.delivered:
        return Colors.grey[600]!;
      case MessageStatus.read:
        return const Color(0xFF25D366);
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildCollaborationRequest() {
    if (message.collaborationData == null) return const SizedBox.shrink();

    final data = message.collaborationData!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2196F3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, color: const Color(0xFF2196F3), size: 20),
              const SizedBox(width: 8),
              Text(
                'Collaboration Request',
                style: TextStyle(
                  color: const Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Project: ${data.projectTitle}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('Role: ${data.role.name.toUpperCase()}'),
          if (data.message != null && data.message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data.message!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
          if (data.isPending && !isCurrentUser) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCollaborationResponse != null
                        ? () => onCollaborationResponse!(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCollaborationResponse != null
                        ? () => onCollaborationResponse!(false)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53E3E),
                      side: const BorderSide(color: Color(0xFFE53E3E)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
          if (!data.isPending) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: data.isAccepted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFE53E3E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data.isAccepted ? 'ACCEPTED' : 'DECLINED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollaborationResponse() {
    if (message.collaborationData == null) return const SizedBox.shrink();

    final data = message.collaborationData!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.isAccepted
            ? const Color(0xFFE8F5E8)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: data.isAccepted
              ? const Color(0xFF4CAF50)
              : const Color(0xFFE53E3E),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.isAccepted ? Icons.check_circle : Icons.cancel,
                color: data.isAccepted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFE53E3E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Collaboration ${data.isAccepted ? 'Accepted' : 'Declined'}',
                style: TextStyle(
                  color: data.isAccepted
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53E3E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Project: ${data.projectTitle}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
