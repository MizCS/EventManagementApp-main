import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'poll.dart' show Poll, PollOption;
import 'poll_cache.dart';

final _logger = Logger();

class PollQueries {
  final supabase = Supabase.instance.client;
  final PollCache _cache = PollCache();
  
  PollCache get cache => _cache;

  // Create a new poll
  Future<Poll> createPoll({
    required String discussionId,
    required String question,
    required List<String> options,
    String? duration,
    bool autoDelete = false,
  }) async {
    final pollResponse = await supabase
        .from('Polls')
        .insert({
          'discussion_id': discussionId,
          'poll_question': question,
          'duration': duration,
          'auto_delete': autoDelete,
        })
        .select()
        .single();

    final pollId = pollResponse['poll_id'];
    
    // Insert poll options
    for (var option in options) {
      await supabase.from('Poll_questions').insert({
        'poll_id': pollId,
        'p_option': option,
        'vote_count': 0,
      });
    }

    final poll = await getPoll(pollId);
    _cache.cachePoll(poll);
    return poll;
  }

  // Get a poll by ID
  Future<Poll> getPoll(String pollId) async {
    // Check cache first
    final cachedPoll = _cache.getPoll(pollId);
    if (cachedPoll != null) {
      return Future.value(cachedPoll);
    }

    final pollResponse = await supabase
        .from('Polls')
        .select()
        .eq('poll_id', pollId)
        .single();

    final optionsResponse = await supabase
        .from('Poll_questions')
        .select()
        .eq('poll_id', pollId);

    final poll = Poll.fromJson(
      pollJson: pollResponse,
      optionsJson: optionsResponse,
    );
    
    _cache.cachePoll(poll);
    return poll;
  }

  // Get all polls for a discussion
  Stream<List<Poll>> getPollsByDiscussion(String discussionId) {
    return supabase
        .from('Polls')
        .stream(primaryKey: ['poll_id'])
        .eq('discussion_id', discussionId)
        .asyncMap((polls) async {
          List<Poll> pollList = [];
          for (var poll in polls) {
            final optionsResponse = await supabase
                .from('Poll_questions')
                .select()
                .eq('poll_id', poll['poll_id'])
                .order('option_order', ascending: true);
            
            final pollObj = Poll.fromJson(
              pollJson: poll,
              optionsJson: optionsResponse,
            );
            _cache.cachePoll(pollObj);
            pollList.add(pollObj);
          }
          return pollList;
        });
  }

  // Vote on a poll option (simple, just increments the vote count)
  Future<void> voteOnPollOption(String optionId) async {
    await supabase.rpc('increment_vote_count', params: {'p_option_id': optionId});
    
    // Update cache with new vote count
    final currentCount = _cache.getVoteCount(optionId) ?? 0;
    _cache.updateVoteCount(optionId, currentCount + 1);
  }

  // Check if a user has already voted on a poll
  Future<bool> hasUserVoted(String pollId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final response = await supabase
        .from('Users')
        .select('p_voted')
        .eq('user_id', user.id)
        .single();

    final List<dynamic>? votedPolls = response['p_voted'] as List<dynamic>?;
    return votedPolls?.contains(pollId) ?? false;
  }

  // Vote on a poll option
  Future<bool> voteOnPoll(String pollId, String optionId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Check if user has already voted
    if (await hasUserVoted(pollId)) {
      return false; // User has already voted
    }

    // Start a transaction to update both the vote count and user's voted polls
    try {
      await supabase.rpc(
        'increment_vote_count',
        params: {'p_option_id': optionId},
      );

      // Add the poll ID to the user's p_voted array
      final response = await supabase
          .from('Users')
          .select('p_voted')
          .eq('user_id', user.id)
          .single();

      List<String> votedPolls = (response['p_voted'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      votedPolls.add(pollId);

      await supabase
          .from('Users')
          .update({'p_voted': votedPolls})
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Mark a poll as past
  Future<void> markPollAsPast(String pollId) async {
    await supabase
        .from('Polls')
        .update({'past': true})
        .eq('poll_id', pollId);
  }

  // Delete a poll
  Future<void> deletePoll(String pollId) async {
    await supabase
        .from('Polls')
        .delete()
        .eq('poll_id', pollId);
  }

  // Get the total votes for a poll
  Future<int> getTotalVotes(String pollId) async {
    final poll = await getPoll(pollId);
    final totalVotes = poll.options.fold(0, (sum, option) => sum + option.votes);
    return totalVotes;
  }

  //get total amount of polls on a discussion
  Future<int> getTotalPolls(String discussionId) async {
    final response = await supabase
        .from('Polls')
        .select()
        .eq('discussion_id', discussionId);
    return response.length;
  }
}

