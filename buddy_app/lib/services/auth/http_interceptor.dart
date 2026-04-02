import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'auth_service.dart';

class HttpInterceptor {
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _makeRequestWithRetry('GET', endpoint, headers: headers);
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _makeRequestWithRetry(
      'POST',
      endpoint,
      headers: headers,
      body: body,
    );
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _makeRequestWithRetry('PUT', endpoint, headers: headers, body: body);
  }

  static Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _makeRequestWithRetry('DELETE', endpoint, headers: headers);
  }

  static Future<http.Response> _makeRequestWithRetry(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await _makeRequest(
          method,
          endpoint,
          headers: headers,
          body: body,
        );
      } on SocketException catch (e) {
        lastException = e;
        print('HttpInterceptor: Network error on attempt ${attempt + 1}: $e');

        if (attempt < maxRetries - 1) {
          final delay = Duration(
            seconds: initialRetryDelay.inSeconds * (attempt + 1),
          );
          print('HttpInterceptor: Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      } on TimeoutException catch (e) {
        lastException = e;
        print('HttpInterceptor: Timeout on attempt ${attempt + 1}: $e');

        if (attempt < maxRetries - 1) {
          final delay = Duration(
            seconds: initialRetryDelay.inSeconds * (attempt + 1),
          );
          await Future.delayed(delay);
        }
      } on HttpException catch (e) {
        lastException = e;
        print('HttpInterceptor: HTTP error on attempt ${attempt + 1}: $e');

        if (attempt < maxRetries - 1) {
          final delay = Duration(
            seconds: initialRetryDelay.inSeconds * (attempt + 1),
          );
          await Future.delayed(delay);
        }
      } catch (e) {
        // For non-network errors, don't retry
        rethrow;
      }
    }

    // If all retries failed, throw the last exception
    throw lastException ?? Exception('All retry attempts failed');
  }

  static Future<http.StreamedResponse> multipartRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    return _makeMultipartRequest(
      method,
      endpoint,
      headers: headers,
      fields: fields,
      files: files,
    );
  }

  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Get the access token
    final token = await AuthService.getToken();

    // Prepare headers with authorization
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };

    if (token != null) {
      requestHeaders['Authorization'] = 'Bearer $token';
    }

    // Make the initial request
    http.Response response;
    final uri = Uri.parse(endpoint);

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(uri, headers: requestHeaders, body: body);
        break;
      case 'PUT':
        response = await http.put(uri, headers: requestHeaders, body: body);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: requestHeaders);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // Check if token expired (401 Unauthorized)
    if (response.statusCode == 401 && token != null) {
      print('HttpInterceptor: Token expired, attempting refresh...');

      // Try to refresh the token
      final refreshSuccess = await AuthService.refreshAccessToken();

      if (refreshSuccess) {
        print(
          'HttpInterceptor: Token refreshed successfully, retrying request...',
        );

        // Get the new token and retry the request
        final newToken = await AuthService.getToken();
        if (newToken != null) {
          requestHeaders['Authorization'] = 'Bearer $newToken';

          // Retry the original request with new token
          switch (method.toUpperCase()) {
            case 'GET':
              response = await http.get(uri, headers: requestHeaders);
              break;
            case 'POST':
              response = await http.post(
                uri,
                headers: requestHeaders,
                body: body,
              );
              break;
            case 'PUT':
              response = await http.put(
                uri,
                headers: requestHeaders,
                body: body,
              );
              break;
            case 'DELETE':
              response = await http.delete(uri, headers: requestHeaders);
              break;
          }

          print(
            'HttpInterceptor: Retry request status: ${response.statusCode}',
          );
        }
      } else {
        print('HttpInterceptor: Token refresh failed, user needs to re-login');
        // Could trigger logout flow here if needed
      }
    }

    return response;
  }

  static Future<http.StreamedResponse> _makeMultipartRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    // Get the access token
    final token = await AuthService.getToken();

    // Create multipart request
    var request = http.MultipartRequest(method, Uri.parse(endpoint));

    // Add headers
    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Add fields
    if (fields != null) {
      request.fields.addAll(fields);
    }

    // Add files
    if (files != null) {
      request.files.addAll(files);
    }

    // Send the initial request
    var response = await request.send();

    // Check if token expired (401 Unauthorized)
    if (response.statusCode == 401 && token != null) {
      print('HttpInterceptor: Token expired, attempting refresh...');

      // Try to refresh the token
      final refreshSuccess = await AuthService.refreshAccessToken();

      if (refreshSuccess) {
        print(
          'HttpInterceptor: Token refreshed successfully, retrying multipart request...',
        );

        // Get the new token and retry the request
        final newToken = await AuthService.getToken();
        if (newToken != null) {
          // Create a new request with the new token
          var retryRequest = http.MultipartRequest(method, Uri.parse(endpoint));

          // Add headers with new token
          if (headers != null) {
            retryRequest.headers.addAll(headers);
          }
          retryRequest.headers['Authorization'] = 'Bearer $newToken';

          // Add fields again
          if (fields != null) {
            retryRequest.fields.addAll(fields);
          }

          // Add files again
          if (files != null) {
            retryRequest.files.addAll(files);
          }

          // Send retry request
          response = await retryRequest.send();
          print(
            'HttpInterceptor: Retry multipart request status: ${response.statusCode}',
          );
        }
      } else {
        print('HttpInterceptor: Token refresh failed, user needs to re-login');
      }
    }

    return response;
  }
}
