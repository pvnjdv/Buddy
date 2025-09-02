class ApiConfig {
  // Environment configuration
  static const bool useProduction = false; // Set to true for release/testing

  // Local development configuration
  static const String _localIp = '10.247.131.3';
  static const String _localPort = '8000';
  static const String _localUrl = 'http://$_localIp:$_localPort';

  // Production Railway URL
  static const String _productionUrl =
      'https://buddy-production-b5dd.up.railway.app';

  // WebSocket URLs
  static const String _localWsUrl = 'ws://$_localIp:$_localPort';
  static const String _productionWsUrl =
      'wss://buddy-production-b5dd.up.railway.app';

  // Current base URL based on environment
  static String get baseUrl => useProduction ? _productionUrl : _localUrl;
  static String get wsBaseUrl => useProduction ? _productionWsUrl : _localWsUrl;

  // API endpoints
  static String get authRequestOtp => '$baseUrl/auth/request-otp';
  static String get authVerifyOtp => '$baseUrl/auth/verify-otp';
  static String get authRefreshToken => '$baseUrl/auth/refresh-token';
  static String get authLogout => '$baseUrl/auth/logout';
  static String get userDetails => '$baseUrl/users/details';
  static String get userProfile => '$baseUrl/users/me';
  static String get userByMobile => '$baseUrl/users/by-mobile';
  static String get tasks => '$baseUrl/tasks';
  static String get chats => '$baseUrl/chats';
  static String get buddy => '$baseUrl/buddy';
  static String get flows => '$baseUrl/flows';
  static String get notes => '$baseUrl/notes';
  static String get alarms => '$baseUrl/alarms';
  static String get contacts => '$baseUrl/contacts';

  // Dock API endpoints
  static String get dockDevices => '$baseUrl/api/dock/devices';
  static String get dockRegister => '$baseUrl/api/dock/register';
  static String get dockAutoRegister => '$baseUrl/api/dock/auto-register';
  static String get dockCommands => '$baseUrl/api/dock/commands';
  static String get dockMacros => '$baseUrl/api/dock/macros';
  static String get dockFiles => '$baseUrl/api/dock/files';
  static String get dockSystem => '$baseUrl/api/dock/system';
  static String get dockNetworkScan => '$baseUrl/api/dock/network/scan';
  static String dockDevice(String deviceId) =>
      '$baseUrl/api/dock/devices/$deviceId';
  static String dockDeviceCommand(String deviceId) =>
      '$baseUrl/api/dock/devices/$deviceId/command';
  static String dockDeviceFiles(String deviceId, [String path = '/']) =>
      '$baseUrl/api/dock/devices/$deviceId/files?path=$path';
  static String dockDeviceApps(String deviceId) =>
      '$baseUrl/api/dock/devices/$deviceId/apps';
  static String dockDeviceSystem(String deviceId) =>
      '$baseUrl/api/dock/devices/$deviceId/system';
  static String dockMacro(String macroId) =>
      '$baseUrl/api/dock/macros/$macroId';
  static String dockWebSocketConnect(String deviceId) =>
      '${wsBaseUrl}/api/dock/connect/$deviceId';
  static String get dockWebSocket => '${wsBaseUrl}/api/dock/ws';

  // For debugging - print the current configuration
  static void printConfig() {
    print('API Environment: ${useProduction ? 'Production' : 'Development'}');
    print('API Base URL: $baseUrl');
  }

  // Helper method to switch to production for testing
  static void switchToProduction() {
    // Note: To actually switch, you need to change the useProduction constant above
    print(
      'To switch to production, set useProduction = true in api_config.dart',
    );
  }
}
