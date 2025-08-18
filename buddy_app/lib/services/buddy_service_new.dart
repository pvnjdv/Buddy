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

  // Get authorization token
  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Get auth headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
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

  // Main chat method with persona support
  static Future<Map<String, dynamic>> askBuddy(String prompt) async {
    try {
      final headers = await _getAuthHeaders();
      final requestBody = {
        'prompt': prompt,
        'chat_history': _chatHistory
            .map((msg) => {'role': msg.role, 'content': msg.content})
            .toList(),
      };

      // Add active persona if available
      if (_activePersona != null) {
        requestBody['persona_id'] = _activePersona!.id;
      }

      print('Sending request to: ${ApiConfig.baseUrl}/buddy/ask');
      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/buddy/ask'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buddyResponse = data['response'] as String;

        // Add messages to chat history
        _chatHistory.add(
          FlowBuddyMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: prompt,
            role: BuddyRole.user,
            timestamp: DateTime.now(),
          ),
        );

        _chatHistory.add(
          FlowBuddyMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            content: buddyResponse,
            role: BuddyRole.assistant,
            timestamp: DateTime.now(),
          ),
        );

        // Update active persona info if provided
        if (data['active_persona'] != null) {
          final personaData = data['active_persona'];
          print('Active persona: ${personaData['name']}');
        }

        return {
          'success': true,
          'message': buddyResponse,
          'active_persona': data['active_persona'],
          'flow_detected': data['flow_detected'] ?? false,
          'suggestion': data['suggestion'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
          'error': 'unauthorized',
        };
      } else {
        return {
          'success': false,
          'message': 'Sorry, I\'m having trouble connecting. Please try again.',
          'error': 'server_error',
        };
      }
    } catch (e) {
      print('Error asking Buddy: $e');
      return {
        'success': false,
        'message': _generateFallbackResponse(prompt),
        'error': 'network_error',
      };
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
}
