import 'package:flutter/material.dart';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/auth_service.dart';
import 'enhanced_individual_chat_screen.dart';
import 'user_profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatContact> _contacts = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final contacts = await EnhancedChatService.getContacts();
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    }
  }

  List<ChatContact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (contact.phoneNumber?.contains(_searchQuery) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        backgroundColor: const Color(0xFF25D366),
        elevation: 1,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _showSearch),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'new_group':
                  _showNewGroupDialog();
                  break;
                case 'refresh':
                  _loadContacts();
                  break;
                case 'profile':
                  _showProfile();
                  break;
                case 'refresh_token':
                  _refreshAccessToken();
                  break;
                case 'create_group':
                  _createGroup();
                  break;
                case 'suspend':
                  _suspendRefreshToken();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Chat specific options
              const PopupMenuItem(
                value: 'new_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('New group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              // Global options
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh_token',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Refresh Token'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Create Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Suspend Session'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
              ),
            )
          : _filteredContacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No contacts found'
                        : 'No chats yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'Start a conversation with someone',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadContacts,
              color: const Color(0xFF25D366),
              child: ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  return _buildContactTile(contact);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildContactTile(ChatContact contact) {
    final hasUnread = contact.unreadCount > 0;

    return InkWell(
      onTap: () => _openChat(contact),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Profile Picture
            Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF25D366),
                  backgroundImage: contact.profileImageUrl != null
                      ? NetworkImage(contact.profileImageUrl!)
                      : null,
                  child: contact.profileImageUrl == null
                      ? Text(
                          _getInitials(contact.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (contact.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Contact Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.lastMessageTime != null)
                        Text(
                          _formatTime(contact.lastMessageTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? const Color(0xFF25D366)
                                : Colors.grey[600],
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.lastMessage ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            contact.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(ChatContact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedIndividualChatScreen(
          contactId: contact.id,
          contactName: contact.name,
          currentUserId: 'current_user', // Replace with actual user ID
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) {
      return 'U';
    }

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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today - show time
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showSearch() {
    showSearch(context: context, delegate: ContactSearchDelegate(_contacts));
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: const Text('This feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Group'),
        content: const Text('Group chat feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserProfileScreen()),
    );
  }

  void _refreshAccessToken() async {
    final success = await AuthService.refreshAccessToken();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token refreshed successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to refresh token')));
    }
  }

  Future<void> _createGroup() async {
    try {
      final result = await Navigator.pushNamed(context, '/create_group');
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
    }
  }

  Future<void> _suspendRefreshToken() async {
    await AuthService.suspendRefreshToken();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session suspended. You will be logged out in 30 minutes unless you refresh.',
        ),
      ),
    );
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout completely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
}

class ContactSearchDelegate extends SearchDelegate<ChatContact?> {
  final List<ChatContact> contacts;

  ContactSearchDelegate(this.contacts);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredContacts = contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(query.toLowerCase()) ||
              (contact.phoneNumber?.contains(query) ?? false),
        )
        .toList();

    return ListView.builder(
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = filteredContacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF25D366),
            backgroundImage: contact.profileImageUrl != null
                ? NetworkImage(contact.profileImageUrl!)
                : null,
            child: contact.profileImageUrl == null
                ? Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(contact.name),
          subtitle: Text(contact.phoneNumber ?? ''),
          onTap: () => close(context, contact),
        );
      },
    );
  }
}
