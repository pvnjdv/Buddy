import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

class TaskService {
  static Future<List<dynamic>> getTasks() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/tasks/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<bool> createTask(String title, String description) async {
    final token = await AuthService.getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tasks/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title, 'description': description}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> createTaskFromTimeline(
    Map<String, dynamic> timelineData,
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tasks/create-from-timeline'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'timeline_data': timelineData}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error creating task from timeline: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getTaskProgress(String taskId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/tasks/$taskId/progress'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting task progress: $e');
      return null;
    }
  }

  static Future<bool> updateCheckpoint(
    String taskId,
    String checkpoint,
    bool completed,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/tasks/$taskId/checkpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'checkpoint': checkpoint, 'completed': completed}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating checkpoint: $e');
      return false;
    }
  }
}
