import 'package:shared_preferences/shared_preferences.dart';
import 'theme_config.dart';

class SettingsManager {
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundKey = 'sound_enabled';
  static const String _autoSyncKey = 'auto_sync_enabled';
  static const String _syncIntervalKey = 'sync_interval';
  static const String _chatHistoryLimitKey = 'chat_history_limit';
  static const String _performanceModeKey = 'performance_mode';

  // Theme settings
  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    AppTheme.setDarkMode(isDark);
  }

  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true; // Default to dark mode
  }

  // Language settings
  static Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  // Notification settings
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  // Sound settings
  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  static Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  // Auto-sync settings
  static Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  static Future<bool> getAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? true;
  }

  // Sync interval settings (in seconds)
  static Future<void> setSyncInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, seconds);
  }

  static Future<int> getSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncIntervalKey) ??
        5; // Default 5 seconds for quick sync
  }

  // Chat history limit
  static Future<void> setChatHistoryLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chatHistoryLimitKey, limit);
  }

  static Future<int> getChatHistoryLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chatHistoryLimitKey) ?? 1000; // Default 1000 messages
  }

  // Performance mode
  static Future<void> setPerformanceMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_performanceModeKey, mode);
  }

  static Future<String> getPerformanceMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_performanceModeKey) ??
        'balanced'; // balanced, fast, quality
  }

  // Initialize all settings
  static Future<void> initialize() async {
    final isDark = await getDarkMode();
    AppTheme.setDarkMode(isDark);
  }

  // Reset all settings to defaults
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_languageKey);
    await prefs.remove(_notificationsKey);
    await prefs.remove(_soundKey);
    await prefs.remove(_autoSyncKey);
    await prefs.remove(_syncIntervalKey);
    await prefs.remove(_chatHistoryLimitKey);
    await prefs.remove(_performanceModeKey);

    // Reinitialize with defaults
    await initialize();
  }

  // Export settings
  static Future<Map<String, dynamic>> exportSettings() async {
    return {
      'theme': await getDarkMode(),
      'language': await getLanguage(),
      'notifications': await getNotificationsEnabled(),
      'sound': await getSoundEnabled(),
      'autoSync': await getAutoSyncEnabled(),
      'syncInterval': await getSyncInterval(),
      'chatHistoryLimit': await getChatHistoryLimit(),
      'performanceMode': await getPerformanceMode(),
    };
  }

  // Import settings
  static Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings.containsKey('theme')) {
      await setDarkMode(settings['theme'] as bool);
    }
    if (settings.containsKey('language')) {
      await setLanguage(settings['language'] as String);
    }
    if (settings.containsKey('notifications')) {
      await setNotificationsEnabled(settings['notifications'] as bool);
    }
    if (settings.containsKey('sound')) {
      await setSoundEnabled(settings['sound'] as bool);
    }
    if (settings.containsKey('autoSync')) {
      await setAutoSyncEnabled(settings['autoSync'] as bool);
    }
    if (settings.containsKey('syncInterval')) {
      await setSyncInterval(settings['syncInterval'] as int);
    }
    if (settings.containsKey('chatHistoryLimit')) {
      await setChatHistoryLimit(settings['chatHistoryLimit'] as int);
    }
    if (settings.containsKey('performanceMode')) {
      await setPerformanceMode(settings['performanceMode'] as String);
    }
  }
}
