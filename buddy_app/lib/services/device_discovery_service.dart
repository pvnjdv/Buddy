// lib/services/device_discovery_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/dock_models.dart';
import '../services/dock_service.dart';
import '../config/api_config.dart';

class DeviceDiscoveryService {
  static final DeviceDiscoveryService _instance =
      DeviceDiscoveryService._internal();
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._internal();

  Timer? _discoveryTimer;
  Timer? _heartbeatTimer;
  WebSocketChannel? _webSocketChannel;
  final List<Device> _discoveredDevices = [];
  final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();

  Stream<List<Device>> get discoveredDevicesStream => _devicesController.stream;
  List<Device> get discoveredDevices => List.from(_discoveredDevices);

  bool _isRunning = false;
  String? _currentDeviceId;

  // Getter for current device ID
  String? get currentDeviceId => _currentDeviceId;

  // Auto-register current device when user logs in
  Future<void> autoRegisterOnLogin(String userId) async {
    try {
      print('🔐 Auto-registering device for user: $userId');

      final response = await DockService().autoRegisterDevice();

      if (response['success']) {
        _currentDeviceId = response['device_id'];
        print('✅ Device auto-registered: $_currentDeviceId');

        // Start auto-discovery after registration
        await startAutoDiscovery();

        // Connect to WebSocket for real-time communication
        await _connectWebSocket();
      }
    } catch (e) {
      print('❌ Auto-registration failed: $e');
    }
  }

