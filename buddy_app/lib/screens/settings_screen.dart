import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Appearance'),
            const SizedBox(height: 12),
            _buildThemeCard(),
            const SizedBox(height: 16),
            _buildColorCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Notifications'),
            const SizedBox(height: 12),
            _buildNotificationCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Account'),
            const SizedBox(height: 12),
            _buildAccountCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('App'),
            const SizedBox(height: 12),
            _buildAppCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Session'),
            const SizedBox(height: 12),
            _buildSessionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive notifications for new messages',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () =>
                setState(() => _notificationsEnabled = !_notificationsEnabled),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            trailing: Switch(
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.vibration,
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            trailing: Switch(
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () => setState(() => _vibrationEnabled = !_vibrationEnabled),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard() {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.refresh,
            title: 'Refresh Token',
            subtitle: 'Update your authentication token',
            onTap: _refreshAccessToken,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.pause_circle_outline,
            title: 'Suspend Session',
            subtitle: 'Temporarily suspend current session',
            onTap: _suspendRefreshToken,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: _logout,
            titleColor: AppTheme.errorColor,
            iconColor: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Theme Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildThemeOption(
                    'Light',
                    Icons.light_mode,
                    !AppTheme.isDarkMode,
                    () => _changeTheme(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeOption(
                    'Dark',
                    Icons.dark_mode,
                    AppTheme.isDarkMode,
                    () => _changeTheme(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.color_lens_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Color Scheme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Primary Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTheme.primaryColors.map((color) {
                final isSelected = color == AppTheme.primaryColor;
                return GestureDetector(
                  onTap: () => _changePrimaryColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.textPrimaryColor,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            Text(
              'Accent Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTheme.accentColors.map((color) {
                final isSelected = color == AppTheme.accentColor;
                return GestureDetector(
                  onTap: () => _changeAccentColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.textPrimaryColor,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Manage your profile information',
            onTap: _showProfile,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Manage your privacy settings',
            onTap: _showPrivacySettings,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Data Management',
            subtitle: 'Manage your app data and storage',
            onTap: _showDataManagement,
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard() {
    return Card(
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {
              _showAboutDialog();
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              // Navigate to help screen
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.star_outline,
            title: 'Rate App',
            subtitle: 'Rate us on the app store',
            onTap: () {
              // Open app store for rating
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: AppTheme.borderColor, indent: 56);
  }

  void _refreshAccessToken() async {
    try {
      final success = await AuthService.refreshAccessToken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Token refreshed successfully!'
                  : 'Failed to refresh token',
            ),
            backgroundColor: success
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _suspendRefreshToken() async {
    try {
      await AuthService.suspendRefreshToken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Session suspended. You will be logged out in 30 minutes unless you refresh.',
            ),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: AppTheme.textPrimaryColor)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout completely?',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await AuthService.logout();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _changeTheme(bool isDark) async {
    await AppTheme.setTheme(isDark);
    setState(() {});
    // Trigger app-wide theme change
    if (mounted) {
      // Find the root BuddyApp and trigger rebuild
      final appState = context.findAncestorStateOfType<State<StatefulWidget>>();
      if (appState != null) {
        appState.setState(() {});
      }
      Navigator.of(context).pop(true); // Return true to indicate theme changed
    }
  }

  void _changePrimaryColor(Color color) async {
    await AppTheme.setPrimaryColor(color);
    setState(() {});
    // Trigger app-wide theme change
    if (mounted) {
      // Find the root BuddyApp and trigger rebuild
      final appState = context.findAncestorStateOfType<State<StatefulWidget>>();
      if (appState != null) {
        appState.setState(() {});
      }
      Navigator.of(context).pop(true); // Return true to indicate theme changed
    }
  }

  void _changeAccentColor(Color color) async {
    await AppTheme.setAccentColor(color);
    setState(() {});
    // Trigger app-wide theme change
    if (mounted) {
      // Find the root BuddyApp and trigger rebuild
      final appState = context.findAncestorStateOfType<State<StatefulWidget>>();
      if (appState != null) {
        appState.setState(() {});
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Buddy',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Buddy App. All rights reserved.',
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Your AI-powered project management companion.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('Profile', style: TextStyle(color: AppTheme.textPrimaryColor)),
          ],
        ),
        content: Text(
          'Profile management feature is coming soon! You\'ll be able to update your name, avatar, and other personal information.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security_outlined, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Privacy & Security',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy settings will include:',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Two-factor authentication\n• Data encryption settings\n• Account activity monitoring\n• Privacy preferences',
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
      ),
    );
  }

  void _showDataManagement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.storage_outlined, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Data Management',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data management features:',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Clear chat history\n• Export conversations\n• Download your data\n• Delete account data',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
