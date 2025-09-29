import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

/// On-device AI service for running TensorFlow Lite models on mobile and desktop
class OnDeviceAIService {
  static const MethodChannel _channel = MethodChannel('on_device_ai');

  // Private state variables
  String? _currentModelPath;
  bool _isModelLoaded = false;

  // Singleton pattern
  static final OnDeviceAIService _instance = OnDeviceAIService._internal();
  factory OnDeviceAIService() => _instance;
  OnDeviceAIService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    print('🚀 Initializing OnDeviceAIService...');
    print('📱 Platform: ${Platform.operatingSystem}');
  }

  /// Check if device is capable of running local AI models
  Future<bool> isDeviceCapable() async {
    try {
      // Check if device has sufficient RAM (minimum 4GB for basic models)
      // This is a basic check - more sophisticated checks can be added

      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, check through native plugin
        final result = await _channel.invokeMethod('isDeviceCapable');
        return result['capable'] ?? false;
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, assume capable if we have TFLite Flutter support
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking device capability: $e');
      return false;
    }
  }

  /// Determine if we should use native plugin or TFLite Flutter
  bool get _useNativePlugin {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Load a model from file path
  Future<bool> loadModelFromFile(String filePath) async {
    try {
      // Determine model type based on file extension
      final fileName = filePath.toLowerCase();

      if (fileName.endsWith('.gguf') ||
          fileName.endsWith('.bin') ||
          fileName.endsWith('.ggml')) {
        // For GGUF models, just mark as loaded - processing handled by BuddyService
        print('🔗 GGUF model detected: $filePath');
        _currentModelPath = filePath;
        _isModelLoaded = true;
        return true;
      } else if (fileName.endsWith('.tflite') || fileName.endsWith('.lite')) {
        // Use native plugin for TFLite models
        if (_useNativePlugin) {
          return await _loadModelWithNativePlugin(filePath);
        } else {
          return await _loadModelWithTFLiteFlutter(filePath);
        }
      } else {
        throw Exception('Unsupported model format: $filePath');
      }
    } catch (e) {
      print('Error loading model: $e');
      return false;
    }
  }

  /// Load model using native plugin (Android/iOS)
  Future<bool> _loadModelWithNativePlugin(String filePath) async {
    try {
      print('📱 Loading TFLite model via native plugin: $filePath');

      final result = await _channel.invokeMethod('loadModel', {
        'modelPath': filePath,
      });

      if (result['success'] == true) {
        _currentModelPath = filePath;
        _isModelLoaded = true;
        return true;
      } else {
        throw Exception(result['error'] ?? 'Failed to load model');
      }
    } catch (e) {
      print('Error loading model with native plugin: $e');
      return false;
    }
  }

  /// Load model using TFLite Flutter (Desktop)
  Future<bool> _loadModelWithTFLiteFlutter(String filePath) async {
    try {
      print('🖥️  Loading TFLite model on desktop: $filePath');

      // For now, simulate successful loading on desktop
      // Once tflite_flutter is properly installed, this will use actual TFLite

      // TODO: Implement actual TFLite Flutter loading when package is available
      // _interpreter = await Interpreter.fromFile(File(filePath));

      _currentModelPath = filePath;
      _isModelLoaded = true;

      print('✅ Desktop TFLite simulation loaded successfully');
      print(
        '📝 Note: This is a simulation. Install tflite_flutter for real desktop support.',
      );

      return true;
    } catch (e) {
      print('Error loading desktop model: $e');
      return false;
    }
  }

  /// Select and load a local AI model using file picker
  Future<bool> selectAndLoadModel() async {
    try {
      // Show user options for model types
      // For now, let's focus on TFLite models for true local processing
      // GGUF models will be supported via server-based local mode

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite', 'lite', 'gguf', 'bin', 'ggml'],
        dialogTitle: 'Select AI Model (.tflite for mobile, .gguf for server)',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = filePath.toLowerCase();

        // Check if it's a GGUF model
        if (fileName.endsWith('.gguf') ||
            fileName.endsWith('.bin') ||
            fileName.endsWith('.ggml')) {
          print('🔄 GGUF model detected: $filePath');
          print(
            '📤 This will use server-based processing for optimal performance',
          );

          // For GGUF models, we'll indicate they're loaded but handle them via BuddyService
          _currentModelPath = filePath;
          _isModelLoaded = true;
          return true;
        }

        // For TFLite models, use the original loading logic
        return await loadModelFromFile(filePath);
      }
      return false;
    } catch (e) {
      print('Error selecting AI model: $e');
      return false;
    }
  }

  /// Generate response using the loaded model
  Future<String> generateResponse(
    String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    Function(String)? onTokenGenerated,
  }) async {
    if (!_isModelLoaded) {
      throw Exception('No model loaded. Call loadModelFromFile first.');
    }

    try {
      // Check if it's a GGUF model - these should be handled by BuddyService
      final fileName = _currentModelPath!.toLowerCase();
      if (fileName.endsWith('.gguf') ||
          fileName.endsWith('.bin') ||
          fileName.endsWith('.ggml')) {
        throw Exception(
          'GGUF models should be processed via BuddyService server API',
        );
      }

      // Handle TFLite models with native plugin or desktop simulation
      if (_useNativePlugin) {
        final result = await _channel.invokeMethod('generateResponse', {
          'prompt': prompt,
          'maxTokens': maxTokens,
          'temperature': temperature,
          'streaming': onTokenGenerated != null,
        });

        if (result['success'] == true) {
          return result['response'] ?? '';
        } else {
          throw Exception(result['error'] ?? 'Failed to generate response');
        }
      } else {
        // Desktop simulation
        print('🖥️  Generating response on desktop (simulated)');
        print('📝 Prompt: $prompt');

        // Simulate response generation
        await Future.delayed(Duration(milliseconds: 500));
        return 'This is a simulated response from the desktop TensorFlow Lite model. '
            'Real implementation will use tflite_flutter when properly installed. '
            'Prompt received: "${prompt.length > 50 ? prompt.substring(0, 50) + "..." : prompt}"';
      }
    } catch (e) {
      print('Error generating response: $e');
      throw e;
    }
  }

  /// Get information about the loaded model
  Future<Map<String, dynamic>?> getModelInfo() async {
    if (!_isModelLoaded) return null;

    try {
      if (_useNativePlugin) {
        final result = await _channel.invokeMethod('getModelInfo');
        return Map<String, dynamic>.from(result);
      } else {
        // For desktop, return basic info
        return {
          'modelPath': _currentModelPath,
          'platform': 'desktop',
          'loaded': _isModelLoaded,
          'note': 'Desktop TFLite support is simulated',
        };
      }
    } catch (e) {
      print('Error getting model info: $e');
      return null;
    }
  }

  /// Unload the current model
  Future<void> unloadModel() async {
    try {
      if (_isModelLoaded && _useNativePlugin) {
        await _channel.invokeMethod('unloadModel');
        print('✅ Model unloaded successfully');
      }

      _isModelLoaded = false;
      _currentModelPath = null;
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  /// Check if a model is currently loaded
  bool get isModelLoaded => _isModelLoaded;

  /// Get the path of the currently loaded model
  String? get currentModelPath => _currentModelPath;

  /// Dispose of resources
  Future<void> dispose() async {
    await unloadModel();
  }
}
