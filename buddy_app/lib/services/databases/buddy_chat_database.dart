import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Separate database service for Buddy Chat conversations
/// This provides isolated storage for chat data with better performance and scalability
class BuddyChatDatabase {
  static const String _chatHistoryKey = 'buddy_chat_history';
  static const String _conversationsKey = 'buddy_conversations';
  static const String _activeConversationKey = 'buddy_active_conversation';
  static const String _conversationMetadataKey = 'buddy_conversation_metadata';

  // Current active conversation ID
  static String? _activeConversationId;

  /// Initialize the database
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _activeConversationId = prefs.getString(_activeConversationKey);

    // Only create a new conversation if there are existing conversations
    // or if this is the very first time the app is run
    if (_activeConversationId == null) {
      final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
      final List<dynamic> conversations = json.decode(conversationsJson);

      // Only auto-create if this is truly the first time (no conversations at all)
      if (conversations.isEmpty && !prefs.containsKey(_conversationsKey)) {
        await startNewConversation();
        print('🆕 First time setup: Created initial conversation');
      } else if (conversations.isNotEmpty) {
        // Load the most recent conversation
        conversations.sort(
          (a, b) =>
              (b['timestamp'] as String).compareTo(a['timestamp'] as String),
        );
        final mostRecentConv = conversations.first;
        await loadConversation(mostRecentConv['id']);
        print('🔄 Loaded most recent conversation: ${mostRecentConv['id']}');
      } else {
        print('📭 No active conversation - waiting for user to start one');
      }
    }
  }

  /// Start a new conversation
  static Future<String> startNewConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final conversationId = DateTime.now().millisecondsSinceEpoch.toString();

    // Save current conversation before starting new one
    if (_activeConversationId != null) {
      await _saveCurrentConversation();
    }

    // Set new active conversation
    _activeConversationId = conversationId;
    await prefs.setString(_activeConversationKey, conversationId);

    // Clear current chat history for new conversation
    await prefs.remove(_chatHistoryKey);

    // Save conversation metadata
    await _saveConversationMetadata(conversationId, []);

    return conversationId;
  }

  /// Save current conversation to persistent storage
  static Future<void> _saveCurrentConversation() async {
    if (_activeConversationId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final chatHistory = prefs.getStringList(_chatHistoryKey) ?? [];

    // Parse messages to generate title
    List<Map<String, dynamic>> parsedMessages = [];
    for (String msgJson in chatHistory) {
      try {
        final decoded = json.decode(msgJson);
        parsedMessages.add({
          'message': decoded['content'] ?? decoded['message'] ?? '',
          'isUser': decoded['isUser'] ?? false,
          'timestamp': decoded['timestamp'] ?? DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Skip malformed messages
        continue;
      }
    }

    // Generate title from messages
    String title = _generateConversationTitle(parsedMessages);

    // Save conversation data
    final conversationData = {
      'id': _activeConversationId,
      'title': title,
      'messages': chatHistory,
      'timestamp': DateTime.now().toIso8601String(),
      'messageCount': chatHistory.length,
    };

    // Get existing conversations
    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);

    // Remove existing conversation with same ID and add updated one
    conversations.removeWhere((conv) => conv['id'] == _activeConversationId);
    conversations.add(conversationData);

    // Save back to storage
    await prefs.setString(_conversationsKey, json.encode(conversations));
  }

  /// Load a specific conversation
  static Future<void> loadConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();

    // Save current conversation first
    if (_activeConversationId != null &&
        _activeConversationId != conversationId) {
      await _saveCurrentConversation();
    }

    // Load the requested conversation
    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);

    final conversation = conversations.firstWhere(
      (conv) => conv['id'] == conversationId,
      orElse: () => null,
    );

    if (conversation != null) {
      // Set as active conversation
      _activeConversationId = conversationId;
      await prefs.setString(_activeConversationKey, conversationId);

      // Load messages
      final List<String> messages = List<String>.from(
        conversation['messages'] ?? [],
      );
      await prefs.setStringList(_chatHistoryKey, messages);
    }
  }

  /// Get all conversations
  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    final prefs = await SharedPreferences.getInstance();

    // Save current conversation first (only if there is one)
    if (_activeConversationId != null) {
      await _saveCurrentConversation();
    }

    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);

    return conversations.cast<Map<String, dynamic>>().map((conv) {
      final messages = List<Map<String, dynamic>>.from(
        (conv['messages'] as List? ?? []).map((msgJson) {
          try {
            if (msgJson is String) {
              final decoded = json.decode(msgJson);
              return {
                'message': decoded['content'] ?? decoded['message'] ?? '',
                'isUser': decoded['isUser'] ?? false,
                'timestamp':
                    decoded['timestamp'] ?? DateTime.now().toIso8601String(),
              };
            }
            return msgJson as Map<String, dynamic>;
          } catch (e) {
            return {
              'message': 'Error loading message',
              'isUser': false,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }
        }),
      );

      return {
        'id': conv['id'],
        'title': conv['title'] ?? _generateConversationTitle(messages),
        'messages': messages,
        'created_at': conv['timestamp'] ?? DateTime.now().toIso8601String(),
        'updated_at': conv['timestamp'] ?? DateTime.now().toIso8601String(),
        'messageCount': messages.length,
      };
    }).toList()..sort(
      (a, b) =>
          (b['updated_at'] as String).compareTo(a['updated_at'] as String),
    );
  }

  /// Generate a conversation title from messages
  static String _generateConversationTitle(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.isEmpty) return 'New Conversation';

    // Find first user message
    final firstUserMessage = messages.firstWhere(
      (msg) => msg['isUser'] == true,
      orElse: () => messages.first,
    );

    String content =
        firstUserMessage['message']?.toString() ?? 'New Conversation';
    if (content.length > 40) {
      content = '${content.substring(0, 40)}...';
    }

    return content;
  }

  /// Force refresh - save current conversation and update list
  static Future<void> forceRefresh() async {
    print('🔄 Force refreshing conversations...');
    // Only save if there's an active conversation
    if (_activeConversationId != null) {
      await _saveCurrentConversation();
    }
    print('✅ Force refresh complete');
  }

  /// Save conversation metadata
  static Future<void> _saveConversationMetadata(
    String conversationId,
    List<String> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final metadata = {
      'id': conversationId,
      'timestamp': DateTime.now().toIso8601String(),
      'messageCount': messages.length,
      'firstMessage': messages.isNotEmpty ? messages.first : '',
    };

    final metadataListJson = prefs.getString(_conversationMetadataKey) ?? '[]';
    final List<dynamic> metadataList = json.decode(metadataListJson);

    // Remove existing and add new
    metadataList.removeWhere((meta) => meta['id'] == conversationId);
    metadataList.add(metadata);

    await prefs.setString(_conversationMetadataKey, json.encode(metadataList));
  }

  /// Add message to current conversation
  static Future<void> addMessage(String messageJson) async {
    final prefs = await SharedPreferences.getInstance();

    // If no active conversation, start a new one
    if (_activeConversationId == null) {
      print('💬 No active conversation, starting new one...');
      await startNewConversation();
    }

    final chatHistory = prefs.getStringList(_chatHistoryKey) ?? [];

    chatHistory.add(messageJson);
    await prefs.setStringList(_chatHistoryKey, chatHistory);

    print(
      '💬 Added message to conversation ${_activeConversationId}. Total messages: ${chatHistory.length}',
    );

    // Update conversation metadata
    if (_activeConversationId != null) {
      await _saveConversationMetadata(_activeConversationId!, chatHistory);
      // Also save the current conversation to update the conversations list
      await _saveCurrentConversation();
      print(
        '📚 Saved conversation ${_activeConversationId} with ${chatHistory.length} messages',
      );
    }
  }

  /// Get current conversation messages
  static Future<List<String>> getCurrentMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_chatHistoryKey) ?? [];
  }

  /// Clear current conversation
  static Future<void> clearCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);

    if (_activeConversationId != null) {
      await _saveConversationMetadata(_activeConversationId!, []);
    }
  }

  /// Delete a specific conversation
  static Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove from conversations list
    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);
    conversations.removeWhere((conv) => conv['id'] == conversationId);
    await prefs.setString(_conversationsKey, json.encode(conversations));

    // Remove from metadata
    final metadataListJson = prefs.getString(_conversationMetadataKey) ?? '[]';
    final List<dynamic> metadataList = json.decode(metadataListJson);
    metadataList.removeWhere((meta) => meta['id'] == conversationId);
    await prefs.setString(_conversationMetadataKey, json.encode(metadataList));

    // If deleted conversation was active
    if (_activeConversationId == conversationId) {
      // Check if there are other conversations remaining
      if (conversations.isNotEmpty) {
        // Load the most recent conversation
        conversations.sort(
          (a, b) =>
              (b['timestamp'] as String).compareTo(a['timestamp'] as String),
        );
        final mostRecentConv = conversations.first;
        await loadConversation(mostRecentConv['id']);
      } else {
        // No conversations left, just clear everything
        _activeConversationId = null;
        await prefs.remove(_activeConversationKey);
        await prefs.remove(_chatHistoryKey);
        print('🗑️ All conversations deleted. Chat history cleared.');
      }
    }
  }

  /// Rename a specific conversation
  static Future<void> renameConversation(
    String conversationId,
    String newTitle,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Update in conversations list
    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);
    for (var conv in conversations) {
      if (conv['id'] == conversationId) {
        conv['title'] = newTitle;
        conv['updated_at'] = DateTime.now().toIso8601String();
        break;
      }
    }
    await prefs.setString(_conversationsKey, json.encode(conversations));

    // Update in metadata
    final metadataListJson = prefs.getString(_conversationMetadataKey) ?? '[]';
    final List<dynamic> metadataList = json.decode(metadataListJson);
    for (var meta in metadataList) {
      if (meta['id'] == conversationId) {
        meta['title'] = newTitle;
        meta['updated_at'] = DateTime.now().toIso8601String();
        break;
      }
    }
    await prefs.setString(_conversationMetadataKey, json.encode(metadataList));
  }

  /// Get current active conversation ID
  static String? get activeConversationId => _activeConversationId;

  /// Export all conversations for backup
  static Future<Map<String, dynamic>> exportAllConversations() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'conversations': prefs.getString(_conversationsKey) ?? '[]',
      'metadata': prefs.getString(_conversationMetadataKey) ?? '[]',
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Import conversations from backup
  static Future<void> importConversations(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('conversations')) {
      await prefs.setString(_conversationsKey, data['conversations']);
    }

    if (data.containsKey('metadata')) {
      await prefs.setString(_conversationMetadataKey, data['metadata']);
    }
  }
}
