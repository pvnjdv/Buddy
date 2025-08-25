import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:buddy_app/services/databases/buddy_chat_database.dart';
import 'package:buddy_app/services/buddy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Chat History Tests', () {
    setUp(() async {
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Should save and load messages correctly', () async {
      // Initialize database
      await BuddyChatDatabase.initialize();

      // Add a test message
      final testMessage = {
        'id': '1',
        'content': 'Hello, this is a test message',
        'role': 'user',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await BuddyChatDatabase.addMessage(jsonEncode(testMessage));

      // Get messages back
      final messages = await BuddyChatDatabase.getCurrentMessages();

      expect(messages.length, 1);

      final retrievedMessage = jsonDecode(messages.first);
      expect(retrievedMessage['content'], 'Hello, this is a test message');
      expect(retrievedMessage['role'], 'user');
    });

    test('Should maintain conversation context', () async {
      // Initialize BuddyService
      await BuddyService.initialize();

      // Simulate adding multiple messages
      await BuddyService.addTestMessage('user', 'My name is John');
      await BuddyService.addTestMessage('assistant', 'Nice to meet you, John!');
      await BuddyService.addTestMessage('user', 'What is my name?');

      // Check if context is maintained
      final history = BuddyService.getChatHistory();
      expect(history.length, 3);
      expect(history[0].content, 'My name is John');
      expect(history[1].content, 'Nice to meet you, John!');
      expect(history[2].content, 'What is my name?');
    });

    test('Should save conversations and load them back', () async {
      await BuddyChatDatabase.initialize();

      // Add messages to first conversation
      await BuddyChatDatabase.addMessage(
        jsonEncode({
          'id': '1',
          'content': 'First conversation message',
          'role': 'user',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // Start new conversation
      await BuddyChatDatabase.startNewConversation();

      // Add message to new conversation
      await BuddyChatDatabase.addMessage(
        jsonEncode({
          'id': '2',
          'content': 'Second conversation message',
          'role': 'user',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // Get all conversations
      final conversations = await BuddyChatDatabase.getAllConversations();
      expect(conversations.length, 2);

      // Load first conversation and check its content
      await BuddyChatDatabase.loadConversation(conversations[1]['id']);
      final firstConversationMessages =
          await BuddyChatDatabase.getCurrentMessages();
      expect(firstConversationMessages.length, 1);

      final firstMessage = jsonDecode(firstConversationMessages.first);
      expect(firstMessage['content'], 'First conversation message');
    });
  });
}
