import 'package:flutter/material.dart';
import '../services/ai/buddy_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({Key? key}) : super(key: key);

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  String _currentMode = 'api';
  bool _isLoading = false;
  Map<String, dynamic> _localAIInfo = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final mode = BuddyService.getCurrentAIMode();
    final localInfo = await BuddyService.getLocalAIInfo();
    
    setState(() {
      _currentMode = mode;
      _localAIInfo = localInfo;
    });
  }

  Future<void> _switchToLocalMode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await BuddyService.switchToLocalMode();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully switched to local AI mode!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadCurrentSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Failed to switch to local mode. Please select a valid model file.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchToAPIMode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await BuddyService.switchToAPIMode();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Switched back to API mode'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadCurrentSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Mode Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current AI Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _currentMode == 'local'
                              ? Icons.phone_android
                              : Icons.cloud,
                          color: _currentMode == 'local'
                              ? Colors.green
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentMode == 'local'
                              ? 'Local On-Device AI'
                              : 'Cloud API',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Local AI Information
            if (_currentMode == 'local') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local AI Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_localAIInfo['available'] == true) ...[
                        Text(
                          'Model Loaded: ${_localAIInfo['model_loaded'] ? 'Yes' : 'No'}',
                        ),
                        if (_localAIInfo['model_path'] != null)
                          Text(
                            'Model: ${_localAIInfo['model_path'].split('/').last}',
                          ),
                        Text(
                          'Device Capable: ${_localAIInfo['device_capable'] ? 'Yes' : 'No'}',
                        ),
                      ] else ...[
                        Text(
                          _localAIInfo['message'] ?? 'Local AI not available',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mode Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Switch AI Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // API Mode Option
                    ListTile(
                      leading: const Icon(Icons.cloud, color: Colors.blue),
                      title: const Text('Cloud API Mode'),
                      subtitle: const Text(
                        'Uses remote servers. Requires internet connection.',
                      ),
                      trailing: _currentMode == 'api'
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: _currentMode != 'api' && !_isLoading
                          ? _switchToAPIMode
                          : null,
                    ),

                    const Divider(),

                    // Local Mode Option
                    ListTile(
                      leading: const Icon(
                        Icons.phone_android,
                        color: Colors.green,
                      ),
                      title: const Text('Local On-Device AI'),
                      subtitle: const Text(
                        'Runs AI models directly on your device. Private and offline.',
                      ),
                      trailing: _currentMode == 'local'
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: _currentMode != 'local' && !_isLoading
                          ? _switchToLocalMode
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Information Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'About AI Modes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Cloud API: Fast, always up-to-date, requires internet\n'
                      '• Local AI: Private, works offline, requires compatible model files (.gguf)\n'
                      '• Local mode requires sufficient device memory and processing power',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Loading indicator
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Switching AI mode...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
