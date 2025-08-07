import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ContactService {
  static const String baseUrl = 'http://192.168.209.3:8000';

  // Get all users/contacts from backend
  static Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      print(
        'Error: Status code ${response.statusCode}, body: ${response.body}',
      );
      return [];
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }

  // Search contacts by name or phone
  static Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/search?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      print(
        'Error: Status code ${response.statusCode}, body: ${response.body}',
      );
      return [];
    } catch (e) {
      print('Error searching contacts: $e');
      return [];
    }
  }

  // Get user profile by ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
