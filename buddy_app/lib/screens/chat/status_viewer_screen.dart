import 'package:flutter/material.dart';

class StatusViewerScreen extends StatelessWidget {
  final String userName;
  final String mediaUrl;

  const StatusViewerScreen({
    super.key,
    required this.userName,
    required this.mediaUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: mediaUrl,
              child: Image.network(mediaUrl, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}
