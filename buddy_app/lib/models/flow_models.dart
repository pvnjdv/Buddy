import 'collaboration_models.dart';
import 'package:flutter/material.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final List<String> labels;
  final String color;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteType type;
  final List<ChecklistItem> checklist;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.labels = const [],
    this.color = '#FFFFFF',
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.type = NoteType.text,
    this.checklist = const [],
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
      color: json['color']?.toString() ?? '#FFFFFF',
      isPinned: json['is_pinned'] ?? false,
      isArchived: json['is_archived'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      type: NoteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NoteType.text,
      ),
      checklist:
          (json['checklist'] as List<dynamic>?)
              ?.map((item) => ChecklistItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'labels': labels,
      'color': color,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'type': type.name,
      'checklist': checklist.map((item) => item.toJson()).toList(),
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? labels,
    String? color,
    bool? isPinned,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    NoteType? type,
    List<ChecklistItem>? checklist,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      labels: labels ?? this.labels,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      checklist: checklist ?? this.checklist,
    );
  }
}

class ChecklistItem {
  final String id;
  final String text;
  final bool isCompleted;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'is_completed': isCompleted};
  }

  ChecklistItem copyWith({String? id, String? text, bool? isCompleted}) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum NoteType { text, checklist, drawing }

class NoteColors {
  static const String white = '#FFFFFF';
  static const String red = '#F28B82';
  static const String orange = '#FBBC04';
  static const String yellow = '#FFF475';
  static const String green = '#CCFF90';
  static const String teal = '#A7FFEB';
  static const String blue = '#CBF0F8';
  static const String darkBlue = '#AECBFA';
  static const String purple = '#D7AEFB';
  static const String pink = '#FDCFE8';
  static const String brown = '#E6C9A8';
  static const String grey = '#E8EAED';

  static const List<String> all = [
    white,
    red,
    orange,
    yellow,
    green,
    teal,
    blue,
    darkBlue,
    purple,
    pink,
    brown,
    grey,
  ];
}

// Chat models for enhanced chat functionality
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final String? mediaUrl;
  final String? replyToId;
  final CollaborationData?
  collaborationData; // New field for collaboration requests

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.mediaUrl,
    this.replyToId,
    this.collaborationData,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      mediaUrl: json['media_url']?.toString(),
      replyToId: json['reply_to_id']?.toString(),
      collaborationData: json['collaboration_data'] != null
          ? CollaborationData.fromJson(json['collaboration_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'media_url': mediaUrl,
      'reply_to_id': replyToId,
      'collaboration_data': collaborationData?.toJson(),
    };
  }
}

enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  collaboration_request, // New type for collaboration invitations
  collaboration_response, // New type for collaboration responses
}

enum MessageStatus { sent, delivered, read }

// Collaboration data for chat messages
class CollaborationData {
  final String projectId;
  final String projectTitle;
  final String invitationId;
  final CollaborationRole role;
  final String? message;
  final DateTime? expiresAt;
  final String? response; // 'accepted', 'rejected', or null for pending

  CollaborationData({
    required this.projectId,
    required this.projectTitle,
    required this.invitationId,
    required this.role,
    this.message,
    this.expiresAt,
    this.response,
  });

  factory CollaborationData.fromJson(Map<String, dynamic> json) {
    return CollaborationData(
      projectId: json['project_id']?.toString() ?? '',
      projectTitle: json['project_title']?.toString() ?? '',
      invitationId: json['invitation_id']?.toString() ?? '',
      role: CollaborationRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => CollaborationRole.contributor,
      ),
      message: json['message']?.toString(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      response: json['response']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_title': projectTitle,
      'invitation_id': invitationId,
      'role': role.name,
      'message': message,
      'expires_at': expiresAt?.toIso8601String(),
      'response': response,
    };
  }

  bool get isPending => response == null;
  bool get isAccepted => response == 'accepted';
  bool get isRejected => response == 'rejected';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

// Project collaboration information for flows
class ProjectCollaborationInfo {
  final String collaborationId;
  final List<CollaborationMember> members;
  final bool isOwner;
  final CollaborationRole myRole;
  final int totalMembers;
  final DateTime? lastActivity;

  ProjectCollaborationInfo({
    required this.collaborationId,
    required this.members,
    required this.isOwner,
    required this.myRole,
    required this.totalMembers,
    this.lastActivity,
  });

  factory ProjectCollaborationInfo.fromJson(Map<String, dynamic> json) {
    return ProjectCollaborationInfo(
      collaborationId: json['collaboration_id']?.toString() ?? '',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => CollaborationMember.fromJson(m))
              .toList() ??
          [],
      isOwner: json['is_owner'] ?? false,
      myRole: CollaborationRole.values.firstWhere(
        (r) => r.name == json['my_role'],
        orElse: () => CollaborationRole.viewer,
      ),
      totalMembers: json['total_members'] ?? 0,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collaboration_id': collaborationId,
      'members': members.map((m) => m.toJson()).toList(),
      'is_owner': isOwner,
      'my_role': myRole.name,
      'total_members': totalMembers,
      'last_activity': lastActivity?.toIso8601String(),
    };
  }
}

class ChatContact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? profileImageUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  ChatContact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    this.profileImageUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final phoneNumber = json['phone_number']?.toString();

    return ChatContact(
      id: json['id']?.toString() ?? '',
      name: name.isNotEmpty ? name : (phoneNumber ?? 'Unknown'),
      phoneNumber: phoneNumber,
      email: json['email']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
    );
  }
}

