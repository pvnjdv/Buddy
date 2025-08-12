class ApiConfig {
  // Change this IP address when your network changes
  // For Android device testing, use your machine's IP address
  // For iOS simulator, you can use 'localhost' or '127.0.0.1'
  static const String _baseIp = '10.247.131.3';
  static const String _port = '8000';

  static const String baseUrl = 'http://$_baseIp:$_port';

  // API endpoints
  static const String authRequestOtp = '$baseUrl/auth/request-otp';
  static const String authVerifyOtp = '$baseUrl/auth/verify-otp';
  static const String userDetails = '$baseUrl/users/details';
  static const String userByMobile = '$baseUrl/users/by-mobile';
  static const String tasks = '$baseUrl/tasks';
  static const String chats = '$baseUrl/chats';
  static const String buddy = '$baseUrl/buddy';
  static const String flows = '$baseUrl/flows';
  static const String notes = '$baseUrl/notes';
  static const String alarms = '$baseUrl/alarms';
  static const String contacts = '$baseUrl/contacts';

  // For debugging - print the current base URL
  static void printConfig() {
    print('API Base URL: $baseUrl');
  }
}
