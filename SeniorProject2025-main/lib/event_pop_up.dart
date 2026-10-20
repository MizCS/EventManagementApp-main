import 'package:flutter/material.dart';
import 'package:icebreaker/Models/edit_form.dart';
import 'package:intl/intl.dart';
//import 'package:latlong2/latlong.dart';
import 'package:icebreaker/map_page.dart';
//import 'package:icebreaker/assets/database/events_database.dart';
//import 'package:icebreaker/assets/database/event_attendees.dart';
import 'package:icebreaker/assets/database/user_info.dart';
import 'package:icebreaker/assets/database/event_queries.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'assets/database/chat_database.dart';
import 'package:icebreaker/chat_page.dart';
import 'package:logger/logger.dart';
import 'package:icebreaker/Models/event_form.dart';
import 'package:photo_view/photo_view.dart';
import 'package:icebreaker/discussion_pop_up.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:icebreaker/Models/event_discussion_form.dart';
import 'assets/database/profile_card.dart';
final _logger = Logger();

String formatTime(String time24hr) {
  // Extracting time part (HH:MM:SS)
  final parts = time24hr.split(RegExp(r'(\+|\-)'));
  final timePart = parts[0]; // "14:30:00"

  // Convert to DateTime (use today's date to create a full DateTime object)
  final now = DateTime.now();
  final timeParts = timePart.split(":");
  final dateTime = DateTime(
    now.year, now.month, now.day,
    int.parse(timeParts[0]), int.parse(timeParts[1]), int.parse(timeParts[2])
  );
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
                color: Colors.black.withValues(alpha:0.5),
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

class EventPopUp extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onEventDeleted;
  
  const EventPopUp({
    super.key,
    required this.event,
    this.onEventDeleted,
  });

  @override
  State<EventPopUp> createState() => _EventPopUpState();
}

class _EventPopUpState extends State<EventPopUp> {
  final dB = Supabase.instance.client;
  final userInfo = UserInfo(supabase: Supabase.instance.client);
  final eventQueries = EventQueries(supabase: Supabase.instance.client);
  bool isAttending = false;
  bool isLoading = true;
  bool isCreator = false;

  @override
  void initState() {
    super.initState();
    _checkAttendanceStatus();
    _checkIfCreator();
  }

