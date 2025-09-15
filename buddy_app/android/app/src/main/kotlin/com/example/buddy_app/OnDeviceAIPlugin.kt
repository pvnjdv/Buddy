package com.example.buddy_app

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.tensorbuffer.TensorBuffer
import org.tensorflow.lite.DataType
import java.io.File
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class OnDeviceAIPlugin(private val context: Context) : MethodCallHandler {
    
    companion object {
        private const val CHANNEL = "on_device_ai"
    }
    
    private var tfliteInterpreter: Interpreter? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var modelLoaded = false
    private var modelPath: String? = null
    
    fun registerWith(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> loadModel(call, result)
            "generateResponse" -> generateResponse(call, result)
            "unloadModel" -> unloadModel(result)
            "getDeviceInfo" -> getDeviceInfo(result)
            "getAvailableMemory" -> getAvailableMemory(result)
            else -> result.notImplemented()
        }
    }
    
    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val modelFilePath = call.argument<String>("modelPath")
                    ?: throw IllegalArgumentException("Model path is required")
                
                val file = File(modelFilePath)
                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "Model file not found: $modelFilePath", null)
                    return@execute
                }
                
                // Check if file is a TFLite model
                if (!modelFilePath.endsWith(".tflite") && !modelFilePath.endsWith(".lite")) {
                    result.error("INVALID_FORMAT", "Only .tflite and .lite files are supported", null)
                    return@execute
                }
                
                // Load TFLite model
                val modelBuffer = loadModelFile(file)
                
                // Configure interpreter options
                val options = Interpreter.Options().apply {
                    setNumThreads(call.argument<Int>("nThreads") ?: 4)
                    setUseNNAPI(true) // Enable Android Neural Networks API if available
                    setUseXNNPACK(true) // Enable XNNPACK for CPU optimization
                }
                
                tfliteInterpreter = Interpreter(modelBuffer, options)
                modelLoaded = true
                modelPath = modelFilePath
                
                // Get model info
                val inputShape = tfliteInterpreter?.getInputTensor(0)?.shape()
                val outputShape = tfliteInterpreter?.getOutputTensor(0)?.shape()
                
                result.success(mapOf(
                    "success" to true,
                    "message" to "TFLite model loaded successfully",
                    "modelPath" to modelFilePath,
                    "inputShape" to inputShape?.toList(),
                    "outputShape" to outputShape?.toList()
                ))
            } catch (e: Exception) {
                result.error("LOAD_ERROR", "Error loading TFLite model: ${e.message}", null)
            }
        }
    }
    
    private fun generateResponse(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                if (!modelLoaded || tfliteInterpreter == null) {
                    result.error("NO_MODEL", "No TFLite model loaded", null)
                    return@execute
                }
                
                val prompt = call.argument<String>("prompt")
                    ?: throw IllegalArgumentException("Prompt is required")
                
                // For now, implement a simple text processing approach
                // This will need to be customized based on your specific TFLite model
                val response = processTextWithTFLite(prompt)
                
                result.success(mapOf(
                    "success" to true,
                    "response" to response
                ))
            } catch (e: Exception) {
                result.error("GENERATE_ERROR", "Error generating response: ${e.message}", null)
            }
        }
    }
    
    private fun processTextWithTFLite(prompt: String): String {
        return try {
            // This is a placeholder implementation
            // The actual implementation depends on your specific TFLite model
            // For conversational AI models, you would:
            // 1. Tokenize the input text
            // 2. Convert to input tensors
            // 3. Run inference
            // 4. Decode output tensors back to text
            
            val interpreter = tfliteInterpreter ?: return "Model not loaded"
            
            // For demonstration, let's create a contextual response
            when {
                prompt.lowercase().contains("hello") || prompt.lowercase().contains("hi") -> {
                    "Hello! I'm Buddy running on TensorFlow Lite. How can I help you today?"
                }
                prompt.lowercase().contains("how are you") -> {
                    "I'm doing great! I'm now powered by TensorFlow Lite, which makes me much more efficient on your device."
                }
                prompt.contains("?") -> {
                    "That's an interesting question! With TensorFlow Lite, I can process your queries directly on your device for better privacy and speed."
                }
                prompt.lowercase().contains("math") || prompt.contains("+") || prompt.contains("-") -> {
                    "I can help with math problems! TensorFlow Lite enables me to perform calculations efficiently on your device."
                }
                else -> {
                    "Thanks for your message! I'm running on TensorFlow Lite now, which provides better performance and privacy. How else can I assist you?"
                }
            }
        } catch (e: Exception) {
            "TFLite processing error: ${e.message}"
        }
    }
    
    private fun unloadModel(result: MethodChannel.Result) {
        executor.execute {
            try {
                tfliteInterpreter?.close()
                tfliteInterpreter = null
                modelLoaded = false
                modelPath = null
                
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                result.error("UNLOAD_ERROR", "Error unloading TFLite model: ${e.message}", null)
            }
        }
    }
    
    private fun getDeviceInfo(result: MethodChannel.Result) {
        try {
            // Get device memory information
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            // Get app memory information for comparison
            val runtime = Runtime.getRuntime()
            val appAvailableMemory = runtime.maxMemory() - (runtime.totalMemory() - runtime.freeMemory())
            val cpuCores = Runtime.getRuntime().availableProcessors()
            
            result.success(mapOf(
                "deviceAvailableMemory" to memoryInfo.availMem,
                "deviceTotalMemory" to memoryInfo.totalMem,
                "appAvailableMemory" to appAvailableMemory,
                "appMaxMemory" to runtime.maxMemory(),
                "cpuCores" to cpuCores,
                "isLowMemory" to memoryInfo.lowMemory,
                "aiFramework" to "TensorFlow Lite",
                "modelLoaded" to modelLoaded,
                "currentModel" to (modelPath ?: "None")
            ))
        } catch (e: Exception) {
            result.error("DEVICE_INFO_ERROR", "Error getting device info: ${e.message}", null)
        }
    }
    
    private fun getAvailableMemory(result: MethodChannel.Result) {
        try {
            // Get actual device memory information
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            // Use device available memory instead of app heap memory
            val deviceAvailableMemory = memoryInfo.availMem
            val totalDeviceMemory = memoryInfo.totalMem
            
            // For debugging - log the values
            println("TFLite - Device Total Memory: ${totalDeviceMemory / (1024 * 1024)} MB")
            println("TFLite - Device Available Memory: ${deviceAvailableMemory / (1024 * 1024)} MB")
            
            result.success(deviceAvailableMemory)
        } catch (e: Exception) {
            result.error("MEMORY_ERROR", "Error getting available memory: ${e.message}", null)
        }
    }
    
    private fun loadModelFile(file: File): MappedByteBuffer {
        val fileInputStream = FileInputStream(file)
        val fileChannel = fileInputStream.channel
        val startOffset = 0L
        val declaredLength = fileChannel.size()
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }
}
