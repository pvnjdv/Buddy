import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'task_service.dart';
import '../models/flow_models.dart';

class BuddyService {
  static const String baseUrl = 'http://192.168.209.3:8000';
  static List<FlowBuddyMessage> _chatHistory = [];

  // Helper method to get authenticated headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get chat history
  static List<FlowBuddyMessage> getChatHistory() {
    return _chatHistory;
  }

  // Clear chat history
  static void clearChatHistory() {
    _chatHistory.clear();
  }

  // Check if message is a flow creation request
  static bool isFlowCreationRequest(String message) {
    final lowercaseMessage = message.toLowerCase();
    return lowercaseMessage.startsWith('create flow') ||
        lowercaseMessage.startsWith('generate flow') ||
        lowercaseMessage.startsWith('flow:') ||
        lowercaseMessage.contains('create a flow') ||
        lowercaseMessage.contains('generate a flow');
  }

  // Extract project description from flow creation message
  static String extractProjectDescription(String message) {
    final lowercaseMessage = message.toLowerCase();

    // Remove flow trigger phrases
    String description = message;
    final triggers = [
      'create flow',
      'generate flow',
      'flow:',
      'create a flow for',
      'generate a flow for',
      'create a flow to',
      'generate a flow to',
    ];

    for (final trigger in triggers) {
      if (lowercaseMessage.contains(trigger)) {
        final index = lowercaseMessage.indexOf(trigger);
        description = message.substring(index + trigger.length).trim();
        break;
      }
    }

    return description;
  }

  // Enhanced AI chat with flow context
  static Future<Map<String, dynamic>> askBuddy(String prompt) async {
    final url = Uri.parse('$baseUrl/buddy/ask');

    // Check if this is a flow creation request
    final isFlowRequest = isFlowCreationRequest(prompt);
    final messageContext = isFlowRequest
        ? MessageContext.flowCreation
        : MessageContext.general;

    // Add user message to history
    final userMessage = FlowBuddyMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      role: BuddyRole.user,
      timestamp: DateTime.now(),
      context: messageContext,
    );
    _chatHistory.add(userMessage);

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'prompt': prompt,
          'chat_history': _chatHistory.map((msg) => msg.toJson()).toList(),
          'is_flow_request': isFlowRequest,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'] ?? 'No response';

