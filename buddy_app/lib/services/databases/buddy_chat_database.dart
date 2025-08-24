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

    // If no active conversation, create a new one
    if (_activeConversationId == null) {
      await startNewConversation();
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

    // Save conversation data
    final conversationData = {
      'id': _activeConversationId,
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

    // Save current conversation first
    await _saveCurrentConversation();

    final conversationsJson = prefs.getString(_conversationsKey) ?? '[]';
    final List<dynamic> conversations = json.decode(conversationsJson);

    return conversations
        .cast<Map<String, dynamic>>()
        .map(
          (conv) => {
            'id': conv['id'],
            'timestamp': conv['timestamp'],
            'messageCount': conv['messageCount'],
            'preview': _getConversationPreview(conv['messages']),
          },
        )
        .toList()
      ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
  }

  /// Get conversation preview text
  static String _getConversationPreview(dynamic messages) {
    if (messages == null || (messages as List).isEmpty) {
      return 'New conversation';
    }

    try {
      final List<String> messageList = List<String>.from(messages);
      if (messageList.isNotEmpty) {
        final firstMessage = json.decode(messageList.first);
        final content = firstMessage['content'] ?? '';
        return content.length > 50 ? '${content.substring(0, 50)}...' : content;
      }
    } catch (e) {
      // Fallback for parsing errors
    }

    return 'Conversation';
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
    final chatHistory = prefs.getStringList(_chatHistoryKey) ?? [];

    chatHistory.add(messageJson);
    await prefs.setStringList(_chatHistoryKey, chatHistory);

    // Update conversation metadata
    if (_activeConversationId != null) {
      await _saveConversationMetadata(_activeConversationId!, chatHistory);
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

    // If deleted conversation was active, start new one
    if (_activeConversationId == conversationId) {
      await startNewConversation();
    }
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
