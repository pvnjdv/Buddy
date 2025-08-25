import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/buddy_service.dart';
import '../../services/databases/buddy_chat_database.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      print('🔄 Loading conversations...');
      // Force save current conversation before loading
      await BuddyChatDatabase.forceRefresh();

      final conversations = await BuddyChatDatabase.getAllConversations();
      print('📋 Loaded ${conversations.length} conversations');

      // Debug: print each conversation
      for (int i = 0; i < conversations.length && i < 3; i++) {
        final conv = conversations[i];
        print(
          '  - Conversation ${i + 1}: ${conv['title']} (${conv['messageCount']} messages)',
        );
      }

      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading conversations: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _debugConversations() async {
    print('🐛 === DEBUG CONVERSATIONS ===');
    try {
      await BuddyChatDatabase.forceRefresh();
      final conversations = await BuddyChatDatabase.getAllConversations();

      print('📊 Total conversations: ${conversations.length}');
      for (int i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        print('🗂️ Conversation $i:');
        print('   ID: ${conv['id']}');
        print('   Title: ${conv['title']}');
        print('   Messages: ${conv['messageCount']}');
        print('   Created: ${conv['created_at']}');

        final messages = conv['messages'] as List<Map<String, dynamic>>;
        if (messages.isNotEmpty) {
          final firstMessage = messages.first['message']?.toString() ?? '';
          final lastMessage = messages.last['message']?.toString() ?? '';

          print(
            '   First message: ${firstMessage.length > 50 ? firstMessage.substring(0, 50) : firstMessage}...',
          );
          print(
            '   Last message: ${lastMessage.length > 50 ? lastMessage.substring(0, 50) : lastMessage}...',
          );
        }
        print('');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug: Found ${conversations.length} conversations'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Debug error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startNewConversation() async {
    try {
      final conversationId = await BuddyChatDatabase.startNewConversation();
      await BuddyService.loadConversation(conversationId);
      Navigator.pop(context);
    } catch (e) {
      print('Error starting new conversation: $e');
    }
  }

  Future<void> _loadConversation(Map<String, dynamic> conversation) async {
    final conversationId = conversation['id']?.toString();
    if (conversationId != null) {
      // Load the conversation in BuddyService and navigate back
      await BuddyService.loadConversation(conversationId);
      Navigator.pop(context);
    }
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    final conversationId = conversation['id']?.toString();
    if (conversationId != null) {
      try {
        await BuddyChatDatabase.deleteConversation(conversationId);
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Reload conversations
        await _loadConversations();
      } catch (e) {
        print('Error deleting conversation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete conversation: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _renameConversation(Map<String, dynamic> conversation) async {
    final conversationId = conversation['id']?.toString();
    final currentTitle = conversation['title']?.toString() ?? 'Conversation';

    if (conversationId == null) return;

    final TextEditingController titleController = TextEditingController(
      text: currentTitle,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Conversation Title',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty && newTitle != currentTitle) {
                  try {
                    await BuddyChatDatabase.renameConversation(
                      conversationId,
                      newTitle,
                    );
                    Navigator.of(context).pop();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conversation renamed successfully'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }

                    // Reload conversations
                    await _loadConversations();
                  } catch (e) {
                    print('Error renaming conversation: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to rename: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
              ),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> conversation) {
    final conversationId = conversation['id']?.toString() ?? 'Unknown';
    final title =
        conversation['title']?.toString() ?? 'Conversation $conversationId';
    final messageCount = (conversation['messages'] as List?)?.length ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Delete Conversation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this conversation?'),
              const SizedBox(height: 12),
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$messageCount messages',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                await _deleteConversation(conversation);

                // Hide loading indicator
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (messageDate == today) {
        final hour = dateTime.hour > 12
            ? dateTime.hour - 12
            : (dateTime.hour == 0 ? 12 : dateTime.hour);
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return 'Today, $hour:$minute $period';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else if (now.difference(messageDate).inDays < 7) {
        const days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        return days[dateTime.weekday - 1];
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _exportConversation(Map<String, dynamic> conversation) async {
    try {
      final conversationId = conversation['id']?.toString() ?? 'unknown';
      final title = conversation['title']?.toString() ?? 'Conversation';
      final messages = List<Map<String, dynamic>>.from(
        conversation['messages'] ?? [],
      );

      // Create export data
      final exportData = {
        'conversation_id': conversationId,
        'title': title,
        'created_at': conversation['created_at'],
        'message_count': messages.length,
        'messages': messages,
        'exported_at': DateTime.now().toIso8601String(),
      };

      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation "$title" exported successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // You could implement file viewing/sharing here
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Export Data'),
                    content: SingleChildScrollView(
                      child: Text(
                        jsonString,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
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
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error exporting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAllConversations() async {
    try {
      if (_conversations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No conversations to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final exportData = {
        'export_info': {
          'exported_at': DateTime.now().toIso8601String(),
          'total_conversations': _conversations.length,
          'app_version': 'BuddyAI v1.0',
        },
        'conversations': _conversations,
      };

      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cloud_download, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully exported ${_conversations.length} conversations.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      jsonString.length > 500
                          ? '${jsonString.substring(0, 500)}...\n\n[Data truncated for display]'
                          : jsonString,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
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
    } catch (e) {
      print('Error exporting all conversations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAIContextInfo() {
    final totalMessages = _conversations.fold<int>(
      0,
      (sum, conv) => sum + (conv['messages'] as List).length,
    );

    final activeConversationId = BuddyChatDatabase.activeConversationId;
    final activeConversation = _conversations
        .where((conv) => conv['id'] == activeConversationId)
        .firstOrNull;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFF667eea)),
              SizedBox(width: 12),
              Text('AI Context Information'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withOpacity(0.1),
                        const Color(0xFF764ba2).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🧠 How BuddyAI Remembers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'BuddyAI maintains context by storing each conversation separately. When you switch conversations, the AI gets the full history of that specific conversation.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5568),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),

                const SizedBox(height: 12),

                _buildInfoRow(
                  'Total Conversations',
                  '${_conversations.length}',
                  Icons.forum,
                  Colors.blue,
                ),

                _buildInfoRow(
                  'Total Messages Stored',
                  '$totalMessages',
                  Icons.chat,
                  Colors.green,
                ),

                _buildInfoRow(
                  'Active Conversation',
                  activeConversation != null
                      ? activeConversation['title']?.toString() ?? 'Unknown'
                      : 'None',
                  Icons.star,
                  Colors.orange,
                ),

                if (activeConversation != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Active Conv. Messages',
                    '${(activeConversation['messages'] as List).length}',
                    Icons.message,
                    const Color(0xFF667eea),
                  ),
                ],

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Pro Tip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'To give BuddyAI context from multiple conversations, you can reference previous conversations in your messages. For example: "Remember when we discussed X in our conversation about Y?"',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4A5568),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it!',
                style: TextStyle(color: Color(0xFF667eea)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationStats() {
    final totalMessages = _conversations.fold<int>(
      0,
      (sum, conv) => sum + (conv['messages'] as List).length,
    );

    final totalUserMessages = _conversations.fold<int>(0, (sum, conv) {
      final messages = conv['messages'] as List<Map<String, dynamic>>;
      final userMsgCount = messages.where((m) => m['isUser'] == true).length;

      // Debug logging with safe substring
      print(
        '🔍 Conversation ${conv['title']}: ${messages.length} total, $userMsgCount user messages',
      );
      for (int i = 0; i < messages.length && i < 3; i++) {
        final msg = messages[i];
        final content = msg['message']?.toString() ?? '';
        final safeContent = content.length > 30
            ? content.substring(0, 30)
            : content;
        print(
          '  - Message $i: isUser=${msg['isUser']}, content=$safeContent...',
        );
      }

      return sum + userMsgCount;
    });

    final totalAiMessages = totalMessages - totalUserMessages;

    print(
      '📊 Stats: Total=$totalMessages, User=$totalUserMessages, AI=$totalAiMessages',
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.1),
            const Color(0xFF764ba2).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics,
                  size: 20,
                  color: Color(0xFF667eea),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Conversation Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Conversations',
                  '${_conversations.length}',
                  Icons.forum,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Your Messages',
                  '$totalUserMessages',
                  Icons.person,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'AI Responses',
                  '$totalAiMessages',
                  Icons.smart_toy,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Each conversation maintains its own context. BuddyAI remembers everything within each conversation separately.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chat History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  'Your conversations with BuddyAI',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 80,
        leading: Container(
          margin: const EdgeInsets.all(8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_comment,
                        size: 18,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    onPressed: _startNewConversation,
                    tooltip: 'New Conversation',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                    onPressed: () async {
                      print('🔄 Manual refresh triggered');
                      await _loadConversations();
                    },
                    tooltip: 'Refresh',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'debug':
                          await _debugConversations();
                          break;
                        case 'export_all':
                          await _exportAllConversations();
                          break;
                        case 'ai_context':
                          _showAIContextInfo();
                          break;
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Colors.orange,
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'ai_context',
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 18,
                              color: Color(0xFF667eea),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'AI Context Info',
                              style: TextStyle(color: Color(0xFF667eea)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_all',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_download,
                              size: 18,
                              color: Colors.green,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Export All',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'debug',
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report,
                              size: 18,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Debug Info',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.shade200,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading conversations...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _conversations.isEmpty
          ? _buildEmptyState()
          : _buildConversationsList(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _startNewConversation,
          backgroundColor: const Color(0xFF667eea),
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: const Text(
            'New Chat',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.1),
                  const Color(0xFF764ba2).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 32),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 24,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start your first conversation with BuddyAI\nand it will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _startNewConversation,
              icon: const Icon(Icons.add_comment),
              label: const Text(
                'Start New Conversation',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 20,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Context Memory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Each conversation maintains its own context. BuddyAI will remember everything you discuss within each conversation.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return CustomScrollView(
      slivers: [
        // Stats overview
        SliverToBoxAdapter(child: _buildConversationStats()),

        // Conversations list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return _buildConversationCard(_conversations[index]);
            }, childCount: _conversations.length),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final messages = List<Map<String, dynamic>>.from(
      conversation['messages'] ?? [],
    );
    final lastMessage = messages.isNotEmpty
        ? messages.last['message'] ?? 'No messages yet'
        : 'No messages yet';

    final messageCount = messages.length;
    final createdAt =
        conversation['created_at'] ?? DateTime.now().toIso8601String();
    final conversationId = conversation['id']?.toString() ?? 'Unknown';
    final title =
        conversation['title']?.toString() ?? 'Conversation $conversationId';

    // Get conversation stats
    final userMessages = messages.where((m) => m['isUser'] == true).length;
    final aiMessages = messages.where((m) => m['isUser'] == false).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _loadConversation(conversation),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: messageCount > 10
                                  ? Colors.green.shade100
                                  : messageCount > 5
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$messageCount messages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: messageCount > 10
                                    ? Colors.green.shade700
                                    : messageCount > 5
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            _renameConversation(conversation);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(conversation);
                            break;
                          case 'export':
                            _exportConversation(conversation);
                            break;
                          case 'details':
                            _showConversationDetails(conversation);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Color(0xFF667eea),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'View Details',
                                style: TextStyle(color: Color(0xFF667eea)),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                size: 18,
                                color: Color(0xFF667eea),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Rename',
                                style: TextStyle(color: Color(0xFF667eea)),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(
                                Icons.download,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Export',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Last Message Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    // User Messages Count
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$userMessages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // AI Messages Count
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.smart_toy,
                              size: 16,
                              color: Colors.purple.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$aiMessages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Date
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatTimestamp(createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConversationDetails(Map<String, dynamic> conversation) {
    final messages = List<Map<String, dynamic>>.from(
      conversation['messages'] ?? [],
    );
    final userMessages = messages.where((m) => m['isUser'] == true).length;
    final aiMessages = messages.where((m) => m['isUser'] == false).length;
    final title = conversation['title']?.toString() ?? 'Conversation';
    final createdAt =
        conversation['created_at'] ?? DateTime.now().toIso8601String();
    final conversationId = conversation['id']?.toString() ?? 'Unknown';

    // Calculate conversation duration
    String duration = 'Unknown';
    if (messages.length >= 2) {
      try {
        final firstMsg = DateTime.parse(
          messages.first['timestamp'] ?? createdAt,
        );
        final lastMsg = DateTime.parse(messages.last['timestamp'] ?? createdAt);
        final diff = lastMsg.difference(firstMsg);

        if (diff.inDays > 0) {
          duration = '${diff.inDays} days';
        } else if (diff.inHours > 0) {
          duration = '${diff.inHours} hours';
        } else if (diff.inMinutes > 0) {
          duration = '${diff.inMinutes} minutes';
        } else {
          duration = '${diff.inSeconds} seconds';
        }
      } catch (e) {
        duration = 'Unknown';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Conversation Details',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Title', title),
                _buildDetailRow('ID', conversationId),
                _buildDetailRow('Created', _formatTimestamp(createdAt)),
                _buildDetailRow('Duration', duration),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Message Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.blue.shade600,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$userMessages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              'Your Messages',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.smart_toy,
                              color: Colors.purple.shade600,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$aiMessages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            Text(
                              'AI Responses',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (messages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Message Preview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      messages.first['message'] ?? 'No content',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF667eea)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadConversation(conversation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open Chat'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
