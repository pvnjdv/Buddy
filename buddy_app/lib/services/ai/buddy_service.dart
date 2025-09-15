import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/flow_models.dart';
import '../../config/api_config.dart';
import '../agent/buddy_orchestrator.dart';
import '../databases/buddy_chat_database.dart';
import 'on_device_ai_service.dart';

class AIPersona {
  final String id;
  final String name;
  final String description;
  final String? responseStyle;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;

  AIPersona({
    required this.id,
    required this.name,
    required this.description,
    this.responseStyle,
    required this.isActive,
    required this.isDefault,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'response_style': responseStyle,
    'is_active': isActive,
    'is_default': isDefault,
    'created_at': createdAt.toIso8601String(),
  };

  factory AIPersona.fromJson(Map<String, dynamic> json) => AIPersona(
    id: json['id'],
    name: json['name'],
    description: json['description'] ?? '',
    responseStyle: json['response_style'],
    isActive: json['is_active'] ?? false,
    isDefault: json['is_default'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
  );
}

class PersonaListResponse {
  final List<AIPersona> personas;
  final AIPersona? activePersona;
  final int totalCount;

  PersonaListResponse({
    required this.personas,
    this.activePersona,
    required this.totalCount,
  });

  factory PersonaListResponse.fromJson(Map<String, dynamic> json) {
    return PersonaListResponse(
      personas: (json['personas'] as List)
          .map((p) => AIPersona.fromJson(p))
          .toList(),
      activePersona: json['active_persona'] != null
          ? AIPersona.fromJson(json['active_persona'])
          : null,
      totalCount: json['total_count'] ?? 0,
    );
  }
}

class BuddyService {
  static List<FlowBuddyMessage> _chatHistory = [];
  static AIPersona? _activePersona;
  static List<AIPersona> _savedPersonas = [];
  static bool _isProcessingRequest = false; // Add request throttling

  // AI Mode management
  static String _currentAIMode = 'api'; // 'api' or 'local'
  static OnDeviceAIService? _onDeviceAI;

  // Chat session management - now using BuddyChatDatabase
  static String _currentChatSessionId = DateTime.now().millisecondsSinceEpoch
      .toString();

  // Initialize the service
  static Future<void> initialize() async {
    print('🚀 Initializing BuddyService...');
    await BuddyChatDatabase.initialize();
    await _loadCurrentChatHistory();
    await loadAIModePreference(); // Load AI mode preference
    print(
      '✅ BuddyService initialized with ${_chatHistory.length} messages, AI mode: $_currentAIMode',
    );
  }

  // Load current chat history from BuddyChatDatabase
  static Future<void> _loadCurrentChatHistory() async {
    try {
      final messages = await BuddyChatDatabase.getCurrentMessages();
      _chatHistory = messages.map((messageJson) {
        final messageData = json.decode(messageJson);
        return FlowBuddyMessage.fromJson(messageData);
      }).toList();
      print('📚 Loaded ${_chatHistory.length} messages from chat database');
    } catch (e) {
      print('❌ Error loading chat history: $e');
      _chatHistory = [];
    }
  }

  // Get authorization token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt');
      print(
        'Auth token retrieved: ${token != null ? _truncateString(token, 10) : "null"}',
      );
      return token;
    } catch (e) {
      print('Error retrieving auth token: $e');
      return null;
    }
  }

