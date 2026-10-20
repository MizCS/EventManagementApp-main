import 'package:supabase_flutter/supabase_flutter.dart';
//import 'chat_map.dart';
//import 'chat_participant.dart';
import 'chat_message.dart';

class ChatDatabase {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
  final userChatRows = await supabase
      .from('Chat_participants')
      .select('chat_id')
      .eq('user_id', userId);

  final chatIds = userChatRows.map((e) => e['chat_id'] as String).toList();
  if (chatIds.isEmpty) return [];

  final chatsMap = <String, Map<String, dynamic>>{};

  for (var chatId in chatIds) {
    final latestMessage = await supabase
        .from('Chat_messages')
        .select('text, sender_id, sent_at')
        .eq('chat_id', chatId)
        .order('sent_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latestMessage == null) {
      // No messages in this chat, skip it
      continue;
    }

    final participant = await supabase
        .from('Chat_participants')
        .select('user_id')
        .neq('user_id', userId)
        .eq('chat_id', chatId)
        .limit(1)
        .maybeSingle();

    final userData = participant != null
        ? await supabase
            .from('Users')
            .select('username, profile_pic')
            .eq('user_id', participant['user_id'])
            .maybeSingle()
        : null;

    String? latestSender = '';
    if (latestMessage != null) {
      final senderInfo = await supabase
          .from('Users')
          .select('username')
          .eq('user_id', latestMessage['sender_id'])
          .maybeSingle();
      latestSender = senderInfo?['username'];
    }

    chatsMap[chatId] = {
      'chat_id': chatId,
      'user_id': participant?['user_id'] ?? '',
      'username': userData?['username'] ?? 'Unknown User',
      'profile_pic': userData?['profile_pic'] ?? '',
      'last_message': latestMessage['text'] ?? '',
      'last_sender': latestSender ?? '',
    };
  }

  return chatsMap.values.toList();
}

  /// Checks for existing chats between users
  Future<Map<String, dynamic>?> getExistingChatBetweenUsers(String userId1, String userId2,) async {
    // 1) grab rows where user_id is either userId1 or userId2
    final rows = await supabase
        .from('Chat_participants')
        .select('chat_id, user_id')
        .inFilter('user_id', [userId1, userId2]);

    // 2) group them by chat_id
    final Map<String, Set<String>> chatMap = {};
    for (final row in rows) {
      final cid = row['chat_id'] as String;
      final uid = row['user_id'] as String;
      chatMap.putIfAbsent(cid, () => {}).add(uid);
    }

    // 3) find a chat that has exactly those two members
    for (final entry in chatMap.entries) {
      final members = entry.value;
      if (members.length == 2 &&
          members.contains(userId1) &&
          members.contains(userId2)) {
        // fetch the other user’s profile for display
        final otherId = members.firstWhere((u) => u != userId1);
        final otherData = await supabase
            .from('Users')
            .select('username, profile_pic')
            .eq('user_id', otherId)
            .maybeSingle();

        return {
          'chat_id': entry.key,
          'user_id': otherId,
          'username': otherData?['username'] ?? 'Unknown',
          'profile_pic': otherData?['profile_pic'] ?? '',
        };
      }
    }

    return null;
  }

  /// Creates a chat with exactly these two participants, returns its ID.
  Future<String?> createChatBetweenUsers(String userId1,String userId2,) async {
  // Create new chat row and get chat ID
  final response = await supabase
      .from('Chats')
      .insert({})
      .select('chat_id')
      .single();

  final newChatId = response['chat_id'] as String?;
  if (newChatId == null) return null;

  // Fetch usernames for both users
  final user1Data = await supabase
      .from('Users')
      .select('username')
      .eq('user_id', userId1)
      .maybeSingle();

  final user2Data = await supabase
      .from('Users')
      .select('username')
      .eq('user_id', userId2)
      .maybeSingle();

  final username1 = user1Data?['username'] ?? 'Unknown User';
  final username2 = user2Data?['username'] ?? 'Unknown User';

  // Insert participants with usernames
  await supabase.from('Chat_participants').insert([
    {
      'chat_id': newChatId,
      'user_id': userId1,
      'username': username1,
    },
    {
      'chat_id': newChatId,
      'user_id': userId2,
      'username': username2,
    },
  ]);

  return newChatId;
}


  /// Helper function, use this one when tryng to create chat between new chat
  Future<Map<String, dynamic>> getOrCreateChatBetween(String userId1, String userId2,) async {
    // try existing
    final existing = await getExistingChatBetweenUsers(userId1, userId2);
    if (existing != null) return existing;

    // otherwise create
    final newChatId = await createChatBetweenUsers(userId1, userId2);
    if (newChatId == null) {
      throw Exception("Could not create chat");
    }

    // now fetch the other user’s profile
    final otherData = await supabase
        .from('Users')
        .select('username, profile_pic')
        .eq('user_id', userId2)
        .maybeSingle();

    return {
      'chat_id': newChatId,
      'user_id': userId2,
      'username': otherData?['username'] ?? 'Unknown',
      'profile_pic': otherData?['profile_pic'] ?? '',
    };
  }
  
  // Message Streams
  Stream<List<ChatMessage>> getChatMessagesStream(String chatId) {
  return Supabase.instance.client
      .from('Chat_messages')
      .stream(primaryKey: ['message_id'])
      .eq('chat_id', chatId)
      .order('sent_at', ascending: true)
      .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
  }

   Future<Map<String, String>> getParticipantUsernames(String chatId) async {
    final response = await supabase
        .from('Chat_participants')
        .select('user_id, Users!inner(username, profile_pic)')
        .eq('chat_id', chatId);

    return {
      for (var row in response)
        row['user_id']: row['username'] ?? 'Unknown'
    };
  }
  
  /// Send a message
  Future<void> sendMessage(ChatMessage message) async {
    await supabase.from('Chat_messages').insert(message.toJson());
  }
  
  void deleteMessage(String messageId) async {
    await supabase.from('Chat_messages').delete().eq('message_id', messageId);
  }


  Future<bool> inChat(String userId1, String userId2) async {
    final response = await supabase
        .from('Chat_participants')
        .select('chat_id')
        .inFilter('user_id', [userId1, userId2]);
    return response.isNotEmpty;
  }
}