class DiscParticipant {
  final String discId;
  final String userId;

  DiscParticipant({required this.discId, required this.userId});

  factory DiscParticipant.fromJson(Map<String, dynamic> json) {
    return DiscParticipant(
      discId: json['discussion_id'],
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'discussion_id': discId,
      'user_id': userId,
    };
  }
}