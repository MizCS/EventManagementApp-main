import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'assets/database/chat_database.dart';
import 'assets/database/chat_message.dart';
import 'package:uuid/uuid.dart';
//import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
//import 'assets/database/chat_map.dart';
import 'package:intl/intl.dart'; 

final ChatDatabase chatDB = ChatDatabase();

class ChatPage extends StatefulWidget {
  final String chatId;
  final String userId;
  final String username; // Other username
  final String? profile;

  const ChatPage({super.key, required this.chatId, required this.userId, required this.username, this.profile});
  
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
    final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

 Future<void> _sendMessage() async {
  if (_messageController.text.trim().isEmpty) return;

  final message = ChatMessage(
      messageId: _generateUUID(),
      chatId: widget.chatId,
      senderId: widget.userId,
      text: _messageController.text,
      timestamp: DateTime.now(),
    );

    try {
      await chatDB.sendMessage(message);
      _messageController.clear();
      // You can call setState to update the UI if necessary
      setState(() {});  // Force UI update
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      // Handle error if sending message fails
    }
  }

  String _generateUUID() {
    return Uuid().v4(); // generate UUID
  }

  Future<void> _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(
                widget.profile ?? 'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png',
              ),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 10),
            Expanded( 
              child: Text(
                widget.username.isNotEmpty ? widget.username : 'Unknown User',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis, // Truncates title (text...)
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, String>>(
              future: chatDB.getParticipantUsernames(widget.chatId),
              builder: (context, nameSnapshot) {
                if (!nameSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<ChatMessage>>(
                  stream: chatDB.getChatMessagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                    // Scroll to bottom whenever messages update
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    
                   return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == widget.userId;

                        // Format the timestamp
                        final formattedTimestamp = DateFormat('MMM d • hh:mm a').format(message.timestamp);

                        return Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                  color: isMe ? Colors.blueAccent : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: GestureDetector(
                                  onLongPress: () => _showMessageOptions(context, message, isMe),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.text,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                      // Add the timestamp below the message
                                      SizedBox(height: 4),  // Add some space between message and timestamp
                                      Text(
                                        formattedTimestamp,
                                        style: TextStyle(
                                          color: isMe ? Colors.white70 : Colors.black54,
                                          fontSize: 12, 
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showMessageOptions(BuildContext context, ChatMessage message, bool isMe) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.content_copy),
              title: Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (!isMe) ...[
              ListTile(
                leading: Icon(Icons.flag),
                title: Text('Report Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context, message);
                },
              ),
            ],
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, message);
                },
              ),
          ],
        ),
      );
    },
  );
}

void _showReportDialog(BuildContext context, ChatMessage message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Report Message'),
        content: Text('Are you sure you want to report this message?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Report'),
            onPressed: () {
              // TODO: Implement report functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message reported'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

void _showDeleteDialog(BuildContext context, ChatMessage message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMessage(message);
            },
          ),
        ],
      );
    },
  );
}
void _deleteMessage(ChatMessage message) {
  chatDB.deleteMessage(message.messageId);
}