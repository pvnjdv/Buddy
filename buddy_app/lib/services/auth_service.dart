import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static Future<bool> requestOtp(String mobile) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/request-otp'),
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
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile_number': mobile, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final accessToken = responseData['access_token'];
      final refreshToken = responseData['refresh_token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('mobile_number', mobile);

      return true;
    }
    return false;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<String?> getMobileNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mobile_number');
  }

  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAccessToken = responseData['access_token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', newAccessToken);
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error refreshing token: $e');
    }
    return false;
  }

  static Future<bool> isLoggedIn() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    // Try to refresh access token
    return await refreshAccessToken();
  }

  static Future<void> logout() async {
    final mobile = await getMobileNumber();
    if (mobile != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mobile_number': mobile}),
        );
      } catch (e) {
        // ignore: avoid_print
        print('Error during logout: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('refresh_token');
    await prefs.remove('mobile_number');
  }

  static Future<void> suspendRefreshToken() async {
    final mobile = await getMobileNumber();
    if (mobile != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mobile_number': mobile}),
        );
      } catch (e) {
        // ignore: avoid_print
        print('Error suspending refresh token: $e');
      }
    }

    // Only remove refresh token, keep other data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('refresh_token');
    await prefs.remove('jwt');
  }

  static Future<bool> saveProfile(
    String mobile,
    String name,
    String? profilePhoto,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/users/details'),
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
      Uri.parse('${ApiConfig.baseUrl}/users/by-mobile/$mobile'),
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
