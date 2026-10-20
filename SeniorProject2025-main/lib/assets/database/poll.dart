class Poll {
  final String pollId;
  final String discussionId;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final DateTime? endTime;
  final bool isPast;
  final bool autoDelete;

  Poll({
    required this.pollId,
    required this.discussionId,
    required this.question,
    required this.options,
    required this.createdAt,
    this.endTime,
    required this.isPast,
    required this.autoDelete,
  });

  factory Poll.fromJson({
    required Map<String, dynamic> pollJson,
    required List<dynamic> optionsJson,
  }) {
    return Poll(
      pollId: pollJson['poll_id'],
      discussionId: pollJson['discussion_id'],
      question: pollJson['poll_question'],
      options: optionsJson.map((option) => PollOption.fromJson(json: option as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse(pollJson['time_created']),
      endTime: pollJson['duration'] != null ? DateTime.parse(pollJson['duration']) : null,
      isPast: pollJson['past'] ?? false,
      autoDelete: pollJson['auto_delete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'discussion_id': discussionId,
      'question': question,
      'options': options.map((option) => option.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'past': isPast,
      'auto_delete': autoDelete,
    };
  }
}

class PollOption {
  final String optionId;
  final String pollId;
  final String text;
  final int votes;

  PollOption({
    required this.optionId,
    required this.pollId,
    required this.text,
    required this.votes,
  });

  factory PollOption.fromJson({required Map<String, dynamic> json}) {
    return PollOption(
      optionId: json['p_option_id'] as String,
      pollId: json['poll_id'] as String,
      text: json['p_option'] as String,
      votes: json['vote_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'p_option_id': optionId,
      'poll_id': pollId,
      'p_option': text,
      'vote_count': votes,
    };
  }
} 