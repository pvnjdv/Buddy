import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../config/api_config.dart';

class UserProfile {
  final String id;
  final String name;
  final String mobileNumber;
  final String? profilePhoto;
  final String? profession;
  final DateTime? lastSeen;
  final bool isOnline;

  UserProfile({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.profilePhoto,
    this.profession,
    this.lastSeen,
    this.isOnline = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString().trim(),
      mobileNumber: json['mobile_number'] ?? '',
      profilePhoto: json['profile_photo'],
      profession: json['profession']?.toString().trim(),
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'])
          : null,
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'profile_photo': profilePhoto,
      'profession': profession,
      'last_seen': lastSeen?.toIso8601String(),
      'is_online': isOnline,
    };
  }
}

class UserService {
  static const String _userProfileKey = 'user_profile';

  // Get current user profile from local storage or API
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      // First try to fetch from API to get latest data
      final apiProfile = await fetchUserProfileFromApi();
      if (apiProfile != null) {
        return apiProfile;
      }

      // Fallback to cached profile
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString(_userProfileKey);
      if (cachedProfile != null) {
        final json = jsonDecode(cachedProfile);
        return UserProfile.fromJson(json);
      }

      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      // Try cached profile as fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedProfile = prefs.getString(_userProfileKey);
        if (cachedProfile != null) {
          final json = jsonDecode(cachedProfile);
          return UserProfile.fromJson(json);
        }
      } catch (cacheError) {
        print('Error getting cached profile: $cacheError');
      }
      return null;
    }
  }

  // Fetch user profile from API
  static Future<UserProfile?> fetchUserProfileFromApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // FIX: use the same JWT key used across the app
      final accessToken = prefs.getString('jwt');

      if (accessToken == null) {
        print('UserService: No access token found');
        throw Exception('No access token found');
      }

      print('UserService: Fetching profile from API...');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('UserService: API response status: ${response.statusCode}');
      print('UserService: API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfile.fromJson(data);

        // Cache the profile locally
        await _cacheUserProfile(profile);

        print(
          'UserService: Successfully fetched and cached profile: ${profile.name}',
        );
        return profile;
      } else {
        print('UserService: Failed to fetch profile: ${response.statusCode}');
        throw Exception('Failed to fetch user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile from API: $e');
      return null;
    }
  }

  // Update user profile
  static Future<bool> updateUserProfile({
    String? name,
    File? profileImage,
    String? profession,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // FIX: use JWT key
      final accessToken = prefs.getString('jwt');

      if (accessToken == null) {
        throw Exception('No access token found');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/users/profile'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      if (name != null) {
        request.fields['name'] = name;
      }

      if (profession != null) {
        request.fields['profession'] = profession;
      }

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', profileImage.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        final updatedProfile = UserProfile.fromJson(data);

        // Update cached profile
        await _cacheUserProfile(updatedProfile);

        return true;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Delete profile image
  static Future<bool> deleteProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // FIX: use JWT key
      final accessToken = prefs.getString('jwt');

      if (accessToken == null) {
        throw Exception('No access token found');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/user/profile/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Update cached profile to remove image
        final currentProfile = await getCurrentUserProfile();
        if (currentProfile != null) {
          final updatedProfile = UserProfile(
            id: currentProfile.id,
            name: currentProfile.name,
            mobileNumber: currentProfile.mobileNumber,
            profilePhoto: null,
            lastSeen: currentProfile.lastSeen,
            isOnline: currentProfile.isOnline,
          );
          await _cacheUserProfile(updatedProfile);
        }

        return true;
      } else {
        throw Exception(
          'Failed to delete profile image: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  // Cache user profile locally
  static Future<void> _cacheUserProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
    } catch (e) {
      print('Error caching user profile: $e');
    }
  }

  // Clear cached profile (useful for logout)
  static Future<void> clearCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userProfileKey);
    } catch (e) {
      print('Error clearing cached profile: $e');
    }
  }

  // Get user initials for avatar
  static String getInitials(String name) {
    if (name.trim().isEmpty) return 'U';

    final parts = name
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  // Mock data for development - remove this when you have real API
  static Future<UserProfile> getMockUserProfile() async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    return UserProfile(
      id: 'user_123',
      name: 'Alex Johnson',
      mobileNumber: '+1 (555) 123-4567',
      profilePhoto: null, // No image for demo
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      isOnline: true,
    );
  }

  // Update user profile (simulated, not used now)
  static Future<void> updateProfile({
    String? name,
    String? bio,
    File? profilePhoto,
    String? profession,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // FIX: use JWT key to keep consistency if ever used
      final token = prefs.getString('jwt');
      if (token == null) {
        throw Exception('No authentication token found');
      }
      await Future.delayed(const Duration(seconds: 1));
      print('Profile updated successfully');
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile');
    }
  }
}
