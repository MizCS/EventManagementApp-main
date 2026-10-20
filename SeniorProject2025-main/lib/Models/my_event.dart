import 'package:flutter/material.dart';
import 'package:icebreaker/Models/edit_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:icebreaker/Models/event_form.dart';
import 'package:stroke_text/stroke_text.dart';
//import 'package:icebreaker/assets/database/event_queries.dart';
import 'package:shimmer/shimmer.dart';
final _logger = Logger();

class MyEvent extends StatefulWidget {
  const MyEvent({super.key});

  @override
  State<MyEvent> createState() => _MyEventState();
}

class _MyEventState extends State<MyEvent> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> events = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          errorMessage = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      final fetchedEvents = await fetchMyEvents();
      if (!mounted) return;
      
      setState(() {
        events = List<Map<String, dynamic>>.from(fetchedEvents);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Failed to load events: ${e.toString()}';
        isLoading = false;
      });
      _logger.e('Error loading events: $e');
    }
  }

  Future<List<dynamic>> fetchMyEvents() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('Events')
          .select()
          .eq('user_id', currentUser.id);
          
      return response;
    } catch (e) {
      _logger.e('Error fetching events: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(int eventId) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await supabase
          .from('Events')
          .delete()
          .eq('event_id', eventId);
          
      if (!mounted) return;
      await _loadEvents();
      
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _logger.e('Error deleting event: $e');
      if (!mounted) return;
      
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete event: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showMoreOptions(int eventId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final event = events.firstWhere((event) => event['event_id'] == eventId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: 
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(event['title'] ?? 'Unnamed Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () => Navigator.pop(context),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditForm(event: event),
                ),
              );
              },
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: Colors.white
              ),
              label: const Text('Edit', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: (){
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    title: Text('Delete Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (mounted) {
                            Navigator.pop(context);
                            deleteEvent(event['event_id']);
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: Colors.white
              ),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('My Events'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: isLoading
            ? ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEvents,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : events.isEmpty
                    ? const Center(child: Text('No events found'))
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          DateTime? eventDate;
                          DateTime? eventEndDate;
                          try {
                            eventDate = DateTime.parse(event['start_date'] ?? '');
                          } catch (e) {
                            eventDate = null; // Default to current date if parsing fails
                          }
                          try {
                            eventEndDate = DateTime.parse(event['end_date'] ?? '');
                          } catch (e) {
                            eventEndDate = null; // Default to current date if parsing fails
                          }
                          final isPastEvent = event['recurring'] == false && eventDate != null && eventDate!.isBefore(DateTime.now());
                          final isFutureEvent = event['recurring'] == false && eventDate != null && eventDate!.isAfter(DateTime.now());
                          final isOngoingEvent = event['recurring'] == true && eventDate != null && eventDate!.isAfter(DateTime.now()) && eventEndDate != null && eventEndDate!.isBefore(DateTime.now());

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Card(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.surface,
                                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Background image with gradient overlay
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: Theme.of(context).brightness == Brightness.dark
                                            ? [
                                                Colors.black.withValues(alpha: 0.8),
                                                Colors.black.withValues(alpha: 0.6),
                                                Colors.transparent,
                                              ]
                                            : [
                                                Colors.black.withValues(alpha: 0.6),
                                                Colors.black.withValues(alpha: 0.3),
                                                Colors.transparent,
                                              ],
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                        ).createShader(bounds),
                                        blendMode: BlendMode.darken,
                                        child: Image.network(
                                          event['image_url'] ?? 'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png',
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            height: 140,
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Content overlay
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: StrokeText(
                                                  text: event['title'] ?? 'Unnamed Event',
                                                  strokeColor: Colors.black87,
                                                  strokeWidth: 3,
                                                  textStyle: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                                                visualDensity: VisualDensity.compact,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                                  shape: const CircleBorder(),
                                                ),
                                                onPressed: () => _showMoreOptions(event['event_id']),
                                                tooltip: 'More options',
                                              ),
                                              if (isPastEvent)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade400,
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.2),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'Past',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              if (isFutureEvent)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade400,
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.2),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'Upcoming',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              if (isOngoingEvent)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade400,  
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.2),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'Ongoing',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${eventDate?.day}/${eventDate?.month}/${eventDate?.year}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.location_on,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          event['location'] ?? 'No location',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.people,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${(event['attendees'] as List?)?.length ?? 0}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Row(
                                              //   children: [
                                              //     Container(
                                              //       decoration: BoxDecoration(
                                              //         color: Colors.white24,
                                              //         borderRadius: BorderRadius.circular(12),
                                              //         border: Border.all(color: Colors.white30),
                                              //       ),
                                              //       child: IconButton(
                                              //         icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                              //         onPressed: () {
                                              //           Navigator.push(
                                              //             context,
                                              //             MaterialPageRoute(
                                              //               builder: (context) => EditForm(event: event),
                                              //             ),
                                              //           );
                                              //         },
                                              //         tooltip: 'Edit Event',
                                              //       ),
                                              //     ),
                                              //     const SizedBox(width: 8),
                                              //     Container(
                                              //       decoration: BoxDecoration(
                                              //         color: Colors.white24,
                                              //         borderRadius: BorderRadius.circular(12),
                                              //         border: Border.all(color: Colors.white30),
                                              //       ),
                                              //       child: IconButton(
                                              //         icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                              //         onPressed: () {
                                              //           showDialog(
                                              //             context: context,
                                              //             builder: (context) => AlertDialog(
                                              //               backgroundColor: Theme.of(context).colorScheme.surface,
                                              //               shape: RoundedRectangleBorder(
                                              //                 borderRadius: BorderRadius.circular(15),
                                              //               ),
                                              //               title: Text(
                                              //                 'Delete Event',
                                              //                 style: TextStyle(
                                              //                   color: Theme.of(context).colorScheme.onSurface,
                                              //                   fontWeight: FontWeight.bold,
                                              //                 ),
                                              //               ),
                                              //               content: Text(
                                              //                 'Are you sure you want to delete this event? This action cannot be undone.',
                                              //                 style: TextStyle(
                                              //                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              //                 ),
                                              //               ),
                                              //               actions: [
                                              //                 TextButton(
                                              //                   onPressed: () => Navigator.pop(context),
                                              //                   child: Text(
                                              //                     'Cancel',
                                              //                     style: TextStyle(
                                              //                       color: Theme.of(context).colorScheme.primary,
                                              //                       fontWeight: FontWeight.w600,
                                              //                     ),
                                              //                   ),
                                              //                 ),
                                              //                 TextButton(
                                              //                   onPressed: () {
                                              //                     Navigator.pop(context);
                                              //                     deleteEvent(event['event_id']);
                                              //                   },
                                              //                   child: Text(
                                              //                     'Delete',
                                              //                     style: TextStyle(
                                              //                       color: Theme.of(context).colorScheme.error,
                                              //                       fontWeight: FontWeight.w600,
                                              //                     ),
                                              //                   ),
                                              //                 ),
                                              //               ],
                                              //             ),
                                              //           );
                                              //         },
                                              //         tooltip: 'Delete Event',
                                              //       ),
                                              //     ),
                                              //   ],
                                              //),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}