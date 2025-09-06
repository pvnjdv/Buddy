// lib/services/dock_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/dock_models.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/device_info_service.dart';

class DockService {
  static final DockService _instance = DockService._internal();
  factory DockService() => _instance;
  DockService._internal();

  WebSocketChannel? _webSocketChannel;
  Stream<dynamic>? _webSocketStream;

  Stream<dynamic> get webSocketStream =>
      _webSocketStream ?? const Stream.empty();

  // HTTP Helper Methods
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _get(String url) async {
    final headers = await _getAuthHeaders();
    return await http.get(Uri.parse(url), headers: headers);
  }

  Future<http.Response> _post(String url, Map<String, dynamic> body) async {
    final headers = await _getAuthHeaders();
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _delete(String url) async {
    final headers = await _getAuthHeaders();
    return await http.delete(Uri.parse(url), headers: headers);
  }

  // Device Management
  // Auto-register current device when user logs in
  Future<Map<String, dynamic>> autoRegisterDevice() async {
    try {
      // Get device information from the Flutter side (works on all platforms)
      final deviceInfoService = DeviceInfoService();
      final deviceInfo = await deviceInfoService.getDeviceInfo();
      final capabilities = deviceInfoService.getDeviceCapabilities();

      // Create the payload with Flutter-collected device info
      final payload = {
        'device_info': deviceInfo,
        'capabilities': capabilities,
        'device_type': deviceInfoService.isMobile() ? 'mobile' : 'desktop',
        'platform': deviceInfoService.getPlatformDisplayName(),
      };

      final response = await _post(ApiConfig.dockAutoRegister, payload);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔐 Auto-registration response: $data');
        return data;
      } else {
        print('❌ Auto-registration failed: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Auto-registration failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Auto-registration error: $e');
      rethrow;
    }
  }

  // Send remote control command to another device
  Future<Map<String, dynamic>> sendRemoteControlCommand(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _post(
        '${ApiConfig.baseUrl}/dock/control/remote',
        request,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📱 Remote control command sent: ${data['message']}');
        return data;
      } else {
        throw Exception('Remote control failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Remote control error: $e');
      rethrow;
    }
  }

  // Execute cross-platform command on target device
  Future<Map<String, dynamic>> executeCrossPlatformCommand(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _post(
        '${ApiConfig.baseUrl}/dock/control/cross-platform',
        request,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('⚡ Cross-platform command executed: ${data['message']}');
        return data;
      } else {
        throw Exception(
          'Cross-platform command failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Cross-platform command error: $e');
      rethrow;
    }
  }

  // Get user devices with real-time status
  Future<Map<String, dynamic>> getUserDevices() async {
    try {
      final response = await _get(ApiConfig.dockDevices);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '📱 Retrieved ${data['total_count']} devices (${data['online_count']} online)',
        );
        return data;
      } else {
        throw Exception('Get devices failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Get devices error: $e');
      rethrow;
    }
  }

  Future<List<Device>> getDevices() async {
    try {
      final data = await getUserDevices();
      final devices = (data['devices'] as List)
          .map((json) => Device.fromJson(json))
          .toList();
      return devices;
    } catch (e) {
      print('❌ Get devices list error: $e');
      return [];
    }
  }

  Future<Device> registerDevice(DeviceRegisterRequest request) async {
    try {
      final response = await _post(ApiConfig.dockRegister, request.toJson());

      if (response.statusCode == 201) {
        return Device.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to register device: ${response.statusCode}');
      }
    } catch (e) {
      print('Error registering device: $e');
      rethrow;
    }
  }

  Future<void> removeDevice(String deviceId) async {
    try {
      final response = await _delete(ApiConfig.dockDevice(deviceId));

      if (response.statusCode != 204) {
        throw Exception('Failed to remove device: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing device: $e');
      rethrow;
    }
  }

  // Command Execution
  Future<DeviceCommand> executeCommand(CommandRequest request) async {
    try {
      final response = await _post(ApiConfig.dockCommands, request.toJson());

      if (response.statusCode == 201) {
        return DeviceCommand.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to execute command: ${response.statusCode}');
      }
    } catch (e) {
      print('Error executing command: $e');
      rethrow;
    }
  }

  Future<List<DeviceCommand>> getCommandHistory() async {
    try {
      final response = await _get(ApiConfig.dockCommands);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DeviceCommand.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load command history: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error getting command history: $e');
      return [];
    }
  }

  // Macro Management
  Future<List<DeviceMacro>> getUserMacros() async {
    try {
      final response = await _get(ApiConfig.dockMacros);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> macrosList = data['macros'] ?? [];
        return macrosList.map((json) => DeviceMacro.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load macros: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting user macros: $e');
      return [];
    }
  }

  Future<DeviceMacro> executeMacro(String macroId) async {
    try {
      final response = await _post(ApiConfig.dockMacro(macroId), {});

      if (response.statusCode == 200) {
        return DeviceMacro.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to execute macro: ${response.statusCode}');
      }
    } catch (e) {
      print('Error executing macro: $e');
      rethrow;
    }
  }

  // Network Operations
  Future<List<Device>> scanNetwork() async {
    try {
      final response = await _post(ApiConfig.dockNetworkScan, {});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Device.fromJson(json)).toList();
      } else {
        throw Exception('Failed to scan network: ${response.statusCode}');
      }
    } catch (e) {
      print('Error scanning network: $e');
      return [];
    }
  }

  // WebSocket Connection
  Future<void> connectWebSocket(String deviceId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final wsUrl = ApiConfig.dockWebSocketConnect(deviceId);

      _webSocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _webSocketStream = _webSocketChannel!.stream.asBroadcastStream();

      // Send authentication message immediately after connection
      sendWebSocketMessage({
        'type': 'auth',
        'token': token,
        'device_id': deviceId,
      });

      print('WebSocket connected to: $wsUrl');
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  void sendWebSocketMessage(Map<String, dynamic> message) {
    try {
      if (_webSocketChannel != null) {
        _webSocketChannel!.sink.add(jsonEncode(message));
      }
    } catch (e) {
      print('Error sending WebSocket message: $e');
    }
  }

  void dispose() {
    try {
      _webSocketChannel?.sink.close();
      _webSocketChannel = null;
      _webSocketStream = null;
    } catch (e) {
      print('Error disposing WebSocket: $e');
    }
  }

  Future<Device> renameDevice(String deviceId, String newName) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.dockDevices}/$deviceId/rename?new_name=$newName',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Device.fromJson(data['device']);
      } else {
        throw Exception('Failed to rename device: ${response.statusCode}');
      }
    } catch (e) {
      print('Error renaming device: $e');
      rethrow;
    }
  }
}