// Buddy AI models
class BuddyConversation {
  final String id;
  final String title;
  final List<BuddyMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  BuddyConversation({
    required this.id,
    required this.title,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuddyConversation.fromJson(Map<String, dynamic> json) {
    return BuddyConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((msg) => BuddyMessage.fromJson(msg))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BuddyMessage {
  final String id;
  final String content;
  final BuddyRole role;
  final DateTime timestamp;
  final bool isTyping;

  BuddyMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isTyping = false,
  });

  // Helper method to create a copy with updated typing status
  BuddyMessage copyWith({
    String? id,
    String? content,
    BuddyRole? role,
    DateTime? timestamp,
    bool? isTyping,
  }) {
    return BuddyMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  factory BuddyMessage.fromJson(Map<String, dynamic> json) {
    return BuddyMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      role: BuddyRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => BuddyRole.user,
      ),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

enum BuddyRole { user, assistant }

// FlowBuddyMessage - specialized message for flow-based buddy conversations
class FlowBuddyMessage {
  final String id;
  final String content;
  final String role;
  final DateTime timestamp;
  final String? flowId;
  final String? checkpointId;

  FlowBuddyMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.flowId,
    this.checkpointId,
  });

  factory FlowBuddyMessage.fromJson(Map<String, dynamic> json) {
    return FlowBuddyMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      flowId: json['flow_id']?.toString(),
      checkpointId: json['checkpoint_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      if (flowId != null) 'flow_id': flowId,
      if (checkpointId != null) 'checkpoint_id': checkpointId,
    };
  }
}

// Status models for sync service
enum StatusType { image, video, text, document }

class StatusItem {
  final String id;
  final String name;
  final String? content;
  final StatusType type;
  final DateTime? timestamp;
  final String? userId;
  final String? userName;
  final String? mediaUrl;
  bool seen;

  StatusItem({
    required this.id,
    required this.name,
    this.content,
    required this.type,
    this.timestamp,
    this.userId,
    this.userName,
    this.mediaUrl,
    this.seen = false,
  });

  factory StatusItem.fromJson(Map<String, dynamic> json) {
    return StatusItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      content: json['content']?.toString(),
      type: StatusType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StatusType.text,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      seen: json['seen'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (content != null) 'content': content,
      'type': type.name,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (userName != null) 'user_name': userName,
      if (mediaUrl != null) 'media_url': mediaUrl,
      'seen': seen,
    };
  }
}

// Flow domain enums and resource model
enum FlowStatus { active, completed, paused, cancelled }

enum FlowDifficulty { easy, medium, hard, expert }

// Enhanced Jira-like issue types
enum CheckpointType {
  epic, // Large user story that can be broken down
  story, // User story with acceptance criteria
  task, // General work item
  bug, // Bug report/fix
  subtask, // Sub-item of another checkpoint
  milestone, // Project milestone
  review, // Code/design review
  testing,
  documentation, // Testing task
}

// Jira-like status workflow
enum CheckpointStatus {
  todo, // To Do
  inProgress, // In Progress
  codeReview, // Code Review
  testing, // Testing
  done, // Done
  blocked, // Blocked
  cancelled, // Cancelled
}

// Priority levels (Jira-style)
enum CheckpointPriority {
  highest, // Highest
  high, // High
  medium, // Medium
  low, // Low
  lowest, // Lowest
}

// Sprint information
enum SprintStatus { planning, active, completed, cancelled }

enum ResourceType { link, document, video, tutorial, tool }

// Jira-like Sprint model
class FlowSprint {
  final String id;
  final String name;
  final String? goal;
  final DateTime startDate;
  final DateTime endDate;
  final SprintStatus status;
  final List<String> checkpointIds;
  final int capacity; // Story points capacity
  final int? burndownHours;

  const FlowSprint({
    required this.id,
    required this.name,
    this.goal,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.checkpointIds = const [],
    this.capacity = 40,
    this.burndownHours,
  });

  factory FlowSprint.fromJson(Map<String, dynamic> json) => FlowSprint(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    goal: json['goal']?.toString(),
    startDate: DateTime.parse(
      json['start_date'] ?? DateTime.now().toIso8601String(),
    ),
    endDate: DateTime.parse(
      json['end_date'] ??
          DateTime.now().add(const Duration(days: 14)).toIso8601String(),
    ),
    status: SprintStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => SprintStatus.planning,
    ),
    checkpointIds:
        (json['checkpoint_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    capacity: json['capacity'] ?? 40,
    burndownHours: json['burndown_hours'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'goal': goal,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'status': status.name,
    'checkpoint_ids': checkpointIds,
    'capacity': capacity,
    'burndown_hours': burndownHours,
  };

  Duration get duration => endDate.difference(startDate);
  bool get isActive => status == SprintStatus.active;
  bool get isCompleted => status == SprintStatus.completed;
}

// Enhanced time tracking
class TimeTracking {
  final Duration? originalEstimate;
  final Duration? remainingEstimate;
  final Duration timeSpent;
  final List<WorkLog> workLogs;

  const TimeTracking({
    this.originalEstimate,
    this.remainingEstimate,
    this.timeSpent = Duration.zero,
    this.workLogs = const [],
  });

  factory TimeTracking.fromJson(Map<String, dynamic> json) => TimeTracking(
    originalEstimate: json['original_estimate'] != null
        ? Duration(minutes: json['original_estimate'])
        : null,
    remainingEstimate: json['remaining_estimate'] != null
        ? Duration(minutes: json['remaining_estimate'])
        : null,
    timeSpent: Duration(minutes: json['time_spent'] ?? 0),
    workLogs:
        (json['work_logs'] as List<dynamic>?)
            ?.map((e) => WorkLog.fromJson(e))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'original_estimate': originalEstimate?.inMinutes,
    'remaining_estimate': remainingEstimate?.inMinutes,
    'time_spent': timeSpent.inMinutes,
    'work_logs': workLogs.map((e) => e.toJson()).toList(),
  };

  double get progressPercentage {
    if (originalEstimate == null || originalEstimate!.inMinutes == 0) return 0;
    return (timeSpent.inMinutes / originalEstimate!.inMinutes * 100).clamp(
      0,
      100,
    );
  }
}

class WorkLog {
  final String id;
  final String userId;
  final String userName;
  final Duration timeSpent;
  final String? description;
  final DateTime loggedAt;

  const WorkLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timeSpent,
    this.description,
    required this.loggedAt,
  });

  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
    id: json['id']?.toString() ?? '',
    userId: json['user_id']?.toString() ?? '',
    userName: json['user_name']?.toString() ?? '',
    timeSpent: Duration(minutes: json['time_spent'] ?? 0),
    description: json['description']?.toString(),
    loggedAt: DateTime.parse(
      json['logged_at'] ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'time_spent': timeSpent.inMinutes,
    'description': description,
    'logged_at': loggedAt.toIso8601String(),
  };
}

// Enhanced issue linking
class IssueLink {
  final String id;
  final String targetId;
  final IssueLinkType type;
  final String? description;

  const IssueLink({
    required this.id,
    required this.targetId,
    required this.type,
    this.description,
  });

  factory IssueLink.fromJson(Map<String, dynamic> json) => IssueLink(
    id: json['id']?.toString() ?? '',
    targetId: json['target_id']?.toString() ?? '',
    type: IssueLinkType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => IssueLinkType.relates,
    ),
    description: json['description']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'target_id': targetId,
    'type': type.name,
    'description': description,
  };
}

enum IssueLinkType {
  blocks, // This issue blocks the linked issue
  blockedBy, // This issue is blocked by the linked issue
  relates, // General relation
  duplicates, // This issue duplicates the linked issue
  duplicatedBy, // This issue is duplicated by the linked issue
  parentOf, // This issue is parent of the linked issue
  childOf, // This issue is child of the linked issue
}

class FlowResource {
  final String id;
  final String title;
  final String description;
  final String url;
  final ResourceType type;
  final DateTime? createdAt;

