class Chat {
  final String chatId;

  Chat({required this.chatId});

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(chatId: json['chat_id']);
  }

  Map<String, dynamic> toJson() {
    return {'chat_id': chatId};
  }
}