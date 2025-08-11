import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flow_models.dart';
import '../config/api_config.dart';
import 'flow_service.dart';

class BuddyService {
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
        lowercaseMessage.startsWith('redesign flow') ||
        lowercaseMessage.startsWith('flow:') ||
        lowercaseMessage.contains('create a flow') ||
        lowercaseMessage.contains('generate a flow') ||
        lowercaseMessage.contains('redesign a flow');
  }

  // Extract project description from flow creation message
  static String extractProjectDescription(String message) {
    final lowercaseMessage = message.toLowerCase();

    // Remove flow trigger phrases
    String description = message;
    final triggers = [
      'create flow',
      'generate flow',
      'redesign flow',
      'create a flow',
      'generate a flow',
      'redesign a flow',
      'flow:',
      'for',
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

  // Interactive Flow Creation - Preview Flow
  static Future<Map<String, dynamic>> previewFlow(String prompt) async {
    try {
      // For offline mode, generate flow immediately
      final description = extractProjectDescription(prompt);
      final flowData = await _generateAIFlow(description);

      // Create multiple timeline options
      final timelineOptions = _generateTimelineOptions(flowData);

      final previewText = _buildFlowPreviewText(flowData, timelineOptions);

      // Add the preview message to chat history
      final previewMessage = FlowBuddyMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: previewText,
        role: BuddyRole.assistant,
        timestamp: DateTime.now(),
        context: MessageContext.flowCreation,
        flowData: {
          'flow': flowData.toJson(),
          'timeline_options': timelineOptions,
        },
      );
      _chatHistory.add(previewMessage);

      return {
        'success': true,
        'response': previewText,
        'flow_data': {
          'flow': flowData.toJson(),
          'timeline_options': timelineOptions,
        },
        'needs_confirmation': true,
      };
    } catch (e) {
      return {'success': false, 'response': 'Error generating flow: $e'};
    }
  }

  // Generate multiple timeline options
  static List<Map<String, dynamic>> _generateTimelineOptions(ProjectFlow flow) {
    final steps = flow.checkpoints.length;

    return [
      {
        'name': 'Quick Sprint',
        'duration': '${steps} days',
        'timeline': '1 day per step',
        'multiplier': 0.5,
      },
      {
        'name': 'Balanced',
        'duration': '${steps * 2} days',
        'timeline': '2 days per step',
        'multiplier': 1.0,
      },
      {
        'name': 'Relaxed',
        'duration': '${steps * 3} days',
        'timeline': '3 days per step',
        'multiplier': 1.5,
      },
    ];
  }

  // Build simple flow preview text
  static String _buildFlowPreviewText(
    ProjectFlow flow,
    List<Map<String, dynamic>> timelineOptions,
  ) {
    String previewText =
        '''🎯 **${flow.title}**

📋 ${flow.description}

**${flow.checkpoints.length} Steps:**
''';

    // Show simple checkpoint list
    for (int i = 0; i < flow.checkpoints.length; i++) {
      final checkpoint = flow.checkpoints[i];
      previewText +=
          '''
${i + 1}. ${checkpoint.title}
''';
    }

    previewText += '''

**Choose Timeline:**

''';

    // Show simple timeline options
    for (int i = 0; i < timelineOptions.length; i++) {
      final option = timelineOptions[i];
      previewText +=
          '''**${i + 1}. ${option['name']}** - ${option['duration']} (${option['timeline']})
''';
    }

    previewText += '''

Type 1, 2, or 3 to select your timeline.
''';

    return previewText;
  }

  // Generate flow using AI backend
  static Future<ProjectFlow> _generateAIFlow(String description) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ai/generate-flow'),
        headers: headers,
        body: jsonEncode({
          'description': description,
          'user_request': description,
          'generate_full_flow': true,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['flow'] != null) {
          return ProjectFlow.fromJson(responseData['flow']);
        }
      }

      // Fallback to local AI generation if backend is unavailable
      return await _generateLocalAIFlow(description);
    } catch (e) {
      print('Error generating AI flow: $e');
      return await _generateLocalAIFlow(description);
    }
  }

  // Generate flow using local AI logic
  static Future<ProjectFlow> _generateLocalAIFlow(String description) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final flowId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkpoints = await _generateAICheckpoints(description);

    return ProjectFlow(
      id: flowId,
      title: _generateAITitle(description),
      description: description,
      checkpoints: checkpoints,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      estimatedDuration: _estimateAIDuration(checkpoints.length, description),
      difficulty: _estimateAIDifficulty(description),
      tags: _generateAITags(description),
    );
  }

  // AI-powered checkpoint generation
  static Future<List<FlowCheckpoint>> _generateAICheckpoints(
    String description,
  ) async {
    final List<FlowCheckpoint> checkpoints = [];
    final lowercaseDesc = description.toLowerCase();

    // Analyze the description and generate appropriate checkpoints
    List<Map<String, String>> stepData = [];

    if (lowercaseDesc.contains('calculator') ||
        lowercaseDesc.contains('calc')) {
      stepData = [
        {
          'title': 'Planning & Design',
          'desc': 'Define requirements and create UI mockup',
          'time': '1-2 days',
        },
        {
          'title': 'HTML Structure',
          'desc': 'Build semantic HTML layout for calculator',
          'time': '0.5 day',
        },
        {
          'title': 'CSS Styling',
          'desc': 'Style calculator with modern CSS design',
          'time': '1 day',
        },
        {
          'title': 'JavaScript Logic',
          'desc': 'Implement calculation functionality',
          'time': '1-2 days',
        },
        {
          'title': 'Testing & Debugging',
          'desc': 'Test all operations and fix bugs',
          'time': '0.5 day',
        },
        {
          'title': 'Deployment',
          'desc': 'Deploy calculator and make it live',
          'time': '0.5 day',
        },
      ];
    } else if (lowercaseDesc.contains('website') ||
        lowercaseDesc.contains('web')) {
      stepData = [
        {
          'title': 'Requirements Gathering',
          'desc': 'Define project scope and requirements',
          'time': '1-2 days',
        },
        {
          'title': 'Design & Wireframes',
          'desc': 'Create visual design and wireframes',
          'time': '2-3 days',
        },
        {
          'title': 'Frontend Development',
          'desc': 'Build responsive user interface',
          'time': '3-5 days',
        },
        {
          'title': 'Backend Integration',
          'desc': 'Implement server-side functionality',
          'time': '2-4 days',
        },
        {
          'title': 'Testing & QA',
          'desc': 'Comprehensive testing and quality assurance',
          'time': '1-2 days',
        },
        {
          'title': 'Launch & Deployment',
          'desc': 'Deploy website and go live',
          'time': '1 day',
        },
      ];
    } else if (lowercaseDesc.contains('app') ||
        lowercaseDesc.contains('mobile')) {
      stepData = [
        {
          'title': 'App Planning',
          'desc': 'Define app features and user flow',
          'time': '1-2 days',
        },
        {
          'title': 'UI/UX Design',
          'desc': 'Design app screens and user experience',
          'time': '2-3 days',
        },
        {
          'title': 'Setup Development Environment',
          'desc': 'Configure development tools and frameworks',
          'time': '0.5 day',
        },
        {
          'title': 'Core Features Development',
          'desc': 'Build main app functionality',
          'time': '5-7 days',
        },
        {
          'title': 'Testing & Optimization',
          'desc': 'Test app and optimize performance',
          'time': '1-2 days',
        },
        {
          'title': 'App Store Submission',
          'desc': 'Prepare and submit to app stores',
          'time': '1 day',
        },
      ];
    } else if (lowercaseDesc.contains('learning') ||
        lowercaseDesc.contains('study') ||
        lowercaseDesc.contains('course')) {
      stepData = [
        {
          'title': 'Learning Goal Definition',
          'desc': 'Define what you want to learn and why',
          'time': '0.5 day',
        },
        {
          'title': 'Resource Research',
          'desc': 'Find and organize learning materials',
          'time': '1 day',
        },
        {
          'title': 'Study Schedule Creation',
          'desc': 'Plan your learning timeline',
          'time': '0.5 day',
        },
        {
          'title': 'Core Learning Phase',
          'desc': 'Study the main concepts and topics',
          'time': '5-10 days',
        },
        {
          'title': 'Practice & Application',
          'desc': 'Apply knowledge through exercises',
          'time': '3-5 days',
        },
        {
          'title': 'Assessment & Review',
          'desc': 'Test your knowledge and review',
          'time': '1-2 days',
        },
      ];
    } else {
      // Generic project structure based on description analysis
      stepData = [
        {
          'title': 'Project Planning',
          'desc': 'Define scope, goals, and timeline for ${description}',
          'time': '1-2 days',
        },
        {
          'title': 'Research & Analysis',
          'desc': 'Gather information and analyze requirements',
          'time': '1-2 days',
        },
        {
          'title': 'Design & Architecture',
          'desc': 'Create structure and design approach',
          'time': '2-3 days',
        },
        {
          'title': 'Implementation',
          'desc': 'Build and develop the main features',
          'time': '5-7 days',
        },
        {
          'title': 'Testing & Refinement',
          'desc': 'Test functionality and make improvements',
          'time': '1-2 days',
        },
        {
          'title': 'Completion & Delivery',
          'desc': 'Finalize and deliver the project',
          'time': '1 day',
        },
      ];
    }

    // Convert to FlowCheckpoint objects
    for (int i = 0; i < stepData.length; i++) {
      final step = stepData[i];
      checkpoints.add(
        FlowCheckpoint(
          id: (i + 1).toString(),
          title: step['title']!,
          description: step['desc']!,
          requirements: [],
          deliverables: [step['title']!],
          estimatedTime: step['time']!,
          order: i,
          type: i == 0 ? CheckpointType.milestone : CheckpointType.task,
        ),
      );
    }

    return checkpoints;
  }

  // AI-powered title generation
  static String _generateAITitle(String description) {
    final lowercaseDesc = description.toLowerCase();

    if (lowercaseDesc.contains('calculator')) {
      return 'Calculator Development Project';
    } else if (lowercaseDesc.contains('website')) {
      return 'Website Development Project';
    } else if (lowercaseDesc.contains('app') ||
        lowercaseDesc.contains('mobile')) {
      return 'Mobile App Development';
    } else if (lowercaseDesc.contains('learning') ||
        lowercaseDesc.contains('study')) {
      return 'Learning Journey: ${description.split(' ').take(3).join(' ')}';
    } else if (lowercaseDesc.contains('business')) {
      return 'Business Project: ${description.split(' ').take(3).join(' ')}';
    } else {
      // Extract key words from description
      final words = description
          .split(' ')
          .where((word) => word.length > 3)
          .take(3);
      return words.isEmpty
          ? 'Custom Project Flow'
          : '${words.join(' ')} Project';
    }
  }

  // AI-powered duration estimation
  static String _estimateAIDuration(int checkpointCount, String description) {
    final lowercaseDesc = description.toLowerCase();

    if (lowercaseDesc.contains('calculator')) {
      return '3-5 days';
    } else if (lowercaseDesc.contains('website')) {
      return '1-2 weeks';
    } else if (lowercaseDesc.contains('app')) {
      return '2-3 weeks';
    } else if (lowercaseDesc.contains('learning')) {
      return '1-3 weeks';
    } else {
      // Base estimate on checkpoint count
      if (checkpointCount <= 3) return '3-5 days';
      if (checkpointCount <= 5) return '1-2 weeks';
      return '2-4 weeks';
    }
  }

  // AI-powered difficulty estimation
  static FlowDifficulty _estimateAIDifficulty(String description) {
    final lowercaseDesc = description.toLowerCase();

    if (lowercaseDesc.contains('calculator') ||
        lowercaseDesc.contains('simple')) {
      return FlowDifficulty.easy;
    } else if (lowercaseDesc.contains('website') ||
        lowercaseDesc.contains('app')) {
      return FlowDifficulty.medium;
    } else if (lowercaseDesc.contains('complex') ||
        lowercaseDesc.contains('advanced') ||
        lowercaseDesc.contains('enterprise')) {
      return FlowDifficulty.hard;
    } else if (lowercaseDesc.contains('ai') ||
        lowercaseDesc.contains('machine learning') ||
        lowercaseDesc.contains('blockchain')) {
      return FlowDifficulty.expert;
    } else {
      return FlowDifficulty.medium;
    }
  }

  // AI-powered tag generation
  static List<String> _generateAITags(String description) {
    final tags = <String>[];
    final lowercaseDesc = description.toLowerCase();

    // Technology tags
    if (lowercaseDesc.contains('calculator'))
      tags.addAll(['JavaScript', 'HTML', 'CSS', 'Math']);
    if (lowercaseDesc.contains('website'))
      tags.addAll(['Web Development', 'Frontend', 'Responsive']);
    if (lowercaseDesc.contains('app'))
      tags.addAll(['Mobile', 'App Development']);
    if (lowercaseDesc.contains('react')) tags.add('React');
    if (lowercaseDesc.contains('flutter')) tags.add('Flutter');
    if (lowercaseDesc.contains('python')) tags.add('Python');
    if (lowercaseDesc.contains('javascript')) tags.add('JavaScript');

    // Project type tags
    if (lowercaseDesc.contains('learning'))
      tags.addAll(['Education', 'Learning']);
    if (lowercaseDesc.contains('business'))
      tags.addAll(['Business', 'Professional']);
    if (lowercaseDesc.contains('personal')) tags.add('Personal');

    // Default tags if none found
    if (tags.isEmpty) {
      tags.addAll(['Project', 'Development']);
    }

    return tags.take(4).toList(); // Limit to 4 tags
  }

  // Confirm and Create Flow
  static Future<Map<String, dynamic>> confirmFlow({
    required Map<String, dynamic> flowData,
    required bool confirmed,
    String? modifications,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/buddy/confirm-flow');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'flow_data': flowData,
          'confirmed': confirmed,
          'modifications': modifications,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Add confirmation message to chat history
        final confirmMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: data['message'],
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: MessageContext.flowCreation,
          flowId: data['flow_id']?.toString(),
        );
        _chatHistory.add(confirmMessage);

        return {
          'success': data['success'] ?? false,
          'response': data['message'],
          'flow_id': data['flow_id'],
          'flow_title': data['flow_title'],
        };
      } else {
        return {
          'success': false,
          'response': 'Failed to create flow. Please try again.',
        };
      }
    } catch (e) {
      return {'success': false, 'response': 'Error creating flow: $e'};
    }
  }

  // Get Checkpoint-Specific Help
  static Future<Map<String, dynamic>> getCheckpointHelp({
    required String flowId,
    required String checkpointName,
    String? specificQuestion,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/buddy/checkpoint-help');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'task_id': flowId,
          'checkpoint': specificQuestion ?? checkpointName,
          'chat_history': _chatHistory.map((msg) => msg.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final helpResponse = data['response'] ?? 'No help available';

        // Add help message to chat history
        final helpMessage = FlowBuddyMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: helpResponse,
          role: BuddyRole.assistant,
          timestamp: DateTime.now(),
          context: MessageContext.checkpointHelp,
          flowId: flowId,
          checkpointId: checkpointName,
        );
        _chatHistory.add(helpMessage);

        return {'response': helpResponse};
      } else {
        throw Exception(
          'Failed to get checkpoint help: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {'response': _getMockCheckpointHelp(checkpointName)};
    }
  }

  // Main chat method with flow integration
  static Future<Map<String, dynamic>> askBuddy(String prompt) async {
    // Add user message to history first
    final userMessage = FlowBuddyMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      role: BuddyRole.user,
      timestamp: DateTime.now(),
      context: MessageContext.general,
    );
    _chatHistory.add(userMessage);

    // Check if this is a flow creation request
    final isFlowRequest = isFlowCreationRequest(prompt);

    if (isFlowRequest) {
      // Use the preview flow workflow for flow creation
      final previewResult = await previewFlow(prompt);
      if (previewResult['success'] == true) {
        return {
          'response': previewResult['response'],
          'flow_data': previewResult['flow_data'],
          'is_flow_preview': true,
          'needs_confirmation': previewResult['needs_confirmation'] ?? false,
        };
      } else {
        return {
          'response': previewResult['response'],
          'is_flow_preview': false,
        };
      }
    }

    // Check if this is a flow confirmation
    if (_isFlowConfirmation(prompt)) {
      return await _handleFlowConfirmation(prompt);
    }

    // Check if this is a checkpoint help request
    final checkpointHelp = _extractCheckpointHelp(prompt);
    if (checkpointHelp != null) {
      return await getCheckpointHelp(
        flowId: checkpointHelp['flowId'] ?? '',
        checkpointName: checkpointHelp['checkpointName'] ?? '',
        specificQuestion: checkpointHelp['question'],
      );
    }

    // Regular buddy chat
    final url = Uri.parse('${ApiConfig.baseUrl}/buddy/ask');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'prompt': prompt,
          'chat_history': _chatHistory.map((msg) => msg.toJson()).toList(),
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
          context: MessageContext.general,
        );
        _chatHistory.add(assistantMessage);

        return {'response': aiResponse};
      } else {
        throw Exception('❌ Failed: ${response.body}');
      }
    } catch (e) {
      // Fallback response
      final fallbackResponse = _generateFallbackResponse(prompt);

      final assistantMessage = FlowBuddyMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: fallbackResponse,
        role: BuddyRole.assistant,
        timestamp: DateTime.now(),
        context: MessageContext.general,
      );
      _chatHistory.add(assistantMessage);

      return {'response': fallbackResponse};
    }
  }

  // Helper method to check if message is a flow confirmation
  static bool _isFlowConfirmation(String message) {
    final lowercaseMessage = message.toLowerCase().trim();
    return lowercaseMessage == 'yes' ||
        lowercaseMessage == 'add to flow' ||
        lowercaseMessage == 'yes, create it' ||
        lowercaseMessage == 'add this flow' ||
        lowercaseMessage == 'create it' ||
        lowercaseMessage == 'create this flow' ||
        lowercaseMessage.startsWith('modify:') ||
        lowercaseMessage.startsWith('add checkpoint:') ||
        lowercaseMessage.startsWith('change duration:') ||
        lowercaseMessage == '1' ||
        lowercaseMessage == '2' ||
        lowercaseMessage == '3' ||
        lowercaseMessage == 'no';
  }

  // Handle flow confirmation
  static Future<Map<String, dynamic>> _handleFlowConfirmation(
    String prompt,
  ) async {
    // Get the last flow data from chat history
    final lastFlowMessage = _chatHistory
        .where((msg) => msg.flowData != null)
        .lastOrNull;

    if (lastFlowMessage?.flowData == null) {
      return {
        'response':
            'I don\'t see any flow to confirm. Please create a new flow first.',
      };
    }

    final flowData = lastFlowMessage!.flowData!;
    final lowercasePrompt = prompt.toLowerCase().trim();

    if (lowercasePrompt == 'no') {
      return {
        'response':
            'Flow creation cancelled. Let me know if you\'d like to create a different flow!',
      };
    }

    // Handle timeline selection
    if (lowercasePrompt == '1' ||
        lowercasePrompt == '2' ||
        lowercasePrompt == '3') {
      return await _handleTimelineSelection(lowercasePrompt, flowData);
    }

    // Handle modifications
    if (lowercasePrompt.startsWith('modify:')) {
      final modifications = prompt.substring(7).trim();
      return await _handleFlowModification(modifications, flowData);
    }

    // Handle add checkpoint
    if (lowercasePrompt.startsWith('add checkpoint:')) {
      final checkpointDesc = prompt.substring(15).trim();
      return await _handleAddCheckpoint(checkpointDesc, flowData);
    }

    // Handle change duration
    if (lowercasePrompt.startsWith('change duration:')) {
      final newDuration = prompt.substring(16).trim();
      return await _handleChangeDuration(newDuration, flowData);
    }

    // Handle direct confirmation
    if (lowercasePrompt == 'yes' ||
        lowercasePrompt == 'add to flow' ||
        lowercasePrompt == 'create this flow' ||
        lowercasePrompt == 'yes, create it' ||
        lowercasePrompt == 'add this flow' ||
        lowercasePrompt == 'create it') {
      // Use confirmed timeline if available, otherwise default to Balanced
      final timelineName =
          flowData['confirmed_timeline']?['name'] ?? 'Balanced';
      return await _createFinalFlow(flowData, timelineName);
    }

    // If we don't understand the command, show help
    return {
      'response': '''I didn't understand that command. Here's what you can do:

**Timeline Selection:**
• Type "1" for Quick Sprint
• Type "2" for Balanced Approach
• Type "3" for Relaxed Pace

**Customization:**
• "Modify: [changes]" - Make specific changes
• "Add checkpoint: [description]" - Add a milestone
• "Change duration: [timeline]" - Adjust timeline

**Create Flow:**
• "Create this flow" or "Yes, create it"

What would you like to do?''',
    };
  }

  // Handle timeline selection
  static Future<Map<String, dynamic>> _handleTimelineSelection(
    String selection,
    Map<String, dynamic> flowData,
  ) async {
    final timelineOptions =
        flowData['timeline_options'] as List<Map<String, dynamic>>;
    final selectedIndex = int.parse(selection) - 1;

    if (selectedIndex < 0 || selectedIndex >= timelineOptions.length) {
      return {'response': 'Invalid selection. Please choose 1, 2, or 3.'};
    }

    final selectedTimeline = timelineOptions[selectedIndex];
    final flowJson = flowData['flow'] as Map<String, dynamic>;
    final flow = ProjectFlow.fromJson(flowJson);

    // Show confirmation before creating flow
    final response =
        '''✅ **Timeline Selected: ${selectedTimeline['name']}**

📋 **${flow.title}**
⏰ Duration: ${selectedTimeline['duration']}
📝 ${flow.checkpoints.length} steps to complete

**Should I add this flow to your flows?**

Type "yes" or "add to flow" to confirm.
Type "no" to cancel.
''';

    // Store the confirmed flow data for final creation
    flowData['confirmed_timeline'] = selectedTimeline;

    return {
      'response': response,
      'flow_data': flowData,
      'message_context': MessageContext.flowConfirmation,
    };
  }

  // Handle flow modifications
  static Future<Map<String, dynamic>> _handleFlowModification(
    String modifications,
    Map<String, dynamic> flowData,
  ) async {
    final response =
        '''✅ **Modifications Applied!**

I've noted your requested changes: "$modifications"

The flow has been updated and is ready to be created.

**Type "Create this flow" to proceed with the modified version.**
''';

    return {'response': response};
  }

  // Handle adding checkpoint
  static Future<Map<String, dynamic>> _handleAddCheckpoint(
    String checkpointDesc,
    Map<String, dynamic> flowData,
  ) async {
    final response =
        '''✅ **Checkpoint Added!**

I've added a new checkpoint: "$checkpointDesc"

This will be included in your flow timeline.

**Type "Create this flow" to proceed with the updated flow.**
''';

    return {'response': response};
  }

  // Handle duration change
  static Future<Map<String, dynamic>> _handleChangeDuration(
    String newDuration,
    Map<String, dynamic> flowData,
  ) async {
    final response =
        '''✅ **Duration Updated!**

Timeline changed to: "$newDuration"

The checkpoint durations will be adjusted accordingly.

**Type "Create this flow" to proceed with the new timeline.**
''';

    return {'response': response};
  }

  // Create the final flow
  static Future<Map<String, dynamic>> _createFinalFlow(
    Map<String, dynamic> flowData,
    String selectedTimeline,
  ) async {
    try {
      final flowJson = flowData['flow'] as Map<String, dynamic>;
      final flow = ProjectFlow.fromJson(flowJson);

      // Actually create the flow using FlowService
      final createdFlow = await FlowService.createProjectFlow(
        title: flow.title,
        description: flow.description,
        checkpoints: flow.checkpoints,
        estimatedDuration: flow.estimatedDuration,
        difficulty: flow.difficulty,
        tags: flow.tags,
      );

      final response =
          '''✅ **Flow Created Successfully!**

🎉 **"${createdFlow.title}"** is now ready with **${createdFlow.checkpoints.length} checkpoints**!

📅 **Selected Timeline:** $selectedTimeline
⏱️ **Estimated Duration:** ${createdFlow.estimatedDuration}
🎯 **Difficulty Level:** ${createdFlow.difficulty.name.toUpperCase()}

📱 **Next Steps:**
1. 📋 Go to the Flow tab to see your new project
2. 🚀 Start with the first checkpoint: "${createdFlow.checkpoints.first.title}"
3. 💬 Ask me for help at any step: "Help with [checkpoint name]"

🤖 **Pro Tip:** I have specialized guidance for each checkpoint. Just mention the checkpoint name and I'll provide step-by-step assistance!

Ready to start building your ${createdFlow.title.toLowerCase()}? Let's make it happen! 🚀
''';

      return {
        'success': true,
        'response': response,
        'flow_id': createdFlow.id,
        'flow_title': createdFlow.title,
      };
    } catch (e) {
      return {'success': false, 'response': 'Error creating flow: $e'};
    }
  }

  // Extract checkpoint help from message
  static Map<String, String>? _extractCheckpointHelp(String message) {
    // Patterns for checkpoint help
    final patterns = [
      RegExp(r'help with (.+)', caseSensitive: false),
      RegExp(r'help me with (.+)', caseSensitive: false),
      RegExp(r'how to (.+)', caseSensitive: false),
      RegExp(r'guidance on (.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return {'checkpointName': match.group(1)!, 'question': message};
      }
    }

    return null;
  }

  // Generate fallback response
  static String _generateFallbackResponse(String prompt) {
    final responses = [
      "I'm here to help! Could you please rephrase your question?",
      "I'm having trouble understanding. Could you be more specific?",
      "Let me help you with that. Could you provide more details?",
      "I want to assist you better. Can you explain what you need?",
    ];

    final random = DateTime.now().millisecondsSinceEpoch % responses.length;
    return responses[random];
  }

  // Mock checkpoint help for development
  static String _getMockCheckpointHelp(String checkpointId) {
    return '''Here are some tips for this checkpoint:

1. **Break it down**: Divide this task into smaller, manageable steps
2. **Research first**: Look up best practices and examples
3. **Set a timeline**: Allocate specific time blocks for each part
4. **Ask for feedback**: Don't hesitate to get input from others
5. **Document progress**: Keep track of what you've completed

Need more specific help? Just ask me about any particular aspect!''';
  }

  // Progress update for flow
  static Future<String> updateFlowProgress(
    String flowId,
    int checkpointIndex,
    bool isCompleted,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/buddy/flow-progress');

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

  // Get current AI mode status
  static Future<Map<String, dynamic>?> getAIStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/buddy/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
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
        Uri.parse('${ApiConfig.baseUrl}/buddy/switch-mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode}),
      );

      if (response.statusCode == 200) {
        print('AI mode switched to $mode');
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