  const FlowResource({
    this.id = '',
    required this.title,
    required this.description,
    required this.url,
    this.type = ResourceType.link,
    this.createdAt,
  });

  factory FlowResource.fromJson(Map<String, dynamic> json) => FlowResource(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    type: ResourceType.values.firstWhere(
      (e) => e.name == (json['type']?.toString() ?? ''),
      orElse: () => ResourceType.link,
    ),
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'title': title,
    'description': description,
    'url': url,
    'type': type.name,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}

// Flow models for project management
class ProjectFlow {
  final String id;
  final String title;
  final String description;
  final List<FlowCheckpoint> checkpoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FlowStatus status;
  final int currentCheckpointIndex;
  final String estimatedDuration;
  final FlowDifficulty difficulty;
  final List<String> tags;
  final ProjectCollaborationInfo?
  collaboration; // New field for collaboration info
  final String? repositoryUrl; // GitHub repository URL
  final String? localPath; // Local repository path
  final List<String> notes; // Flow-specific notes
  final List<String> alarms; // Critical alarms and reminders

  ProjectFlow({
    required this.id,
    required this.title,
    required this.description,
    this.checkpoints = const [],
    required this.createdAt,
    required this.updatedAt,
    this.status = FlowStatus.active,
    this.currentCheckpointIndex = 0,
    this.estimatedDuration = '1 week',
    this.difficulty = FlowDifficulty.medium,
    this.tags = const [],
    this.collaboration,
    this.repositoryUrl,
    this.localPath,
    this.notes = const [],
    this.alarms = const [],
  });

  factory ProjectFlow.fromJson(Map<String, dynamic> json) {
    return ProjectFlow(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      checkpoints:
          (json['checkpoints'] as List<dynamic>?)
              ?.map((checkpoint) => FlowCheckpoint.fromJson(checkpoint))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      status: FlowStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FlowStatus.active,
      ),
      currentCheckpointIndex: json['current_checkpoint_index'] ?? 0,
      estimatedDuration: json['estimated_duration'] ?? '1 week',
      difficulty: FlowDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => FlowDifficulty.medium,
      ),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      collaboration: json['collaboration'] != null
          ? ProjectCollaborationInfo.fromJson(json['collaboration'])
          : null,
      repositoryUrl: json['repository_url']?.toString(),
      localPath: json['local_path']?.toString(),
      notes: (json['notes'] as List<dynamic>?)?.cast<String>() ?? [],
      alarms: (json['alarms'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'checkpoints': checkpoints
          .map((checkpoint) => checkpoint.toJson())
          .toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status.name,
      'current_checkpoint_index': currentCheckpointIndex,
      'estimated_duration': estimatedDuration,
      'difficulty': difficulty.name,
      'tags': tags,
      'collaboration': collaboration?.toJson(),
      'repository_url': repositoryUrl,
      'local_path': localPath,
      'notes': notes,
      'alarms': alarms,
    };
  }

