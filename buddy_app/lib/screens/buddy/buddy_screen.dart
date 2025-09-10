import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/flow_models.dart';
import '../../services/ai/buddy_service.dart';
import '../../config/settings/theme_config.dart';
import '../../config/settings/settings_manager.dart';
import '../settings/settings_screen.dart';
import 'chat_history_screen.dart';
import '../../widgets/chat/buddy_message_bubble.dart';

class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<BuddyMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  late AnimationController _typingController;

  // AI Mode State
  String _currentAIMode = 'api'; // Default to API mode
  bool _isLoadingMode = false;

  // Real-time sync
  Timer? _syncTimer;
  Timer? _quickSyncTimer;
  bool _isOnline = true;
  DateTime? _lastSyncTime;
  bool _hasDataChanged = false;

  // Custom AI Persona (UI state)
  AIPersona? _activePersona;
  List<AIPersona> _savedPersonas = [];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadChatHistory();
    _loadAIStatus();
    _initPersona();
    _startRealTimeSync();

    // Start subtle animation for empty state
    _typingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    _syncTimer?.cancel();
    _quickSyncTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeSync() async {
    // Get sync interval from settings
    final quickSyncInterval = await SettingsManager.getSyncInterval();
    final autoSyncEnabled = await SettingsManager.getAutoSyncEnabled();

    if (autoSyncEnabled) {
      // Start quick sync for chat data changes
      _quickSyncTimer = Timer.periodic(Duration(seconds: quickSyncInterval), (
        timer,
      ) {
        _quickSyncData();
      });

      // Start regular sync for other data (every 30 seconds)
      _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _syncData();
      });
    }
  }

  Future<void> _quickSyncData() async {
    try {
      // Quick check for chat history changes
      final history = BuddyService.getChatHistory();
      if (history.length != _messages.length) {
        await _reloadChatData();
        setState(() {
          _hasDataChanged = true;
          _lastSyncTime = DateTime.now();
          _isOnline = true;
        });

        // Show brief sync indicator when data changes
        if (_hasDataChanged) {
          _showSyncIndicator();
          // Reset flag after showing indicator
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _hasDataChanged = false;
              });
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isOnline = false;
        _hasDataChanged = false;
      });
    }
  }

  Future<void> _reloadChatData() async {
    final history = BuddyService.getChatHistory();
    _messages = history
        .map(
          (msg) => BuddyMessage(
            id: msg.id,
            content: msg.content,
            role: msg.role,
            timestamp: msg.timestamp,
          ),
        )
        .toList();

    // Auto-scroll to bottom if user was near bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (maxScroll - currentScroll < 100) {
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _syncData() async {
    try {
      // Check network connectivity and sync chat history
      final history = BuddyService.getChatHistory();
      if (history.length != _messages.length) {
        setState(() {
          _messages = history
              .map(
                (msg) => BuddyMessage(
                  id: msg.id,
                  content: msg.content,
                  role: msg.role,
                  timestamp: msg.timestamp,
                ),
              )
              .toList();
          _lastSyncTime = DateTime.now();
          _isOnline = true;
        });
      }
    } catch (e) {
      setState(() {
        _isOnline = false;
      });
    }
  }

  void _loadChatHistory() async {
    // Load chat history from persistent storage first
    await BuddyService.loadChatHistory();

    final history = BuddyService.getChatHistory();
    setState(() {
      _messages = history
          .map(
            (msg) => BuddyMessage(
              id: msg.id,
              content: msg.content,
              role: msg.role,
              timestamp: msg.timestamp,
            ),
          )
          .toList();
    });
  }

  // AI Mode Management Methods
  Future<void> _loadAIStatus() async {
    try {
      final status = await BuddyService.getAIStatus();
      if (mounted) {
        setState(() {
          _currentAIMode = status['mode'] ?? 'api';
        });
      }
    } catch (e) {
      // Silent fail for AI status loading
    }
  }

  Future<void> _switchAIMode() async {
    final newMode = _currentAIMode == 'local' ? 'api' : 'local';

    setState(() {
      _isLoadingMode = true;
    });

    try {
      final success = await BuddyService.switchAIMode(newMode);
      if (success && mounted) {
        setState(() {
          _currentAIMode = newMode;
        });
        _showSnackBar('AI mode switched to ${newMode.toUpperCase()}');
      } else {
        _showSnackBar('Failed to switch AI mode');
      }
    } catch (e) {
      _showSnackBar('Error switching AI mode: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMode = false;
        });
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages = [];
    });
    BuddyService.clearChatHistory();
    _showSnackBar('Chat history cleared');
  }

  void _showChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;

    final userMessage = _controller.text.trim();
    _controller.clear();

    // Add user message
    final userMsg = BuddyMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: userMessage,
      role: BuddyRole.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _isTyping = true;
    });

    _typingController.repeat();
    _scrollToBottom();

    try {
      print('=== BUDDY SCREEN: Sending message ===');
      print('User message: "$userMessage"');

      final result = await BuddyService.askBuddy(userMessage);

      print('=== BUDDY SCREEN: Received result ===');
      print('Full result: $result');
      print('Result success: ${result['success']}');
      print('Result message: ${result['message']}');
      print('Result response: ${result['response']}');

      final response =
          result['response'] ?? // Try 'response' first (like old code)
          result['message'] ?? // Then 'message' as fallback
          'Sorry, I couldn\'t process that.';

      print('=== BUDDY SCREEN: Final response ===');
      print('Response to display: "$response"');

      if (mounted) {
        // Add AI message with typing animation enabled
        final aiMsg = BuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          isTyping: true, // Enable typing animation
        );

        print(
          '=== BUDDY SCREEN: Adding message to UI with typing animation ===',
        );
        print('AI message content: "${aiMsg.content}"');

        setState(() {
          _messages.add(aiMsg);
          _isLoading = false;
          _isTyping = false;
        });

        _typingController.stop();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
        _typingController.stop();
        _showSnackBar('Error: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primaryColor),
    );
  }

  Future<void> _initPersona() async {
    await BuddyService.loadSavedPersonas();
    _activePersona = BuddyService.getActivePersona();
    _savedPersonas = BuddyService.getSavedPersonas();
    if (!mounted) return;
    setState(() {});
  }

  void _onTypingComplete(String messageId) {
    setState(() {
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isTyping: false);
      }
    });
  }

  Future<void> _startNewConversation() async {
    await BuddyService.startNewConversation();
    setState(() {
      _messages.clear();
    });
    _showSnackBar('New conversation started');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back button
        title: Row(
          children: [
            // Animated AI Avatar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.accentColor,
                    Colors.purple.shade300,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isTyping ? Icons.smart_toy_outlined : Icons.smart_toy,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Buddy AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Online status indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (_activePersona != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune,
                                size: 12,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _activePersona!.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        _currentAIMode == 'local'
                            ? Icons.computer
                            : Icons.cloud,
                        size: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentAIMode == 'local' ? 'Local AI' : 'Cloud AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_lastSyncTime != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatSyncTime(_lastSyncTime!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondaryColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: AppTheme.textPrimaryColor),
            onPressed: _showChatHistory,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimaryColor),
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            onSelected: (value) {
              switch (value) {
                case 'create_persona':
                  _showCreatePersonaDialog();
                  break;
                case 'manage_personas':
                  _showManagePersonasDialog();
                  break;
                case 'clear_persona':
                  _clearActivePersona();
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'clear':
                  _clearChat();
                  break;
                case 'switch_mode':
                  _switchAIMode();
                  break;
                case 'history':
                  _showChatHistory();
                  break;
                case 'new_conversation':
                  _startNewConversation();
                  break;
                default:
                  // Handle persona selection
                  if (value.startsWith('persona_')) {
                    final personaId = value.substring(8); // Remove "persona_"
                    _selectPersona(personaId);
                  }
              }
            },
            itemBuilder: (context) => [
              // Show saved personas first
              ..._savedPersonas.map(
                (persona) => PopupMenuItem(
                  value: 'persona_${persona.id}',
                  child: Row(
                    children: [
                      Icon(
                        _activePersona?.id == persona.id
                            ? Icons.check_circle
                            : Icons.person_outline,
                        color: _activePersona?.id == persona.id
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              persona.name,
                              style: TextStyle(
                                color: _activePersona?.id == persona.id
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimaryColor,
                                fontWeight: _activePersona?.id == persona.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (persona.description.isNotEmpty)
                              Text(
                                persona.description.length > 30
                                    ? '${persona.description.substring(0, 30)}...'
                                    : persona.description,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_savedPersonas.isNotEmpty) const PopupMenuDivider(),

              // Persona management
              PopupMenuItem(
                value: 'create_persona',
                child: Row(
                  children: [
                    Icon(Icons.add, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Create New AI',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
              if (_savedPersonas.isNotEmpty)
                PopupMenuItem(
                  value: 'manage_personas',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: AppTheme.textPrimaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Manage AIs',
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                      ),
                    ],
                  ),
                ),
              if (_activePersona != null)
                PopupMenuItem(
                  value: 'clear_persona',
                  child: Row(
                    children: [
                      Icon(Icons.clear, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Clear Active AI',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),

              const PopupMenuDivider(),

              // Original menu items
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'new_conversation',
                child: Row(
                  children: [
                    Icon(
                      Icons.add_comment_outlined,
                      color: AppTheme.textPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Conversation',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: AppTheme.textPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Clear chat',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'switch_mode',
                child: Row(
                  children: [
                    Icon(
                      _isLoadingMode
                          ? Icons.hourglass_empty
                          : (_currentAIMode == 'local'
                                ? Icons.cloud
                                : Icons.computer),
                      color: AppTheme.textPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isLoadingMode
                          ? 'Switching...'
                          : 'Switch to ${_currentAIMode == 'local' ? 'API' : 'Local'}',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: AppTheme.textPrimaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Chat history',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated gradient container with pulsing effect
          AnimatedBuilder(
            animation: _typingController,
            builder: (context, child) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.8),
                      AppTheme.accentColor.withValues(alpha: 0.6),
                      Colors.purple.shade300.withValues(alpha: 0.4),
                    ],
                    stops: [0.3, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(70),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20 + (_typingController.value * 10),
                      spreadRadius: 5 + (_typingController.value * 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 70,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Welcome text with gradient
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
            ).createShader(bounds),
            child: const Text(
              'Hello! I\'m Buddy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your intelligent AI assistant for\nproject management and creative tasks',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          // Feature highlights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureItem(Icons.lightbulb_outline, 'Creative Ideas'),
              _buildFeatureItem(Icons.task_alt, 'Task Planning'),
              _buildFeatureItem(Icons.chat_bubble_outline, 'Smart Chat'),
            ],
          ),
          const SizedBox(height: 40),
          // Animated call-to-action
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.15),
                  AppTheme.accentColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_voice,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ask me anything!',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(BuddyMessage message) {
    return BuddyMessageBubble(
      message: message,
      onTypingComplete: () => _onTypingComplete(message.id),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final value = (_typingController.value + index * 0.3) % 1.0;
        final opacity = value < 0.5 ? value * 2 : 2 - (value * 2);

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.textSecondaryColor.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _controller.text.isNotEmpty
                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                      : AppTheme.borderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  if (_controller.text.isNotEmpty)
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                ),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: '💭 Ask Buddy anything...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                onChanged: (text) {
                  setState(() {}); // Rebuild to update border color
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _controller.text.isNotEmpty
                    ? [AppTheme.primaryColor, AppTheme.accentColor]
                    : [
                        AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                        AppTheme.textSecondaryColor.withValues(alpha: 0.2),
                      ],
              ),
              shape: BoxShape.circle,
              boxShadow: _controller.text.isNotEmpty
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isLoading
                      ? Icons.hourglass_empty
                      : _controller.text.isNotEmpty
                      ? Icons.send_rounded
                      : Icons.mic,
                  key: ValueKey(
                    _isLoading
                        ? 'loading'
                        : _controller.text.isNotEmpty
                        ? 'send'
                        : 'mic',
                  ),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_controller.text.isNotEmpty) {
                        _sendMessage();
                      } else {
                        // Could implement voice input here
                        _showSnackBar('Voice input coming soon!');
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  // Persona management methods
  Future<void> _selectPersona(String personaId) async {
    await BuddyService.setActivePersona(personaId);
    _activePersona = BuddyService.getActivePersona();
    setState(() {});
    _showSnackBar('AI switched to ${_activePersona?.name}');
  }

  Future<void> _clearActivePersona() async {
    final personaName = _activePersona?.name;
    await BuddyService.setActivePersona(null);
    _activePersona = null;
    setState(() {});
    _showSnackBar('Cleared active AI: $personaName');
  }

  Future<void> _showCreatePersonaDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.smart_toy, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Create Custom AI',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'AI Name',
                  hintText: 'e.g., Teacher, Developer, Writer',
                  labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'AI Description & Behavior',
                  hintText:
                      'Describe how this AI should behave, its expertise, tone, etc.',
                  labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                  prefixIcon: Icon(
                    Icons.description,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Be specific! e.g., "Primary school teacher who explains complex topics in simple words"',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter AI name')),
                );
                return;
              }

              await BuddyService.createPersona(name, descCtrl.text.trim());
              _savedPersonas = BuddyService.getSavedPersonas();

              // Auto-select the new persona
              if (_savedPersonas.isNotEmpty) {
                await BuddyService.setActivePersona(_savedPersonas.last.id);
                _activePersona = BuddyService.getActivePersona();
              }

              setState(() {});
              Navigator.of(ctx).pop();
              _showSnackBar('AI "${name}" created and activated!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text(
              'Create & Use',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManagePersonasDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          title: Row(
            children: [
              Icon(Icons.manage_accounts, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Manage Custom AIs',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _savedPersonas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Custom AIs yet',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showCreatePersonaDialog();
                          },
                          icon: Icon(Icons.add, color: AppTheme.primaryColor),
                          label: Text(
                            'Create First AI',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _savedPersonas.length,
                    itemBuilder: (context, index) {
                      final persona = _savedPersonas[index];
                      final isActive = _activePersona?.id == persona.id;

                      return Card(
                        color: isActive
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : AppTheme.backgroundColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? AppTheme.primaryColor
                                : AppTheme.accentColor,
                            child: Icon(
                              isActive ? Icons.check : Icons.smart_toy,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            persona.name,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: persona.description.isNotEmpty
                              ? Text(
                                  persona.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                IconButton(
                                  icon: Icon(
                                    Icons.play_circle_outline,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () async {
                                    await BuddyService.setActivePersona(
                                      persona.id,
                                    );
                                    _activePersona =
                                        BuddyService.getActivePersona();
                                    setState(() {});
                                    setDialogState(() {});
                                    _showSnackBar(
                                      'Switched to ${persona.name}',
                                    );
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Delete ${persona.name}?'),
                                      content: Text(
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await BuddyService.deletePersona(
                                      persona.id,
                                    );
                                    _savedPersonas =
                                        BuddyService.getSavedPersonas();
                                    _activePersona =
                                        BuddyService.getActivePersona();
                                    setState(() {});
                                    setDialogState(() {});
                                    _showSnackBar('${persona.name} deleted');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCreatePersonaDialog();
              },
              icon: Icon(Icons.add, color: AppTheme.primaryColor),
              label: Text(
                'Add New AI',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncTime(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Show sync indicator when data changes
  void _showSyncIndicator() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Syncing new messages...'),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
