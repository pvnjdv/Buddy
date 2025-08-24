import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/buddy/buddy_screen.dart';
import 'screens/flow/flow_screen.dart';
import 'services/auth_service.dart';
import 'services/buddy_service.dart';
import 'config/settings/theme_config.dart';
import 'config/settings/settings_manager.dart';
import 'services/databases/buddy_chat_database.dart';
import 'services/databases/flow_database.dart';
import 'services/databases/dock_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all databases
  await BuddyChatDatabase.initialize();
  await FlowDatabase.initialize();
  await DockDatabase.initialize();

  // Initialize services
  await BuddyService.initialize();

  // Initialize theme and settings
  await AppTheme.loadTheme();
  await SettingsManager.initialize();

  runApp(const BuddyApp());
}

class BuddyApp extends StatefulWidget {
  const BuddyApp({super.key});

  static _BuddyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BuddyAppState>();

  @override
  State<BuddyApp> createState() => _BuddyAppState();
}

class _BuddyAppState extends State<BuddyApp> {
  void rebuildApp() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddy',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthChecker(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const HomeScreen(),
        '/buddy': (context) => const BuddyScreen(),
        '/flows': (context) => const FlowScreen(),
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Show loading for a moment
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn = await AuthService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        // User has valid refresh token, go to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // No valid authentication, go to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button during auth check
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Buddy',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered companion',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              Text(
                'Checking login status...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
