import 'package:flutter/material.dart';
import 'chat/chat_list_screen.dart';
import 'buddy/buddy_screen.dart';
import 'flow/flow_screen.dart';
import 'dock_screen.dart';
import 'settings/settings_screen.dart';
import '../config/settings/theme_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    const ChatListScreen(),
    const BuddyScreen(),
    const FlowScreen(),
    const DockScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _selectedIndex == 0 ? _buildAppBar() : null,
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              top: BorderSide(color: AppTheme.borderColor, width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppTheme.surfaceColor,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: AppTheme.textSecondaryColor,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
            elevation: 0,
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
              BottomNavigationBarItem(
                icon: Icon(Icons.developer_board_outlined),
                activeIcon: Icon(Icons.developer_board),
                label: 'Dock',
              ),
            ],
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Buddy',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: AppTheme.textPrimaryColor),
          onPressed: () {
            _showSearchDialog();
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppTheme.textPrimaryColor),
          color: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          position: PopupMenuPosition.under,
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: AppTheme.textPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'help',
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: AppTheme.textPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Help',
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (String value) {
            _handleMenuAction(value);
          },
        ),
      ],
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'settings':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        if (result == true && mounted) {
          // Theme was changed, rebuild the app
          setState(() {});
        }
        break;
      case 'help':
        _showHelpDialog();
        break;
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Search',
            style: TextStyle(color: AppTheme.textPrimaryColor),
          ),
          content: TextField(
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Search chats, flows, notes...',
              hintStyle: TextStyle(color: AppTheme.textSecondaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Implement search functionality
              },
              child: Text(
                'Search',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Help', style: TextStyle(color: AppTheme.textPrimaryColor)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to Buddy!',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered project management companion. Get help with flows, chat with AI, and manage your tasks efficiently.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }
}
