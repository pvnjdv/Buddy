import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/buddy/buddy_screen.dart';
import 'screens/flow/flow_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const BuddyApp());
}

class BuddyApp extends StatelessWidget {
  const BuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Buddy',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthChecker(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/profile_setup': (context) =>
            const ProfileSetupScreen(mobile: ''), // Update as needed
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.supervised_user_circle,
                size: 80,
                color: Colors.blue[600],
              ),
              const SizedBox(height: 20),
              const Text(
                'Buddy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Checking login status...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
