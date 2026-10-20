import 'package:flutter/material.dart';
// //import 'package:supabase_flutter/supabase_flutter.dart';
import 'assets/database/chat_database.dart';
import 'assets/database/chat_message.dart';
import 'package:uuid/uuid.dart';
//import 'assets/database/chat_map.dart';
import 'assets/database/disc_database.dart';
//import 'assets/database/disc_message.dart';

import 'package:icebreaker/chat_page.dart';
import 'package:icebreaker/discussion_page.dart';


//final ChatDatabase chatDB = ChatDatabase();
//final DiscDatabase discDB = DiscDatabase();


class ChatList extends StatefulWidget {
  final String userId;
  final String username;

  const ChatList({super.key, required this.userId, required this.username});

  @override
  ChatListState createState() => ChatListState();
}

class ChatListState extends State<ChatList> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'Chats'),
              Tab(icon: Icon(Icons.forum), text: 'Discussions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Chats Tab
            FutureBuilder<List<Map<String, dynamic>>>(
              future: chatDB.getUserChats(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading chats: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No chats found'));
                }

                final chats = snapshot.data!;

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ListTile(
                      subtitle: Text(
                        chat['last_message'].isNotEmpty
                          ? '${chat['last_sender'] == widget.username ? "You" : chat['last_sender']}: ${chat['last_message']}'
                          : 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700]),
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: chat['profile_pic'] != null && chat['profile_pic'].isNotEmpty
                            ? NetworkImage(chat['profile_pic']!)
                            : const NetworkImage('https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png') as ImageProvider,
                      ),
                      title: Text(chat['username'] ?? 'Unknown User'),
                       onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              chatId: chat['chat_id'],
                              userId: widget.userId,
                              username: chat['username'],
                              profile: chat['profile_pic'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            // Discussions Tab (come back to this later, may be broken asl)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: discDB.getUserDiscussions(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading discussions: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No discussions found'));
                }

                final discussions = snapshot.data!;

                return ListView.builder(
                  itemCount: discussions.length,
                  itemBuilder: (context, index) {
                    final discussion = discussions[index];

                    return ListTile(
                      title: Text(discussion['title'] ?? 'Untitled Discussion'),
                      subtitle: Text(
                        discussion['last_message'].isNotEmpty
                          ? '${discussion['last_sender'] == widget.username ? "You" : discussion['last_sender']}: ${discussion['last_message']}'
                          : 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DiscPage(
                              discId: discussion['discussion_id'],
                              userId: widget.userId,
                              title: discussion['title'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}