import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeKey = 'app_theme';
  static const String _primaryColorKey = 'primary_color';
  static const String _accentColorKey = 'accent_color';

  // Default colors
  static const Color defaultPrimary = Color(0xFF6366F1); // Indigo
  static const Color defaultAccent = Color(0xFF10B981); // Emerald

  // Available color options
  static const List<Color> primaryColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF84CC16), // Lime
  ];

  static const List<Color> accentColors = [
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF84CC16), // Lime
    Color(0xFF6366F1), // Indigo
  ];

  static Color _primaryColor = defaultPrimary;
  static Color _accentColor = defaultAccent;
  static bool _isDarkMode = false;

  static Color get primaryColor => _primaryColor;
  static Color get accentColor => _accentColor;
  static bool get isDarkMode => _isDarkMode;

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;

    final primaryIndex = prefs.getInt(_primaryColorKey) ?? 0;
    final accentIndex = prefs.getInt(_accentColorKey) ?? 1;

    _primaryColor = primaryColors[primaryIndex];
    _accentColor = accentColors[accentIndex];
  }

  static Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  static Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final index = primaryColors.indexOf(color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, index);
  }

  static Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final index = accentColors.indexOf(color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, index);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF334155),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );
  }

  // Custom colors for specific use cases
  static Color get backgroundColor =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  static Color get surfaceColor =>
      _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

  static Color get cardColor =>
      _isDarkMode ? const Color(0xFF334155) : Colors.white;

  static Color get textPrimaryColor =>
      _isDarkMode ? Colors.white : Colors.black87;

  static Color get textSecondaryColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

  static Color get borderColor =>
      _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

  static Color get errorColor => const Color(0xFFEF4444);
  static Color get successColor => const Color(0xFF10B981);
  static Color get warningColor => const Color(0xFFF59E0B);
  static Color get shadowColor =>
      _isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1);
}
