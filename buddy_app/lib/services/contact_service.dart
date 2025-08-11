import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';
import '../config/api_config.dart';

class ContactService {
  // Request permission to access contacts
  static Future<bool> requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }

  // Get device contacts
  static Future<List<Contact>> getDeviceContacts() async {
    try {
      // Request permission first
      bool hasPermission = await requestContactPermission();
      if (!hasPermission) {
        print('Contact permission denied');
        return [];
      }

      // Fetch contacts from device
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // Filter contacts with phone numbers
      List<Contact> contactsWithPhones = contacts
          .where(
            (contact) =>
                contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
          )
          .toList();

      // Sort by display name
      contactsWithPhones.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      return contactsWithPhones;
    } catch (e) {
      print('Error fetching device contacts: $e');
      return [];
    }
  }

  // Search device contacts
  static Future<List<Contact>> searchDeviceContacts(String query) async {
    try {
      if (query.isEmpty) return await getDeviceContacts();

      List<Contact> allContacts = await getDeviceContacts();
      String searchQuery = query.toLowerCase();

      return allContacts.where((contact) {
        String name = contact.displayName.toLowerCase();
        bool nameMatch = name.contains(searchQuery);

        bool phoneMatch = contact.phones.any(
          (phone) =>
              phone.number.replaceAll(RegExp(r'\D'), '').contains(searchQuery),
        );

        return nameMatch || phoneMatch;
      }).toList();
    } catch (e) {
      print('Error searching device contacts: $e');
      return [];
    }
  }

  // Format phone number for consistent comparison
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // Handle different phone number formats
    if (digits.length == 10) {
      // Add country code if missing (assuming India +91)
      return '+91$digits';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    } else if (digits.length == 13 && digits.startsWith('91')) {
      return '+${digits.substring(1)}';
    }

    return phone;
  }

  // Check if a contact exists in backend by phone number
  static Future<Map<String, dynamic>?> findBackendUserByPhone(
    String phoneNumber,
  ) async {
    try {
      String formattedPhone = formatPhoneNumber(phoneNumber);

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/users/by-mobile/${Uri.encodeComponent(formattedPhone)}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error finding backend user by phone: $e');
      return null;
    }
  }

  // Combine device contacts with backend user data
  static Future<List<Map<String, dynamic>>> getCombinedContacts() async {
    try {
      List<Contact> deviceContacts = await getDeviceContacts();
      List<Map<String, dynamic>> combinedContacts = [];

      for (Contact contact in deviceContacts) {
        if (contact.phones.isNotEmpty) {
          String phoneNumber = contact.phones.first.number;

          // Check if this contact exists in backend
          Map<String, dynamic>? backendUser = await findBackendUserByPhone(
            phoneNumber,
          );

          Map<String, dynamic> combinedContact = {
            'id': contact.id,
            'display_name': contact.displayName,
            'phone_number': phoneNumber,
            'photo': contact.photo,
            'is_buddy_user': backendUser != null,
            'backend_user_id': backendUser?['id'],
            'backend_user_name': backendUser?['name'],
          };

          combinedContacts.add(combinedContact);
        }
      }

      return combinedContacts;
    } catch (e) {
      print('Error getting combined contacts: $e');
      return [];
    }
  }

  // Get all users/contacts from backend
  static Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/'),
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
        Uri.parse(
          '${ApiConfig.baseUrl}/users/search?q=${Uri.encodeComponent(query)}',
        ),
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
        Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
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
