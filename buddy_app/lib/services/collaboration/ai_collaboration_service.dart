// Enhanced AI Collaboration Service for Flutter
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../auth/auth_service.dart';
import '../../models/collaboration_models.dart';

class AICollaborationService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/collaboration';

  // Create a new collaboration
  static Future<CollaborationProject> createCollaboration({
    required int projectId,
    required String name,
    String? description,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'project_id': projectId,
          'name': name,
          'description': description,
          'settings': settings ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return CollaborationProject.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Failed to create collaboration: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error creating collaboration: $e');
    }
  }

  // Send collaboration invitation
  static Future<bool> sendInvitation({
    required String collaborationId,
    required String inviteeMobile,
    required CollaborationRole role,
    String? message,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/invite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'collaboration_id': collaborationId,
          'invitee_mobile': inviteeMobile,
          'role': role.name,
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending invitation: $e');
      return false;
    }
  }

  // Get pending invitations for current user
  static Future<List<CollaborationInvitation>> getMyInvitations() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/invitations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((json) => CollaborationInvitation.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching invitations: $e');
      return [];
    }
  }

  // Respond to invitation (accept/reject)
  static Future<bool> respondToInvitation(
    String invitationId,
    bool accept,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/invitations/$invitationId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'accept': accept}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error responding to invitation: $e');
      return false;
    }
  }

  // Get AI insights for a project
  static Future<List<AICollaborationInsight>> getAIInsights(
    int projectId,
  ) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/insights'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((json) => AICollaborationInsight.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching AI insights: $e');
      return [];
    }
  }

  // Generate new AI insights
  static Future<bool> generateAIInsights(int projectId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/generate-insights'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error generating AI insights: $e');
      return false;
    }
  }

  // Real-time collaboration features
  static Future<void> startRealTimeCollaboration(String collaborationId) async {
    // TODO: Implement WebSocket connection for real-time updates
    print('Starting real-time collaboration for: $collaborationId');
  }

  static Future<void> stopRealTimeCollaboration() async {
    // TODO: Close WebSocket connection
    print('Stopping real-time collaboration');
  }

  // AI-powered project analysis
  static Future<ProjectAnalysis> analyzeProjectProgress(int projectId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/analysis'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ProjectAnalysis.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to analyze project: ${response.statusCode}');
      }
    } catch (e) {
      // Return mock data for now
      return ProjectAnalysis(
        overallProgress: 65.0,
        completedCheckpoints: 3,
        totalCheckpoints: 8,
        collaboratorContributions: {
          'user1': 45.0,
          'user2': 35.0,
          'user3': 20.0,
        },
        blockers: ['API integration pending', 'Design review needed'],
        suggestions: ['Focus on milestone 2', 'Schedule team sync'],
        estimatedCompletion: DateTime.now().add(const Duration(days: 14)),
      );
    }
  }

  // Auto-generate project documentation
  static Future<String> generateProjectDocumentation(int projectId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/generate-docs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['documentation'] ?? '';
      }
      return '';
    } catch (e) {
      print('Error generating documentation: $e');
      return '';
    }
  }

  // AI suggestions for next steps
  static Future<List<String>> getAINextStepSuggestions(int projectId) async {
    try {
      final insights = await getAIInsights(projectId);
      return insights
          .where((insight) => insight.insightType == 'suggestion')
          .map((insight) => insight.content)
          .toList();
    } catch (e) {
      print('Error getting AI suggestions: $e');
      return [];
    }
  }

  // Get pending collaboration invitations for chat messages
  static Future<List<CollaborationInvitation>> getPendingInvitations() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/invitations/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => CollaborationInvitation.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch pending invitations');
      }
    } catch (e) {
      print('Error fetching pending invitations: $e');
      return [];
    }
  }

  // Get user's collaborations for flow display
  static Future<List<CollaborationProject>> getUserCollaborations() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/user-collaborations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CollaborationProject.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch user collaborations');
      }
    } catch (e) {
      print('Error fetching user collaborations: $e');
      return [];
    }
  }

  // Convert collaboration invitation to chat message data
  static Map<String, dynamic> invitationToChatMessage(
    CollaborationInvitation invitation,
  ) {
    return {
      'project_id': invitation.id, // Using invitation id as placeholder
      'project_title': invitation.collaborationName,
      'invitation_id': invitation.id,
      'role': invitation.role.name,
      'message': invitation.message,
      'expires_at': invitation.expiresAt?.toIso8601String(),
      'response': null, // Response will be added when user responds
    };
  }

  // Get collaboration info for a project flow
  static Future<Map<String, dynamic>?> getCollaborationInfoForProject(
    int projectId,
  ) async {
    try {
      final collaborations = await getUserCollaborations();
      final collaboration = collaborations.firstWhere(
        (collab) => collab.projectId == projectId,
        orElse: () => throw Exception('No collaboration found'),
      );

      return {
        'collaboration_id': collaboration.id,
        'members': [], // Members would need to be fetched separately
        'is_owner': false, // Would need additional API endpoint
        'my_role': 'contributor', // Default role
        'total_members': collaboration.memberCount,
        'last_activity': collaboration.createdAt.toIso8601String(),
      };
    } catch (e) {
      print('Error getting collaboration info for project: $e');
      return null;
    }
  }
}
