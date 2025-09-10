// lib/screens/code_editor/buddy_editor_screen.dart
import 'package:flutter/material.dart';
import 'buddy_code_editor_mobile.dart';

class BuddyEditorScreen extends StatelessWidget {
  const BuddyEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: const BuddyCodeEditorMobile(),
      ),
    );
  }
}

// Route helper with enhanced transition
Route<void> createBuddyEditorRoute() {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, _) => const BuddyEditorScreen(),
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOut)),
        ),
        child: child,
      );
    },
  );
}
