// lib/services/code_execution_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class CodeExecutionService {
  static final CodeExecutionService _instance =
      CodeExecutionService._internal();
  factory CodeExecutionService() => _instance;
  CodeExecutionService._internal();

  final String baseUrl = ApiConfig.baseUrl;
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<CodeExecutionResult> executeCode({
    required String code,
    required String language,
    String? filename,
    List<String>? arguments,
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/execute'),
        headers: _headers,
        body: jsonEncode({
          'code': code,
          'language': language,
          'filename': filename,
          'arguments': arguments ?? [],
          'environment': environment ?? {},
          'working_directory': workingDirectory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final executionId = data['execution_id'];

        // Start polling for results
        return await _pollForResults(executionId);
      } else {
        throw Exception('Failed to execute code: ${response.statusCode}');
      }
    } catch (e) {
      return CodeExecutionResult(
        executionId: '',
        status: ExecutionStatus.error,
        output: '',
        error: 'Error executing code: $e',
        exitCode: -1,
        executionTime: 0.0,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<CodeExecutionResult> _pollForResults(String executionId) async {
    const maxAttempts = 60; // 30 seconds with 500ms intervals
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/code/execution/$executionId'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final result = CodeExecutionResult.fromJson(
            jsonDecode(response.body),
          );

          if (result.status != ExecutionStatus.running) {
            return result;
          }
        }
      } catch (e) {
        debugPrint('Error polling execution result: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    // Timeout
    return CodeExecutionResult(
      executionId: executionId,
      status: ExecutionStatus.error,
      output: '',
      error: 'Execution timed out',
      exitCode: -1,
      executionTime: 30.0,
      createdAt: DateTime.now(),
    );
  }

  Stream<CodeExecutionResult> executeCodeStream({
    required String code,
    required String language,
    String? filename,
    List<String>? arguments,
    Map<String, String>? environment,
    String? workingDirectory,
  }) async* {
    try {
      // Start execution
      final response = await http.post(
        Uri.parse('$baseUrl/api/code/execute'),
        headers: _headers,
        body: jsonEncode({
          'code': code,
          'language': language,
          'filename': filename,
          'arguments': arguments ?? [],
          'environment': environment ?? {},
          'working_directory': workingDirectory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final executionId = data['execution_id'];

        // Stream results
        yield* _streamResults(executionId);
      } else {
        yield CodeExecutionResult(
          executionId: '',
          status: ExecutionStatus.error,
          output: '',
          error: 'Failed to start execution: ${response.statusCode}',
          exitCode: -1,
          executionTime: 0.0,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      yield CodeExecutionResult(
        executionId: '',
        status: ExecutionStatus.error,
        output: '',
        error: 'Error starting execution: $e',
        exitCode: -1,
        executionTime: 0.0,
        createdAt: DateTime.now(),
      );
    }
  }

  Stream<CodeExecutionResult> _streamResults(String executionId) async* {
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/api/code/execution/$executionId/stream'),
      );
      request.headers.addAll(_headers);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              try {
                final jsonData = line.substring(6);
                if (jsonData.isNotEmpty) {
                  final data = jsonDecode(jsonData);
                  final result = CodeExecutionResult.fromJson(data);
                  yield result;

                  if (result.status != ExecutionStatus.running) {
                    return;
                  }
                }
              } catch (e) {
                debugPrint('Error parsing stream data: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      yield CodeExecutionResult(
        executionId: executionId,
        status: ExecutionStatus.error,
        output: '',
        error: 'Error streaming results: $e',
        exitCode: -1,
        executionTime: 0.0,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<bool> stopExecution(String executionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/code/execution/$executionId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error stopping execution: $e');
      return false;
    }
  }

  Future<List<SupportedLanguage>> getSupportedLanguages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/code/languages'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final languages = data['languages'] as List;
        return languages.map((l) => SupportedLanguage.fromJson(l)).toList();
      } else {
        throw Exception('Failed to get languages: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting supported languages: $e');
      return _getDefaultLanguages();
    }
  }

  List<SupportedLanguage> _getDefaultLanguages() {
    return [
      SupportedLanguage(
        name: 'Python',
        id: 'python',
        extension: '.py',
        supportsExecution: true,
        supportsCompilation: false,
      ),
      SupportedLanguage(
        name: 'Dart',
        id: 'dart',
        extension: '.dart',
        supportsExecution: true,
        supportsCompilation: false,
      ),
      SupportedLanguage(
        name: 'JavaScript',
        id: 'javascript',
        extension: '.js',
        supportsExecution: true,
        supportsCompilation: false,
      ),
      SupportedLanguage(
        name: 'TypeScript',
        id: 'typescript',
        extension: '.ts',
        supportsExecution: true,
        supportsCompilation: true,
      ),
      SupportedLanguage(
        name: 'Java',
        id: 'java',
        extension: '.java',
        supportsExecution: true,
        supportsCompilation: true,
      ),
    ];
  }
}

enum ExecutionStatus { running, completed, error, stopped }

class CodeExecutionResult {
  final String executionId;
  final ExecutionStatus status;
  final String output;
  final String error;
  final int? exitCode;
  final double executionTime;
  final DateTime createdAt;

  CodeExecutionResult({
    required this.executionId,
    required this.status,
    required this.output,
    required this.error,
    this.exitCode,
    required this.executionTime,
    required this.createdAt,
  });

  factory CodeExecutionResult.fromJson(Map<String, dynamic> json) {
    return CodeExecutionResult(
      executionId: json['execution_id'] ?? '',
      status: _parseStatus(json['status']),
      output: json['output'] ?? '',
      error: json['error'] ?? '',
      exitCode: json['exit_code'],
      executionTime: (json['execution_time'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static ExecutionStatus _parseStatus(String? status) {
    switch (status) {
      case 'running':
        return ExecutionStatus.running;
      case 'completed':
        return ExecutionStatus.completed;
      case 'error':
        return ExecutionStatus.error;
      case 'stopped':
        return ExecutionStatus.stopped;
      default:
        return ExecutionStatus.error;
    }
  }

  bool get isRunning => status == ExecutionStatus.running;
  bool get isCompleted => status == ExecutionStatus.completed;
  bool get hasError => status == ExecutionStatus.error || error.isNotEmpty;
  bool get isSuccessful =>
      status == ExecutionStatus.completed &&
      (exitCode == 0 || exitCode == null);
}

class SupportedLanguage {
  final String name;
  final String id;
  final String extension;
  final bool supportsExecution;
  final bool supportsCompilation;

  SupportedLanguage({
    required this.name,
    required this.id,
    required this.extension,
    required this.supportsExecution,
    required this.supportsCompilation,
  });

  factory SupportedLanguage.fromJson(Map<String, dynamic> json) {
    return SupportedLanguage(
      name: json['name'] ?? '',
      id: json['id'] ?? '',
      extension: json['extension'] ?? '',
      supportsExecution: json['supports_execution'] ?? false,
      supportsCompilation: json['supports_compilation'] ?? false,
    );
  }
}
