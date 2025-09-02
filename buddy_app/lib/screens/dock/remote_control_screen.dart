// lib/screens/dock/remote_control_screen.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../models/dock_models.dart';
import '../../services/device_discovery_service.dart';

class RemoteControlScreen extends StatefulWidget {
  final Device targetDevice;
  final Device currentDevice;

  const RemoteControlScreen({
    super.key,
    required this.targetDevice,
    required this.currentDevice,
  });

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen>
    with TickerProviderStateMixin {
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();

  late TabController _tabController;

  bool _isScreenSharing = false;
  bool _isMouseControlEnabled = false;
  bool _isKeyboardControlEnabled = false;

  Uint8List? _currentScreenData;
  double _screenScale = 1.0;
  Offset _screenOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeRemoteControl();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stopAllControlSessions();
    super.dispose();
  }

  void _initializeRemoteControl() {
    // Initialize remote control session
    print(
      '🎮 Starting remote control session with ${widget.targetDevice.name}',
    );
  }

  void _stopAllControlSessions() {
    if (_isScreenSharing) _stopScreenShare();
    if (_isMouseControlEnabled) _disableMouseControl();
    if (_isKeyboardControlEnabled) _disableKeyboardControl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control ${widget.targetDevice.name}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.desktop_windows), text: 'Screen'),
            Tab(icon: Icon(Icons.mouse), text: 'Control'),
            Tab(icon: Icon(Icons.folder), text: 'Files'),
            Tab(icon: Icon(Icons.settings), text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScreenShareTab(),
          _buildControlTab(),
          _buildFileManagerTab(),
          _buildSystemControlTab(),
        ],
      ),
    );
  }

  // Screen Sharing Tab
  Widget _buildScreenShareTab() {
    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isScreenSharing
                    ? _stopScreenShare
                    : _startScreenShare,
                icon: Icon(_isScreenSharing ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isScreenSharing ? 'Stop Sharing' : 'Start Sharing',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScreenSharing ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              if (_isScreenSharing) ...[
                const Text('Quality: '),
                DropdownButton<String>(
                  value: 'Medium',
                  items: const [
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                  ],
                  onChanged: _onQualityChanged,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _fitToScreen,
                  icon: const Icon(Icons.fit_screen),
                  tooltip: 'Fit to Screen',
                ),
                IconButton(
                  onPressed: _actualSize,
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Actual Size',
                ),
              ],
            ],
          ),
        ),
        // Screen Display
        Expanded(
          child: _isScreenSharing
              ? _buildScreenViewer()
              : _buildScreenSharePlaceholder(),
        ),
      ],
    );
  }

  Widget _buildScreenViewer() {
    if (_currentScreenData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading screen data...'),
          ],
        ),
      );
    }

    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.1,
      maxScale: 3.0,
      onInteractionUpdate: _onScreenInteraction,
      child: GestureDetector(
        onTapDown: _onScreenTap,
        onPanUpdate: _onScreenPan,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: Image.memory(
            _currentScreenData!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Error displaying screen'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScreenSharePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.desktop_windows_outlined,
            size: 120,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Screen Sharing Inactive',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            'Start screen sharing to view and control\n${widget.targetDevice.name}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Control Tab
  Widget _buildControlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Input Control',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),

          // Mouse Control
          Card(
            child: ListTile(
              leading: Icon(Icons.mouse, color: Colors.blue),
              title: const Text('Mouse Control'),
              subtitle: Text(_isMouseControlEnabled ? 'Active' : 'Inactive'),
              trailing: Switch(
                value: _isMouseControlEnabled,
                onChanged: _toggleMouseControl,
              ),
            ),
          ),

          // Keyboard Control
          Card(
            child: ListTile(
              leading: Icon(Icons.keyboard, color: Colors.blue),
              title: const Text('Keyboard Control'),
              subtitle: Text(_isKeyboardControlEnabled ? 'Active' : 'Inactive'),
              trailing: Switch(
                value: _isKeyboardControlEnabled,
                onChanged: _toggleKeyboardControl,
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Virtual Keyboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Virtual Keyboard
          _buildVirtualKeyboard(),

          const SizedBox(height: 24),
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          // Quick Action Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionButton('Ctrl+C', Icons.content_copy),
              _buildQuickActionButton('Ctrl+V', Icons.content_paste),
              _buildQuickActionButton('Alt+Tab', Icons.tab),
              _buildQuickActionButton('Win+D', Icons.desktop_windows),
              _buildQuickActionButton('Ctrl+Z', Icons.undo),
              _buildQuickActionButton('Ctrl+Y', Icons.redo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('Esc'),
              _buildKeyButton('F1'),
              _buildKeyButton('F2'),
              _buildKeyButton('F12'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Type here to send to remote device...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: _sendKeyboardInput,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _sendKeyboardInput(''),
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String key) {
    return ElevatedButton(
      onPressed: () => _sendSpecialKey(key),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(60, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(key, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildQuickActionButton(String action, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _executeQuickAction(action),
      icon: Icon(icon, size: 16),
      label: Text(action),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // File Manager Tab
  Widget _buildFileManagerTab() {
    return const Center(child: Text('File Manager - Coming Soon'));
  }

  // System Control Tab
  Widget _buildSystemControlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.power_settings_new,
                    color: Colors.red,
                  ),
                  title: const Text('Shutdown'),
                  subtitle: const Text('Turn off the remote device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _executeSystemCommand('shutdown'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.orange),
                  title: const Text('Restart'),
                  subtitle: const Text('Restart the remote device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _executeSystemCommand('restart'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.blue),
                  title: const Text('Lock Screen'),
                  subtitle: const Text('Lock the remote device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _executeSystemCommand('lock'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen Sharing Methods
  Future<void> _startScreenShare() async {
    try {
      setState(() => _isScreenSharing = true);

      final success = await _discoveryService.sendRemoteControlCommand(
        targetDeviceId: widget.targetDevice.id,
        controlType: 'screen_share',
        action: 'start',
        parameters: {'quality': 'medium'},
      );

      if (success) {
        print('📺 Screen sharing started');
        // TODO: Start receiving screen data
      } else {
        setState(() => _isScreenSharing = false);
        _showErrorSnackBar('Failed to start screen sharing');
      }
    } catch (e) {
      setState(() => _isScreenSharing = false);
      _showErrorSnackBar('Error starting screen sharing: $e');
    }
  }

  Future<void> _stopScreenShare() async {
    try {
      await _discoveryService.sendRemoteControlCommand(
        targetDeviceId: widget.targetDevice.id,
        controlType: 'screen_share',
        action: 'stop',
      );

      setState(() {
        _isScreenSharing = false;
        _currentScreenData = null;
      });

      print('📺 Screen sharing stopped');
    } catch (e) {
      _showErrorSnackBar('Error stopping screen sharing: $e');
    }
  }

  // Input Control Methods
  void _toggleMouseControl(bool enabled) {
    setState(() => _isMouseControlEnabled = enabled);

    if (enabled) {
      _enableMouseControl();
    } else {
      _disableMouseControl();
    }
  }

  void _toggleKeyboardControl(bool enabled) {
    setState(() => _isKeyboardControlEnabled = enabled);

    if (enabled) {
      _enableKeyboardControl();
    } else {
      _disableKeyboardControl();
    }
  }

  Future<void> _enableMouseControl() async {
    await _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'mouse_control',
      action: 'enable',
    );
  }

  Future<void> _disableMouseControl() async {
    await _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'mouse_control',
      action: 'disable',
    );
  }

  Future<void> _enableKeyboardControl() async {
    await _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'keyboard_control',
      action: 'enable',
    );
  }

  Future<void> _disableKeyboardControl() async {
    await _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'keyboard_control',
      action: 'disable',
    );
  }

  // Event Handlers
  void _onQualityChanged(String? quality) {
    // TODO: Change screen sharing quality
  }

  void _fitToScreen() {
    // TODO: Fit screen to viewer
  }

  void _actualSize() {
    // TODO: Show actual screen size
  }

  void _onScreenInteraction(ScaleUpdateDetails details) {
    // TODO: Handle screen interaction for panning/zooming
  }

  void _onScreenTap(TapDownDetails details) {
    if (!_isMouseControlEnabled) return;

    // Send mouse click to remote device
    _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'mouse_control',
      action: 'click',
      parameters: {
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'button': 'left',
      },
    );
  }

  void _onScreenPan(DragUpdateDetails details) {
    if (!_isMouseControlEnabled) return;

    // Send mouse move to remote device
    _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'mouse_control',
      action: 'move',
      parameters: {
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
      },
    );
  }

  void _sendKeyboardInput(String text) {
    if (!_isKeyboardControlEnabled || text.isEmpty) return;

    _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'keyboard_control',
      action: 'type',
      parameters: {'text': text},
    );
  }

  void _sendSpecialKey(String key) {
    if (!_isKeyboardControlEnabled) return;

    _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'keyboard_control',
      action: 'key',
      parameters: {'key': key},
    );
  }

  void _executeQuickAction(String action) {
    if (!_isKeyboardControlEnabled) return;

    _discoveryService.sendRemoteControlCommand(
      targetDeviceId: widget.targetDevice.id,
      controlType: 'keyboard_control',
      action: 'hotkey',
      parameters: {'combination': action},
    );
  }

  Future<void> _executeSystemCommand(String command) async {
    final confirmed = await _confirmSystemCommand(command);
    if (!confirmed) return;

    try {
      await _discoveryService.executeCrossPlatformCommand(
        deviceId: widget.targetDevice.id,
        commandType: 'system',
        command: command,
      );

      _showSuccessSnackBar('$command command sent successfully');
    } catch (e) {
      _showErrorSnackBar('Error executing $command: $e');
    }
  }

  Future<bool> _confirmSystemCommand(String command) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm $command'),
            content: Text(
              'Are you sure you want to $command ${widget.targetDevice.name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(command.toUpperCase()),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
