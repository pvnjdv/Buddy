import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/collaboration_models.dart';
import '../../models/flow_models.dart';
import '../ai/chat_service.dart';

class TeamCollaborationService {
  static const String baseUrl = 'http://localhost:8000';

  // Send collaboration invitation via chat
  static Future<bool> sendCollaborationInvite({
    required String receiverMobile,
    required ProjectFlow flow,
    required CollaborationRole role,
    String? message,
  }) async {
    try {
      // Create collaboration data for the chat message
      final collaborationData = {
        'project_id': flow.id,
        'project_title': flow.title,
        'invitation_id': 'inv_${DateTime.now().millisecondsSinceEpoch}',
        'role': role.name,
        'message': message ?? 'Would you like to collaborate on this project?',
        'expires_at': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'response': null,
        'flow_details': {
          'description': flow.description,
          'difficulty': flow.difficulty.name,
          'estimated_duration': flow.estimatedDuration,
          'total_checkpoints': flow.checkpoints.length,
          'completed_checkpoints': flow.completedCheckpoints.length,
          'progress_percentage': flow.progressPercentage,
        },
      };

      // Send collaboration request as chat message
      final success = await ChatService.sendCollaborationRequest(
        receiverId: receiverMobile,
        collaborationData: collaborationData,
      );

      if (success) {
        // Optionally, also create a backend record of the invitation
        await _createInvitationRecord(
          flowId: flow.id,
          receiverMobile: receiverMobile,
          role: role,
          message: message,
        );
      }

      return success;
    } catch (e) {
      print('Error sending collaboration invite: $e');
      return false;
    }
  }

  // Create invitation record in backend
  static Future<void> _createInvitationRecord({
    required String flowId,
    required String receiverMobile,
    required CollaborationRole role,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collaboration/invitations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'project_id': flowId,
          'receiver_mobile': receiverMobile,
          'role': role.name,
          'message': message,
          'expires_at': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to create invitation record: ${response.body}');
      }
    } catch (e) {
      print('Error creating invitation record: $e');
    }
  }

  // Add work contribution to a checkpoint
  static Future<bool> addWorkContribution({
    required String flowId,
    required String checkpointId,
    required WorkContribution contribution,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collaboration/work-contributions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_id': checkpointId,
          'user_id': contribution.userId,
          'user_name': contribution.userName,
          'hours_worked': contribution.hoursWorked,
          'work_description': contribution.workDescription,
          'type': contribution.type.name,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding work contribution: $e');
      return false;
    }
  }

  // Get work contributions for a checkpoint
  static Future<List<WorkContribution>> getCheckpointContributions(
    String flowId,
    String checkpointId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/collaboration/work-contributions/$flowId/$checkpointId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => WorkContribution.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting checkpoint contributions: $e');
      return [];
    }
  }

  // Assign checkpoint to team member
  static Future<bool> assignCheckpoint({
    required String flowId,
    required String checkpointId,
    required String assigneeId,
    required String assigneeName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collaboration/assign-checkpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_id': checkpointId,
          'assignee_id': assigneeId,
          'assignee_name': assigneeName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error assigning checkpoint: $e');
      return false;
    }
  }

  // Add comment to checkpoint
  static Future<bool> addCheckpointComment({
    required String flowId,
    required String checkpointId,
    required String userId,
    required String userName,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collaboration/checkpoint-comments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_id': checkpointId,
          'user_id': userId,
          'user_name': userName,
          'comment': comment,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding checkpoint comment: $e');
      return false;
    }
  }

  // Record AI Buddy assistance for checkpoint
  static Future<bool> recordAIAssistance({
    required String flowId,
    required String checkpointId,
    required AIBuddyAssistance assistance,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collaboration/ai-assistance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flow_id': flowId,
          'checkpoint_id': checkpointId,
          'assistance_id': assistance.assistanceId,
          'query': assistance.query,
          'response': assistance.response,
          'type': assistance.type.name,
          'was_helpful': assistance.wasHelpful,
          'feedback': assistance.feedback,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error recording AI assistance: $e');
      return false;
    }
  }

  // Get AI assistance history for checkpoint
  static Future<List<AIBuddyAssistance>> getAIAssistanceHistory(
    String flowId,
    String checkpointId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collaboration/ai-assistance/$flowId/$checkpointId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => AIBuddyAssistance.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting AI assistance history: $e');
      return [];
    }
  }

  // Get team member statistics
  static Future<Map<String, dynamic>> getTeamMemberStats(String flowId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collaboration/team-stats/$flowId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error getting team member stats: $e');
      return {};
    }
  }
}
