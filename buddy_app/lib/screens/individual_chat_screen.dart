import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';
import '../services/buddy_service.dart';

class IndividualChatScreen extends StatefulWidget {
  final String contactId;
  final String? contactName;
  final String currentUserId;

  const IndividualChatScreen({
    super.key,
    required this.contactId,
    this.contactName,
    required this.currentUserId,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  List<types.Message> _messages = [];
  late final types.User _user;
  late final types.User _contact;
  late final types.User _buddyUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _user = types.User(id: widget.currentUserId);
    _contact = types.User(id: widget.contactId);
    _buddyUser = types.User(id: 'buddy-ai', firstName: 'Buddy', lastName: 'AI');
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    try {
      // Load messages between current user and this contact
      final backendMessages = await ChatService.getChats();

      // Filter messages for this specific chat
      final filteredMessages = backendMessages.where((msg) {
        final senderId = msg['sender_id']?.toString();
        final receiverId = msg['receiver_id']?.toString();
        return (senderId == widget.currentUserId &&
                receiverId == widget.contactId) ||
            (senderId == widget.contactId &&
                receiverId == widget.currentUserId);
      }).toList();

      // Convert to flutter_chat_types.Message
      final messages = filteredMessages.map<types.Message>((msg) {
        final isFromCurrentUser =
            msg['sender_id']?.toString() == widget.currentUserId;
        return types.TextMessage(
          author: isFromCurrentUser ? _user : _contact,
          createdAt: msg['timestamp'] != null
              ? DateTime.tryParse(msg['timestamp'])?.millisecondsSinceEpoch ??
                    DateTime.now().millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          id: msg['id']?.toString() ?? const Uuid().v4(),
          text: msg['content']?.toString() ?? '',
        );
      }).toList();

      // Sort messages by createdAt descending (latest first)
      messages.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final messageText = message.text.trim();

    // Check if message starts with @Buddy
    if (messageText.toLowerCase().startsWith('@buddy ')) {
      await _handleBuddyMention(messageText);
      return;
    }

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: messageText,
    );

    setState(() {
      _messages.insert(0, textMessage);
    });

    try {
      await ChatService.sendMessage(widget.contactId, messageText);
      // Message is already added optimistically, no need to reload
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
      // Remove the optimistic message if sending failed
      setState(() {
        _messages.removeWhere((msg) => msg.id == textMessage.id);
      });
    }
  }

  Future<void> _handleBuddyMention(String messageText) async {
    // Extract the prompt after @Buddy
    final prompt = messageText.substring(7).trim(); // Remove "@buddy "

    // Add user's @Buddy message
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: messageText,
    );

    setState(() {
      _messages.insert(0, userMessage);
    });

    // Show typing indicator for Buddy
    final typingMessage = types.TextMessage(
      author: _buddyUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: '🤖 Buddy is thinking...',
    );

    setState(() {
      _messages.insert(0, typingMessage);
    });

    try {
      // Check if this is a project request
      final isProjectRequest = _isProjectRequest(prompt);

      if (isProjectRequest) {
        await _handleProjectRequest(prompt, typingMessage);
      } else {
        // Regular AI chat
        final buddyResponse = await BuddyService.askBuddy(prompt);

        // Remove typing indicator
        setState(() {
          _messages.removeWhere((msg) => msg.id == typingMessage.id);
        });

        // Add Buddy's response
        final buddyMessage = types.TextMessage(
          author: _buddyUser,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: '🤖 Buddy: $buddyResponse',
        );

        setState(() {
          _messages.insert(0, buddyMessage);
        });
      }
    } catch (e) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      // Add error message
      final errorMessage = types.TextMessage(
        author: _buddyUser,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: '🤖 Buddy: Sorry, I encountered an error: $e',
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  bool _isProjectRequest(String prompt) {
    final projectKeywords = [
      'build project',
      'create project',
      'help me build',
      'project timeline',
      'make a project',
      'develop',
      'timeline for',
      'project plan',
    ];

    final lowerPrompt = prompt.toLowerCase();
    return projectKeywords.any((keyword) => lowerPrompt.contains(keyword));
  }

  Future<void> _handleProjectRequest(
    String prompt,
    types.TextMessage typingMessage,
  ) async {
    try {
      // Generate project timeline
      final timelineData = await BuddyService.generateProjectTimeline(prompt);

      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      // Create timeline response message
      final timelineText = _formatTimelineResponse(timelineData);

      final timelineMessage = types.TextMessage(
        author: _buddyUser,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: timelineText,
      );

      setState(() {
        _messages.insert(0, timelineMessage);
      });

      // Show option to create task
      await _showCreateTaskDialog(timelineData);
    } catch (e) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg.id == typingMessage.id);
      });

      // Fallback to regular AI response
      final buddyResponse = await BuddyService.askBuddy(prompt);

      final buddyMessage = types.TextMessage(
        author: _buddyUser,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: '🤖 Buddy: $buddyResponse',
      );

      setState(() {
        _messages.insert(0, buddyMessage);
      });
    }
  }

  String _formatTimelineResponse(Map<String, dynamic> timelineData) {
    final buffer = StringBuffer();
    buffer.writeln('🤖 Buddy: I\'ve created a project timeline for you!');
    buffer.writeln('');
    buffer.writeln('📊 **Project Overview:**');
    buffer.writeln(
      '⏱️ Estimated Duration: ${timelineData['estimated_duration']}',
    );
    buffer.writeln('🔥 Difficulty: ${timelineData['difficulty']}');
    buffer.writeln('');
    buffer.writeln('📋 **Tasks:**');

    final tasks = timelineData['tasks'] as List? ?? [];
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      buffer.writeln('${i + 1}. ${task['title']} (${task['duration']})');
      buffer.writeln('   ${task['description']}');
    }

    buffer.writeln('');
    buffer.writeln(
      '💡 Would you like me to create this as a task in your Tasker?',
    );

    return buffer.toString();
  }

  Future<void> _showCreateTaskDialog(Map<String, dynamic> timelineData) async {
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Task'),
        content: const Text(
          'Would you like to add this project to your Tasker with progress tracking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Create Task'),
          ),
        ],
      ),
    );

    if (shouldCreate == true) {
      await _createTaskFromTimeline(timelineData);
    }
  }

  Future<void> _createTaskFromTimeline(
    Map<String, dynamic> timelineData,
  ) async {
    try {
      final success = await BuddyService.createTaskFromTimeline(
        timelineData,
        widget.currentUserId,
      );

      if (success) {
        // Add success message
        final successMessage = types.TextMessage(
          author: _buddyUser,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text:
              '🤖 Buddy: ✅ Great! I\'ve created the task in your Tasker. You can find it in the Tasker tab with progress tracking and checkpoints. I\'ll help you at each checkpoint!',
        );

        setState(() {
          _messages.insert(0, successMessage);
        });

        // Show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task created successfully in Tasker!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to create task');
      }
    } catch (e) {
      // Add error message
      final errorMessage = types.TextMessage(
        author: _buddyUser,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text:
            '🤖 Buddy: ❌ Sorry, I couldn\'t create the task. Please try again later.',
      );

      setState(() {
        _messages.insert(0, errorMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(
                (widget.contactName ?? widget.contactId)
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName ?? widget.contactId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Tap @Buddy + message for AI help',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              showUserAvatars: true,
              showUserNames: false, // Don't show names in 1-on-1 chat
            ),
    );
  }
}
