// Collaboration Models for Flutter App
class CollaborationProject {
  final String id;
  final int projectId;
  final String name;
  final String? description;
  final CollaborationStatus status;
  final int memberCount;
  final DateTime createdAt;

  CollaborationProject({
    required this.id,
    required this.projectId,
    required this.name,
    this.description,
    required this.status,
    required this.memberCount,
    required this.createdAt,
  });

  factory CollaborationProject.fromJson(Map<String, dynamic> json) {
    return CollaborationProject(
      id: json['id'],
      projectId: json['project_id'],
      name: json['name'],
      description: json['description'],
      status: CollaborationStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => CollaborationStatus.active,
      ),
      memberCount: json['member_count'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'description': description,
      'status': status.name,
      'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CollaborationInvitation {
  final String id;
  final String collaborationName;
  final String inviterName;
  final CollaborationRole role;
  final String? message;
  final DateTime invitedAt;
  final DateTime? expiresAt;

  CollaborationInvitation({
    required this.id,
    required this.collaborationName,
    required this.inviterName,
    required this.role,
    this.message,
    required this.invitedAt,
    this.expiresAt,
  });

  factory CollaborationInvitation.fromJson(Map<String, dynamic> json) {
    return CollaborationInvitation(
      id: json['id'],
      collaborationName: json['collaboration_name'],
      inviterName: json['inviter_name'],
      role: CollaborationRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => CollaborationRole.contributor,
      ),
      message: json['message'],
      invitedAt: DateTime.parse(json['invited_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collaboration_name': collaborationName,
      'inviter_name': inviterName,
      'role': role.name,
      'message': message,
      'invited_at': invitedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}

class AICollaborationInsight {
  final String id;
  final String insightType;
  final String title;
  final String content;
  final int relevanceScore;
  final DateTime createdAt;

  AICollaborationInsight({
    required this.id,
    required this.insightType,
    required this.title,
    required this.content,
    required this.relevanceScore,
    required this.createdAt,
  });

  factory AICollaborationInsight.fromJson(Map<String, dynamic> json) {
    return AICollaborationInsight(
      id: json['id'],
      insightType: json['insight_type'],
      title: json['title'],
      content: json['content'],
      relevanceScore: json['relevance_score'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'insight_type': insightType,
      'title': title,
      'content': content,
      'relevance_score': relevanceScore,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ProjectAnalysis {
  final double overallProgress;
  final int completedCheckpoints;
  final int totalCheckpoints;
  final Map<String, double> collaboratorContributions;
  final List<String> blockers;
  final List<String> suggestions;
  final DateTime estimatedCompletion;

  ProjectAnalysis({
    required this.overallProgress,
    required this.completedCheckpoints,
    required this.totalCheckpoints,
    required this.collaboratorContributions,
    required this.blockers,
    required this.suggestions,
    required this.estimatedCompletion,
  });

  factory ProjectAnalysis.fromJson(Map<String, dynamic> json) {
    return ProjectAnalysis(
      overallProgress: (json['overall_progress'] as num).toDouble(),
      completedCheckpoints: json['completed_checkpoints'],
      totalCheckpoints: json['total_checkpoints'],
      collaboratorContributions: Map<String, double>.from(
        json['collaborator_contributions'].map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      blockers: List<String>.from(json['blockers']),
      suggestions: List<String>.from(json['suggestions']),
      estimatedCompletion: DateTime.parse(json['estimated_completion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_progress': overallProgress,
      'completed_checkpoints': completedCheckpoints,
      'total_checkpoints': totalCheckpoints,
      'collaborator_contributions': collaboratorContributions,
      'blockers': blockers,
      'suggestions': suggestions,
      'estimated_completion': estimatedCompletion.toIso8601String(),
    };
  }
}

enum CollaborationStatus {
  pending,
  accepted,
  rejected,
  active,
  completed,
  cancelled,
}

enum CollaborationRole { owner, admin, contributor, viewer }

class CollaborationMember {
  final String id;
  final String userId;
  final String userName;
  final CollaborationRole role;
  final DateTime joinedAt;
  final DateTime lastActive;

  CollaborationMember({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.joinedAt,
    required this.lastActive,
  });

  factory CollaborationMember.fromJson(Map<String, dynamic> json) {
    return CollaborationMember(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      role: CollaborationRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => CollaborationRole.contributor,
      ),
      joinedAt: DateTime.parse(json['joined_at']),
      lastActive: DateTime.parse(json['last_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
      'last_active': lastActive.toIso8601String(),
    };
  }
}

class CollaborationActivity {
  final String id;
  final String userId;
  final String userName;
  final String activityType;
  final String description;
  final DateTime createdAt;

  CollaborationActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.activityType,
    required this.description,
    required this.createdAt,
  });

  factory CollaborationActivity.fromJson(Map<String, dynamic> json) {
    return CollaborationActivity(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      activityType: json['activity_type'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'activity_type': activityType,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
