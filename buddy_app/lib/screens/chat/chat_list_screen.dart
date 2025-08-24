import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/contacts_service.dart';
import '../../services/status_service.dart';
import '../../config/settings/theme_config.dart';
import '../../widgets/new_chat_bottom_sheet.dart';
import '../contacts_screen.dart';
import 'enhanced_individual_chat_screen.dart';
import 'status_viewer_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatContact> _contacts = [];
  bool _loading = true;
  String _searchQuery = '';
  List<StatusItem> _statuses = [];
  String? _currentUserId;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _initProfileAndSocket();
    _loadContacts();
    _loadStatuses();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _initProfileAndSocket() async {
    try {
      // Fetch current user id
      final profile = await UserService.fetchUserProfileFromApi();
      setState(() => _currentUserId = profile?.id);
      // Ensure socket is connected
      final token = await AuthService.getToken();
      if (token != null) {
        EnhancedChatService.connectSocket(token);
        _wsSub ??= EnhancedChatService.socketStream?.listen(_onWsEvent);
      }
    } catch (_) {}
  }

  void _onWsEvent(dynamic event) async {
    try {
      final data = event is String ? jsonDecode(event) : event;
      if (data is Map && (data['type'] == 'message' || data['type'] == 'ack')) {
        final msg = Map<String, dynamic>.from(data['data'] as Map);
        final senderId = msg['sender_id'].toString();
        final receiverId = msg['receiver_id'].toString();
        final otherId = (senderId == _currentUserId) ? receiverId : senderId;
        final lastText = msg['content']?.toString() ?? '';
        final ts = DateTime.tryParse(msg['timestamp']?.toString() ?? '');

        // Find or resolve the contact
        int idx = _contacts.indexWhere((c) => c.id == otherId);
        ChatContact? contact;
        if (idx == -1) {
          contact = await EnhancedChatService.resolveContactById(otherId);
          if (contact != null) {
            contact = ChatContact(
              id: contact.id,
              name: contact.name,
              phoneNumber: contact.phoneNumber,
              email: contact.email,
              profileImageUrl: contact.profileImageUrl,
              lastMessage: lastText,
              lastMessageTime: ts ?? DateTime.now(),
              unreadCount: (senderId != _currentUserId) ? 1 : 0,
              isOnline: contact.isOnline,
            );
            setState(() {
              _contacts.insert(0, contact!);
            });
          }
        } else {
          final existing = _contacts[idx];
          final updated = ChatContact(
            id: existing.id,
            name: existing.name,
            phoneNumber: existing.phoneNumber,
            email: existing.email,
            profileImageUrl: existing.profileImageUrl,
            lastMessage: lastText,
            lastMessageTime: ts ?? existing.lastMessageTime ?? DateTime.now(),
            unreadCount: (senderId != _currentUserId)
                ? (existing.unreadCount + 1)
                : existing.unreadCount,
            isOnline: existing.isOnline,
          );
          setState(() {
            _contacts.removeAt(idx);
            _contacts.insert(0, updated);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final contacts = await EnhancedChatService.getContacts();
      // Already returned sorted by latest from backend
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadStatuses() async {
    try {
      final items = await StatusService.getStatuses();
      if (!mounted) return;
      setState(() => _statuses = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _statuses = []);
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
    final statusBarHeight = 96.0;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: statusBarHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final isYou = index == 0;
                  if (isYou) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: Icon(Icons.add, color: Colors.grey[800]),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(
                          width: 56,
                          child: Text(
                            'My Status',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, height: 1.1),
                          ),
                        ),
                      ],
                    );
                  }

                  final statusIndex = index - 1;
                  final status = statusIndex < _statuses.length
                      ? _statuses[statusIndex]
                      : null;
                  final ringColor = (status?.seen ?? false)
                      ? Colors.grey
                      : const Color(0xFF25D366);
                  final name = status?.userName ?? 'Status';
                  final image = status?.mediaUrl;

                  return GestureDetector(
                    onTap: () {
                      if (status != null && image != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StatusViewerScreen(
                              userName: name,
                              mediaUrl: image,
                            ),
                          ),
                        );
                        setState(() => status.seen = true);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: ringColor, width: 2),
                              ),
                            ),
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: image != null
                                    ? Hero(
                                        tag: image,
                                        child: Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: Colors.grey[300],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 56,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: 1 + (_statuses.isEmpty ? 6 : _statuses.length),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    hintStyle: TextStyle(color: AppTheme.textSecondaryColor),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.textSecondaryColor,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppTheme.textSecondaryColor,
                            ),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            // Chat list
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : _filteredContacts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      color: AppTheme.primaryColor,
                      backgroundColor: AppTheme.surfaceColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return _buildContactTile(contact, index);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showNewChatSheet,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add_comment_outlined),
        ),
      ),
    );
  }

  void _showNewChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NewChatBottomSheet(currentUserId: _currentUserId),
    );
  }

  Widget _buildPhoneNumberTab() {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: 'e.g. 9579348057',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final phone = controller.text.trim();
                    if (phone.isEmpty) return;
                    ChatContact? contact = _contacts.firstWhere(
                      (c) => (c.phoneNumber ?? '') == phone,
                      orElse: () => ChatContact(id: '', name: ''),
                    );
                    if (contact.id.isEmpty) {
                      final resolved =
                          await EnhancedChatService.resolveContactByPhone(
                            phone,
                          );
                      if (resolved != null) {
                        contact = resolved;
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User not found for phone'),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EnhancedIndividualChatScreen(
                          contactId: contact!.id,
                          contactName: contact.name.isNotEmpty
                              ? contact.name
                              : contact.phoneNumber ?? 'Unknown',
                          currentUserId: _currentUserId ?? '',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Start Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactsTab() {
    return FutureBuilder<List<ChatContact>>(
      future: _getQuickContacts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final quickContacts = snapshot.data ?? [];
        if (quickContacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.contacts_outlined,
                  size: 48,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Buddy contacts found',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openContacts();
                  },
                  child: const Text('View all contacts'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16),
          itemCount: quickContacts.length,
          itemBuilder: (context, index) {
            final contact = quickContacts[index];
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
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnhancedIndividualChatScreen(
                      contactId: contact.id,
                      contactName: contact.name,
                      currentUserId: _currentUserId ?? '',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<ChatContact>> _getQuickContacts() async {
    try {
      return await ContactsService.getBuddyContacts();
    } catch (e) {
      return [];
    }
  }

  void _openContacts() async {
    final user = await UserService.getCurrentUserProfile();
    if (mounted && user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactsScreen(currentUserId: user.id),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No contacts found' : 'No chats yet',
            style: TextStyle(
              fontSize: 20,
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Start a conversation with someone',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showNewChatSheet,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactTile(ChatContact contact, int index) {
    final hasUnread = contact.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(contact),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        backgroundImage: contact.profileImageUrl != null
                            ? NetworkImage(contact.profileImageUrl!)
                            : null,
                        child: contact.profileImageUrl == null
                            ? Text(
                                _getInitials(contact.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (contact.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.surfaceColor,
                              width: 2,
                            ),
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
                                color: AppTheme.textPrimaryColor,
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
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondaryColor,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.lastMessage ?? 'No messages yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasUnread
                                    ? AppTheme.textPrimaryColor
                                    : AppTheme.textSecondaryColor,
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
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                contact.unreadCount > 99
                                    ? '99+'
                                    : contact.unreadCount.toString(),
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
          currentUserId: _currentUserId ?? 'current_user',
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
}
