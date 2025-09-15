import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/user_profile_screen.dart';
import 'appearance_settings_screen.dart';
import '../contacts_screen.dart';
import '../ai_settings_screen.dart';
import '../../config/settings/theme_config.dart';
import '../../config/settings/settings_manager.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoSyncEnabled = true;
  bool _isDarkMode = true;
  int _syncInterval = 5;
  String _performanceMode = 'balanced';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await SettingsManager.getNotificationsEnabled();
    final sound = await SettingsManager.getSoundEnabled();
    final autoSync = await SettingsManager.getAutoSyncEnabled();
    final darkMode = await SettingsManager.getDarkMode();
    final syncInterval = await SettingsManager.getSyncInterval();
    final performance = await SettingsManager.getPerformanceMode();

    setState(() {
      _notificationsEnabled = notifications;
      _soundEnabled = sound;
      _autoSyncEnabled = autoSync;
      _isDarkMode = darkMode;
      _syncInterval = syncInterval;
      _performanceMode = performance;
    });
  }

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
            _buildSectionHeader('Account'),
            const SizedBox(height: 12),
            _buildAccountCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Notifications'),
            const SizedBox(height: 12),
            _buildNotificationCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Performance & Sync'),
            const SizedBox(height: 12),
            _buildPerformanceCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('Appearance'),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme mode and colors',
                onTap: _openAppearanceSettings,
              ),
            ),
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
              onChanged: (value) async {
                await SettingsManager.setNotificationsEnabled(value);
                setState(() => _notificationsEnabled = value);
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () async {
              final newValue = !_notificationsEnabled;
              await SettingsManager.setNotificationsEnabled(newValue);
              setState(() => _notificationsEnabled = newValue);
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            trailing: Switch(
              value: _soundEnabled,
              onChanged: (value) async {
                await SettingsManager.setSoundEnabled(value);
                setState(() => _soundEnabled = value);
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () async {
              final newValue = !_soundEnabled;
              await SettingsManager.setSoundEnabled(newValue);
              setState(() => _soundEnabled = newValue);
            },
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.contacts_outlined,
            title: 'Contacts',
            subtitle: 'Find friends and manage contacts',
            onTap: () async {
              final user = await UserService.getCurrentUserProfile();
              if (mounted && user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactsScreen(currentUserId: user.id),
                  ),
                );
              }
            },
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
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.smart_toy_outlined,
            title: 'AI Settings',
            subtitle: 'Configure AI mode (Local/Cloud)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AISettingsScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: _showAboutDialog,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: _openSupportEmail,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.star_outline,
            title: 'Rate App',
            subtitle: 'Rate us on the app store',
            onTap: _openRateLink,
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

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Buddy',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Buddy App. All rights reserved.',
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Your AI-powered project management companion.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@buddy.app',
      query: Uri.encodeQueryComponent(
        'subject=Buddy Support&body=Describe your issue...',
      ),
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open email app'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _openRateLink() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.buddy.app',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open store link'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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

  void _openAppearanceSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.sync,
            title: 'Auto Sync',
            subtitle: 'Automatically sync chat data',
            trailing: Switch(
              value: _autoSyncEnabled,
              onChanged: (value) async {
                await SettingsManager.setAutoSyncEnabled(value);
                setState(() => _autoSyncEnabled = value);
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () async {
              final newValue = !_autoSyncEnabled;
              await SettingsManager.setAutoSyncEnabled(newValue);
              setState(() => _autoSyncEnabled = newValue);
            },
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.speed,
            title: 'Sync Interval',
            subtitle: 'How often to sync data ($_syncInterval seconds)',
            onTap: () => _showSyncIntervalDialog(),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.tune,
            title: 'Performance Mode',
            subtitle: _getPerformanceModeDescription(),
            onTap: () => _showPerformanceModeDialog(),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            subtitle: 'Use stylish black theme',
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) async {
                await SettingsManager.setDarkMode(value);
                setState(() => _isDarkMode = value);
                if (mounted) {
                  // Force rebuild the entire app to apply theme changes
                  Navigator.of(context).pushReplacementNamed('/home');
                }
              },
              activeColor: AppTheme.primaryColor,
            ),
            onTap: () async {
              final newValue = !_isDarkMode;
              await SettingsManager.setDarkMode(newValue);
              setState(() => _isDarkMode = newValue);
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          ),
        ],
      ),
    );
  }

  String _getPerformanceModeDescription() {
    switch (_performanceMode) {
      case 'fast':
        return 'Fast mode - optimized for speed';
      case 'quality':
        return 'Quality mode - best experience';
      case 'balanced':
      default:
        return 'Balanced mode - good speed and quality';
    }
  }

  void _showSyncIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sync Interval',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how often to sync chat data:',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            ...[1, 5, 10, 30, 60].map(
              (seconds) => RadioListTile<int>(
                title: Text(
                  '$seconds second${seconds == 1 ? '' : 's'}',
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                ),
                value: seconds,
                groupValue: _syncInterval,
                onChanged: (value) async {
                  if (value != null) {
                    await SettingsManager.setSyncInterval(value);
                    setState(() => _syncInterval = value);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPerformanceModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Performance Mode',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose performance mode:',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            ...['fast', 'balanced', 'quality'].map(
              (mode) => RadioListTile<String>(
                title: Text(
                  _getPerformanceModeTitle(mode),
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                ),
                subtitle: Text(
                  _getPerformanceModeSubtitle(mode),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                value: mode,
                groupValue: _performanceMode,
                onChanged: (value) async {
                  if (value != null) {
                    await SettingsManager.setPerformanceMode(value);
                    setState(() => _performanceMode = value);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPerformanceModeTitle(String mode) {
    switch (mode) {
      case 'fast':
        return 'Fast Mode';
      case 'quality':
        return 'Quality Mode';
      case 'balanced':
      default:
        return 'Balanced Mode';
    }
  }

  String _getPerformanceModeSubtitle(String mode) {
    switch (mode) {
      case 'fast':
        return 'Optimized for speed, reduced animations';
      case 'quality':
        return 'Best visual experience, smooth animations';
      case 'balanced':
      default:
        return 'Good balance of speed and quality';
    }
  }
}
