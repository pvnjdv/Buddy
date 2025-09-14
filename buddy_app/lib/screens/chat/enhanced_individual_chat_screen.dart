import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/ai/chat_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';

class EnhancedIndividualChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String currentUserId;

  const EnhancedIndividualChatScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.currentUserId,
  });

  @override
  State<EnhancedIndividualChatScreen> createState() =>
      _EnhancedIndividualChatScreenState();
}

class _EnhancedIndividualChatScreenState
    extends State<EnhancedIndividualChatScreen> {
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  Stream<dynamic>? _socketSub;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _loadMessages();
  }

  Future<void> _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    if (token != null) {
      EnhancedChatService.connectSocket(token);
      _socketSub = EnhancedChatService.socketStream;
      _socketSub?.listen((event) {
        try {
          final data = event is String ? jsonDecode(event) : event;
          if (data is Map && data['type'] == 'message') {
            final msg = data['data'] as Map<String, dynamic>;
            if (msg['sender_id'].toString() == widget.contactId ||
                msg['receiver_id'].toString() == widget.contactId) {
              setState(() {
                _messages.add(
                  ChatMessage.fromJson({
                    ...msg,
                    'type': 'text',
                    'status': 'delivered',
                  }),
                );
              });
              _scrollToBottom();
            }
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    // Do not disconnect globally here; let app lifecycle manage WS
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final messages = await EnhancedChatService.getMessages(widget.contactId);
      setState(() {
        _messages = messages.reversed
            .toList(); // Reverse for correct chronological order
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final optimistic = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      receiverId: widget.contactId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent, // Show sending status
    );

    setState(() {
      _messages.add(optimistic);
    });

    _scrollToBottom();

    // Send via REST POST (which also handles WebSocket broadcasting on backend)
    try {
      await EnhancedChatService.sendMessage(
        widget.contactId,
        content,
        MessageType.text,
      );
    } catch (e) {
      // Remove optimistic message on failure
      setState(() {
        _messages.removeWhere((msg) => msg.id == optimistic.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
      }
    }
  }

  Future<void> _sendMedia(MessageType type, String filePath) async {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      receiverId: widget.contactId,
      content: type == MessageType.image ? 'Image' : 'Media',
      type: type,
      timestamp: DateTime.now(),
      mediaUrl: filePath,
    );

    setState(() {
      _messages.add(message);
    });

    _scrollToBottom();

    // TODO: Upload media to server and send message
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Media upload coming soon!')));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onMessageLongPress(ChatMessage message) {
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
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Copy to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            if (message.senderId == widget.currentUserId)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Info'),
              onTap: () {
                Navigator.pop(context);
                _showMessageInfo(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.remove(message);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMessageInfo(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent: ${_formatDateTime(message.timestamp)}'),
            Text('Status: ${message.status.name}'),
            if (message.mediaUrl != null) Text('Media: ${message.mediaUrl}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleCollaborationResponse(
    ChatMessage message,
    bool accept,
  ) async {
    if (message.collaborationData == null) return;

    try {
      final success = await ChatService.respondToCollaborationRequest(
        messageId: message.id,
        response: accept ? 'accepted' : 'rejected',
      );

      if (success) {
        // Update the message in our local list
        setState(() {
          final index = _messages.indexOf(message);
          if (index != -1) {
            // Create a new message with updated collaboration data
            final updatedCollabData = CollaborationData(
              projectId: message.collaborationData!.projectId,
              projectTitle: message.collaborationData!.projectTitle,
              invitationId: message.collaborationData!.invitationId,
              role: message.collaborationData!.role,
              message: message.collaborationData!.message,
              expiresAt: message.collaborationData!.expiresAt,
              response: accept ? 'accepted' : 'rejected',
            );

            final updatedMessage = ChatMessage(
              id: message.id,
              senderId: message.senderId,
              receiverId: message.receiverId,
              content: message.content,
              timestamp: message.timestamp,
              type: MessageType.collaboration_request,
              status: message.status,
              collaborationData: updatedCollabData,
            );

            _messages[index] = updatedMessage;
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Collaboration request accepted! You can now work together.'
                  : 'Collaboration request declined.',
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      } else {
        throw Exception('Failed to respond to collaboration request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B263B), Color(0xFF1B263B), Color(0xFF2D3748)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Custom App Bar
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A202C).withOpacity(0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF4A5568).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color.fromARGB(255, 247, 245, 245),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // Profile section (clickable)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showUserProfile,
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  widget.contactName.isNotEmpty
                                      ? widget.contactName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
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
                                    widget.contactName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color.fromARGB(255, 246, 245, 245),
                                    ),
                                  ),
                                  if (_isTyping)
                                    const Text(
                                      'typing...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF667EEA),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'online',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Action buttons
                    IconButton(
                      icon: const Icon(Icons.videocam, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Video call coming soon!'),
                            backgroundColor: Color(0xFF667EEA),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Voice call coming soon!'),
                            backgroundColor: Color(0xFF667EEA),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: const Color(0xFF1A202C),
                      onSelected: (value) {
                        switch (value) {
                          case 'view_contact':
                            _showUserProfile();
                            break;
                          case 'media':
                            _showMediaGallery();
                            break;
                          case 'search':
                            _showSearchInChat();
                            break;
                          case 'mute':
                            _toggleMute();
                            break;
                          case 'wallpaper':
                            _changeWallpaper();
                            break;
                          case 'clear_chat':
                            _clearChat();
                            break;
                          case 'block':
                            _blockUser();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view_contact',
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'View contact',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'media',
                          child: Row(
                            children: [
                              Icon(Icons.photo_library, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Media, links, and docs',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'search',
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Search',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'mute',
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_off,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Mute notifications',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'wallpaper',
                          child: Row(
                            children: [
                              Icon(Icons.wallpaper, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Wallpaper',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'clear_chat',
                          child: Row(
                            children: [
                              Icon(Icons.clear_all, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Clear chat',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Block',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Messages section
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A202C).withOpacity(0.1),
                  // Removed background image asset to avoid missing asset errors
                  // image: DecorationImage(
                  //   image: AssetImage('assets/images/chat_bg.png'),
                  //   fit: BoxFit.cover,
                  //   opacity: 0.1,
                  // ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF25D366),
                              ),
                            )
                          : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Send a message to start the conversation',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isCurrentUser =
                                    message.senderId == widget.currentUserId;
                                return MessageBubble(
                                  message: message,
                                  isCurrentUser: isCurrentUser,
                                  onLongPress: () =>
                                      _onMessageLongPress(message),
                                  onCollaborationResponse: (accept) =>
                                      _handleCollaborationResponse(
                                        message,
                                        accept,
                                      ),
                                );
                              },
                            ),
                    ),
                    ChatInput(
                      onSendMessage: _sendMessage,
                      onSendMedia: _sendMedia,
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

  void _showUserProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A202C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.transparent,
                child: Text(
                  widget.contactName.isNotEmpty
                      ? widget.contactName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.contactName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last seen recently',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfileAction(Icons.call, 'Call', () {}),
                _buildProfileAction(Icons.videocam, 'Video', () {}),
                _buildProfileAction(Icons.info, 'Info', () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3748),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  void _showMediaGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media gallery coming soon!'),
        backgroundColor: Color(0xFF667EEA),
      ),
    );
  }

  void _showSearchInChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search in chat coming soon!'),
        backgroundColor: Color(0xFF667EEA),
      ),
    );
  }

  void _toggleMute() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mute notifications toggled!'),
        backgroundColor: Color(0xFF667EEA),
      ),
    );
  }

  void _changeWallpaper() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallpaper options coming soon!'),
        backgroundColor: Color(0xFF667EEA),
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A202C),
        title: const Text(
          'Block Contact',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Block ${widget.contactName}? Blocked contacts will no longer be able to call you or send you messages.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact blocked!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A202C),
        title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to clear all messages? This cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await EnhancedChatService.clearChat(
                widget.contactId,
              );

              if (success) {
                setState(() {
                  _messages.clear();
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cleared successfully'),
                      backgroundColor: Color(0xFF667EEA),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to clear chat'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
