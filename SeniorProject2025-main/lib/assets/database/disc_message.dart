class DiscMessage {
  final String messageId;
  final String discId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final List<String> emoji;

  DiscMessage({
    required this.messageId,
    required this.discId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.emoji = const [],
  });

  factory DiscMessage.fromJson(Map<String, dynamic> json) {
    return DiscMessage(
      messageId: json['message_id'],
      discId: json['discussion_id'],
      senderId: json['sender_id'],
      text: json['message'],
      timestamp: DateTime.parse(json['sent_at']),
      emoji: List<String>.from(json['emoji'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'discussion_id': discId,
      'sender_id': senderId,
      'message': text,
      'sent_at': timestamp.toIso8601String(),
      'emoji': emoji,
    };
  }
}