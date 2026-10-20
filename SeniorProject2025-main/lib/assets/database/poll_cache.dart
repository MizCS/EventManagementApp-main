import 'package:flutter/foundation.dart';
import 'poll.dart';

class PollCache extends ChangeNotifier {
  final Map<String, Poll> _polls = {};
  final Map<String, int> _voteCounts = {};

  void cachePoll(Poll poll) {
    _polls[poll.pollId] = poll;
    for (var option in poll.options) {
      _voteCounts[option.optionId] = option.votes;
    }
    notifyListeners();
  }

  void updateVoteCount(String optionId, int newCount) {
    _voteCounts[optionId] = newCount;
    notifyListeners();
  }

  int? getVoteCount(String optionId) {
    return _voteCounts[optionId];
  }

  Poll? getPoll(String pollId) {
    return _polls[pollId];
  }

  void clearCache() {
    _polls.clear();
    _voteCounts.clear();
    notifyListeners();
  }
} 