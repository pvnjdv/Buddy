import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const baseUrl = 'http://192.168.209.3:8000';

class AuthService {
  static Future<bool> requestOtp(String mobile) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile_number': mobile}),
    );
    // ignore: avoid_print
    print('OTP response status: ${response.statusCode}');
    // ignore: avoid_print
    print('OTP response body: ${response.body}');
    return response.statusCode == 200;
  }

  static Future<bool> verifyOtp(String mobile, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile_number': mobile, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', token);
      return true;
    }
    return false;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  static Future<bool> saveProfile(
    String mobile,
    String name,
    String? profilePhoto,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/users/details'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'mobile_number': mobile,
        'name': name,
        'profile_photo': profilePhoto,
      }),
    );
    // ignore: avoid_print
    print('Profile response: ${response.body}');
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> getUserDetails(String mobile) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/users/by-mobile/$mobile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
