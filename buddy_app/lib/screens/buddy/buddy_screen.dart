import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/flow_models.dart';
import '../../services/ai/buddy_service.dart';
import '../../services/databases/buddy_chat_database.dart';
import '../../config/settings/theme_config.dart';
import '../../config/settings/settings_manager.dart';

import 'chat_history_screen.dart';
import '../../widgets/chat/enhanced_message_bubble.dart';
import '../../services/conversation_export_service.dart';

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
  bool _isSearching = false;
  String _searchQuery = '';
  List<BuddyMessage> _filteredMessages = [];
  late AnimationController _typingController;

  // Cancel token for stopping AI generation
  bool _isCancelled = false;

  // AI Mode State
  String _currentAIMode = 'api'; // Default to API mode
  String _currentInfrastructure = 'cloud'; // 'cloud' or 'local'
  String _currentSubMode =
      'standard'; // Current submode: standard, ask, agent, reasoning, deepthink

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
            role: BuddyRole.values.firstWhere(
              (role) => role.name == msg.role,
              orElse: () => BuddyRole.user,
            ),
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
                  role: BuddyRole.values.firstWhere(
                    (role) => role.name == msg.role,
                    orElse: () => BuddyRole.user,
                  ),
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
              role: BuddyRole.values.firstWhere(
                (role) => role.name == msg.role,
                orElse: () => BuddyRole.user,
              ),
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
          // Determine infrastructure based on mode
          _currentInfrastructure = status['mode'] == 'local'
              ? 'local'
              : 'cloud';
        });
      }
    } catch (e) {
      // Silent fail for AI status loading
    }
  }

  Future<void> _switchAIMode() async {
    // Cycle through AI modes: api -> creative -> local -> api
    String nextMode;
    switch (_currentAIMode) {
      case 'api':
        nextMode = 'local';
        break;
      case 'local':
        nextMode = 'api';
        break;
      default:
        nextMode = 'api';
    }

    await _switchToMode(nextMode);
  }

  // Method to handle mode switching with proper backend integration
  Future<void> _switchToMode(String newMode) async {
    try {
      bool success = false;

      // Handle infrastructure modes (local/api)
      if (newMode == 'local') {
        // Switch to local mode (requires model selection)
        success = await BuddyService.switchToLocalMode();
        if (success) {
          setState(() {
            _currentAIMode = 'local';
            _currentInfrastructure = 'local';
            // Keep current submode when switching infrastructure
          });
          _showSnackBar(
            'Switched to Local • ${_getSubModeName(_currentSubMode)}',
          );
        } else {
          _showSnackBar('Failed to switch to local mode or no model selected');
        }
      } else if (newMode == 'api') {
        // Switch to API mode
        success = await BuddyService.switchAIMode('api');
        if (success) {
          setState(() {
            _currentAIMode = 'api';
            _currentInfrastructure = 'cloud';
            // Keep current submode when switching infrastructure
          });
          _showSnackBar(
            'Switched to Cloud • ${_getSubModeName(_currentSubMode)}',
          );
        } else {
          _showSnackBar('Failed to switch to API mode');
        }
      } else {
        // Handle submode switching (standard, ask, agent, reasoning, deepthink)
        final validSubModes = [
          'standard',
          'ask',
          'agent',
          'reasoning',
          'deepthink',
        ];
        if (validSubModes.contains(newMode)) {
          setState(() {
            _currentSubMode = newMode;
          });
          _showSnackBar(
            'Mode: ${_getSubModeName(newMode)} • ${_currentInfrastructure == 'local' ? 'Local' : 'Cloud'}',
          );
          success = true;
        } else {
          _showSnackBar('Invalid mode: $newMode');
        }
      }
    } catch (e) {
      _showSnackBar('Error switching mode: $e');
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _filteredMessages = [];
      }
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMessages = [];
      } else {
        _filteredMessages = _messages
            .where(
              (message) =>
                  message.content.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _filteredMessages = [];
    });
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

    // Reset cancellation flag
    _isCancelled = false;

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

      final result = await BuddyService.askBuddy(
        userMessage,
        subMode: _currentSubMode,
      );

      // Check if cancelled during the request
      if (_isCancelled) {
        print('=== BUDDY SCREEN: Request was cancelled ===');
        return;
      }

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

      if (mounted && !_isCancelled) {
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
      if (mounted && !_isCancelled) {
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
        _typingController.stop();
        _showSnackBar('Error: $e');
      }
    }
  }

  void _stopGeneration() {
    setState(() {
      _isCancelled = true;
      _isLoading = false;
      _isTyping = false;
    });
    _typingController.stop();
    _showSnackBar('AI response stopped');
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
    try {
      // Start new conversation in database
      await BuddyChatDatabase.startNewConversation();

      // Start new conversation in buddy service
      await BuddyService.startNewConversation();

      // Clear UI messages and reset state
      setState(() {
        _messages.clear();
        _activePersona = null; // Reset persona for new conversation
        _isLoading = false;
        _isTyping = false;
      });

      // Scroll to bottom (no messages to scroll to, but reset scroll position)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      _showSnackBar('✨ New conversation started');
      print('🆕 Started new conversation - UI reset complete');
    } catch (e) {
      print('❌ Error starting new conversation: $e');
      _showSnackBar('Failed to start new conversation');
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('$feature coming soon!'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportChat() async {
    try {
      if (_messages.isEmpty) {
        _showSnackBar('No messages to export');
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Generating PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Generate conversation title
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final title = 'Buddy Chat $dateStr $timeStr';

      // Export to PDF
      await ConversationExportService.exportConversationToPDF(
        messages: _messages,
        context: context,
        title: title,
      );
    } catch (e) {
      _showSnackBar('Error exporting chat: $e');
    }
  }

  Future<void> _importChat() async {
    try {
      // TODO: Implement actual import functionality
      _showSnackBar('Chat import feature coming soon!');
    } catch (e) {
      _showSnackBar('Error importing chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Custom App Bar with Enhanced Buddy Logo
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A202C).withOpacity(0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF4A5568).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Enhanced Buddy Logo (same as home screen)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow effect
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                          // Buddy logo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/icon/app_icon.jpg',
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.smart_toy,
                                  color: Colors.white,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row with status
                          Row(
                            children: [
                              const Text(
                                'Buddy AI',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Online status indicator
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_isOnline
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              if (_activePersona != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.tune,
                                        size: 11,
                                        color: Color(0xFF667EEA),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _activePersona!.name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF667EEA),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Mode indicator below title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getModeColor(
                                    _currentAIMode,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _getModeColor(
                                      _currentAIMode,
                                    ).withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getModeIcon(_currentAIMode),
                                      size: 12,
                                      color: _getModeColor(_currentAIMode),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_getSubModeName(_currentSubMode)} • ${_currentInfrastructure == 'local' ? 'Local' : 'Cloud'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getModeColor(_currentAIMode),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_lastSyncTime != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${_formatSyncTime(_lastSyncTime!)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // New conversation button
                    IconButton(
                      icon: const Icon(Icons.add_comment, color: Colors.white),
                      onPressed: _startNewConversation,
                      tooltip: 'Start New Conversation',
                    ),
                    // History button
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: _showChatHistory,
                      tooltip: 'Chat History',
                    ),
                    // Export button
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _exportChat,
                      tooltip: 'Export as PDF',
                    ),
                    // Search button
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.search_off : Icons.search,
                        color: Colors.white,
                      ),
                      onPressed: _toggleSearch,
                      tooltip: _isSearching
                          ? 'Close Search'
                          : 'Search Messages',
                    ),
                    // Enhanced menu with more features
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: const Color(0xFF1A202C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF4A5568)),
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
                            _showComingSoon('Settings');
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
                          case 'export_chat':
                            _exportChat();
                            break;
                          case 'import_chat':
                            _importChat();
                            break;
                          default:
                            // Handle persona selection
                            if (value.startsWith('persona_')) {
                              final personaId = value.substring(8);
                              _selectPersona(personaId);
                            }
                        }
                      },
                      itemBuilder: (context) => [
                        // Personas Section
                        ..._savedPersonas
                            .map(
                              (persona) => PopupMenuItem(
                                value: 'persona_${persona.id}',
                                child: Row(
                                  children: [
                                    Icon(
                                      _activePersona?.id == persona.id
                                          ? Icons.check_circle
                                          : Icons.person_outline,
                                      color: _activePersona?.id == persona.id
                                          ? const Color(0xFF667EEA)
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            persona.name,
                                            style: TextStyle(
                                              color:
                                                  _activePersona?.id ==
                                                      persona.id
                                                  ? const Color(0xFF667EEA)
                                                  : Colors.white,
                                              fontWeight:
                                                  _activePersona?.id ==
                                                      persona.id
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (persona.description.isNotEmpty)
                                            Text(
                                              persona.description.length > 30
                                                  ? '${persona.description.substring(0, 30)}...'
                                                  : persona.description,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        if (_savedPersonas.isNotEmpty) const PopupMenuDivider(),

                        // Persona management
                        PopupMenuItem(
                          value: 'create_persona',
                          child: Row(
                            children: [
                              const Icon(Icons.add, color: Color(0xFF667EEA)),
                              const SizedBox(width: 8),
                              const Text(
                                'Create New AI',
                                style: TextStyle(color: Color(0xFF667EEA)),
                              ),
                            ],
                          ),
                        ),
                        if (_savedPersonas.isNotEmpty)
                          PopupMenuItem(
                            value: 'manage_personas',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.manage_accounts,
                                  color: Color(0xFF667EEA),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Manage Custom AIs',
                                  style: TextStyle(color: Color(0xFF667EEA)),
                                ),
                              ],
                            ),
                          ),
                        if (_activePersona != null)
                          PopupMenuItem(
                            value: 'clear_persona',
                            child: Row(
                              children: [
                                const Icon(Icons.clear, color: Colors.white54),
                                const SizedBox(width: 8),
                                const Text(
                                  'Clear Active AI',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),

                        const PopupMenuDivider(),

                        // Chat management
                        PopupMenuItem(
                          value: 'new_conversation',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_comment,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'New Conversation',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              const Icon(Icons.clear_all, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Clear Chat',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export_chat',
                          child: Row(
                            children: [
                              const Icon(Icons.download, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Export Chat',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        const PopupMenuDivider(),

                        // Settings and mode switching
                        PopupMenuItem(
                          value: 'switch_mode',
                          child: Row(
                            children: [
                              Icon(
                                _currentInfrastructure == 'local'
                                    ? Icons.cloud
                                    : Icons.computer,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Switch to ${_currentInfrastructure == 'local' ? 'Cloud' : 'Local'} Mode',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Settings',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Search bar (conditionally shown)
            if (_isSearching)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: _performSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search messages...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      Text(
                        '${_filteredMessages.length} results',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSearch,
                        color: Colors.grey,
                      ),
                    ],
                  ],
                ),
              ),
            // Chat area
            Expanded(child: _buildChatArea()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    final displayMessages = _isSearching && _searchQuery.isNotEmpty
        ? _filteredMessages
        : _messages;

    if (displayMessages.isEmpty) {
      if (_isSearching && _searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No messages found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: displayMessages.length + (_isTyping && !_isSearching ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayMessages.length && _isTyping && !_isSearching) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(displayMessages[index]);
      },
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow effect
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                    // Buddy logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        'assets/icon/app_icon.jpg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.smart_toy,
                            size: 70,
                            color: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
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

  Widget _buildMessageBubble(BuddyMessage message) {
    return EnhancedMessageBubble(
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1B263B), Color(0xFF1B263B), Color(0xFF2D3748)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4A5568).withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3748).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _controller.text.isNotEmpty
                          ? const Color(0xFF667EEA).withOpacity(0.5)
                          : const Color(0xFF4A5568).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (_controller.text.isNotEmpty)
                        BoxShadow(
                          color: const Color(0xFF667EEA).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: '💭 Ask Buddy anything...',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 8),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white54,
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
              const SizedBox(width: 8),
              // Mode selector button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3748).withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4A5568).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    _getModeIcon(_currentAIMode),
                    color: _getModeColor(_currentAIMode),
                    size: 20,
                  ),
                  color: const Color(0xFF1A202C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF4A5568)),
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'api':
                        await _switchToMode('api');
                        break;
                      case 'ask':
                        await _switchToMode('ask');
                        break;
                      case 'agent':
                        await _switchToMode('agent');
                        break;
                      case 'reasoning':
                        await _switchToMode('reasoning');
                        break;
                      case 'deep_think':
                        await _switchToMode('deepthink');
                        break;
                      case 'image_generation':
                        _showComingSoon('Image Generation');
                        break;
                      case 'hybrid_beta':
                        _showComingSoon('Hybrid Beta');
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'api',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud,
                            color: _currentInfrastructure == 'cloud'
                                ? const Color(0xFF667EEA)
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Standard Mode',
                            style: TextStyle(
                              color: _currentInfrastructure == 'cloud'
                                  ? const Color(0xFF667EEA)
                                  : Colors.white,
                              fontWeight: _currentInfrastructure == 'cloud'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ask',
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: _currentSubMode == 'ask'
                                ? Colors.orange
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ask Mode',
                            style: TextStyle(
                              color: _currentSubMode == 'ask'
                                  ? Colors.orange
                                  : Colors.white,
                              fontWeight: _currentSubMode == 'ask'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'agent',
                      child: Row(
                        children: [
                          Icon(
                            Icons.android,
                            color: _currentSubMode == 'agent'
                                ? Colors.green
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Agent Mode',
                            style: TextStyle(
                              color: _currentSubMode == 'agent'
                                  ? Colors.green
                                  : Colors.white,
                              fontWeight: _currentSubMode == 'agent'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reasoning',
                      child: Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            color: _currentAIMode == 'reasoning'
                                ? Colors.purple
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reasoning Mode',
                            style: TextStyle(
                              color: _currentAIMode == 'reasoning'
                                  ? Colors.purple
                                  : Colors.white,
                              fontWeight: _currentAIMode == 'reasoning'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'deep_think',
                      child: Row(
                        children: [
                          Icon(
                            Icons.psychology_alt,
                            color: _currentSubMode == 'deepthink'
                                ? Colors.indigo
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Deep Think Mode',
                            style: TextStyle(
                              color: _currentSubMode == 'deepthink'
                                  ? Colors.indigo
                                  : Colors.white,
                              fontWeight: _currentSubMode == 'deepthink'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'image_generation',
                      child: Row(
                        children: [
                          const Icon(Icons.image, color: Colors.white54),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Image Generation',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SOON',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'hybrid_beta',
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white54),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Hybrid Beta',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BETA',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Send/Mic button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _controller.text.isNotEmpty
                        ? [const Color(0xFF667EEA), const Color(0xFF764BA2)]
                        : [Colors.white24, Colors.white12],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _controller.text.isNotEmpty
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
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
                      _isLoading || _isTyping
                          ? Icons.stop_rounded
                          : _controller.text.isNotEmpty
                          ? Icons.send_rounded
                          : Icons.mic,
                      key: ValueKey(
                        _isLoading || _isTyping
                            ? 'stop'
                            : _controller.text.isNotEmpty
                            ? 'send'
                            : 'mic',
                      ),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    if (_isLoading || _isTyping) {
                      _stopGeneration();
                    } else if (_controller.text.isNotEmpty) {
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
    final expertiseCtrl = TextEditingController();
    final toneCtrl = TextEditingController();
    String selectedCategory = 'General';

    final categories = [
      'General',
      'Education',
      'Programming',
      'Creative Writing',
      'Business',
      'Science',
      'Health',
      'Lifestyle',
      'Entertainment',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.borderColor),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Custom AI',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Design your perfect AI assistant',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Name Section
                  Text(
                    'AI Identity',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'AI Name *',
                      hintText:
                          'e.g., Professor Alex, Code Mentor, Creative Writer',
                      labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                      prefixIcon: Icon(
                        Icons.badge,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Selection
                  Text(
                    'Category',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryColor,
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Expertise Section
                  Text(
                    'Expertise & Skills',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expertiseCtrl,
                    decoration: InputDecoration(
                      labelText: 'Areas of Expertise',
                      hintText:
                          'e.g., Python, Machine Learning, Creative Writing',
                      labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                      prefixIcon: Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Personality & Tone
                  Text(
                    'Personality & Communication',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Communication Style',
                      hintText:
                          'e.g., Friendly, Professional, Encouraging, Detailed',
                      labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                      prefixIcon: Icon(
                        Icons.chat,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detailed Description
                  Text(
                    'Detailed Behavior Description',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'How should this AI behave?',
                      hintText:
                          'Describe the AI\'s role, expertise, tone, and how it should help users. Be specific about its personality and approach.',
                      labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: Icon(
                          Icons.description,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tips Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pro Tips',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Be specific about the AI\'s role and expertise\n'
                          '• Define the communication style you prefer\n'
                          '• Include examples of how it should respond\n'
                          '• Set clear boundaries for the AI\'s behavior',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            ElevatedButton.icon(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter AI name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Build comprehensive description
                String fullDescription = '';
                if (descCtrl.text.trim().isNotEmpty) {
                  fullDescription = descCtrl.text.trim();
                }
                if (expertiseCtrl.text.trim().isNotEmpty) {
                  fullDescription +=
                      '\n\nExpertise: ${expertiseCtrl.text.trim()}';
                }
                if (toneCtrl.text.trim().isNotEmpty) {
                  fullDescription +=
                      '\n\nCommunication Style: ${toneCtrl.text.trim()}';
                }
                fullDescription += '\n\nCategory: $selectedCategory';

                await BuddyService.createPersona(name, fullDescription);
                _savedPersonas = BuddyService.getSavedPersonas();

                // Auto-select the new persona
                if (_savedPersonas.isNotEmpty) {
                  await BuddyService.setActivePersona(_savedPersonas.last.id);
                  _activePersona = BuddyService.getActivePersona();
                }

                setState(() {});
                Navigator.of(ctx).pop();
                _showSnackBar('🎉 AI "$name" created and activated!');
              },
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text(
                'Create & Activate',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
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
        ),
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

  // Helper method for category icons
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Education':
        return Icons.school;
      case 'Programming':
        return Icons.code;
      case 'Creative Writing':
        return Icons.edit;
      case 'Business':
        return Icons.business;
      case 'Science':
        return Icons.science;
      case 'Health':
        return Icons.health_and_safety;
      case 'Lifestyle':
        return Icons.favorite;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.star;
    }
  }

  // Helper methods for mode icons and colors
  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'local':
        return Icons.computer;
      case 'ask':
        return Icons.help_outline;
      case 'agent':
        return Icons.android;
      case 'reasoning':
        return Icons.psychology;
      case 'deep_think':
        return Icons.psychology_alt;
      case 'image_generation':
        return Icons.image;
      case 'hybrid_beta':
        return Icons.auto_awesome;
      default:
        return Icons.cloud;
    }
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'local':
        return Colors.amber;
      case 'ask':
        return Colors.orange;
      case 'agent':
        return Colors.green;
      case 'reasoning':
        return Colors.purple;
      case 'deep_think':
        return Colors.indigo;
      case 'image_generation':
        return Colors.pink;
      case 'hybrid_beta':
        return Colors.cyan;
      default:
        return const Color(0xFF667EEA);
    }
  }

  String _getSubModeName(String subMode) {
    switch (subMode) {
      case 'standard':
        return 'Standard';
      case 'ask':
        return 'Ask';
      case 'agent':
        return 'Agent';
      case 'reasoning':
        return 'Reasoning';
      case 'deepthink':
        return 'Deep Think';
      default:
        return subMode;
    }
  }
}