  ProjectFlow copyWith({
    String? id,
    String? title,
    String? description,
    List<FlowCheckpoint>? checkpoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    FlowStatus? status,
    int? currentCheckpointIndex,
    String? estimatedDuration,
    FlowDifficulty? difficulty,
    List<String>? tags,
    ProjectCollaborationInfo? collaboration,
    String? repositoryUrl,
    String? localPath,
    List<String>? notes,
    List<String>? alarms,
  }) {
    return ProjectFlow(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      checkpoints: checkpoints ?? this.checkpoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      currentCheckpointIndex:
          currentCheckpointIndex ?? this.currentCheckpointIndex,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      collaboration: collaboration ?? this.collaboration,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      localPath: localPath ?? this.localPath,
      notes: notes ?? this.notes,
      alarms: alarms ?? this.alarms,
    );
  }

  double get progressPercentage {
    if (checkpoints.isEmpty) return 0.0;
    final completedCount = checkpoints.where((c) => c.isCompleted).length;
    return (completedCount / checkpoints.length) * 100;
  }

  FlowCheckpoint? get currentCheckpoint {
    if (currentCheckpointIndex >= checkpoints.length) return null;
    return checkpoints[currentCheckpointIndex];
  }

  List<FlowCheckpoint> get completedCheckpoints {
    return checkpoints.where((c) => c.isCompleted).toList();
  }

  List<FlowCheckpoint> get pendingCheckpoints {
    return checkpoints.where((c) => !c.isCompleted).toList();
  }
}

// Work contribution tracking
class WorkContribution {
  final String userId;
  final String userName;
  final double hoursWorked;
  final String workDescription;
  final DateTime contributedAt;
  final ContributionType type;

  WorkContribution({
    required this.userId,
    required this.userName,
    required this.hoursWorked,
    required this.workDescription,
    required this.contributedAt,
    this.type = ContributionType.development,
  });

  factory WorkContribution.fromJson(Map<String, dynamic> json) {
    return WorkContribution(
      userId: json['user_id'],
      userName: json['user_name'],
      hoursWorked: (json['hours_worked'] as num).toDouble(),
      workDescription: json['work_description'],
      contributedAt: DateTime.parse(json['contributed_at']),
      type: ContributionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContributionType.development,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'hours_worked': hoursWorked,
      'work_description': workDescription,
      'contributed_at': contributedAt.toIso8601String(),
      'type': type.name,
    };
  }
}

// AI Buddy assistance tracking
class AIBuddyAssistance {
  final String assistanceId;
  final String query;
  final String response;
  final DateTime requestedAt;
  final AIAssistanceType type;
  final bool wasHelpful;
  final String? feedback;

  AIBuddyAssistance({
    required this.assistanceId,
    required this.query,
    required this.response,
    required this.requestedAt,
    this.type = AIAssistanceType.guidance,
    this.wasHelpful = false,
    this.feedback,
  });

  factory AIBuddyAssistance.fromJson(Map<String, dynamic> json) {
    return AIBuddyAssistance(
      assistanceId: json['assistance_id'],
      query: json['query'],
      response: json['response'],
      requestedAt: DateTime.parse(json['requested_at']),
      type: AIAssistanceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AIAssistanceType.guidance,
      ),
      wasHelpful: json['was_helpful'] ?? false,
      feedback: json['feedback'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assistance_id': assistanceId,
      'query': query,
      'response': response,
      'requested_at': requestedAt.toIso8601String(),
      'type': type.name,
      'was_helpful': wasHelpful,
      'feedback': feedback,
    };
  }
}

// Enums for contribution and assistance types
enum ContributionType {
  development,
  testing,
  review,
  documentation,
  research,
  design,
  other,
}

enum AIAssistanceType {
  guidance,
  troubleshooting,
  codeReview,
  explanation,
  optimization,
  testing,
  other,
}

class FlowCheckpoint {
  final String id;
  final String title;
  final String description;
  final List<String> requirements;
  final List<String> deliverables;
  final String estimatedTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<FlowResource> resources;
  final CheckpointType type;
  final int order;
  final List<WorkContribution> workContributions;
  final List<String> collaboratorComments;
  final String? assignedTo;
  final AIBuddyAssistance? aiAssistance;
  // Added for nested checkpoints and auto-marking
  final List<FlowCheckpoint> children;
  final List<String> filePatterns;
  final List<String> filePaths;
  final List<String> rules;

  // New Jira-like fields
  final CheckpointStatus status;
  final CheckpointPriority priority;
  final List<String> labels;
  final String? reporterId;
  final String? reporterName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sprintId;
  final int? storyPoints;
  final TimeTracking? timeTracking;
  final List<IssueLink> issueLinks;
  final String? parentId; // For epic/story relationships
  final List<String> acceptanceCriteria;
  final String? epicId; // Link to epic
  final int? epicRank; // Order within epic
  final List<String> notes; // Checkpoint-specific notes
  final List<String> alarms; // Critical alarms and reminders for this checkpoint

