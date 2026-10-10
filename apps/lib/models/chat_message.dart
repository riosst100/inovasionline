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
    this.replyTo,
    this.createdAt,
    this.status = ChatMessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        senderId: json['sender_id'] as String?,
        senderName: json['sender_name'] as String?,
        isOfficial: json['is_official'] as bool? ?? false,
        body: json['body'] as String,
        replyTo: json['reply_to'] != null ? ChatMessageReplyTo.fromJson(json['reply_to'] as Map<String, dynamic>) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  final String id;
  final String threadId;
  final String? senderId;
  final String? senderName;
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
        replyTo: replyTo,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );
}