  // Start automatic device discovery
  Future<void> startAutoDiscovery() async {
    if (_isRunning) return;

    print('🔍 Starting comprehensive device discovery...');
    _isRunning = true;

    // Initial discovery
    await _discoverUserDevices();

    // Start periodic discovery (every 30 seconds)
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _discoverUserDevices();
    });

    // Start heartbeat (every 10 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendHeartbeat();
    });
  }

  // Connect to WebSocket for real-time device communication
  Future<void> _connectWebSocket() async {
    try {
      if (_currentDeviceId == null) return;

      final wsUrl = ApiConfig.dockWebSocketConnect(_currentDeviceId!);
      _webSocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for real-time messages
      _webSocketChannel!.stream.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) => print('❌ WebSocket error: $error'),
        onDone: () => _reconnectWebSocket(),
      );

      print('🔗 WebSocket connected for device: $_currentDeviceId');
    } catch (e) {
      print('❌ WebSocket connection failed: $e');
    }
  }

  // Handle real-time WebSocket messages
  void _handleWebSocketMessage(dynamic data) {
    try {
      final message = json.decode(data);
      final type = message['type'];

      switch (type) {
        case 'device_connected':
          _onDeviceConnected(message);
          break;
        case 'device_disconnected':
          _onDeviceDisconnected(message);
          break;
        case 'remote_control':
          _handleRemoteControl(message);
          break;
        case 'execute_command':
          _executeCommand(message);
          break;
        case 'screen_update':
          _handleScreenUpdate(message);
          break;
        case 'input_control':
          _handleInputControl(message);
          break;
        case 'heartbeat_ack':
          // Heartbeat acknowledged
          break;
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  // Discover all user devices from backend
  Future<void> _discoverUserDevices() async {
    try {
      final response = await DockService().getUserDevices();

      if (response['devices'] != null) {
        final devices = (response['devices'] as List)
            .map((deviceData) => Device.fromJson(deviceData))
            .toList();

        _discoveredDevices.clear();
        _discoveredDevices.addAll(devices);

        _devicesController.add(_discoveredDevices);
        print('🔄 Discovered ${devices.length} user devices');
      }
    } catch (e) {
      print('❌ Error discovering devices: $e');
    }
  }

  // Handle new device connected
  void _onDeviceConnected(Map<String, dynamic> message) {
    try {
      final deviceData = message['device_info'];
      final device = Device.fromJson(deviceData);

      final existingIndex = _discoveredDevices.indexWhere(
        (d) => d.id == device.id,
      );

      if (existingIndex != -1) {
        _discoveredDevices[existingIndex] = device;
      } else {
        _discoveredDevices.add(device);
      }

      _devicesController.add(_discoveredDevices);
      print('📱 Device connected: ${device.name}');
    } catch (e) {
      print('❌ Error handling device connection: $e');
    }
  }

  // Handle device disconnected
  void _onDeviceDisconnected(Map<String, dynamic> message) {
    try {
      final deviceId = message['device_id'];
      _discoveredDevices.removeWhere((d) => d.id == deviceId);
      _devicesController.add(_discoveredDevices);
      print('📱 Device disconnected: $deviceId');
    } catch (e) {
      print('❌ Error handling device disconnection: $e');
    }
  }

  // Send remote control command to another device
  Future<bool> sendRemoteControlCommand({
    required String targetDeviceId,
    required String controlType,
    required String action,
    Map<String, dynamic> parameters = const {},
  }) async {
    try {
      final response = await DockService().sendRemoteControlCommand({
        'target_device_id': targetDeviceId,
        'control_type': controlType,
        'action': action,
        'parameters': parameters,
      });

      return response['success'] ?? false;
    } catch (e) {
      print('❌ Error sending remote control: $e');
      return false;
    }
  }

  // Execute cross-platform command on target device
  Future<bool> executeCrossPlatformCommand({
    required String deviceId,
    required String commandType,
    required String command,
    Map<String, dynamic> parameters = const {},
    bool executeAsync = true,
  }) async {
    try {
      final response = await DockService().executeCrossPlatformCommand({
        'device_id': deviceId,
        'command_type': commandType,
        'command': command,
        'parameters': parameters,
        'execute_async': executeAsync,
      });

      return response['success'] ?? false;
    } catch (e) {
      print('❌ Error executing command: $e');
      return false;
    }
  }

  // Handle incoming remote control requests
  void _handleRemoteControl(Map<String, dynamic> message) {
    final controlType = message['control_type'];
    final action = message['action'];
    final parameters = message['parameters'] ?? {};

    switch (controlType) {
      case 'screen_share':
        _handleScreenShare(action, parameters);
        break;
      case 'mouse_control':
        _handleMouseControl(action, parameters);
        break;
      case 'keyboard_control':
        _handleKeyboardControl(action, parameters);
        break;
      case 'file_transfer':
        _handleFileTransfer(action, parameters);
        break;
    }
  }

  // Handle screen sharing requests
  void _handleScreenShare(String action, Map<String, dynamic> parameters) {
    switch (action) {
      case 'start':
        _startScreenShare(parameters['target_device'] ?? '');
        break;
      case 'stop':
        _stopScreenShare();
        break;
    }
  }

  // Handle file transfer requests
  void _handleFileTransfer(String action, Map<String, dynamic> parameters) {
    print('📁 File transfer: $action with params: $parameters');
    // Implement file transfer based on action
  }

  // Start screen sharing to target device
  void _startScreenShare(String targetDevice) {
    print('📺 Starting screen share to: $targetDevice');
    // TODO: Implement actual screen capture and streaming
  }

  // Stop screen sharing
  void _stopScreenShare() {
    print('📺 Stopping screen share');
    // TODO: Implement screen share stopping
  }

  // Handle mouse/keyboard control
  void _handleMouseControl(String action, Map<String, dynamic> parameters) {
    print('🖱️ Mouse control: $action with params: $parameters');
    // Implement mouse control based on platform
  }

  void _handleKeyboardControl(String action, Map<String, dynamic> parameters) {
    print('⌨️ Keyboard control: $action with params: $parameters');
    // Implement keyboard control based on platform
  }

  // Execute commands from other devices
  void _executeCommand(Map<String, dynamic> message) {
    final commandType = message['command_type'];
    final command = message['command'];

    print('⚡ Executing command: $commandType - $command');
    // TODO: Execute command based on platform and type
  }

  // Handle screen updates from other devices
  void _handleScreenUpdate(Map<String, dynamic> message) {
    final sourceDevice = message['source_device'];
    print('📺 Received screen update from: $sourceDevice');
    // TODO: Update UI with received screen data
  }

  // Handle input control events
  void _handleInputControl(Map<String, dynamic> message) {
    final sourceDevice = message['source_device'];
    final eventType = message['event_type'];
    print('🎮 Input control from $sourceDevice: $eventType');
    // TODO: Process input events
  }

  // Send heartbeat to maintain connection
  void _sendHeartbeat() {
    if (_webSocketChannel != null && _currentDeviceId != null) {
      _webSocketChannel!.sink.add(
        json.encode({
          'type': 'heartbeat',
          'device_id': _currentDeviceId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
  }

  // Reconnect WebSocket if disconnected
  void _reconnectWebSocket() {
    print('🔄 WebSocket disconnected, attempting reconnect...');
    Timer(const Duration(seconds: 5), () {
      _connectWebSocket();
    });
  }

  // Get device by ID
  Device? getDeviceById(String deviceId) {
    try {
      return _discoveredDevices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  // Get all online devices
  List<Device> getOnlineDevices() {
    return _discoveredDevices.where((device) => device.isOnline).toList();
  }

  // Refresh discovery manually
  Future<void> refreshDiscovery() async {
    await _discoverUserDevices();
  }

  // Stop auto-discovery
  void stopAutoDiscovery() {
    print('🛑 Stopping device discovery...');
    _isRunning = false;

    _discoveryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _webSocketChannel?.sink.close();

    _discoveryTimer = null;
    _heartbeatTimer = null;
    _webSocketChannel = null;
  }

  // Clean up resources
  void dispose() {
    stopAutoDiscovery();
    _devicesController.close();
  }
}
