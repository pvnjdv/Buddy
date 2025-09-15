# On-Device AI Model Implementation Guide

## Overview
Run AI models directly on user's mobile device instead of server-side processing.

## Solution 1: TensorFlow Lite + Flutter

### Step 1: Add TensorFlow Lite Dependencies
```yaml
dependencies:
  tflite_flutter: ^0.10.4
  tflite_flutter_helper: ^0.3.1
```

### Step 2: Convert GGUF models to TensorFlow Lite
```python
# Convert GGUF/GGML models to TensorFlow Lite format
import tensorflow as tf

# This requires custom conversion logic as GGUF is specific to llama.cpp
# Alternative: Use pre-converted TFLite models
```

### Step 3: Flutter Implementation
```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class OnDeviceAI {
  late Interpreter _interpreter;
  
  Future<void> loadModel(String modelPath) async {
    _interpreter = await Interpreter.fromAsset(modelPath);
  }
  
  Future<String> generateResponse(String prompt) async {
    // Tokenize input
    var input = tokenize(prompt);
    
    // Run inference
    var output = List.filled(1024, 0.0).reshape([1, 1024]);
    _interpreter.run(input, output);
    
    // Decode output
    return decode(output);
  }
}
```

## Solution 2: ONNX Runtime Mobile

### Dependencies
```yaml
dependencies:
  onnxruntime: ^1.16.0
```

### Implementation
```dart
import 'package:onnxruntime/onnxruntime.dart';

class ONNXMobileAI {
  late OrtSession _session;
  
  Future<void> loadModel(String modelPath) async {
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromFile(modelPath, sessionOptions);
  }
  
  Future<String> generateResponse(String prompt) async {
    // Similar inference logic
  }
}
```

## Solution 3: Flutter + llama.cpp (Most Compatible)

### Use flutter_llama plugin
```yaml
dependencies:
  flutter_llama: ^0.2.0  # Custom plugin needed
```

### Implementation
```dart
import 'package:flutter_llama/flutter_llama.dart';

class LlamaMobileAI {
  late LlamaModel _model;
  
  Future<void> loadModel(String modelPath) async {
    _model = await LlamaModel.fromFile(modelPath);
  }
  
  Future<String> generateResponse(String prompt) async {
    return await _model.generate(prompt, maxTokens: 512);
  }
}
```

## Solution 4: WebAssembly (WASM) in WebView

### Create WASM Module
```javascript
// wasm_ai_module.js
class WASMAIRunner {
  async loadModel(modelData) {
    // Load model using WebAssembly
  }
  
  async generateResponse(prompt) {
    // Run inference in WASM
  }
}
```

### Flutter WebView Integration
```dart
import 'package:webview_flutter/webview_flutter.dart';

class WASMAIWidget extends StatefulWidget {
  @override
  _WASMAIWidgetState createState() => _WASMAIWidgetState();
}

class _WASMAIWidgetState extends State<WASMAIWidget> {
  late WebViewController _controller;
  
  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: 'assets/ai_runner.html',
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      javascriptMode: JavascriptMode.unrestricted,
    );
  }
  
  Future<String> generateResponse(String prompt) async {
    final result = await _controller.runJavascriptReturningResult(
      'generateResponse("$prompt")'
    );
    return result;
  }
}
```

## Performance Considerations

### Model Size Optimization
- Use quantized models (4-bit, 8-bit)
- Prefer smaller models (7B parameters max for mobile)
- Consider model distillation

### Memory Management
```dart
class OptimizedAIRunner {
  static const int MAX_CONTEXT_LENGTH = 2048;
  static const int MAX_TOKENS = 512;
  
  String _trimContext(String context) {
    if (context.length > MAX_CONTEXT_LENGTH) {
      return context.substring(context.length - MAX_CONTEXT_LENGTH);
    }
    return context;
  }
}
```

### Battery Optimization
```dart
class BatteryAwareAI {
  bool _isLowPowerMode = false;
  
  Future<void> checkBatteryStatus() async {
    final battery = Battery();
    final batteryLevel = await battery.batteryLevel;
    _isLowPowerMode = batteryLevel < 20;
  }
  
  Future<String> generateResponse(String prompt) async {
    if (_isLowPowerMode) {
      // Use simpler/faster inference
      return await _generateSimpleResponse(prompt);
    }
    return await _generateFullResponse(prompt);
  }
}
```

## Recommended Implementation for Your App

### 1. Hybrid Approach
```dart
class HybridAIService {
  OnDeviceAI? _onDeviceAI;
  bool _useOnDevice = false;
  
  Future<void> initializeAI() async {
    try {
      _onDeviceAI = OnDeviceAI();
      await _onDeviceAI!.loadModel('assets/models/small_model.tflite');
      _useOnDevice = true;
    } catch (e) {
      print('On-device AI not available, falling back to server');
      _useOnDevice = false;
    }
  }
  
  Future<String> generateResponse(String prompt) async {
    if (_useOnDevice && _onDeviceAI != null) {
      return await _onDeviceAI!.generateResponse(prompt);
    } else {
      // Fallback to your existing server-based AI
      return await BuddyService.sendMessage(prompt);
    }
  }
}
```

### 2. Update Your BuddyScreen
```dart
class _BuddyScreenState extends State<BuddyScreen> {
  HybridAIService _aiService = HybridAIService();
  
  @override
  void initState() {
    super.initState();
    _aiService.initializeAI();
  }
  
  Future<void> _sendMessage() async {
    // Use hybrid AI service instead of direct server calls
    final response = await _aiService.generateResponse(_controller.text);
    // Handle response...
  }
}
```

## Benefits of On-Device AI

1. **Privacy**: User data never leaves device
2. **Offline Capability**: Works without internet
3. **Low Latency**: No network round-trip
4. **Cost Effective**: No server compute costs
5. **Scalability**: Scales with user devices

## Challenges

1. **Model Size**: Large models may not fit in mobile storage/memory
2. **Performance**: Mobile CPUs are slower than server GPUs
3. **Battery Drain**: Intensive computations drain battery
4. **Platform Differences**: iOS vs Android optimization
5. **Model Updates**: Harder to update models on device

## Next Steps

1. Choose TensorFlow Lite for broad compatibility
2. Find or convert small quantized models (1-3GB max)
3. Implement progressive loading (download models on demand)
4. Add server fallback for complex queries
5. Implement user choice between on-device and cloud AI