  Future<void> _checkAttendanceStatus() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final attending = await eventQueries.isUserAttendingEvent(
        widget.event['event_id'],
        currentUser.id
      );

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
      isCreator = currentUser.id == widget.event['user_id'];
    });
  }

  Future<void> _toggleAttendance() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final success = await eventQueries.toggleAttendance(
        widget.event['event_id'],
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

  




  Future<void> _deleteEvent() async {
    try {
      await eventQueries.deleteEvent(widget.event['event_id']);
      if (!mounted) return;
      if (widget.onEventDeleted != null) {
        widget.onEventDeleted!();
      }
      Navigator.pop(context); // Close the popup
    } catch (e) {
      _logger.e('Error deleting event: $e');
      if (!mounted) return;
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete event')),
      );
    }
  }

  Future<void> _editEvent() async {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditForm(
          event: widget.event,
          onEventUpdated: () {
            if (widget.onEventDeleted != null) {
              widget.onEventDeleted!();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDiscussionsTab() {
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: eventQueries.getDiscussionsForEventStream(widget.event['event_id'].toString()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading discussions'));
          }
          final discussions = snapshot.data ?? [];
          return ListView.builder(
            itemCount: discussions.length,
            itemBuilder: (context, index) {
              final discussion = discussions[index];
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 5.0),
                child: ExpansionTileCard(
                  
                  baseColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                  expandedColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                  initialElevation: 5,
                  borderRadius: BorderRadius.circular(20),
                  shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.blue : Colors.black,
                  title: Text(discussion['title']),
                  subtitle: Row(
                    children: [
                      Icon(Icons.person,
                      size: 16,
                      ),
                      Text((discussion['participants']?.length ?? 0).toString(),
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(discussion['description'],
                      style: TextStyle(
                        fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    ),
                    ),
                    OverflowBar(
                      children: [
                        TextButton(
                          onPressed: (){
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DiscussionPopUp(discussion: discussion, onDiscussionDeleted: (){
                              if (widget.onEventDeleted != null) {
                                widget.onEventDeleted!();
                              }
                            }),
                              ),
                            );
                          },
                          child: Text('View'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Dialog(
                insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  decoration: BoxDecoration(
                    //color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                              IconButton(
                              icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300],
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ]
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 16),
                                  if (widget.event['image_url'] != null)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullScreenImageViewer(
                                              imageUrl: widget.event['image_url'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Hero(
                                        tag: 'event_image_${widget.event['event_id']}',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        widget.event['image_url'],
                                            height: MediaQuery.of(context).size.height * 0.25,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        height: MediaQuery.of(context).size.height * 0.25,
                                        width: double.infinity,
                                        color: Theme.of(context).colorScheme.surface,
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 16),
                                  Text(
                                    widget.event['title'],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: 180),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (widget.event['tags'] != null && widget.event['tags'].isNotEmpty)
                                            Wrap(
                                              spacing: 2,
                                              runSpacing: 2,
                                              children: widget.event['tags'].map<Widget>((tag) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(20),
                                                  
                                                      
                                                    
                                                  ),
                                                  child: Chip(
                                                  label: Text(
                                                    tag,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                      color: Colors.white,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    backgroundColor: const Color(0xFF2196F3),
                                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 3,
                                                    shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 5.0) : Colors.black,
                                                    //shadowColor: const Color(0xFF2196F3),//.withValues(alpha: 0.25),
                                                  ),
                                                );
                                              }).toList(),
                                            )
                                          else
                                            Text(
                                              'No tags',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          SizedBox(height: 24),
                                          Text(
                                            'Description',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            widget.event['description'],
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          SizedBox(height: 24),
                                          Text(
                                            'Location',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  widget.event['location'],
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 24),
                                          Text(
                                            'Time',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '${formatTime(widget.event['time_start'] ?? 0)} - ${formatTime(widget.event['time_end'] ?? 0)}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
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
                                    icon: Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3) // Material Blue
                                        : Colors.white,
                                    ),
                                    label: Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                      onPressed: _editEvent,
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3) // Material Blue
                                        : Colors.white,
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade900
                                        : const Color(0xFF2196F3), // Material Blue
                                      elevation: Theme.of(context).brightness == Brightness.dark ? 3 : 3,
                                      shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 5.0) : Colors.black,
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
                                Flexible(
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.delete_forever_rounded,
                                      size: 18,
                                      color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3) // Material Blue
                                        : Colors.white,
                                    ),
                                    label: Text('Delete'),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                          backgroundColor: Theme.of(context).colorScheme.surface,
                                          title: Text(
                                            'Delete Event',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete this event? This action cannot be undone.',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                Navigator.pop(context);
                                                  _deleteEvent();
                                                },
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
                                      },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3) // Material Blue
                                        : Colors.white,
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade900
                                        : const Color(0xFF2196F3), // Material Blue
                                      elevation: Theme.of(context).brightness == Brightness.dark ? 3 : 3,
                                      shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 5.0) : Colors.black,
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: Theme.of(context).brightness == Brightness.dark
                                          ? BorderSide(color: const Color(0xFF2196F3))
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
                                              Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF2196F3) // Material Blue
                                                : Colors.white,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          isAttending ? Icons.person_remove : Icons.person_add,
                                          size: 18,
                                          color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF2196F3) // Material Blue
                                            : Colors.white,
                                        ),
                                    label: Text(
                                      isAttending ? "Unattend" : "Attend",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  onPressed: isLoading ? null : _toggleAttendance,
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2196F3)
                                        : Colors.white,
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade900
                                        : const Color(0xFF2196F3),
                                      disabledBackgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha:0.3),
                                      disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6),
                                      elevation: Theme.of(context).brightness == Brightness.dark ? 3 : 3,
                                      shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 5.0) : Colors.black,
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
                              Flexible(
                                child: ElevatedButton.icon(
                                  icon: Icon(
                                    Icons.map,
                                    size: 18,
                                    color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color.fromARGB(255, 104, 182, 247)
                                      : Colors.white,
                                  ),
                                  label: Text(
                                    "Map",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GoogleMapScreen(initialEventIndex: int.parse(widget.event['event_id'].toString())),
                                    ),
                                  );
                                }, 
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? const Color.fromARGB(255, 104, 182, 247)
                                      : Colors.white,
                                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade900
                                      : const Color.fromARGB(255, 104, 182, 247),
                                    elevation: Theme.of(context).brightness == Brightness.dark ? 3 : 3,
                                    shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 5.0) : Colors.black,
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: Theme.of(context).brightness == Brightness.dark
                                        ? BorderSide(
                                            color: const Color.fromARGB(255, 104, 182, 247),
                                            width: 1.5,
                                          )
                                        : BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                          ],
                        ),
                        SizedBox(height: 32),
                        Text(
                          'Event Organizer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        FutureBuilder<Map<String, dynamic>>(
                          future: userInfo.getUserInfo(widget.event['user_id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              );
                            }
                            return GestureDetector(
                                    onTap: () {
                                    showProfileCard(context, widget.event['user_id'], true);
                                  },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  backgroundImage: (snapshot.data?['profile_pic']?.isNotEmpty ?? false)
                                    ? NetworkImage(snapshot.data!['profile_pic']!)
                                    : null,
                                  child: (snapshot.data?['profile_pic']?.isEmpty ?? true)
                                    ? Text(
                                        snapshot.data?['username']?[0].toUpperCase() ?? 'U',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    snapshot.data?['username'] is String 
                                      ? snapshot.data!['username'] 
                                      : 'Unknown User',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (currentUser != null && currentUser.id != widget.event['user_id'])
                                if (!isCreator && snapshot.data?['private'] == false)
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    color: Colors.grey[600],
                                    onPressed: () async {
                                      final currentUserId = currentUser.id;

                                      final existingChatId = await chatDB.getOrCreateChatBetween(
                                        currentUserId,
                                        widget.event['user_id'],
                                      );

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
                                      } // cleaned up logic
                                    },
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                            );
                          },
                        ),
                        Divider(height: 24),
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 1, vertical: 10),
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child:DefaultTabController(
                            length: 2,
                            child: Column(
                          children: [
                            FutureBuilder<int>(
                              future: eventQueries.getAttendeeCount(widget.event['event_id']),
                          builder: (context, snapshot) {
                                  return TabBar(
                                    
                                    indicatorColor: Colors.blueAccent.shade100,
                                    indicatorWeight: 3,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    labelColor: Colors.blue,
                                    unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade500,
                                    labelPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    tabs: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.group),
                                          SizedBox(width: 4),
                                          Text('${snapshot.data ?? 0}'),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.topic),
                                          SizedBox(width: 4),
                                          Text('Discussions'),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(
                                height: 400, // Adjust this height based on your needs
                                child: TabBarView(
                                  
                                  children: [
                                    // Attendees Tab
                                    SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          
                        SizedBox(height: 10),
                        Container(
                            constraints: BoxConstraints(maxHeight: 390),
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: eventQueries.getEventAttendees(widget.event['event_id']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(child: CircularProgressIndicator());
                                }

                                if (snapshot.hasError) {
                                  return Center(child: Text('Error loading attendees'));
                                }

                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return Center(child: Text('No attendees yet'));
                                }

                                return Column(
                                  children: snapshot.data!.map((attendee) {
                                    final currentUserId = currentUser?.id;
                                    final isMe = currentUserId == attendee['user_id'];

                                    return GestureDetector(
                                    onTap: () {
                                    showProfileCard(context, attendee['user_id']!, true);
                                  },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.purple[100],
                                            backgroundImage: (attendee['profile_pic']?.isNotEmpty ?? false)
                                              ? NetworkImage(attendee['profile_pic']!)
                                              : null,
                                            child: (attendee['profile_pic']?.isEmpty ?? true)
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
                                          FutureBuilder<bool>(
                                            future: chatDB.inChat(currentUser!.id, attendee['user_id']),
                                            builder: (context, snapshot) {
                                              if (!isMe && (snapshot.data == true && attendee['private'] == false)) {
                                                return IconButton(
                                                  icon: Icon(Icons.chat_bubble_outline),
                                                  color: Colors.grey[600],
                                                  onPressed: () async {
                                                    final currentUserId = currentUser!.id;

                                                    final existingChatId = await chatDB.getOrCreateChatBetween(currentUserId, attendee['user_id']);

                                                    if (!context.mounted) return;

                                                    if (existingChatId != null) {
                                                      // Navigate to normal ChatPage
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => ChatPage(
                                                            chatId: existingChatId['chat_id'],
                                                            userId: currentUserId,
                                                            username: attendee['username'],
                                                            profile: attendee['profile_pic'],
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
                                        ],
                                      ),
                                    ),
                                    // Discussion Tab
                                    Stack(
                                      children: [
                                        SingleChildScrollView(
                                          child: Column(
                                            children: [
                                              _buildDiscussionsTab(),
                                            ],
                                          ),
                                        ),
                                        if (isCreator)
                                          Positioned(
                                            right: 16,
                                            bottom: 16,
                                            child: FloatingActionButton(
                                              onPressed: (){
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EventDiscussionForm(
                                                      eventId: widget.event['event_id'].toString(),
                                                    ),
                                                  ),
                                                );
                                              },
                                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.blue,
                                              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                                              child: Icon(Icons.add),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
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