  // Get auth headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    print(
      'Retrieved auth token: ${token != null ? _truncateString(token, 10) : "null"}',
    );

    final headers = {'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Load all personas from backend
  static Future<void> loadSavedPersonas() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/personas/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final personaResponse = PersonaListResponse.fromJson(
          jsonDecode(response.body),
        );
        _savedPersonas = personaResponse.personas;
        _activePersona = personaResponse.activePersona;
      } else if (response.statusCode == 401) {
        // Unauthorized - clear local data
        _savedPersonas.clear();
        _activePersona = null;
      }
    } catch (e) {
      print('Error loading personas from backend: $e');
      // Keep existing local data on error
    }
  }

  // Create a new persona via backend
  static Future<bool> createPersona(
    String name,
    String description, {
    String? responseStyle,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({
        'name': name.trim(),
        'description': description.trim(),
        'response_style': responseStyle ?? 'conversational',
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/personas/'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        // Reload personas to get the updated list
        await loadSavedPersonas();
        return true;
      }
    } catch (e) {
      print('Error creating persona: $e');
    }
    return false;
  }

  // Set active persona via backend
  static Future<bool> setActivePersona(String? personaId) async {
    try {
      final headers = await _getAuthHeaders();

      if (personaId == null) {
        // Deactivate all personas
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/personas/deactivate'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          _activePersona = null;
          return true;
        }
      } else {
        // Activate specific persona
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/personas/$personaId/activate'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          // Find and set the active persona locally
          _activePersona = _savedPersonas.firstWhere(
            (p) => p.id == personaId,
            orElse: () => _activePersona!,
          );
          return true;
        }
      }
    } catch (e) {
      print('Error setting active persona: $e');
    }
    return false;
  }

  // Delete a persona via backend
  static Future<bool> deletePersona(String personaId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/personas/$personaId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Remove from local list
        _savedPersonas.removeWhere((p) => p.id == personaId);
        if (_activePersona?.id == personaId) {
          _activePersona = null;
        }
        return true;
      }
    } catch (e) {
      print('Error deleting persona: $e');
    }
    return false;
  }

  // Initialize default personas
  static Future<bool> initializeDefaultPersonas() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/personas/initialize-defaults'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        await loadSavedPersonas();
        return true;
      }
    } catch (e) {
      print('Error initializing default personas: $e');
    }
    return false;
  }

  // Get all saved personas
  static List<AIPersona> getSavedPersonas() => List.from(_savedPersonas);

  // Get active persona
  static AIPersona? getActivePersona() => _activePersona;

  // Legacy compatibility method
  static Map<String, String>? getCustomAI() {
    if (_activePersona == null) return null;
    return {
      'name': _activePersona!.name,
      'description': _activePersona!.description,
    };
  }

  // Legacy compatibility methods
  static Future<void> loadSavedPersona() => loadSavedPersonas();

  static Future<void> setCustomAI(String name, String description) async {
    await createPersona(name, description);
  }

  static Future<void> clearCustomAI() async {
    if (_activePersona != null) {
      await setActivePersona(null);
    }
  }

  // Test method to debug connectivity
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      print('Testing basic HTTP connection...');
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/docs'))
          .timeout(const Duration(seconds: 10));

      print('Test connection status: ${response.statusCode}');
      return {
        'success': response.statusCode == 200,
        'status_code': response.statusCode,
        'url': '${ApiConfig.baseUrl}/docs',
      };
    } catch (e) {
      print('Test connection failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'url': '${ApiConfig.baseUrl}/docs',
      };
    }
  }

  // Chat history methods
  static List<FlowBuddyMessage> getChatHistory() {
    return List.from(_chatHistory);
  }

  // Load chat history from persistent storage
  static Future<void> loadChatHistory() async {
    await _loadCurrentChatHistory();
  }

  // Save chat history to persistent storage
  static Future<void> saveChatHistory() async {
    try {
      // This method is now deprecated - individual messages are saved immediately
      // when added. This is kept for compatibility but does nothing to avoid duplicates.
      print('saveChatHistory() called - individual messages already saved');
    } catch (e) {
      print('Error in saveChatHistory: $e');
    }
  }

  // Start new conversation - Save current one before starting new
  static Future<void> startNewConversation() async {
    try {
      // Use the new database for conversation management
      final conversationId = await BuddyChatDatabase.startNewConversation();
      _currentChatSessionId = conversationId;

      // Clear current chat history in memory
      _chatHistory.clear();

      print('Started new conversation: $conversationId');
    } catch (e) {
      print('Error starting new conversation: $e');
      _chatHistory.clear();
      _currentChatSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  // Get all conversations
  static Future<List<Map<String, dynamic>>> getAllConversations() async {
    try {
      return await BuddyChatDatabase.getAllConversations();
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  // Load a specific conversation
  static Future<void> loadConversation(String conversationId) async {
    try {
      // Load conversation from database
      await BuddyChatDatabase.loadConversation(conversationId);
      _currentChatSessionId = conversationId;

      // Reload chat history from the loaded conversation
      await _loadCurrentChatHistory();

      print(
        'Loaded conversation: $conversationId with ${_chatHistory.length} messages',
      );
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }

  static void clearChatHistory() {
    _chatHistory.clear();
    saveChatHistory();
  }

  // Flow detection methods
  static bool isFlowCreationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final flowKeywords = [
      'create flow',
      'generate flow',
      'flow:',
      'make flow',
      'new flow',
      'flow for',
    ];

    return flowKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  // Detect task continuation/modification requests
  static bool isTaskContinuationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final continuationKeywords = [
      'add this',
      'add that',
      'also add',
      'include this',
      'put this',
      'add another',
      'and also',
      'modify',
      'change',
      'update',
      'edit this',
      'add to it',
      'add to that',
      'add in it',
      'append',
      'insert',
      'put in',
      'add more',
      'additional',
      'also make',
      'also create',
    ];

    // Check if this looks like a continuation request
    final hasContinuationKeywords = continuationKeywords.any(
      (keyword) => lowerMessage.contains(keyword),
    );

    // Check if we have recent context (recent messages about notes/alarms/flows)
    final hasRecentContext =
        _chatHistory.length >= 2 &&
        _chatHistory.reversed
            .take(3)
            .any(
              (msg) =>
                  msg.role == 'assistant' &&
                  (msg.content.toLowerCase().contains('note') ||
                      msg.content.toLowerCase().contains('alarm') ||
                      msg.content.toLowerCase().contains('flow') ||
                      msg.content.toLowerCase().contains('created') ||
                      msg.content.toLowerCase().contains('added')),
            );

    return hasContinuationKeywords ||
        (hasRecentContext && _isFollowUpMessage(lowerMessage));
  }

  // Check if this is a follow-up message based on context
  static bool _isFollowUpMessage(String lowerMessage) {
    final followUpPatterns = [
      RegExp(r'\b(that|this|it)\b'),
      RegExp(r'\b(the (note|alarm|flow|task))\b'),
      RegExp(r'\b(make it|do it|add it)\b'),
    ];

    return followUpPatterns.any((pattern) => pattern.hasMatch(lowerMessage));
  }

  // Get recent task context for continuation
  static Map<String, dynamic>? _getRecentTaskContext() {
    // Look for recent assistant messages about created tasks
    final recentMessages = _chatHistory.reversed.take(5).toList();

    for (final message in recentMessages) {
      if (message.role == 'assistant') {
        final content = message.content.toLowerCase();

        // Check for note creation
        if (content.contains('note') &&
            (content.contains('created') ||
                content.contains('added') ||
                content.contains('saved'))) {
          return {
            'type': 'note',
            'content': message.content,
            'timestamp': message.timestamp.toIso8601String(),
          };
        }

        // Check for alarm creation
        if (content.contains('alarm') &&
            (content.contains('created') ||
                content.contains('set') ||
                content.contains('added'))) {
          return {
            'type': 'alarm',
            'content': message.content,
            'timestamp': message.timestamp.toIso8601String(),
          };
        }

        // Check for flow creation
        if (content.contains('flow') &&
            (content.contains('created') || content.contains('generated'))) {
          return {
            'type': 'flow',
            'content': message.content,
            'timestamp': message.timestamp.toIso8601String(),
          };
        }
      }
    }

    return null;
  }

  static String extractProjectDescription(String message) {
    final lowerMessage = message.toLowerCase();
    final flowTriggers = [
      'create flow for',
      'generate flow for',
      'flow:',
      'make flow for',
      'new flow for',
      'flow for',
    ];

    for (final trigger in flowTriggers) {
      if (lowerMessage.contains(trigger)) {
        final startIndex = lowerMessage.indexOf(trigger) + trigger.length;
        if (startIndex < message.length) {
          return message.substring(startIndex).trim();
        }
      }
    }

    return message.trim();
  }

  // Main chat method with persona support - Simplified like old code
  static Future<Map<String, dynamic>> askBuddy(String prompt) async {
    // Prevent multiple simultaneous requests
    if (_isProcessingRequest) {
      print('Request blocked: Another request is already in progress');
      return {
        'success': false,
        'response': 'Please wait for the previous message to complete.',
        'error': 'request_throttled',
      };
    }

    _isProcessingRequest = true;

    // Add user message to chat history first
    final userMessage = FlowBuddyMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      role: 'user',
      timestamp: DateTime.now(),
    );
    _chatHistory.add(userMessage);
    // Save user message to database immediately
    await BuddyChatDatabase.addMessage(json.encode(userMessage.toJson()));
    print('💾 Saved user message: ${_truncateString(userMessage.content, 50)}');

    try {
      print('=== SIMPLE ASKBUDDY STARTED ===');
      print('Prompt: "$prompt"');

      // 1) Try on-device orchestrator skills first
      try {
        final orchestrator = BuddyOrchestrator();
        final agentResult = await orchestrator.handle(prompt);
        if (agentResult.handled) {
          final msg = agentResult.message.isNotEmpty
              ? agentResult.message
              : 'Done.';
          final assistantMessage = FlowBuddyMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: msg,
            role: 'assistant',
            timestamp: DateTime.now(),
          );
          _chatHistory.add(assistantMessage);
          // Save assistant message to database immediately
          await BuddyChatDatabase.addMessage(
            json.encode(assistantMessage.toJson()),
          );
          print(
            '💾 Saved assistant message: ${_truncateString(assistantMessage.content, 50)}',
          );

          // Enhanced response with navigation support
          final response = {
            'success': true,
            'response': msg,
            'message': msg,
            'is_flow_created': agentResult.extra?['is_flow_created'] ?? false,
            'flow': agentResult.flow?.toJson(),
            'note': agentResult.note,
            'alarm': agentResult.alarm,
            'extra': agentResult.extra,
          };

          // Handle navigation actions from AppControlSkill
          if (agentResult.extra?['action'] == 'navigate') {
            response['navigate'] = {
              'route': agentResult.extra?['route'],
              'arguments': agentResult.extra?['arguments'],
            };
          }

          // Handle system control responses
          if (agentResult.extra?['type'] == 'system_info' ||
              agentResult.extra?['type'] == 'process_list') {
            response['system_data'] = agentResult.extra?['data'];
          }

          // Handle GitHub operation results
          if (agentResult.extra?['type'] == 'git_operation') {
            response['git_result'] = {
              'operation': agentResult.extra?['operation'],
              'success': agentResult.extra?['success'],
              'output': agentResult.extra?['output'],
            };
          }

          _isProcessingRequest = false; // Reset flag before returning
          return response;
        }
      } catch (e) {
        print('Orchestrator error (ignored, fallback to backend): $e');
      }

      // 2) Check if we should use local AI mode
      if (_currentAIMode == 'local' && _onDeviceAI != null) {
        try {
          print('🤖 Using local on-device AI');
          final localResponse = await _processWithLocalAI(prompt);

          final assistantMessage = FlowBuddyMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: localResponse,
            role: 'assistant',
            timestamp: DateTime.now(),
          );
          _chatHistory.add(assistantMessage);
          // Save assistant message to database immediately
          await BuddyChatDatabase.addMessage(
            json.encode(assistantMessage.toJson()),
          );
          print(
            '💾 Saved local AI response: ${_truncateString(assistantMessage.content, 50)}',
          );

          _isProcessingRequest = false; // Reset flag before returning
          return {
            'success': true,
            'response': localResponse,
            'message': localResponse,
            'mode': 'local',
          };
        } catch (e) {
          print('❌ Local AI failed, falling back to API: $e');
          // Continue to API fallback below
        }
      }

      // 3) Fallback to API mode
      print('🌐 Using API mode');
      final url = Uri.parse('${ApiConfig.baseUrl}/buddy/ask');
      print('Request URL: $url');

      // Get token directly like old code
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt');
      print('Token found: ${token != null}');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Enhanced request body with task continuation context
      final isTaskContinuation = isTaskContinuationRequest(prompt);
      final recentContext = isTaskContinuation ? _getRecentTaskContext() : null;

      final requestBody = {
        'prompt': prompt,
        'chat_history': _chatHistory
            .map((msg) => {'role': msg.role, 'content': msg.content})
            .toList(),
        'is_task_continuation': isTaskContinuation,
        'recent_context': recentContext,
        'session_id': _currentChatSessionId,
      };

      print(
        '💬 Buddy Request - Session: $_currentChatSessionId, History: ${_chatHistory.length} msgs',
      );

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Response received: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'] ?? 'No response';

        // Add AI response to history
        final assistantMessage = FlowBuddyMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          content: aiResponse,
          role: 'assistant',
          timestamp: DateTime.now(),
        );
        _chatHistory.add(assistantMessage);
        // Save assistant message to database immediately
        await BuddyChatDatabase.addMessage(
          json.encode(assistantMessage.toJson()),
        );

        print('=== SUCCESS - RETURNING RESPONSE ===');
        print('AI Response: $aiResponse');

        _isProcessingRequest = false; // Reset flag before returning
        return {'success': true, 'response': aiResponse, 'message': aiResponse};
      } else {
        print('Server error: ${response.statusCode} - ${response.body}');
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('=== ERROR IN ASKBUDDY ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');

      final fallbackResponse = _generateFallbackResponse(prompt);

      // Add fallback message to chat history
      final assistantMessage = FlowBuddyMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        content: fallbackResponse,
        role: 'assistant',
        timestamp: DateTime.now(),
      );
      _chatHistory.add(assistantMessage);
      // Save assistant message to database immediately
      await BuddyChatDatabase.addMessage(
        json.encode(assistantMessage.toJson()),
      );

      return {
        'success': false,
        'response': fallbackResponse,
        'message': fallbackResponse,
        'error': 'network_error',
        'details': e.toString(),
      };
    } finally {
      _isProcessingRequest = false;
    }
  }

  static String _generateFallbackResponse(String prompt) {
    final responses = [
      "I'm having trouble connecting right now, but I'm here to help! Could you try asking again?",
      "Sorry, I'm experiencing some technical difficulties. Please try again in a moment.",
      "I'm temporarily offline, but I'll be back shortly. Please try your question again.",
      "Connection issues are preventing me from responding properly. Please retry your request.",
    ];

    return responses[DateTime.now().millisecond % responses.length];
  }

  // Flow preview methods (existing)
  static Future<Map<String, dynamic>> previewFlow(String prompt) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/buddy/preview-flow'),
        headers: headers,
        body: jsonEncode({
          'prompt': prompt,
          'chat_history': _chatHistory
              .map((msg) => {'role': msg.role, 'content': msg.content})
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'is_flow_request': data['is_flow_request'] ?? false,
          'preview_text': data['preview_text'] ?? '',
          'flow_data': data['flow_data'],
          'needs_confirmation': data['needs_confirmation'] ?? false,
        };
      }
    } catch (e) {
      print('Error previewing flow: $e');
    }

    return {
      'success': false,
      'message': 'Unable to preview flow. Please try again.',
    };
  }

  static Future<Map<String, dynamic>> confirmFlow(
    Map<String, dynamic> flowData,
    bool confirmed, {
    String? modifications,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/buddy/confirm-flow'),
        headers: headers,
        body: jsonEncode({
          'flow_data': flowData,
          'confirmed': confirmed,
          'modifications': modifications,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Flow created successfully!',
          'flow_id': data['flow_id'],
        };
      }
    } catch (e) {
      print('Error confirming flow: $e');
    }

    return {
      'success': false,
      'message': 'Unable to create flow. Please try again.',
    };
  }

  // AI Status and mode methods
  static Future<Map<String, dynamic>> getAIStatus() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/buddy/status'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': 'online',
          'mode': data['current_mode'] ?? 'api',
          'available_modes': data['available_modes'] ?? ['local', 'api'],
          'models': data['models'] ?? {},
          'last_updated': DateTime.now().toIso8601String(),
        };
      } else {
        print('Failed to get AI status: ${response.statusCode}');
        return {
          'status': 'offline',
          'mode': 'api',
          'last_updated': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      print('Error getting AI status: $e');
      return {
        'status': 'offline',
        'mode': 'api',
        'last_updated': DateTime.now().toIso8601String(),
      };
    }
  }

  static Future<bool> switchAIMode(String mode) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/buddy/switch-mode'),
            headers: headers,
            body: jsonEncode({'mode': mode}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('AI mode switched to: $mode');
        return true;
      } else {
        print('Failed to switch AI mode: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error switching AI mode: $e');
      return false;
    }
  }

  /// Switch to local on-device AI mode (new enhanced version)
  static Future<bool> switchToLocalMode() async {
    try {
      if (_onDeviceAI == null) {
        _onDeviceAI = OnDeviceAIService();
      }

      // Check if device is capable of running AI models
      final isCapable = await _onDeviceAI!.isDeviceCapable();
      if (!isCapable) {
        print('⚠️ Device may not be suitable for on-device AI');
        // Still allow user to try, but warn them
      }

      // Let user select and load a model
      final success = await _onDeviceAI!.selectAndLoadModel();

      if (success) {
        _currentAIMode = 'local';
        print('✅ Successfully switched to local AI mode');

        // Save the preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ai_mode', 'local');

        return true;
      } else {
        print('❌ Failed to load local model');
        return false;
      }
    } catch (e) {
      print('Error switching to local mode: $e');
      return false;
    }
  }

  /// Legacy method for server-based local mode (deprecated)
  static Future<bool> switchToServerLocalMode(String modelPath) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/buddy/switch-to-local'),
            headers: headers,
            body: jsonEncode({'mode': 'local', 'model_path': modelPath}),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Longer timeout for model loading

      if (response.statusCode == 200) {
        print('AI mode switched to server local with model: $modelPath');
        return true;
      } else {
        print('Failed to switch to server local mode: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error switching to server local mode: $e');
      return false;
    }
  }

  // Flow-related methods
  static Future<bool> updateFlowProgress(
    String flowId,
    int checkpointIndex,
    bool isCompleted,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/flows/$flowId/progress'),
        headers: headers,
        body: jsonEncode({
          'checkpoint_index': checkpointIndex,
          'is_completed': isCompleted,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('Error updating flow progress: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>> getCheckpointHelp({
    required String flowId,
    required String checkpointName,
  }) async {
    try {
      // Use the regular askBuddy method with a specific prompt for checkpoint help
      final helpPrompt =
          'Help me with checkpoint "$checkpointName" in my project flow. Please provide guidance, tips, and specific steps I should take to complete this checkpoint successfully.';

      final response = await askBuddy(helpPrompt);

      if (response['success'] == true) {
        return {'success': true, 'response': response['message']};
      } else {
        return {
          'success': false,
          'response':
              'Sorry, I couldn\'t get help for this checkpoint right now. Please try asking me directly in the chat.',
        };
      }
    } catch (e) {
      print('Error getting checkpoint help: $e');
      return {
        'success': false,
        'response':
            'Error getting help. Please try asking me directly in the chat.',
      };
    }
  }

  // Test method for debugging chat history
  static Future<void> addTestMessage(String role, String content) async {
    final message = FlowBuddyMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: role == 'user' ? 'user' : 'assistant',
      timestamp: DateTime.now(),
    );

    _chatHistory.add(message);
    await BuddyChatDatabase.addMessage(json.encode(message.toJson()));
    print('Added test message: $content');
  }

  // Debug method to check chat history status
  static Future<void> debugChatHistory() async {
    print('=== CHAT HISTORY DEBUG ===');
    print('Memory chat history count: ${_chatHistory.length}');

    final dbMessages = await BuddyChatDatabase.getCurrentMessages();
    print('Database messages count: ${dbMessages.length}');

    print('Memory messages:');
    for (int i = 0; i < _chatHistory.length; i++) {
      print('  $i: [${_chatHistory[i].role}] ${_chatHistory[i].content}');
    }

    print('Database messages:');
    for (int i = 0; i < dbMessages.length; i++) {
      final msg = json.decode(dbMessages[i]);
      print('  $i: [${msg['role']}] ${msg['content']}');
    }
    print('=== END DEBUG ===');
  }

  // Helper method for safe string truncation
  static String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // Emergency method to reset processing flag if it gets stuck
  static void resetProcessingFlag() {
    print('🔄 Manually resetting processing flag');
    _isProcessingRequest = false;
  }

  // Check if currently processing
  static bool isProcessing() {
    return _isProcessingRequest;
  }

  /// Get conversation context with optional cross-conversation awareness
  static Map<String, dynamic> getConversationContext({
    bool includeAllConversations = false,
  }) {
    final context = {
      'current_session_id': _currentChatSessionId,
      'current_conversation_messages': _chatHistory.length,
      'active_persona': _activePersona?.toJson(),
    };

    if (includeAllConversations) {
      // This could be used for advanced context awareness
      // For now, we keep it simple and focused on current conversation
      context['note'] = 'Cross-conversation context disabled for performance';
    }

    return context;
  }

  /// Get conversation summary for context sharing
  static String getConversationSummary({int maxMessages = 5}) {
    if (_chatHistory.isEmpty) return 'No conversation history';

    final recentMessages = _chatHistory.length > maxMessages
        ? _chatHistory.sublist(_chatHistory.length - maxMessages)
        : _chatHistory;

    final summary = recentMessages
        .map((msg) => '${msg.role}: ${msg.content}')
        .join('\n');

    return 'Recent conversation context:\n$summary';
  }

  // ====== ON-DEVICE AI MODE METHODS ======

  /// Process message using local AI
  static Future<String> _processWithLocalAI(String prompt) async {
    try {
      if (_onDeviceAI == null || !_onDeviceAI!.isModelLoaded) {
        throw Exception('Local AI model not loaded');
      }

      // Create a simple prompt with some context from chat history
      String contextPrompt = prompt;

      if (_chatHistory.isNotEmpty) {
        final recentMessages = _chatHistory.length > 3
            ? _chatHistory.sublist(_chatHistory.length - 3)
            : _chatHistory;

        final context = recentMessages
            .map(
              (msg) =>
                  '${msg.role == 'user' ? 'User' : 'Assistant'}: ${msg.content}',
            )
            .join('\n');

        contextPrompt =
            'Previous conversation:\n$context\n\nUser: $prompt\nAssistant:';
      } else {
        contextPrompt = 'User: $prompt\nAssistant:';
      }

      final response = await _onDeviceAI!.generateResponse(
        contextPrompt,
        maxTokens: 512,
        temperature: 0.7,
      );

      return response.trim();
    } catch (e) {
      print('Error processing with local AI: $e');
      throw e;
    }
  }

  /// Switch back to API mode
  static Future<bool> switchToAPIMode() async {
    try {
      if (_onDeviceAI != null) {
        await _onDeviceAI!.unloadModel();
      }

      _currentAIMode = 'api';
      print('✅ Switched back to API mode');

      // Save the preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_mode', 'api');

      return true;
    } catch (e) {
      print('Error switching to API mode: $e');
      return false;
    }
  }

  /// Get current AI mode
  static String getCurrentAIMode() {
    return _currentAIMode;
  }

  /// Check if currently using local AI
  static bool isUsingLocalAI() {
    return _currentAIMode == 'local' && _onDeviceAI != null;
  }

  /// Get local AI model info
  static Future<Map<String, dynamic>> getLocalAIInfo() async {
    if (_onDeviceAI == null) {
      return {'available': false, 'message': 'On-device AI not initialized'};
    }

    final modelInfo = await _onDeviceAI!.getModelInfo();
    return {
      'available': true,
      'model_loaded': modelInfo?['loaded'] ?? false,
      'model_path': modelInfo?['modelPath'],
      'device_capable': true, // We can check this separately if needed
    };
  }

  /// Load AI mode preference on startup
  static Future<void> loadAIModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString('ai_mode') ?? 'api';
      _currentAIMode = savedMode;

      print('📱 Loaded AI mode preference: $_currentAIMode');

      // If local mode was saved, try to initialize on-device AI
      if (_currentAIMode == 'local') {
        _onDeviceAI = OnDeviceAIService();
        // Don't auto-load model, let user choose when they want to use it
      }
    } catch (e) {
      print('Error loading AI mode preference: $e');
      _currentAIMode = 'api'; // Default to API mode on error
    }
  }
}
