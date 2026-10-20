import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'assets/database/disc_database.dart';
import 'assets/database/disc_message.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:swipe_to/swipe_to.dart';
import 'models/reaction_manager.dart';
//import 'assets/database/chat_map.dart';
import 'package:intl/intl.dart'; 

import 'discussion_pop_up.dart';

/// Global database instance for discussion operations
final DiscDatabase discDB = DiscDatabase();

/// Main discussion page widget that displays messages and handles interactions
class DiscPage extends StatefulWidget {
  final String discId;
  final String userId;
  final String title;

  const DiscPage({
    super.key, 
    required this.discId, 
    required this.userId, 
    required this.title
  });
  
  @override
  DiscPageState createState() => DiscPageState();
}

/// State management for the discussion page
class DiscPageState extends State<DiscPage> with SingleTickerProviderStateMixin {
  // Controllers for user input and scrolling
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers and states
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Reaction system manager - initialized in didChangeDependencies
  ReactionManager? _reactionManager;

  // User interface state
  Map<String, String> userColors = {};
  Map<String, String> userInfo = {};
  bool isLoadingColors = true;
  DiscMessage? replyingToMessage;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  /// Initialize all necessary state variables and controllers
  void _initializeState() {
    preloadColors();
    _initializeAnimationController();
  }

  /// Initialize the animation controller for message interactions
  void _initializeAnimationController() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeReactionManager();
  }

  /// Initialize the reaction manager with necessary dependencies
  void _initializeReactionManager() {
    _reactionManager = ReactionManager(
      context: context,
      currentUserId: widget.userId,
      onUpdateReaction: _updateMessageReaction,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Send a new message to the discussion
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String messageText = _messageController.text;
    if (replyingToMessage != null) {
      messageText = "${replyingToMessage!.text}::replying to::$messageText";
    }

    final message = DiscMessage(
      messageId: _generateUUID(),
      discId: widget.discId,
      senderId: widget.userId,
      text: messageText,
      timestamp: DateTime.now(),
    );

    await discDB.sendMessage(message);
    _messageController.clear();
    setState(() {
      replyingToMessage = null;
    });

    // Wait for the next frame to ensure the ListView has updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// Generate a unique identifier for messages
  String _generateUUID() => const Uuid().v4();

  /// Load user colors for message styling
  Future<void> preloadColors() async {
    userColors = await discDB.getUserColor(widget.discId);
    setState(() {
      isLoadingColors = false;
    });
  }

  /// Blend user color with gray for message styling
  Color blendWithGray(Color userColor, [double strength = 0.15]) {
    final gray = Colors.grey[200]!;
    return Color.lerp(gray, userColor, strength)!;
  }

  /// Scroll the message list to the bottom
  Future<void> _scrollToBottom() async {
    if (_scrollController.hasClients) {
      try {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        // Ignore scroll errors
      }
    }
  }
  
  /// Update a message's reactions
  Future<void> _updateMessageReaction(DiscMessage message, String emoji) async {
    final userReactions = Map<String, String>.fromEntries(
      message.emoji.map((r) {
        final info = ReactionInfo.fromString(r);
        return MapEntry(info.userId, info.emoji);
      })
    );

    if (userReactions.containsKey(widget.userId)) {
      if (userReactions[widget.userId] == emoji) {
        userReactions.remove(widget.userId);
      } else {
        userReactions[widget.userId] = emoji;
      }
    } else {
      userReactions[widget.userId] = emoji;
    }

    final updatedEmoji = userReactions.entries
        .map((e) => ReactionInfo(e.key, e.value).format())
        .toList();
    
    await discDB.updateMessageEmoji(message.messageId, updatedEmoji);
  }

  /// Build the content of a message, handling reply formatting
  Widget _buildMessageContent(String messageText, bool isMe, String formattedTimestamp) {
    if (messageText.contains("::replying to::")) {
      final parts = messageText.split("::replying to::");
      final originalMessage = parts[0];
      final replyMessage = parts[1];
      
      return Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              originalMessage,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            replyMessage,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formattedTimestamp,
            style: TextStyle(
              color: isMe ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          messageText,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formattedTimestamp,
          style: TextStyle(
            color: isMe ? Colors.white70 : Colors.black54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build a message bubble with reactions and interaction handlers
  Widget _buildMessageBubble(DiscMessage message, bool isMe, String username, Color userColor, String formattedTimestamp) {
    final reactionManager = _reactionManager;
    if (reactionManager == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SwipeTo(
            onRightSwipe: !isMe ? (details) {
              setState(() {
                replyingToMessage = message;
              });
            } : null,
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: GestureDetector(
                  onLongPress: () => _showMessageOptions(context, message, isMe),
                  onDoubleTapDown: (details) {
                    reactionManager.showQuickReactionPicker(message, details.globalPosition);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blueAccent : blendWithGray(userColor, 0.2),
                      border: Border.all(
                        color: isMe ? Colors.blue[100]! : userColor,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(ReactionConstants.messageBorderRadius),
                    ),
                    child: _buildMessageContent(message.text, isMe, formattedTimestamp),
                  ),
                ),
              ),
            ),
            
          ),
          if (message.emoji.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                right: isMe ? 12 : 0,
                left: isMe ? 0 : 12,
              ),
              child: reactionManager.buildReactions(message.emoji),
            ),
        ],
      ),
    );
  }

  /// Show message options in a bottom sheet
  void _showMessageOptions(BuildContext context, DiscMessage message, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy Message'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Report Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(context, message);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Message'),
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

  /// Show report dialog for a message
  void _showReportDialog(BuildContext context, DiscMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Message'),
          content: const Text('Are you sure you want to report this message?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Report'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
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

  /// Show delete confirmation dialog
  void _showDeleteDialog(BuildContext context, DiscMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                discDB.deleteMessage(message.messageId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded( 
              child: Text(
                widget.title.isNotEmpty ? widget.title : 'Missing Title',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            /*
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // TODO: Implement info card
              }
            ),
            */
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, String>>(
              future: discDB.getParticipantUsernames(widget.discId),
              builder: (context, nameSnapshot) {
                if (!nameSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                userInfo = nameSnapshot.data!;

                return StreamBuilder<List<DiscMessage>>(
                  stream: discDB.getDiscMessagesStream(widget.discId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                    
                    // Scroll to bottom when messages are first loaded
                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    }
                    
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == widget.userId;
                        final username = userInfo[message.senderId] ?? 'Unknown';
                        final userColorHex = userColors[message.senderId] ?? '#CCCCCC';
                        final userColor = Color(int.parse(userColorHex.replaceFirst('#', '0xFF')));

                        final showUsername = index == 0 || message.senderId != messages[index - 1].senderId;
                        final formattedTimestamp = DateFormat('MMM d • hh:mm a').format(message.timestamp);

                        return Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (showUsername)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                                child: Text(
                                  isMe ? 'You' : username,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            _buildMessageBubble(message, isMe, username, userColor,formattedTimestamp),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.reply,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Replying to ${replyingToMessage!.senderId == widget.userId ? 'You' : userInfo[replyingToMessage!.senderId] ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  replyingToMessage = null;
                                  _messageController.clear();
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          replyingToMessage!.text,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
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
                  icon: const Icon(Icons.send),
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
