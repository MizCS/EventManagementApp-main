class ChatMessage {
  final String messageId;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      text: json['text'],
      timestamp: DateTime.parse(json['sent_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'sent_at': timestamp.toIso8601String(),
    };
  }
}