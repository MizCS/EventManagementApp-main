class ChatParticipant {
  final String chatId;
  final String userId;

  ChatParticipant({required this.chatId, required this.userId});

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      chatId: json['chat_id'],
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'user_id': userId,
    };
  }
}