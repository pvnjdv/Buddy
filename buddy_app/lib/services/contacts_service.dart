import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/flow_models.dart';
import 'flow_service.dart';

class ContactsService {
  static Future<bool> requestPermission() async {
    final permission = await Permission.contacts.request();
    return permission.isGranted;
  }

  static Future<List<Contact>> getPhoneContacts() async {
    if (!await requestPermission()) {
      throw Exception('Contacts permission denied');
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    return contacts
        .where(
          (contact) =>
              contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
        )
        .toList();
  }

  static Future<List<ChatContact>> getBuddyContacts() async {
    final phoneContacts = await getPhoneContacts();
    final buddyUsers = await EnhancedChatService.getAllUsers();

    final buddyContacts = <ChatContact>[];

    for (final contact in phoneContacts) {
      for (final phone in contact.phones) {
        final cleanPhone = _cleanPhoneNumber(phone.number);
        final buddyUser = buddyUsers.firstWhere(
          (user) => _cleanPhoneNumber(user.phoneNumber ?? '') == cleanPhone,
          orElse: () => ChatContact(
            id: '',
            name: '',
            phoneNumber: '',
            lastMessage: '',
            lastMessageTime: DateTime.now(),
          ),
        );

        if (buddyUser.id.isNotEmpty) {
          buddyContacts.add(
            ChatContact(
              id: buddyUser.id,
              name: contact.displayName.isNotEmpty
                  ? contact.displayName
                  : (buddyUser.name.isNotEmpty ? buddyUser.name : phone.number),
              phoneNumber: phone.number,
              profileImageUrl: buddyUser.profileImageUrl,
              lastMessage: buddyUser.lastMessage,
              lastMessageTime: buddyUser.lastMessageTime ?? DateTime.now(),
            ),
          );
          break; // Only add once per contact
        }
      }
    }

    return buddyContacts;
  }

  static Future<List<Contact>> getNonBuddyContacts() async {
    final phoneContacts = await getPhoneContacts();
    final buddyUsers = await EnhancedChatService.getAllUsers();

    final nonBuddyContacts = <Contact>[];

    for (final contact in phoneContacts) {
      bool isBuddyUser = false;
      for (final phone in contact.phones) {
        final cleanPhone = _cleanPhoneNumber(phone.number);
        final hasBuddy = buddyUsers.any(
          (user) => _cleanPhoneNumber(user.phoneNumber ?? '') == cleanPhone,
        );
        if (hasBuddy) {
          isBuddyUser = true;
          break;
        }
      }
      if (!isBuddyUser) {
        nonBuddyContacts.add(contact);
      }
    }

    return nonBuddyContacts;
  }

  static String _cleanPhoneNumber(String phone) {
    // Remove all non-digits and normalize
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Handle Indian numbers - remove leading 91 if present and length > 10
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }

    // Handle leading zeros
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }

  static Future<List<ChatContact>> getAllBuddyUsers() async {
    return await EnhancedChatService.getAllUsers();
  }

  static Future<ChatContact?> findBuddyUserByPhone(String phoneNumber) async {
    final buddyUsers = await getAllBuddyUsers();
    final cleanPhone = _cleanPhoneNumber(phoneNumber);

    return buddyUsers
            .firstWhere(
              (user) => _cleanPhoneNumber(user.phoneNumber ?? '') == cleanPhone,
              orElse: () => ChatContact(
                id: '',
                name: '',
                phoneNumber: '',
                lastMessage: '',
                lastMessageTime: DateTime.now(),
              ),
            )
            .id
            .isNotEmpty
        ? buddyUsers.firstWhere(
            (user) => _cleanPhoneNumber(user.phoneNumber ?? '') == cleanPhone,
          )
        : null;
  }
}
