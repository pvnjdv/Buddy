// lib/screens/college/college_home_screen.dart
import 'package:flutter/material.dart';
import '../../config/settings/theme_config.dart';
import '../../services/app_mode_service.dart';
import '../buddy/buddy_screen.dart';
import '../flow/flow_screen.dart';
import '../dock/dock_screen.dart';
import 'dashboard/college_dashboard_screen.dart';

class CollegeHomeScreen extends StatefulWidget {
  const CollegeHomeScreen({super.key});

  @override
  State<CollegeHomeScreen> createState() => _CollegeHomeScreenState();
}

class _CollegeHomeScreenState extends State<CollegeHomeScreen> {
  int _selectedIndex = 0;
  final AppModeService _appModeService = AppModeService();

  List<Widget> get _screens {
    return [
      const CollegeDashboardScreen(), // Dashboard
      const BuddyScreen(), // AI
      const FlowScreen(), // Flow (adapted for college)
      const DockScreen(), // Dock (adapted for college)
    ];
  }

  List<BottomNavigationBarItem> get _navigationItems {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy_outlined),
        activeIcon: Icon(Icons.smart_toy),
        label: 'AI',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.lightbulb_outline),
        activeIcon: Icon(Icons.lightbulb),
        label: 'Flow',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.developer_board_outlined),
        activeIcon: Icon(Icons.developer_board),
        label: 'Dock',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _selectedIndex == 0 ? _buildCollegeAppBar() : null,
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
            items: _navigationItems,
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCollegeAppBar() {
    final institution = _appModeService.currentInstitution;
    final role = _appModeService.getRoleDisplayName();

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
            child: const Icon(Icons.school, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  institution?.name ?? 'College Mode',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      actions: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () {
            _showNotifications();
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
              value: 'profile',
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppTheme.textPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Profile',
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'switch_mode',
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: AppTheme.textPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Switch to Normal Mode',
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
            ),
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
          ],
          onSelected: (String value) async {
            switch (value) {
              case 'profile':
                _showProfile();
                break;
              case 'switch_mode':
                await _switchToNormalMode();
                break;
              case 'settings':
                _showSettings();
                break;
            }
          },
        ),
      ],
    );
  }

  void _showNotifications() {
    // TODO: Implement notifications
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notifications coming soon!')));
  }

  void _showProfile() {
    // TODO: Implement profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile screen coming soon!')),
    );
  }

  Future<void> _switchToNormalMode() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to Normal Mode'),
        content: const Text(
          'Are you sure you want to switch back to normal mode? You can always switch back to college mode later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _appModeService.switchToNormalMode();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  void _showSettings() {
    // TODO: Implement college settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('College settings coming soon!')),
    );
  }
}
