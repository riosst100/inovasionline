class ChatOtherUser {
  ChatOtherUser({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ChatOtherUser.fromJson(Map<String, dynamic> json) => ChatOtherUser(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );

  final String id;
  final String name;
  final String? avatarUrl;
}

class ChatParticipant {
  ChatParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      ChatParticipant(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );

  final String id;
  final String name;
  final String? avatarUrl;
}

class ChatThreadLatestMessage {
  ChatThreadLatestMessage({
    required this.body,
    this.senderId,
    this.senderName,
    this.createdAt,
  });

  factory ChatThreadLatestMessage.fromJson(Map<String, dynamic> json) =>
      ChatThreadLatestMessage(
        body: json['body'] as String,
        senderId: json['sender_id'] as String?,
        senderName: json['sender_name'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String body;
  final String? senderId;
  final String? senderName;
  final DateTime? createdAt;
}

class ChatThread {
  ChatThread({
    required this.id,
    required this.type,
    required this.title,
    this.regionLevel,
    this.regionCode,
    this.otherUser,
    this.latestMessage,
    this.participantCount,
    this.isFavorite = false,
    this.isUnread = false,
    this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    regionLevel: json['region_level'] as String?,
    regionCode: json['region_code'] as String?,
    otherUser: json['other_user'] != null
        ? ChatOtherUser.fromJson(json['other_user'] as Map<String, dynamic>)
        : null,
    latestMessage: json['latest_message'] != null
        ? ChatThreadLatestMessage.fromJson(
            json['latest_message'] as Map<String, dynamic>,
          )
        : null,
    participantCount: json['participant_count'] as int?,
    isFavorite: json['is_favorite'] as bool? ?? false,
    isUnread: json['is_unread'] as bool? ?? false,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
  );

  final String id;
  final String type;
  final String title;
  final String? regionLevel;
  final String? regionCode;
  final ChatOtherUser? otherUser;
  final ChatThreadLatestMessage? latestMessage;
  final int? participantCount;
  final bool isFavorite;
  final bool isUnread;
  final DateTime? updatedAt;

  bool get isOfficial => type == 'official';
  bool get isGlobal => type == 'global';
  bool get isRegion => type == 'region';
  bool get isDirectMessage => type == 'dm';
}
