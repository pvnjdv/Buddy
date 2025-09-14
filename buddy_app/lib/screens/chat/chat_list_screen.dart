import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../../models/flow_models.dart';
import '../../services/flow_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/user_service.dart';
import '../../services/sync/status_service.dart';
import '../../widgets/new_chat_bottom_sheet.dart';
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
            backgroundColor: Colors.red,
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
    return _contacts;
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = 90.0; // Reduced height to bring closer to app bar
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF2D3748)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Status bar section - removed extra spacing
            Container(
              height: statusBarHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1A202C).withOpacity(0.7),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF4A5568).withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4, // Reduced vertical padding for tighter spacing
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                            border: Border.all(
                              color: const Color(0xFF667EEA),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: Icon(Icons.add, color: Colors.white),
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
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              color: Colors.white,
                            ),
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
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              color: Colors.white70,
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
            const SizedBox(
              height: 8,
            ), // Reduced space between status and chat list for tighter layout
            // Chat list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF667EEA),
                      ),
                    )
                  : _filteredContacts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      color: const Color(0xFF667EEA),
                      backgroundColor: const Color(0xFF1A202C),
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
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showNewChatSheet,
          backgroundColor: Colors.transparent,
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
      backgroundColor: const Color(0xFF1A202C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NewChatBottomSheet(currentUserId: _currentUserId),
    );
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
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.2),
                  const Color(0xFF764BA2).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Color(0xFF667EEA),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No chats yet',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with someone',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _showNewChatSheet,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(ChatContact contact, int index) {
    final hasUnread = contact.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A5568).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
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
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1A202C),
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
                                color: Colors.white,
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
                                    ? const Color(0xFF667EEA)
                                    : Colors.grey[400],
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
                                    ? Colors.white
                                    : Colors.grey[400],
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
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                ),
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
