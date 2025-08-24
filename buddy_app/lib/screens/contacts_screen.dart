import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contacts_service.dart';
import '../models/flow_models.dart';
import '../config/settings/theme_config.dart';
import 'chat/enhanced_individual_chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  final String currentUserId;

  const ContactsScreen({super.key, required this.currentUserId});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ChatContact> _buddyContacts = [];
  List<Contact> _nonBuddyContacts = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      _hasPermission = await ContactsService.requestPermission();
      if (_hasPermission) {
        _buddyContacts = await ContactsService.getBuddyContacts();
        _nonBuddyContacts = await ContactsService.getNonBuddyContacts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Contacts',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
          ? _buildPermissionDenied()
          : _buildContactsList(),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Contacts Permission Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Allow access to contacts to find friends on Buddy',
            style: TextStyle(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'On Buddy (${_buddyContacts.length})'),
              Tab(text: 'Invite (${_nonBuddyContacts.length})'),
              Tab(text: 'Add New'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBuddyContacts(),
                _buildInviteContacts(),
                _buildAddNewContact(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuddyContacts() {
    if (_buddyContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No contacts on Buddy yet',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite your friends to join Buddy!',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _buddyContacts.length,
      itemBuilder: (context, index) {
        final contact = _buddyContacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: contact.profileImageUrl?.isNotEmpty == true
                ? NetworkImage(contact.profileImageUrl!)
                : null,
            child: contact.profileImageUrl?.isEmpty != false
                ? Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(
            contact.name,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            contact.phoneNumber ?? '',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          trailing: Icon(Icons.chat_outlined, color: AppTheme.primaryColor),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnhancedIndividualChatScreen(
                  contactId: contact.id,
                  contactName: contact.name,
                  currentUserId: widget.currentUserId,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInviteContacts() {
    if (_nonBuddyContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'All your contacts are on Buddy!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _nonBuddyContacts.length,
      itemBuilder: (context, index) {
        final contact = _nonBuddyContacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.textSecondaryColor,
            child: Text(
              contact.displayName.isNotEmpty
                  ? contact.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            contact.displayName,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            contact.phones.isNotEmpty ? contact.phones.first.number : '',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          trailing: ElevatedButton(
            onPressed: () => _inviteContact(contact),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Invite'),
          ),
          onTap: () => _inviteContact(contact),
        );
      },
    );
  }

  Widget _buildAddNewContact() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_add, color: AppTheme.primaryColor),
                  title: Text(
                    'Add Contact',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Add a new contact to your phone',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onTap: _addNewContact,
                ),
                Divider(height: 1, color: AppTheme.borderColor),
                ListTile(
                  leading: Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Scan someone\'s Buddy QR code',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onTap: _scanQRCode,
                ),
                Divider(height: 1, color: AppTheme.borderColor),
                ListTile(
                  leading: Icon(Icons.share, color: AppTheme.primaryColor),
                  title: Text(
                    'Share Buddy',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Invite friends to join Buddy',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onTap: _shareBuddy,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.sync, size: 48, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Sync Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatically find friends who have joined Buddy',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loadContacts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sync Now'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewContact() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final phoneController = TextEditingController();

        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Add New Contact',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter contact name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isNotEmpty && phone.isNotEmpty) {
                  Navigator.pop(context);
                  // TODO: Implement adding contact to phone
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature coming soon!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _scanQRCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Code scanner coming soon!')),
    );
  }

  void _shareBuddy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.share, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Share Buddy',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Text(
          'Hey! I\'m using Buddy for chatting. Download it from the app store and let\'s connect!',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _inviteContact(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.share, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Invite ${contact.displayName}',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Text(
          'Invite ${contact.displayName} to join Buddy and start chatting!',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement share invite link
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite feature coming soon!')),
              );
            },
            child: Text(
              'Send Invite',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
