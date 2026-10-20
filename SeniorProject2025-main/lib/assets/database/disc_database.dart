import 'package:supabase_flutter/supabase_flutter.dart';
import 'disc_message.dart';
import 'disc_participant.dart';
import 'dart:math';

class DiscDatabase {
   final SupabaseClient supabase = Supabase.instance.client;

  // Get discussion list
  Future<List<Map<String, dynamic>>> getUserDiscussions(String userId) async {
  final userDiscussionRows = await supabase
      .from('Disc_participants')
      .select('discussion_id')
      .eq('user_id', userId);

  final discussionIds = userDiscussionRows.map((e) => e['discussion_id'] as String).toList();

  if (discussionIds.isEmpty) return [];

  // Get discussion info per id
  final discussionsMap = <String, Map<String, dynamic>>{};

  for (var discussionId in discussionIds) {
    final participant = await supabase
        .from('Disc_participants')
        .select('user_id')
        .neq('user_id', userId)
        .eq('discussion_id', discussionId)
        .limit(1)
        .maybeSingle();

    // extracting user profile for later implementations
    final userData = participant != null
        ? await supabase
            .from('Users')
            .select('username, profile_pic')
            .eq('user_id', participant['user_id'])
            .maybeSingle()
        : null;

    final discussionInfo = await supabase
        .from('Discussions')
        .select('title, image_url')
        .eq('discussion_id', discussionId)
        .maybeSingle();

    final latestMessage = await supabase
        .from('Disc_msg')
        .select('message, sender_id, sent_at')
        .eq('discussion_id', discussionId)
        .order('sent_at', ascending: false)
        .limit(1)
        .maybeSingle();

    
    String? latestSender = '';
    if (latestMessage != null) {
      final senderInfo = await supabase
          .from('Users')
          .select('username')
          .eq('user_id', latestMessage['sender_id'])
          .maybeSingle();
      latestSender = senderInfo?['username'];
    }

    discussionsMap[discussionId] = {
      'discussion_id': discussionId,
      'user_id': participant?['user_id'] ?? '',
      'username': userData?['username'] ?? 'Unknown User',
      'profile_pic': userData?['profile_pic'] ?? '',
      'title': discussionInfo?['title'] ?? 'Untitled',
      'image_url': discussionInfo?['image_url'] ?? '',
      'last_message': latestMessage?['message'] ?? '',
      'last_sender': latestSender ?? '',
    };
  }

  return discussionsMap.values.toList();
}

  // Send messages
  Future<void> sendMessage(DiscMessage message) async {
    await supabase.from('Disc_msg').insert(message.toJson());
  }

// Get discussion messages)
 Stream<List<DiscMessage>> getDiscMessagesStream(String discId) {
  return Supabase.instance.client
      .from('Disc_msg')
      .stream(primaryKey: ['message_id'])
      .eq('discussion_id', discId)
      .order('sent_at', ascending: true)
      .map((data) => data.map((json) => DiscMessage.fromJson(json)).toList());
  }

  Future<Map<String, String>> getUserColor(String discId) async {
  final response = await supabase
      .from('Disc_participants')
      .select('user_id, msg_color')
      .eq('discussion_id', discId);

  final colorMap = <String, String>{};
  for (final row in response) {
    colorMap[row['user_id']] = row['msg_color'];
  }
  return colorMap;
  }

  /// Generates a random hex color string, e.g. '#AABBCC'
  String generateRandomColor() {
    final random = Random();
    final r = random.nextInt(256);
    final g = random.nextInt(256);
    final b = random.nextInt(256);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  Future<Map<String, String>> getParticipantUsernames(String discId) async {
    final response = await supabase
        .from('Disc_participants')
        .select('user_id, username')
        .eq('discussion_id', discId);

    return {
      for (var row in response)
        row['user_id']: row['username'] ?? 'Unknown'
    };
  }


  void deleteMessage(String messageId) async {
    await supabase.from('Disc_msg').delete().eq('message_id', messageId);
  }

  Future<void> updateMessageEmoji(String messageId, List<String> emoji) async {
    await supabase
        .from('Disc_msg')
        .update({'emoji': emoji})
        .eq('message_id', messageId);
  }

  Future<bool> addUserToDiscussion(String discId, String userId) async {
    //final supabase = Supabase.instance.client;

    // Check if user is already in the discussion
    final existing = await supabase
        .from('Disc_participants')
        .select()
        .eq('discussion_id', discId)
        .eq('user_id', userId)
        .maybeSingle();


    if (existing != null) {
      print('User already in discussion.');
      //return false;
    }

     // Fetch the username from the Users table
    final userResp = await supabase
        .from('Users') // <- match your actual table name
        .select('username')
        .eq('user_id', userId)
        .maybeSingle();

    if (userResp == null || userResp['username'] == null) {
      print('Username not found for user ID: $userId');
    }

    final username = userResp!['username'] as String;

    final usedColorsData = await supabase
        .from('Disc_participants')
        .select('msg_color')
        .eq('discussion_id', discId);

    final usedColors = usedColorsData
        .map((row) => row['msg_color'].toString().toUpperCase())
        .where((color) => color.isNotEmpty)
        .toSet();

    // Step 2: Generate a new, unused color
    String randomColor;
    int attempts = 0;
    do {
      randomColor = generateRandomColor();
      attempts++;
    } while (usedColors.contains(randomColor) && attempts < 100);

    // failsafe:
    //final userColor = generateRandomColor();

    final response = await supabase.from('Disc_participants').insert({
      'discussion_id': discId,
      'user_id': userId,
      'username': username,
      'msg_color': randomColor,
      'is_owner' : false
    });

    return true;
  }

  Future<bool> removeUserFromDiscussion(String discId, String userId) async {
  final response = await supabase
      .from('Disc_participants')
      .delete()
      .match({
        'discussion_id': discId,
        'user_id': userId,
      });

    return true;
  }


  // may be redundant, but good for quick checks
  Future<bool> isUserInDiscussion(String discId, String userId) async {
    final result = await supabase
        .from('Disc_participants')
        .select('user_id')
        .eq('discussion_id', discId)
        .eq('user_id', userId)
        .maybeSingle();

    return result != null;
  }
}
