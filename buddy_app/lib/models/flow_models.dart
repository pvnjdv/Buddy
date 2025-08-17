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
    };
  }
}

enum MessageType { text, image, video, audio, document }

enum MessageStatus { sent, delivered, read }

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

  BuddyMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

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
  });

  factory FlowCheckpoint.fromJson(Map<String, dynamic> json) {
    return FlowCheckpoint(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      requirements:
          (json['requirements'] as List<dynamic>?)?.cast<String>() ?? [],
      deliverables:
          (json['deliverables'] as List<dynamic>?)?.cast<String>() ?? [],
      estimatedTime: json['estimated_time'] ?? '1 day',
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      resources:
          (json['resources'] as List<dynamic>?)
              ?.map((resource) => FlowResource.fromJson(resource))
              .toList() ??
          [],
      type: CheckpointType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CheckpointType.task,
      ),
      order: json['order'] ?? 0,
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
      'resources': resources.map((resource) => resource.toJson()).toList(),
      'type': type.name,
      'order': order,
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
    );
  }
}

class FlowResource {
  final String id;
  final String title;
  final String description;
  final String url;
  final ResourceType type;

  FlowResource({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.type = ResourceType.link,
  });

  factory FlowResource.fromJson(Map<String, dynamic> json) {
    return FlowResource(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      type: ResourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceType.link,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'type': type.name,
    };
  }
}

enum FlowStatus { active, completed, paused, cancelled }

enum FlowDifficulty { easy, medium, hard, expert }

enum CheckpointType { task, milestone, review, testing }

enum ResourceType { link, document, video, tutorial, tool }

// Enhanced BuddyMessage for flow context
class FlowBuddyMessage extends BuddyMessage {
  final String? flowId;
  final String? checkpointId;
  final MessageContext context;
  final Map<String, dynamic>? flowData; // For storing flow preview data

  FlowBuddyMessage({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    this.flowId,
    this.checkpointId,
    this.context = MessageContext.general,
    this.flowData,
  });

  factory FlowBuddyMessage.fromJson(Map<String, dynamic> json) {
    return FlowBuddyMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      role: BuddyRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => BuddyRole.user,
      ),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      flowId: json['flow_id']?.toString(),
      checkpointId: json['checkpoint_id']?.toString(),
      context: MessageContext.values.firstWhere(
        (e) => e.name == json['context'],
        orElse: () => MessageContext.general,
      ),
      flowData: json['flow_data'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'flow_id': flowId,
      'checkpoint_id': checkpointId,
      'context': context.name,
      'flow_data': flowData,
    });
    return json;
  }
}

enum MessageContext {
  general,
  flowCreation,
  flowConfirmation,
  checkpointHelp,
  flowProgress,
}

// Alarm and Reminder Models
class FlowAlarm {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final bool isActive;
  final AlarmType type;
  final AlarmRepeat repeat;
  final String? flowId;
  final String? checkpointId;
  final DateTime createdAt;
  final DateTime? lastTriggered;

  FlowAlarm({
    required this.id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    this.isActive = true,
    this.type = AlarmType.reminder,
    this.repeat = AlarmRepeat.none,
    this.flowId,
    this.checkpointId,
    required this.createdAt,
    this.lastTriggered,
  });

  factory FlowAlarm.fromJson(Map<String, dynamic> json) {
    return FlowAlarm(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      scheduledTime: DateTime.parse(
        json['scheduled_time'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['is_active'] ?? true,
      type: AlarmType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlarmType.reminder,
      ),
      repeat: AlarmRepeat.values.firstWhere(
        (e) => e.name == json['repeat'],
        orElse: () => AlarmRepeat.none,
      ),
      flowId: json['flow_id']?.toString(),
      checkpointId: json['checkpoint_id']?.toString(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastTriggered: json['last_triggered'] != null
          ? DateTime.parse(json['last_triggered'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduled_time': scheduledTime.toIso8601String(),
      'is_active': isActive,
      'type': type.name,
      'repeat': repeat.name,
      'flow_id': flowId,
      'checkpoint_id': checkpointId,
      'created_at': createdAt.toIso8601String(),
      'last_triggered': lastTriggered?.toIso8601String(),
    };
  }

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
    DateTime? lastTriggered,
  }) {
    return FlowAlarm(
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
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }
}

enum AlarmType { reminder, deadline, meeting, task, custom }

enum AlarmRepeat { none, daily, weekly, monthly, custom }

// Status (Stories) models
enum StatusType { image, video }

class StatusItem {
  final String id;
  final String userId;
  final String userName;
  final String mediaUrl; // network image/video url
  final StatusType type;
  final DateTime timestamp;
  bool seen;

  StatusItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.mediaUrl,
    this.type = StatusType.image,
    required this.timestamp,
    this.seen = false,
  });
}
