import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';
import '../services/buddy_service.dart';
import '../services/contact_service.dart';
import 'individual_chat_screen.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<types.Message> _messages = [];
  final _user = const types.User(id: 'user-1'); // Replace with actual user ID
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  String _getContactInitial(Map<String, dynamic> contact) {
    final name = contact['name']?.toString() ?? '';
    final mobile =
        contact['mobile_number']?.toString() ??
        contact['mobile']?.toString() ??
        '';

    if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    } else if (mobile.isNotEmpty) {
      return mobile.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final backendMessages = await ChatService.getChats();

    // Convert backend messages to flutter_chat_types.Message
    final messages = backendMessages.map<types.Message>((msg) {
      return types.TextMessage(
        author: types.User(id: msg['sender_id'] ?? 'unknown'),
        createdAt: msg['timestamp'] != null
            ? DateTime.tryParse(msg['timestamp'])?.millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch,
        id: msg['id']?.toString() ?? const Uuid().v4(),
        text: msg['content'] ?? '',
      );
    }).toList();

    // Sort messages by createdAt descending (latest first)
    messages.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    setState(() {
      _messages.insert(0, textMessage);
    });

    // TODO: Replace 'receiver_id' with actual selected contact when you add contact selection
    await ChatService.sendMessage('receiver_id', message.text);
    await _loadMessages();
  }

  void _showNewChatOptions() {
    _showContactList(); // Directly show contact list, remove the options modal
  }

  void _showContactList() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch real contacts from backend
      final contacts = await ContactService.getContacts();
      Navigator.pop(context); // Close loading dialog

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No contacts found')));
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: contact['profile_photo'] != null
                            ? NetworkImage(contact['profile_photo'])
                            : null,
                        child: contact['profile_photo'] == null
                            ? Text(_getContactInitial(contact))
                            : null,
                      ),
                      title: Text(
                        contact['name'] ??
                            contact['mobile_number'] ??
                            'Unknown',
                      ),
                      subtitle: Text(contact['mobile_number'] ?? ''),
                      onTap: () {
                        Navigator.pop(context);
                        _startChatWithContact(
                          contact['mobile'] ?? contact['id'].toString(),
                          contact['name'] ?? 'Unknown',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
    }
  }

  void _startChatWithContact(String contactId, [String? contactName]) {
    // Navigate to individual chat screen with this contact
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualChatScreen(
          contactId: contactId,
          contactName: contactName,
          currentUserId: _user.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              showUserAvatars: true,
              showUserNames: true,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewChatOptions();
        },
        child: const Icon(Icons.chat),
        tooltip: 'New Chat',
      ),
    );
  }
}
