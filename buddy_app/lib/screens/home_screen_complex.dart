import 'package:flutter/material.dart';
import 'chat/chat_list_screen.dart';
import 'buddy/buddy_screen.dart';
import 'flow/flow_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _screens = [
    const ChatListScreen(),
    const BuddyScreen(),
    const FlowScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getScreenTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false, // Remove back arrow
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          actions: [
            // More options menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refreshAccessToken();
                    break;
                  case 'create_group':
                    _createGroup();
                    break;
                  case 'suspend':
                    _suspendRefreshToken();
                    break;
                  case 'logout':
                    _logout();
                    break;
                  case 'chat_search':
                    _chatSearch();
                    break;
                  case 'new_chat':
                    _newChat();
                    break;
                  case 'buddy_clear':
                    _buddyClear();
                    break;
                  case 'switch_ai_mode':
                    _switchAIMode();
                    break;
                  case 'chat_history':
                    _chatHistory();
                    break;
                  case 'notes_alarms':
                    _notesAlarms();
                    break;
                  case 'refresh_flows':
                    _refreshFlows();
                    break;
                }
              },
              itemBuilder: (context) => [
                // Chat screen specific options
                if (_selectedIndex == 0) ...[
                  const PopupMenuItem(
                    value: 'chat_search',
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Search Chats'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'new_chat',
                    child: Row(
                      children: [
                        Icon(Icons.chat, color: Colors.green),
                        SizedBox(width: 8),
                        Text('New Chat'),
                      ],
                    ),
                  ),
                ],
                // Buddy screen specific options
                if (_selectedIndex == 1) ...[
                  const PopupMenuItem(
                    value: 'chat_history',
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Chat History'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'switch_ai_mode',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Switch AI Mode'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'buddy_clear',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                ],
                // Flow screen specific options
                if (_selectedIndex == 2) ...[
                  const PopupMenuItem(
                    value: 'notes_alarms',
                    child: Row(
                      children: [
                        Icon(Icons.note_add, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Notes & Alarms'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh_flows',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Refresh Flows'),
                      ],
                    ),
                  ),
                ],
                // Global options
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Refresh Token'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'create_group',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Create Group'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.pause_circle, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Suspend Session'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF25D366),
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'Buddy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline),
              activeIcon: Icon(Icons.lightbulb),
              label: 'Flow',
            ),
          ],
          onTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }

  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Chats';
      case 1:
        return 'Buddy AI';
      case 2:
        return 'Flows';
      default:
        return 'Buddy';
    }
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout completely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _refreshAccessToken() async {
    final success = await AuthService.refreshAccessToken();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token refreshed successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to refresh token')));
    }
  }

  Future<void> _createGroup() async {
    try {
      // Navigate to create group screen
      final result = await Navigator.pushNamed(context, '/create_group');
      if (result == true) {
        // Group created successfully
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
    }
  }

  Future<void> _suspendRefreshToken() async {
    await AuthService.suspendRefreshToken();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session suspended. You will be logged out in 30 minutes unless you refresh.',
        ),
      ),
    );
  }

  void _chatSearch() {
    // Chat search functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat search functionality coming soon!')),
    );
  }

  void _newChat() {
    // New chat functionality
    Navigator.pushNamed(context, '/new_chat');
  }

  void _buddyClear() {
    // Clear buddy chat functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Buddy chat cleared!')));
  }

  void _switchAIMode() {
    // Switch AI mode functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI mode switched!')));
  }

  void _chatHistory() {
    // Chat history functionality
    Navigator.pushNamed(context, '/chat_history');
  }

  void _notesAlarms() {
    // Notes and alarms functionality
    Navigator.pushNamed(context, '/notes_alarms');
  }

  void _refreshFlows() {
    // Refresh flows functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Flows refreshed!')));
  }
}
