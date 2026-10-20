import 'package:flutter/material.dart';
import 'package:icebreaker/discussion_page.dart';
import 'package:intl/intl.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';

import 'package:icebreaker/assets/database/user_info.dart';
import 'package:icebreaker/assets/database/discussion_queries.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'assets/database/chat_database.dart';
import 'package:icebreaker/chat_page.dart';
import 'package:logger/logger.dart';
//import 'package:icebreaker/edit_form.dart';
import 'package:photo_view/photo_view.dart';
import 'package:icebreaker/assets/database/poll.dart';
import 'package:provider/provider.dart';
import 'package:icebreaker/assets/database/poll_cache.dart';
import 'package:icebreaker/assets/database/poll_queries.dart';
import 'package:icebreaker/Models/poll_card.dart';import 'assets/database/profile_card.dart';

final _logger = Logger();

String formatTime(String time24hr) {
  // Extracting time part (HH:MM:SS)
  final parts = time24hr.split(RegExp(r'(\+|\-)'));
  final timePart = parts[0]; // "14:30:00"

  // Convert to DateTime (use today's date to create a full DateTime object)
  final now = DateTime.now();
  final timeParts = timePart.split(":");
  final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]));
  String formattedTime = DateFormat.jm().format(dateTime);

  return formattedTime;
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: BoxDecoration(
              color: Colors.black,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscussionPopUp extends StatefulWidget {
  final Map<String, dynamic> discussion;
  final VoidCallback? onDiscussionDeleted;

  const DiscussionPopUp({
    super.key,
    required this.discussion,
    this.onDiscussionDeleted,
  });

  @override
  State<DiscussionPopUp> createState() => _DiscussionPopUpState();
}

class _DiscussionPopUpState extends State<DiscussionPopUp> {
  final currentUser = Supabase.instance.client.auth.currentUser;
  final dB = Supabase.instance.client;
  final userInfo = UserInfo(supabase: Supabase.instance.client);
  final discussionQueries = DiscussionQueries();
  final pollQueries = PollQueries();
  bool isAttending = false;
  bool isLoading = true;
  bool isCreator = false;
  bool voted = false;
  late final ValueNotifier<bool> _isDeleteModeNotifier;
  late final ValueNotifier<Set<String>> _selectedPollsNotifier;

  @override
  void initState() {
    super.initState();
    _isDeleteModeNotifier = ValueNotifier<bool>(false);
    _selectedPollsNotifier = ValueNotifier<Set<String>>({});
    _checkAttendanceStatus();
    _checkIfCreator();
  }

  @override
  void dispose() {
    _isDeleteModeNotifier.dispose();
    _selectedPollsNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkAttendanceStatus() async {
    if (currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final attending = await discussionQueries.isUserAttendingDiscussion(
          widget.discussion['discussion_id'], currentUser!.id);

      setState(() {
        isAttending = attending;
        isLoading = false;
      });
    } catch (e) {
      _logger.e('Error checking attendance status: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  

  Future<void> _checkIfCreator() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      isCreator = currentUser.id == widget.discussion['owner_id'];
    });
  }

  Future<void> _toggleAttendance() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final success = await discussionQueries.toggleAttendance(
        widget.discussion['discussion_id'],
        currentUser.id
      );

      if (success) {
        setState(() {
          isAttending = !isAttending;
        });
      }
    } catch (e) {
      _logger.e('Error toggling attendance: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteDiscussion() async {
    try {
      await discussionQueries
          .deleteDiscussion(widget.discussion['discussion_id']);
      if (!mounted) return;
      if (widget.onDiscussionDeleted != null) {
        widget.onDiscussionDeleted!();
      }
      Navigator.pop(context); // Close the popup
    } catch (e) {
      _logger.e('Error deleting discussion: $e');
      if (!mounted) return;
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete discussion')),
      );
    }
  }

  Future<void> _deleteSelectedPolls() async {
    final pollsToDelete = _selectedPollsNotifier.value;
    if (pollsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Delete Polls',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${pollsToDelete.length} poll${pollsToDelete.length > 1 ? 's' : ''}? This action cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final pollId in pollsToDelete) {
          await pollQueries.deletePoll(pollId);
        }
        _selectedPollsNotifier.value = {};
        _isDeleteModeNotifier.value = false;

        setState(() {});

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting polls: $e')),
        );
      }
    }
  }

  Widget byUser(String userId) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text('By: '),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
            future: userInfo.getUserInfo(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      radius: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                );
              }
              return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    radius: 12,
                    backgroundImage: (snapshot.data?['profile_pic']?.isNotEmpty ?? false)
                        ? NetworkImage(snapshot.data!['profile_pic']!)
                        : null,
                    child: (snapshot.data?['profile_pic']?.isNotEmpty ?? false)
                        ? null
                        : Text(
                            snapshot.data?['username']?[0] ?? 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  SizedBox(width: 12),
                          Flexible(
                            child: Text(
                    snapshot.data?['username'] ?? 'Unknown User',
                    style: TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      //mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        //if (currentUser != null && currentUser!.id != widget.discussion['owner_id'])
                          if (!isCreator && snapshot.data?['private'] == false) ...[
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              color: Colors.grey[600],
                              onPressed: () async {
                                final currentUserId = currentUser!.id;
                                final existingChatId = await chatDB.getOrCreateChatBetween(currentUserId, widget.discussion['owner_id']);
                                if (!context.mounted) return;
                                if (existingChatId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        chatId: existingChatId['chat_id'],
                                        userId: currentUserId,
                                        username: snapshot.data?['username'],
                                        profile: snapshot.data?['profile_pic'],
                                      ),
                                    ),
                                  );
                                } else {
                                  final newChat = await chatDB.getOrCreateChatBetween(currentUserId, widget.discussion['user_id']);
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        chatId: newChat['chat_id'],
                                        userId: currentUserId,
                                        username: snapshot.data?['username'],
                                        profile: snapshot.data?['profile_pic'],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ]
                          else ...[
                            PopupMenuButton(
                              icon: Icon(Icons.more_vert),
                              menuPadding: EdgeInsets.all(10),
                              borderRadius: BorderRadius.circular(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              popUpAnimationStyle: AnimationStyle(
                                duration: Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                              ),
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                              itemBuilder: (context) => [
                                // PopupMenuItem(
                                //   onTap: () {},
                                //   child: Row(
                                //     children: [
                                //       Icon(Icons.edit, size: 16, color: Colors.blue,),
                                //       SizedBox(width: 4),
                                //       Text('Edit', style: TextStyle(color: Colors.blue, fontSize: 14),),
                                //     ],
                                //   ),
                                // ),
                                PopupMenuItem(
                                  onTap: () {
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          title: Text(
                                            'Delete Discussion',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete this discussion? This action cannot be undone.',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteDiscussion();
                                              },
                                              child: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red,),
                                      SizedBox(width: 4),
                                      Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14),),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ]
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget displayCategories() {
    if (widget.discussion['categories'] != null &&
        widget.discussion['categories'].isNotEmpty) {
      return Wrap(
        spacing: 2,
        runSpacing: 2,
        children: widget.discussion['categories']
            .map<Widget>((tag) {
          return Container(
            decoration: BoxDecoration(
              
            ),
            child: Chip(
              label: Text(
                tag,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 3,
              shadowColor: Colors.black,
            ),
          );
        }).toList(),
      );
    } else {
      return Text(
        'No tags',
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  Widget buildPolls() {
    return Container(
      child: ExpansionTile(
        title: Row(
          children: [
            FutureBuilder<int>(
              future: pollQueries.getTotalPolls(widget.discussion['discussion_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                return Row(
                  children: [
                    Icon(Icons.poll_outlined,size: 30, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    SizedBox(width: 8),
                    Text( snapshot.data == 0 ? 'No polls' : snapshot.data! > 1 ? '${snapshot.data} polls' : '${snapshot.data} poll', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                  ],
                );
              },
            ),
          ],
        ),
        children: [
          if (isCreator) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePollDialog(discussionId: widget.discussion['discussion_id']),
                        ),
                      );
                    }, 
                    icon: Icon(Icons.add, size: 20,color: Theme.of(context).colorScheme.onSurfaceVariant), 
                    label: Text('Poll', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isCreator) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isDeleteModeNotifier,
                      builder: (context, isDeleteMode, child) {
                        return ElevatedButton.icon(
                          onPressed: () {
                            final currentMode = _isDeleteModeNotifier.value;
                            final anySelected = _selectedPollsNotifier.value.isNotEmpty;

                            if (currentMode) {
                              if (anySelected) {
                                _deleteSelectedPolls();
                              } else {
                                _isDeleteModeNotifier.value = false;
                              }
                            } else {
                              _isDeleteModeNotifier.value = true;
                              _selectedPollsNotifier.value = {};
                            }
                          },
                          icon: Icon(
                            isDeleteMode ? Icons.delete : Icons.delete_outline,
                            size: 20,
                            color: isDeleteMode ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            isDeleteMode ? 'Delete Selected' : 'Delete',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDeleteMode ? Colors.red : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: 5),
          StreamBuilder<List<Poll>>(
            stream: pollQueries.getPollsByDiscussion(widget.discussion['discussion_id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                );
              }
              final polls = snapshot.data ?? [];
              if (polls.isEmpty) {
                return Center(child: Column(
                  children: [
                    Icon(Icons.poll_outlined,size: 30, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    SizedBox(height: 8),
                    Text('No polls at the moment', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),),
                  ],
                ));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: polls.length,
                itemBuilder: (context, index) {
                  final poll = polls[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ExpansionTileCard(
                      key: ValueKey(poll.pollId),
                      title: Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: _isDeleteModeNotifier,
                            builder: (context, isDeleteMode, _) {
                              if (isDeleteMode && isCreator) {
                                return ValueListenableBuilder<Set<String>>(
                                  valueListenable: _selectedPollsNotifier,
                                  builder: (context, selectedPolls, _) {
                                    return Checkbox(
                                      value: selectedPolls.contains(poll.pollId),
                                      onChanged: (bool? value) {
                                        final currentSelection = Set<String>.from(_selectedPollsNotifier.value);
                                        if (value == true) {
                                          currentSelection.add(poll.pollId);
                                        } else {
                                          currentSelection.remove(poll.pollId);
                                        }
                                        _selectedPollsNotifier.value = currentSelection;
                                      },
                                    );
                                  },
                                );
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              poll.question,
                              style: TextStyle(fontWeight: FontWeight.w500,),
                            ),
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...poll.options.map((option) => FutureBuilder<bool>(
                                future: Future.delayed(Duration(milliseconds: 100), () => pollQueries.hasUserVoted(poll.pollId)),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return ListTile(
                                      key: ValueKey(option.optionId),
                                      title: Text(option.text),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      dense: true,
                                    );
                                  }

                                  final hasVoted = snapshot.data ?? false;
                                  return ListTile(
                                    key: ValueKey(option.optionId),
                                    title: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 400),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                      child: hasVoted
                                          ? Container(
                                              key: ValueKey<String>('${option.optionId}_voted'),
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.blue.withValues(alpha: 0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      option.text,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: Colors.blue,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  FutureBuilder<int>(
                                                    future: pollQueries.getTotalVotes(poll.pollId),
                                                    builder: (context, totalSnapshot) {
                                                      if (totalSnapshot.connectionState == ConnectionState.waiting) {
                                                        return Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: Colors.deepPurple.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            '...',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.blueAccent,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      final totalVotes = totalSnapshot.data ?? 0;
                                                      final percentage = totalVotes > 0
                                                        ? ((option.votes / totalVotes) * 100).toStringAsFixed(1)
                                                        : '0.0';
                                                      return Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          '$percentage%',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.blue,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ElevatedButton(
                                              key: ValueKey<String>('${option.optionId}_vote'),
                                              onPressed: () async {
                                                await pollQueries.voteOnPoll(poll.pollId, option.optionId);
                                                setState(() {});
                                              },
                                              child: Text(option.text,style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                            ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    dense: true,
                                  );
                                },
                              )).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Future<void> _editDiscussion() async {
  //   if (!mounted) return;

  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => EditForm(
  //         discussion: widget.discussion,
  //         onDiscussionUpdated: () {
  //           if (widget.onDiscussionDeleted != null) {
  //             widget.onDiscussionDeleted!();
  //           }
  //         },
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Dialog(
                insetPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.95,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                
                                children: [
                                  IconButton(
                                        icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300],
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      SizedBox(height: 12),
                                  //++++++++++++ User ++++++++++++
                                  //++++++++++++ Title ++++++++++++
                                  Text(
                                    widget.discussion['title'],
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  byUser(widget.discussion['owner_id']),
                                  Divider(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  SizedBox(height: 1),
                                  //++++++++++++ Categories ++++++++++++
                                  displayCategories(),
                                  SizedBox(height: 16),
                                  //++++++++++++ Description ++++++++++++
                                  Text(
                                    widget.discussion['description'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: 16),

                                  //++++++++++++ Image ++++++++++++
                                  widget.discussion['image_url'] != null 
                                  ? Container(
                                      height: 200,
                                      width: double.infinity,
                                      child:
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImageViewer(
                                                  imageUrl: widget
                                                      .discussion['image_url'],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag:
                                                'discussion_image_${widget.discussion['discussion_id']}',
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Image.network(
                                                widget.discussion['image_url'],
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.25,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        )
                                    )
                                    : 
                                  SizedBox(height: 20),
                                  buildPolls()
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (Navigator.of(context).canPop()) ...[
                              if (isCreator) ...[
                                Flexible(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.forum_outlined,color: Colors.white),
                                    label: Text('Comment'),
                                    //label: Text('Discussion'),
                                    onPressed: () => Navigator.pop(context),

                                    style: ElevatedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF2196F3)
                                              : Colors.white,
                                      backgroundColor:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF2196F3)
                                                  .withValues(alpha: 0.1)
                                              : const Color(0xFF2196F3),
                                      elevation: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? 0
                                          : 2,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? BorderSide(
                                                color: const Color(0xFF2196F3))
                                            : BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else
                                Flexible(
                                  child: ElevatedButton.icon(
                                    icon: isLoading
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          )
                                        : Icon(Icons.forum_outlined, color: Colors.white), // default icon when not loading

                                    label: Text(
                                      isAttending ? "Leave" : "Comment",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),

                                    onPressed: isLoading ? null : () {
                                        // toggles attendance if already attending
                                        if (isAttending) {
                                          _toggleAttendance();
                                        } else {
                                          // toggles and redirects to discussion
                                          _toggleAttendance();
                                          
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => DiscPage(
                                                discId: widget.discussion['discussion_id'], 
                                                userId: userId!, 
                                                title: widget.discussion['title']
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF2196F3)
                                              : Colors.white,
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                                              : const Color(0xFF2196F3),
                                      disabledBackgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                                      disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 3,
                                      shadowColor: const Color(0xFF2196F3).withValues(alpha: 0.5),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: Theme.of(context).brightness == Brightness.dark
                                            ? BorderSide(color: const Color(0xFF2196F3))
                                            : BorderSide.none,
                                      ),
                                    ),
                                  ),

                                ),
                              SizedBox(width: 8),
                            ] else
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                          ],
                        ),
                        SizedBox(height: 32),
                        FutureBuilder<int>(
                          future: discussionQueries.getAttendeeCount(
                              widget.discussion['discussion_id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text(
                                '...',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              );
                            }
                            return Text(
                              'Participants (${snapshot.data ?? 0})',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: discussionQueries.getDiscussionAttendees(
                                  widget.discussion['discussion_id']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                      child:
                                          Text('Error loading participants'));
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Center(
                                      child: Text('No participants yet'));
                                }

                                return Column(
                                  children: snapshot.data!.map((attendee) {
                                    final currentUserId = currentUser?.id;
                                    final isMe = currentUserId == attendee['user_id'];

                                    return GestureDetector(
                            onTap: () {
                              bool message = true;
                              if (isCreator) {
                                message = false;
                              }
                              showProfileCard(context, attendee['user_id'], message);
                            },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.purple[100],
                                            backgroundImage: (attendee['Users']['profile_pic']?.isNotEmpty ?? false)
                                                ? NetworkImage(attendee['Users']['profile_pic']!)
                                                : null,
                                            child: (attendee['Users']['profile_pic']?.isEmpty ?? true)
                                                ? Text(
                                                    attendee['username'][0].toUpperCase(),
                                                    style: TextStyle(
                                                      color: Colors.purple[900],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              attendee['username'],
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (!isMe) FutureBuilder<bool>(
                                            future: chatDB.inChat(currentUser!.id, attendee['user_id']),
                                            builder: (context, snapshot) {
                                              final bool isInChat = snapshot.data ?? false;
                                              final bool isPrivate = attendee['Users']['private'] == true;
                                              if (isInChat && !isPrivate) {
                                                  return IconButton(
                                                    icon: Icon(Icons.chat_bubble_outline),
                                                    color: Colors.grey[600],
                                                    onPressed: () async {
                                                    final currentUser = Supabase.instance.client.auth.currentUser;
                                                    if (currentUser == null) return;
                                                    final currentUserId = currentUser.id;

                                                    final chatInfo = await chatDB.getOrCreateChatBetween(
                                                      currentUserId,
                                                      attendee['user_id'],
                                                    );

                                                    if (!context.mounted) return;

                                                    if (chatInfo != null) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => ChatPage(
                                                            chatId: chatInfo['chat_id'],
                                                            userId: currentUserId,
                                                            username: chatInfo['username'],
                                                            profile: chatInfo['profile_pic'],
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
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
  }
}

Future<void> voteOnPollOption(String optionId) async {
  await Supabase.instance.client.rpc('increment_vote_count', params: {'p_option_id': optionId});
}

