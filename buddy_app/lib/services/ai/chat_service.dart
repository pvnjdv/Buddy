import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../auth/http_interceptor.dart';
import '../../config/api_config.dart';

class ChatService {
  static Future<List<dynamic>> getChats() async {
    final response = await HttpInterceptor.get('${ApiConfig.baseUrl}/chats/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getChatMessages(String otherUserId) async {
    final response = await HttpInterceptor.get(
      '${ApiConfig.baseUrl}/chats/$otherUserId/messages',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getChatContacts() async {
    final response = await HttpInterceptor.get(
      '${ApiConfig.baseUrl}/chats/contacts',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<bool> sendMessage(String receiverId, String content) async {
    final token = await AuthService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'receiver_id': receiverId, 'content': content}),
    );
    return response.statusCode == 200;
  }

  // Send collaboration request as chat message
  static Future<bool> sendCollaborationRequest({
    required String receiverId,
    required Map<String, dynamic> collaborationData,
  }) async {
    final response = await HttpInterceptor.post(
      '${ApiConfig.baseUrl}/chats/send',
      body: jsonEncode({
        'receiver_id': receiverId,
        'content': 'Collaboration Request',
        'message_type': 'collaboration_request',
        'collaboration_data': collaborationData,
      }),
    );
    return response.statusCode == 200;
  }

  // Respond to collaboration request in chat
  static Future<bool> respondToCollaborationRequest({
    required String messageId,
    required String response, // 'accepted' or 'rejected'
  }) async {
    final httpResponse = await HttpInterceptor.post(
      '${ApiConfig.baseUrl}/chats/collaboration-response',
      body: jsonEncode({'message_id': messageId, 'response': response}),
    );
    return httpResponse.statusCode == 200;
  }
}
