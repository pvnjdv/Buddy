import 'package:flutter/material.dart';
import '../models/flow_models.dart';
import '../services/contacts_service.dart';
import '../config/theme_config.dart';
import '../screens/chat/enhanced_individual_chat_screen.dart';
import '../screens/contacts_screen.dart';

class NewChatBottomSheet extends StatefulWidget {
  final String? currentUserId;

  const NewChatBottomSheet({super.key, this.currentUserId});

  @override
  State<NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<NewChatBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatContact> _allBuddyUsers = [];
  List<ChatContact> _filteredUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBuddyUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuddyUsers() async {
    setState(() => _loading = true);
    try {
      _allBuddyUsers = await ContactsService.getAllBuddyUsers();
      _filteredUsers = List.from(_allBuddyUsers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
    setState(() => _loading = false);
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allBuddyUsers);
      } else {
        _filteredUsers = _allBuddyUsers.where((user) {
          final nameMatch = user.name.toLowerCase().contains(query);
          final phoneMatch = (user.phoneNumber ?? '').contains(query);
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.add_comment_outlined, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Start new chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openContacts();
                },
                icon: Icon(
                  Icons.contacts_outlined,
                  color: AppTheme.primaryColor,
                ),
                tooltip: 'Manage contacts',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or phone number',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddByPhoneDialog,
                  icon: const Icon(Icons.phone),
                  label: const Text('Add by Phone'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showQRScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Users list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildUserTile(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ChatContact user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor,
        backgroundImage: user.profileImageUrl?.isNotEmpty == true
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl?.isEmpty != false
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(
        user.name.isNotEmpty ? user.name : 'User ${user.id}',
        style: TextStyle(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        user.phoneNumber ?? '',
        style: TextStyle(color: AppTheme.textSecondaryColor),
      ),
      trailing: Icon(Icons.chat_outlined, color: AppTheme.primaryColor),
      onTap: () => _startChat(user),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No users found' : 'No Buddy users yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different search term'
                : 'Invite your friends to join Buddy!',
            style: TextStyle(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openContacts();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Friends'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _startChat(ChatContact user) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedIndividualChatScreen(
          contactId: user.id,
          contactName: user.name.isNotEmpty
              ? user.name
              : user.phoneNumber ?? 'User',
          currentUserId: widget.currentUserId ?? '',
        ),
      ),
    );
  }

  void _showAddByPhoneDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Add by Phone',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: 'e.g. 9579348057',
          ),
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
              final phone = controller.text.trim();
              if (phone.isEmpty) return;

              Navigator.pop(context); // Close dialog

              try {
                final user = await ContactsService.findBuddyUserByPhone(phone);
                if (user != null) {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnhancedIndividualChatScreen(
                        contactId: user.id,
                        contactName: user.name.isNotEmpty ? user.name : phone,
                        currentUserId: widget.currentUserId ?? '',
                      ),
                    ),
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User not found with this phone number'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Find'),
          ),
        ],
      ),
    );
  }

  void _showQRScanner() {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR Scanner coming soon!')));
  }

  void _openContacts() {
    if (widget.currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactsScreen(currentUserId: widget.currentUserId!),
        ),
      );
    }
  }
}
