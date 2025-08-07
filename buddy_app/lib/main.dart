import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/buddy/buddy_screen.dart';
import 'screens/flow/flow_screen.dart';
// import 'services/auth_service.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
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
