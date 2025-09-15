package com.example.buddy_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the OnDeviceAI plugin
        OnDeviceAIPlugin(this).registerWith(flutterEngine)
    }
}
