class ChatMessageReplyTo {
  ChatMessageReplyTo({required this.id, required this.body, this.senderId, this.senderName});

  factory ChatMessageReplyTo.fromJson(Map<String, dynamic> json) => ChatMessageReplyTo(
        id: json['id'] as String,
        body: json['body'] as String,
        senderId: json['sender_id'] as String?,
        senderName: json['sender_name'] as String?,
      );

  final String id;
  final String body;
  final String? senderId;
  final String? senderName;
}

/// Client-side delivery state for a message. Messages loaded from the server
/// are always [sent]; [sending] and [failed] only apply to an optimistic
/// message inserted locally while [ChatService.sendMessage] is in flight.
enum ChatMessageStatus { sending, sent, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.threadId,
    required this.body,
    required this.isOfficial,
    this.senderId,
    this.senderName,
    this.senderVerifiedBadge = false,
    this.senderAdminBadge,
    this.isDeleted = false,
    this.canDelete = false,
    this.replyTo,
    this.createdAt,
    this.status = ChatMessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        senderId: json['sender_id'] as String?,
        senderName: json['sender_name'] as String?,
        senderVerifiedBadge: json['sender_verified_badge'] as bool? ?? false,
        senderAdminBadge: json['sender_admin_badge'] as String?,
        isDeleted: json['is_deleted'] as bool? ?? false,
        canDelete: json['can_delete'] as bool? ?? false,
        isOfficial: json['is_official'] as bool? ?? false,
        body: json['body'] as String,
        replyTo: json['reply_to'] != null ? ChatMessageReplyTo.fromJson(json['reply_to'] as Map<String, dynamic>) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  final String id;
  final String threadId;
  final String? senderId;
  final String? senderName;
  final bool senderVerifiedBadge;

  /// e.g. "Admin Tiwulandu" when the sender looks after a region; null otherwise.
  final String? senderAdminBadge;

  /// Deleted by its sender or a region moderator; [body] is empty and the app shows "Pesan ini dihapus".
  final bool isDeleted;

  /// The viewer may delete it: they sent it, or their role may delete chat in this region.
  final bool canDelete;
  final bool isOfficial;
  final String body;
  final ChatMessageReplyTo? replyTo;
  final DateTime? createdAt;
  final ChatMessageStatus status;

  ChatMessage copyWith({
    String? id,
    DateTime? createdAt,
    ChatMessageStatus? status,
  }) => ChatMessage(
        id: id ?? this.id,
        threadId: threadId,
        body: body,
        isOfficial: isOfficial,
        senderId: senderId,
        senderName: senderName,
        senderVerifiedBadge: senderVerifiedBadge,
        senderAdminBadge: senderAdminBadge,
        isDeleted: isDeleted,
        canDelete: canDelete,
        replyTo: replyTo,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );
}