        // Add AI response to history
        final assistantMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiResponse,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: messageContext,
        );
        _chatHistory.add(assistantMessage);

        // If this was a flow request, also return flow data
        if (isFlowRequest && data.containsKey('flow_data')) {
          return {
            'response': aiResponse,
            'flow_data': data['flow_data'],
            'is_flow_created': true,
          };
        }

        return {'response': aiResponse, 'is_flow_created': false};
      } else {
        throw Exception('❌ Failed: ${response.body}');
      }
    } catch (e) {
      // Fallback for offline mode
      if (isFlowRequest) {
        final projectDescription = extractProjectDescription(prompt);
        final mockFlowData = await _generateMockFlow(projectDescription);
        final response =
            'I\'ve created a project flow for "$projectDescription". You can track your progress and get help at each checkpoint!';

        final assistantMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: MessageContext.flowCreation,
        );
        _chatHistory.add(assistantMessage);

        return {
          'response': response,
          'flow_data': mockFlowData,
          'is_flow_created': true,
        };
      }

      throw Exception('❌ Error: $e');
    }
  }

  // Generate project flow from description
  static Future<ProjectFlow> generateProjectFlow(
    String projectDescription,
  ) async {
    final url = Uri.parse('$baseUrl/buddy/generate-flow');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'project_description': projectDescription,
          'chat_history': _chatHistory.map((msg) => msg.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProjectFlow.fromJson(data['flow']);
      } else {
        throw Exception('❌ Failed to generate flow: ${response.body}');
      }
    } catch (e) {
      // Return mock flow for development
      return await _generateMockFlow(projectDescription);
    }
  }

  // Generate checkpoint help
  static Future<String> getCheckpointHelp(
    String flowId,
    String checkpointId,
  ) async {
    final url = Uri.parse('$baseUrl/buddy/checkpoint-help');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_id': checkpointId,
          'chat_history': _chatHistory.map((msg) => msg.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final helpContent = data['help'] ?? 'No help available';

        // Add help message to history
        final helpMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: helpContent,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: MessageContext.checkpointHelp,
          flowId: flowId,
          checkpointId: checkpointId,
        );
        _chatHistory.add(helpMessage);

        return helpContent;
      } else {
        throw Exception('❌ Failed to get checkpoint help: ${response.body}');
      }
    } catch (e) {
      return _getMockCheckpointHelp(checkpointId);
    }
  }

  // Progress update for flow
  static Future<String> updateFlowProgress(
    String flowId,
    int checkpointIndex,
    bool isCompleted,
  ) async {
    final url = Uri.parse('$baseUrl/buddy/flow-progress');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_index': checkpointIndex,
          'is_completed': isCompleted,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final progressMessage =
            data['message'] ?? 'Progress updated successfully!';

        // Add progress message to history
        final progressUpdateMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: progressMessage,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: MessageContext.flowProgress,
          flowId: flowId,
        );
        _chatHistory.add(progressUpdateMessage);

        return progressMessage;
      } else {
        throw Exception('❌ Failed to update progress: ${response.body}');
      }
    } catch (e) {
      return 'Great progress! Keep up the excellent work on your project.';
    }
  }

  // Mock flow generation for development
  static Future<ProjectFlow> _generateMockFlow(String description) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    final flowId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkpoints = _generateMockCheckpoints(description);

    return ProjectFlow(
      id: flowId,
      title: _generateFlowTitle(description),
      description: description,
      checkpoints: checkpoints,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      estimatedDuration: _estimateDuration(checkpoints.length),
      difficulty: _estimateDifficulty(description),
      tags: _generateTags(description),
    );
  }

  static List<FlowCheckpoint> _generateMockCheckpoints(String description) {
    final List<FlowCheckpoint> checkpoints = [];
    final lowercaseDesc = description.toLowerCase();

    if (lowercaseDesc.contains('website') || lowercaseDesc.contains('web')) {
      checkpoints.addAll([
        FlowCheckpoint(
          id: '1',
          title: 'Planning & Research',
          description: 'Define requirements and research the target audience.',
          requirements: ['Project scope', 'Target audience research'],
          deliverables: ['Requirements document', 'Research findings'],
          estimatedTime: '1-2 days',
          order: 0,
          type: CheckpointType.milestone,
        ),
        FlowCheckpoint(
          id: '2',
          title: 'Design & Wireframing',
          description: 'Create wireframes and visual designs.',
          requirements: ['Approved requirements', 'Design tools'],
          deliverables: ['Wireframes', 'Visual designs', 'Style guide'],
          estimatedTime: '2-3 days',
          order: 1,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '3',
          title: 'Frontend Development',
          description: 'Build the user interface and interactions.',
          requirements: ['Approved designs', 'Development environment'],
          deliverables: ['HTML/CSS code', 'Interactive components'],
          estimatedTime: '3-5 days',
          order: 2,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '4',
          title: 'Testing & Launch',
          description: 'Test functionality and deploy the website.',
          requirements: ['Completed development', 'Hosting setup'],
          deliverables: ['Test results', 'Live website'],
          estimatedTime: '1-2 days',
          order: 3,
          type: CheckpointType.review,
        ),
      ]);
    } else if (lowercaseDesc.contains('app') ||
        lowercaseDesc.contains('mobile')) {
      checkpoints.addAll([
        FlowCheckpoint(
          id: '1',
          title: 'Concept & Planning',
          description: 'Define app concept and create project plan.',
          requirements: ['App idea', 'Market research'],
          deliverables: ['App concept document', 'Project timeline'],
          estimatedTime: '2-3 days',
          order: 0,
          type: CheckpointType.milestone,
        ),
        FlowCheckpoint(
          id: '2',
          title: 'UI/UX Design',
          description: 'Design user interface and user experience.',
          requirements: ['Concept approval', 'Design tools'],
          deliverables: ['UI mockups', 'User flow diagrams'],
          estimatedTime: '4-5 days',
          order: 1,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '3',
          title: 'Development Setup',
          description: 'Set up development environment and architecture.',
          requirements: ['Approved designs', 'Development tools'],
          deliverables: ['Project structure', 'Basic navigation'],
          estimatedTime: '1-2 days',
          order: 2,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '4',
          title: 'Core Features',
          description: 'Implement main app functionality.',
          requirements: ['Development setup', 'Feature specifications'],
          deliverables: ['Working features', 'Basic app functionality'],
          estimatedTime: '5-7 days',
          order: 3,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '5',
          title: 'Testing & Deployment',
          description: 'Test the app and prepare for release.',
          requirements: ['Completed features', 'Test devices'],
          deliverables: ['Test results', 'Published app'],
          estimatedTime: '2-3 days',
          order: 4,
          type: CheckpointType.review,
        ),
      ]);
    } else {
      // Generic project checkpoints
      checkpoints.addAll([
        FlowCheckpoint(
          id: '1',
          title: 'Project Planning',
          description: 'Define project scope and create detailed plan.',
          requirements: ['Project idea', 'Resource assessment'],
          deliverables: ['Project plan', 'Timeline', 'Resource allocation'],
          estimatedTime: '1-2 days',
          order: 0,
          type: CheckpointType.milestone,
        ),
        FlowCheckpoint(
          id: '2',
          title: 'Research & Analysis',
          description: 'Conduct necessary research and analysis.',
          requirements: ['Project plan', 'Research tools'],
          deliverables: ['Research findings', 'Analysis report'],
          estimatedTime: '2-3 days',
          order: 1,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '3',
          title: 'Implementation',
          description: 'Execute the main project tasks.',
          requirements: ['Completed research', 'Implementation tools'],
          deliverables: ['Working solution', 'Progress reports'],
          estimatedTime: '5-7 days',
          order: 2,
          type: CheckpointType.task,
        ),
        FlowCheckpoint(
          id: '4',
          title: 'Review & Finalization',
          description: 'Review work and finalize the project.',
          requirements: ['Completed implementation', 'Review criteria'],
          deliverables: ['Final product', 'Documentation'],
          estimatedTime: '1-2 days',
          order: 3,
          type: CheckpointType.review,
        ),
      ]);
    }

    return checkpoints;
  }

  static String _generateFlowTitle(String description) {
    if (description.length <= 50) return description;
    return '${description.substring(0, 47)}...';
  }

  static String _estimateDuration(int checkpointCount) {
    if (checkpointCount <= 3) return '1 week';
    if (checkpointCount <= 5) return '2 weeks';
    return '3-4 weeks';
  }

  static FlowDifficulty _estimateDifficulty(String description) {
    final lowercaseDesc = description.toLowerCase();
    if (lowercaseDesc.contains('simple') || lowercaseDesc.contains('basic')) {
      return FlowDifficulty.easy;
    }
    if (lowercaseDesc.contains('complex') ||
        lowercaseDesc.contains('advanced')) {
      return FlowDifficulty.hard;
    }
    return FlowDifficulty.medium;
  }

  static List<String> _generateTags(String description) {
    final tags = <String>[];
    final lowercaseDesc = description.toLowerCase();

    if (lowercaseDesc.contains('website') || lowercaseDesc.contains('web')) {
      tags.addAll(['web', 'frontend']);
    }
    if (lowercaseDesc.contains('app') || lowercaseDesc.contains('mobile')) {
      tags.addAll(['mobile', 'app']);
    }
    if (lowercaseDesc.contains('business')) {
      tags.add('business');
    }
    if (lowercaseDesc.contains('design')) {
      tags.add('design');
    }

    return tags;
  }

  static String _getMockCheckpointHelp(String checkpointId) {
    return '''Here are some tips for this checkpoint:

1. **Break it down**: Divide this task into smaller, manageable steps
2. **Research first**: Look up best practices and examples
3. **Set a timeline**: Allocate specific time blocks for each part
4. **Ask for feedback**: Don't hesitate to get input from others
5. **Document progress**: Keep track of what you've completed

Need more specific help? Just ask me about any particular aspect!''';
  }

  // Legacy methods for backward compatibility
  static Future<Map<String, dynamic>> generateProjectTimeline(
    String projectDescription,
  ) async {
    final flow = await generateProjectFlow(projectDescription);
    return {
      'timeline': flow.checkpoints.map((c) => c.toJson()).toList(),
      'estimated_duration': flow.estimatedDuration,
      'difficulty': flow.difficulty.name,
      'tasks': flow.checkpoints.map((c) => c.title).toList(),
    };
  }

  static Future<bool> createTaskFromTimeline(
    Map<String, dynamic> timelineData,
    String userId,
  ) async {
    return await TaskService.createTaskFromTimeline(timelineData, userId);
  }

  // AI Mode Switching Methods

  // Get current AI mode status
  static Future<Map<String, dynamic>?> getAIStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/buddy/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get AI status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting AI status: $e');
      return null;
    }
  }

  // Switch AI mode between 'local' and 'api'
  static Future<bool> switchAIMode(String mode) async {
    try {
      if (mode != 'local' && mode != 'api') {
        print('Invalid mode: $mode. Must be "local" or "api"');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/buddy/switch-mode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mode': mode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('AI mode switched to: ${data['current_mode']}');
        return true;
      } else {
        print('Failed to switch AI mode: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error switching AI mode: $e');
      return false;
    }
  }
}
