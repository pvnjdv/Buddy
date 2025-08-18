import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flow_models.dart';
import '../config/api_config.dart';

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

  // Get authorization token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt');
      print(
        'Auth token retrieved: ${token != null ? "${token.substring(0, 10)}..." : "null"}',
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
    print('Retrieved auth token: ${token?.substring(0, 10)}...');

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

  static void clearChatHistory() {
    _chatHistory.clear();
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
        return message.substring(startIndex).trim();
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
      role: BuddyRole.user,
      timestamp: DateTime.now(),
    );
    _chatHistory.add(userMessage);

    try {
      print('=== SIMPLE ASKBUDDY STARTED ===');
      print('Prompt: "$prompt"');

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

      final requestBody = {
        'prompt': prompt,
        'chat_history': _chatHistory
            .map((msg) => {'role': msg.role.name, 'content': msg.content})
            .toList(),
      };

      print('Sending simplified request...');
      print('Headers: $headers');

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
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
        );
        _chatHistory.add(assistantMessage);

        print('=== SUCCESS - RETURNING RESPONSE ===');
        print('AI Response: $aiResponse');

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
        role: BuddyRole.assistant,
        timestamp: DateTime.now(),
      );
      _chatHistory.add(assistantMessage);

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

  // AI Status and mode methods (for compatibility)
  static Future<Map<String, dynamic>> getAIStatus() async {
    return {
      'status': 'online',
      'mode': 'api',
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  static Future<bool> switchAIMode(String mode) async {
    // This could be used to switch between different AI backends in the future
    return true;
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
}