  FlowCheckpoint({
    required this.id,
    required this.title,
    required this.description,
    this.requirements = const [],
    this.deliverables = const [],
    this.estimatedTime = '1 day',
    this.isCompleted = false,
    this.completedAt,
    this.resources = const [],
    this.type = CheckpointType.task,
    required this.order,
    this.workContributions = const [],
    this.collaboratorComments = const [],
    this.assignedTo,
    this.aiAssistance,
    this.children = const [],
    this.filePatterns = const [],
    this.filePaths = const [],
    this.rules = const [],
    // New Jira-like parameters
    this.status = CheckpointStatus.todo,
    this.priority = CheckpointPriority.medium,
    this.labels = const [],
    this.reporterId,
    this.reporterName,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sprintId,
    this.storyPoints,
    this.timeTracking,
    this.issueLinks = const [],
    this.parentId,
    this.acceptanceCriteria = const [],
    this.epicId,
    this.epicRank,
    this.notes = const [],
    this.alarms = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory FlowCheckpoint.fromJson(Map<String, dynamic> json) {
    return FlowCheckpoint(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      requirements:
          (json['requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      deliverables:
          (json['deliverables'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      estimatedTime: json['estimated_time']?.toString() ?? '1 day',
      isCompleted: json['is_completed'] == true,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      resources:
          (json['resources'] as List<dynamic>?)
              ?.map((e) => FlowResource.fromJson(e))
              .toList() ??
          const [],
      type: CheckpointType.values.firstWhere(
        (e) => e.name == (json['type']?.toString() ?? ''),
        orElse: () => CheckpointType.task,
      ),
      order: (json['order'] as num?)?.toInt() ?? 0,
      workContributions:
          (json['work_contributions'] as List<dynamic>?)
              ?.map((e) => WorkContribution.fromJson(e))
              .toList() ??
          const [],
      collaboratorComments:
          (json['collaborator_comments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      assignedTo: json['assigned_to']?.toString(),
      aiAssistance: json['ai_assistance'] != null
          ? AIBuddyAssistance.fromJson(json['ai_assistance'])
          : null,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => FlowCheckpoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      filePatterns:
          (json['file_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      filePaths:
          (json['file_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      // New Jira-like fields
      status: CheckpointStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString() ?? 'todo'),
        orElse: () => CheckpointStatus.todo,
      ),
      priority: CheckpointPriority.values.firstWhere(
        (e) => e.name == (json['priority']?.toString() ?? 'medium'),
        orElse: () => CheckpointPriority.medium,
      ),
      labels:
          (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      reporterId: json['reporter_id']?.toString(),
      reporterName: json['reporter_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sprintId: json['sprint_id']?.toString(),
      storyPoints: json['story_points'],
      timeTracking: json['time_tracking'] != null
          ? TimeTracking.fromJson(json['time_tracking'])
          : null,
      issueLinks:
          (json['issue_links'] as List<dynamic>?)
              ?.map((e) => IssueLink.fromJson(e))
              .toList() ??
          const [],
      parentId: json['parent_id']?.toString(),
      acceptanceCriteria:
          (json['acceptance_criteria'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      epicId: json['epic_id']?.toString(),
      epicRank: json['epic_rank'],
      notes: (json['notes'] as List<dynamic>?)?.cast<String>() ?? [],
      alarms: (json['alarms'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requirements': requirements,
      'deliverables': deliverables,
      'estimated_time': estimatedTime,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'resources': resources.map((e) => e.toJson()).toList(),
      'type': type.name,
      'order': order,
      'work_contributions': workContributions.map((e) => e.toJson()).toList(),
      'collaborator_comments': collaboratorComments,
      'assigned_to': assignedTo,
      'ai_assistance': aiAssistance?.toJson(),
      'children': children.map((e) => e.toJson()).toList(),
      'file_patterns': filePatterns,
      'file_paths': filePaths,
      'rules': rules,
      // New Jira-like fields
      'status': status.name,
      'priority': priority.name,
      'labels': labels,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sprint_id': sprintId,
      'story_points': storyPoints,
      'time_tracking': timeTracking?.toJson(),
      'issue_links': issueLinks.map((e) => e.toJson()).toList(),
      'parent_id': parentId,
      'acceptance_criteria': acceptanceCriteria,
      'epic_id': epicId,
      'epic_rank': epicRank,
      'notes': notes,
      'alarms': alarms,
    };
  }

  FlowCheckpoint copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? requirements,
    List<String>? deliverables,
    String? estimatedTime,
    bool? isCompleted,
    DateTime? completedAt,
    List<FlowResource>? resources,
    CheckpointType? type,
    int? order,
    List<WorkContribution>? workContributions,
    List<String>? collaboratorComments,
    String? assignedTo,
    AIBuddyAssistance? aiAssistance,
    List<FlowCheckpoint>? children,
    List<String>? filePatterns,
    List<String>? filePaths,
    List<String>? rules,
    // New Jira-like fields
    CheckpointStatus? status,
    CheckpointPriority? priority,
    List<String>? labels,
    String? reporterId,
    String? reporterName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sprintId,
    int? storyPoints,
    TimeTracking? timeTracking,
    List<IssueLink>? issueLinks,
    String? parentId,
    List<String>? acceptanceCriteria,
    String? epicId,
    int? epicRank,
    List<String>? notes,
    List<String>? alarms,
  }) {
    return FlowCheckpoint(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      deliverables: deliverables ?? this.deliverables,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      resources: resources ?? this.resources,
      type: type ?? this.type,
      order: order ?? this.order,
      workContributions: workContributions ?? this.workContributions,
      collaboratorComments: collaboratorComments ?? this.collaboratorComments,
      assignedTo: assignedTo ?? this.assignedTo,
      aiAssistance: aiAssistance ?? this.aiAssistance,
      children: children ?? this.children,
      filePatterns: filePatterns ?? this.filePatterns,
      filePaths: filePaths ?? this.filePaths,
      rules: rules ?? this.rules,
      // New Jira-like fields
      status: status ?? this.status,
      priority: priority ?? this.priority,
      labels: labels ?? this.labels,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sprintId: sprintId ?? this.sprintId,
      storyPoints: storyPoints ?? this.storyPoints,
      timeTracking: timeTracking ?? this.timeTracking,
      issueLinks: issueLinks ?? this.issueLinks,
      parentId: parentId ?? this.parentId,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      epicId: epicId ?? this.epicId,
      epicRank: epicRank ?? this.epicRank,
      notes: notes ?? this.notes,
      alarms: alarms ?? this.alarms,
    );
  }

  // Jira-like helper methods
  bool get isStory => type == CheckpointType.story;
  bool get isEpic => type == CheckpointType.epic;
  bool get isBug => type == CheckpointType.bug;
  bool get isSubtask => type == CheckpointType.subtask;

  bool get isDone => status == CheckpointStatus.done;
  bool get isInProgress => status == CheckpointStatus.inProgress;
  bool get isBlocked => status == CheckpointStatus.blocked;

  bool get isHighPriority =>
      priority == CheckpointPriority.highest ||
      priority == CheckpointPriority.high;

  String get statusDisplay {
    switch (status) {
      case CheckpointStatus.todo:
        return 'To Do';
      case CheckpointStatus.inProgress:
        return 'In Progress';
      case CheckpointStatus.codeReview:
        return 'Code Review';
      case CheckpointStatus.testing:
        return 'Testing';
      case CheckpointStatus.done:
        return 'Done';
      case CheckpointStatus.blocked:
        return 'Blocked';
      case CheckpointStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case CheckpointPriority.highest:
        return 'Highest';
      case CheckpointPriority.high:
        return 'High';
      case CheckpointPriority.medium:
        return 'Medium';
      case CheckpointPriority.low:
        return 'Low';
      case CheckpointPriority.lowest:
        return 'Lowest';
    }
  }

  String get typeDisplay {
    switch (type) {
      case CheckpointType.epic:
        return 'Epic';
      case CheckpointType.story:
        return 'Story';
      case CheckpointType.task:
        return 'Task';
      case CheckpointType.bug:
        return 'Bug';
      case CheckpointType.subtask:
        return 'Subtask';
      case CheckpointType.milestone:
        return 'Milestone';
      case CheckpointType.review:
        return 'Review';
      case CheckpointType.testing:
        return 'Testing';
      case CheckpointType.documentation:
        return 'Documentation';
    }
  }
}

// Config written to repo root (buddy.json) when scaffolding a project
class BuddyScaffoldCheckpointMap {
  final String id;
  final String title;
  final List<String> filePatterns;
  final List<String> rules; // e.g. ['exists', 'tests_pass']

  BuddyScaffoldCheckpointMap({
    required this.id,
    required this.title,
    this.filePatterns = const [],
    this.rules = const [],
  });

  factory BuddyScaffoldCheckpointMap.fromJson(Map<String, dynamic> json) =>
      BuddyScaffoldCheckpointMap(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        filePatterns:
            (json['file_patterns'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rules:
            (json['rules'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'file_patterns': filePatterns,
    'rules': rules,
  };
}

class BuddyScaffoldConfig {
  final String? template;
  final String? language;
  final List<BuddyScaffoldCheckpointMap> checkpoints;

  BuddyScaffoldConfig({
    this.template,
    this.language,
    this.checkpoints = const [],
  });

  factory BuddyScaffoldConfig.fromJson(Map<String, dynamic> json) =>
      BuddyScaffoldConfig(
        template: json['template']?.toString(),
        language: json['language']?.toString(),
        checkpoints:
            (json['checkpoints'] as List<dynamic>?)
                ?.map(
                  (e) => BuddyScaffoldCheckpointMap.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    if (template != null) 'template': template,
    if (language != null) 'language': language,
    'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
  };
}

// File change events coming from editors (VS Code or Buddy Editor)
class CodeEvent {
  final String path;
  final String event; // created|modified|deleted
  final String? sha; // optional commit/file hash when available
  final String editor; // 'vscode' | 'buddy'
  final DateTime timestamp;

  CodeEvent({
    required this.path,
    required this.event,
    this.sha,
    required this.editor,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory CodeEvent.fromJson(Map<String, dynamic> json) => CodeEvent(
    path: json['path']?.toString() ?? '',
    event: json['event']?.toString() ?? 'modified',
    sha: json['sha']?.toString(),
    editor: json['editor']?.toString() ?? 'vscode',
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'event': event,
    'sha': sha,
    'editor': editor,
    'timestamp': timestamp.toIso8601String(),
  };
}

// ---------------- Alarms ----------------
enum AlarmType { task, deadline, reminder, meeting }

enum AlarmRepeat { none, daily, weekly, monthly, custom }

class FlowAlarm {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledTime;
  final bool isActive;
  final AlarmType? type;
  final AlarmRepeat? repeat;
  final String? flowId;
  final String? checkpointId;
  final DateTime? createdAt;

  FlowAlarm({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledTime,
    this.isActive = true,
    this.type,
    this.repeat,
    this.flowId,
    this.checkpointId,
    this.createdAt,
  });

  FlowAlarm copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledTime,
    bool? isActive,
    AlarmType? type,
    AlarmRepeat? repeat,
    String? flowId,
    String? checkpointId,
    DateTime? createdAt,
  }) => FlowAlarm(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    scheduledTime: scheduledTime ?? this.scheduledTime,
    isActive: isActive ?? this.isActive,
    type: type ?? this.type,
    repeat: repeat ?? this.repeat,
    flowId: flowId ?? this.flowId,
    checkpointId: checkpointId ?? this.checkpointId,
    createdAt: createdAt ?? this.createdAt,
  );

  factory FlowAlarm.fromJson(Map<String, dynamic> json) => FlowAlarm(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString(),
    scheduledTime:
        DateTime.tryParse(json['scheduled_time']?.toString() ?? '') ??
        DateTime.now(),
    isActive: json['is_active'] == true || json['isActive'] == true,
    type: json['type'] != null
        ? AlarmType.values.firstWhere(
            (e) => e.name == json['type'].toString(),
            orElse: () => AlarmType.task,
          )
        : null,
    repeat: json['repeat'] != null
        ? AlarmRepeat.values.firstWhere(
            (e) => e.name == json['repeat'].toString(),
            orElse: () => AlarmRepeat.none,
          )
        : null,
    flowId: json['flow_id']?.toString(),
    checkpointId: json['checkpoint_id']?.toString(),
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    'scheduled_time': scheduledTime.toIso8601String(),
    'is_active': isActive,
    if (type != null) 'type': type!.name,
    if (repeat != null) 'repeat': repeat!.name,
    if (flowId != null) 'flow_id': flowId,
    if (checkpointId != null) 'checkpoint_id': checkpointId,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}

// ---------------- Tasks ----------------
enum TaskPriority { low, normal, high, urgent }

enum TaskStatus { todo, inProgress, done, blocked }

class FlowTask {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? flowId;
  final String? checkpointId;
  final List<String> labels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FlowTask({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.todo,
    this.flowId,
    this.checkpointId,
    this.labels = const [],
    this.createdAt,
    this.updatedAt,
  });

  FlowTask copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    String? flowId,
    String? checkpointId,
    List<String>? labels,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FlowTask(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    dueDate: dueDate ?? this.dueDate,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    flowId: flowId ?? this.flowId,
    checkpointId: checkpointId ?? this.checkpointId,
    labels: labels ?? this.labels,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory FlowTask.fromJson(Map<String, dynamic> json) => FlowTask(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    dueDate: json['due_date'] != null
        ? DateTime.tryParse(json['due_date'].toString())
        : null,
    priority: TaskPriority.values.firstWhere(
      (e) => e.name == (json['priority']?.toString().toLowerCase() ?? 'normal'),
      orElse: () => TaskPriority.normal,
    ),
    status: TaskStatus.values.firstWhere(
      (e) => e.name == (json['status']?.toString() ?? 'todo'),
      orElse: () => TaskStatus.todo,
    ),
    flowId: json['flow_id']?.toString(),
    checkpointId: json['checkpoint_id']?.toString(),
    labels:
        (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    if (flowId != null) 'flow_id': flowId,
    if (checkpointId != null) 'checkpoint_id': checkpointId,
    'labels': labels,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

// ---------------- Dashboard ----------------
class FlowDashboard {
  final _FlowDashFlow flow;
  final _FlowDashProgress progress;
  final List<String> participants;
  final int notesCount;
  final int assignmentsCount;
  final List<_FlowDashAlarm> upcomingAlarms;
  final List<String> insights;
  final TeamStats teamStats;

  FlowDashboard({
    required this.flow,
    required this.progress,
    this.participants = const [],
    this.notesCount = 0,
    this.assignmentsCount = 0,
    this.upcomingAlarms = const [],
    this.insights = const [],
    required this.teamStats,
  });

  factory FlowDashboard.fromJson(Map<String, dynamic> json) => FlowDashboard(
    flow: _FlowDashFlow.fromJson(json['flow'] as Map<String, dynamic>),
    progress: _FlowDashProgress.fromJson(
      json['progress'] as Map<String, dynamic>,
    ),
    participants:
        (json['participants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    notesCount: (json['notes_count'] as num?)?.toInt() ?? 0,
    assignmentsCount: (json['assignments_count'] as num?)?.toInt() ?? 0,
    upcomingAlarms:
        (json['upcoming_alarms'] as List<dynamic>?)
            ?.map((e) => _FlowDashAlarm.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    insights:
        (json['insights'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    teamStats: json['team_stats'] != null
        ? TeamStats.fromJson(json['team_stats'] as Map<String, dynamic>)
        : TeamStats(),
  );
}

class _FlowDashFlow {
  final String id;
  final String title;
  final FlowStatus? status;
  final FlowDifficulty? difficulty;
  final String? estimatedDuration;
  final int currentCheckpointIndex;
  final List<String> tags;

  _FlowDashFlow({
    required this.id,
    required this.title,
    this.status,
    this.difficulty,
    this.estimatedDuration,
    this.currentCheckpointIndex = 0,
    this.tags = const [],
  });

  factory _FlowDashFlow.fromJson(Map<String, dynamic> json) => _FlowDashFlow(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    status: (json['status'] != null)
        ? FlowStatus.values.firstWhere(
            (e) => e.name == json['status'].toString(),
            orElse: () => FlowStatus.active,
          )
        : null,
    difficulty: (json['difficulty'] != null)
        ? FlowDifficulty.values.firstWhere(
            (e) => e.name == json['difficulty'].toString(),
            orElse: () => FlowDifficulty.medium,
          )
        : null,
    estimatedDuration: json['estimated_duration']?.toString(),
    currentCheckpointIndex:
        (json['current_checkpoint_index'] as num?)?.toInt() ?? 0,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
  );
}

class _FlowDashProgress {
  final int total;
  final int completed;
  final double percentage;

  _FlowDashProgress({
    this.total = 0,
    this.completed = 0,
    this.percentage = 0.0,
  });

  factory _FlowDashProgress.fromJson(Map<String, dynamic> json) =>
      _FlowDashProgress(
        total: (json['total'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class _FlowDashAlarm {
  final String id;
  final String title;
  final DateTime at;
  final String? checkpointId;

  _FlowDashAlarm({
    required this.id,
    required this.title,
    required this.at,
    this.checkpointId,
  });

  factory _FlowDashAlarm.fromJson(Map<String, dynamic> json) => _FlowDashAlarm(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    checkpointId: json['checkpoint_id']?.toString(),
  );
}

class TeamStats {
  final double totalHoursWorked;
  final int totalContributors;
  final int aiAssistanceSessions;
  final int teamMembers;
  final DateTime? lastActivity;

  TeamStats({
    this.totalHoursWorked = 0.0,
    this.totalContributors = 0,
    this.aiAssistanceSessions = 0,
    this.teamMembers = 0,
    this.lastActivity,
  });

  factory TeamStats.fromJson(Map<String, dynamic> json) => TeamStats(
    totalHoursWorked: (json['total_hours_worked'] as num?)?.toDouble() ?? 0.0,
    totalContributors: (json['total_contributors'] as num?)?.toInt() ?? 0,
    aiAssistanceSessions:
        (json['ai_assistance_sessions'] as num?)?.toInt() ?? 0,
    teamMembers: (json['team_members'] as num?)?.toInt() ?? 0,
    lastActivity: json['last_activity'] != null
        ? DateTime.tryParse(json['last_activity'].toString())
        : null,
  );
}

// Extension methods for enum display names and colors

extension CheckpointTypeExtension on CheckpointType {
  String get displayName {
    switch (this) {
      case CheckpointType.epic:
        return 'Epic';
      case CheckpointType.story:
        return 'Story';
      case CheckpointType.task:
        return 'Task';
      case CheckpointType.bug:
        return 'Bug';
      case CheckpointType.subtask:
        return 'Subtask';
      case CheckpointType.milestone:
        return 'Milestone';
      case CheckpointType.review:
        return 'Review';
      case CheckpointType.testing:
        return 'Testing';
      case CheckpointType.documentation:
        return 'Documentation';
    }
  }

  IconData get icon {
    switch (this) {
      case CheckpointType.epic:
        return Icons.rocket_launch;
      case CheckpointType.story:
        return Icons.library_books;
      case CheckpointType.task:
        return Icons.task;
      case CheckpointType.bug:
        return Icons.bug_report;
      case CheckpointType.subtask:
        return Icons.subdirectory_arrow_right;
      case CheckpointType.milestone:
        return Icons.flag;
      case CheckpointType.review:
        return Icons.rate_review;
      case CheckpointType.testing:
        return Icons.science;
      case CheckpointType.documentation:
        return Icons.description;
    }
  }

  Color get color {
    switch (this) {
      case CheckpointType.epic:
        return Colors.purple;
      case CheckpointType.story:
        return Colors.green;
      case CheckpointType.task:
        return Colors.blue;
      case CheckpointType.bug:
        return Colors.red;
      case CheckpointType.subtask:
        return Colors.grey;
      case CheckpointType.milestone:
        return Colors.orange;
      case CheckpointType.review:
        return Colors.teal;
      case CheckpointType.testing:
        return Colors.indigo;
      case CheckpointType.documentation:
        return Colors.teal;
    }
  }
}

extension CheckpointStatusExtension on CheckpointStatus {
  String get displayName {
    switch (this) {
      case CheckpointStatus.todo:
        return 'To Do';
      case CheckpointStatus.inProgress:
        return 'In Progress';
      case CheckpointStatus.codeReview:
        return 'Code Review';
      case CheckpointStatus.testing:
        return 'Testing';
      case CheckpointStatus.done:
        return 'Done';
      case CheckpointStatus.blocked:
        return 'Blocked';
      case CheckpointStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case CheckpointStatus.todo:
        return Colors.grey.shade400;
      case CheckpointStatus.inProgress:
        return Colors.blue;
      case CheckpointStatus.codeReview:
        return Colors.orange;
      case CheckpointStatus.testing:
        return Colors.purple;
      case CheckpointStatus.done:
        return Colors.green;
      case CheckpointStatus.blocked:
        return Colors.red;
      case CheckpointStatus.cancelled:
        return Colors.grey.shade600;
    }
  }
}

extension CheckpointPriorityExtension on CheckpointPriority {
  String get displayName {
    switch (this) {
      case CheckpointPriority.highest:
        return 'Highest';
      case CheckpointPriority.high:
        return 'High';
      case CheckpointPriority.medium:
        return 'Medium';
      case CheckpointPriority.low:
        return 'Low';
      case CheckpointPriority.lowest:
        return 'Lowest';
    }
  }

  Color get color {
    switch (this) {
      case CheckpointPriority.highest:
        return Colors.red.shade700;
      case CheckpointPriority.high:
        return Colors.red.shade400;
      case CheckpointPriority.medium:
        return Colors.orange;
      case CheckpointPriority.low:
        return Colors.green.shade400;
      case CheckpointPriority.lowest:
        return Colors.green.shade700;
    }
  }
}
