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

  Future<void> _logout() async {
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

  @override

  Future<void> _suspendRefreshToken() async {
    final shouldSuspend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Session'),
        content: const Text(
          'This will suspend your refresh token. You\'ll need to login again next time you open the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Suspend',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (shouldSuspend == true) {
      await AuthService.suspendRefreshToken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session suspended. You\'ll need to login next time.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  

  Future<void> _createGroup() async {
    // Placeholder for create group functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Group feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Chat screen specific methods
  void _chatSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat search feature coming soon!')),
    );
  }

  void _newChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New chat feature coming soon!')),
    );
  }

  // Buddy screen specific methods
  void _buddyClear() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clear chat feature coming soon!')),
    );
  }

  void _switchAIMode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Switch AI mode feature coming soon!')),
    );
  }

  void _chatHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat history feature coming soon!')),
    );
  }

  // Flow screen specific methods
  void _notesAlarms() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes & Alarms feature coming soon!')),
    );
  }

  void _refreshFlows() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refresh flows feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Chats', 'Buddy AI', 'Flow'];

    return PopScope(
      canPop: false, // Prevent accidental back button navigation from home
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            titles[_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false, // Remove back arrow
          actions: [
            // More options menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
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
}
