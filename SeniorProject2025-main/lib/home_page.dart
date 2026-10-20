import 'package:flutter/material.dart';
import 'package:icebreaker/chat_page.dart';
import 'package:icebreaker/chat_list.dart';
import 'package:icebreaker/map_page.dart';
import 'package:icebreaker/settings_page.dart';
import 'package:icebreaker/Models/events_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroke_text/stroke_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icebreaker/assets/geoloc.dart';
import 'package:icebreaker/assets/database/user_info.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:icebreaker/Models/grid_view.dart';
import 'event_pop_up.dart' as event_popup;
import 'create_page.dart';
import 'dart:io';
import 'assets/database/event_queries.dart';
import 'assets/database/profile_card.dart';
import 'package:logger/logger.dart';
import 'package:icebreaker/assets/database/discussion_queries.dart';
import 'discussion_pop_up.dart';
import 'package:icebreaker/assets/database/chat_database.dart';
import 'Models/discussions_grid_view.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:icebreaker/assets/database/discussion_queries.dart';
import 'assets/database/online_status.dart';

final _logger = Logger();


// possibly move MainScreen to main.dart, for now working solution
// may keep this solution, instagram uses a similar system
// TODO: Fix crashing issue when user uses back arrow. Fix incorrect redirects (may need to pass in index number to mainscreen)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Remove unused variables
  String? _backgroundPath;
  final eventsModel = EventsModel();
  final discussionQueries = DiscussionQueries();
  List<dynamic> events = [];
  List<dynamic> nearbyEvents = [];
  List<dynamic> filteredEvents = [];
  List<dynamic> filteredNearbyEvents = [];
  Set<String> selectedTags = {};
  Set<String> selectedCategories = {};
  Set<String> preferredCategories = {};
  Set<String> preferredTags = {};
  LatLng? cLocation;
  List<dynamic> filteredDiscussions = [];  
  final List<String> availableCategories = [
    'General',
    'Questions',
    'Ideas',
    'Feedback',
    'Announcements',
    'Help',
    'Other'
  ];

  late String username = '';
  late String profilePic = '';
  late String userId = '';
  late bool private = false;
  bool isLoading = true;
  bool isEventsLoading = true;
  
  String isNear = 'Events near me';
  String isChats = 'Chats';
  Color containerColor = Colors.black.withValues(alpha: 0.7);
  Color cardColor = Colors.white;
  Color textColor = Colors.black;
  bool isGridView = false;
  final onlineStatus = OnlineStatus(supabase: Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
    _loadBackgroundImagePath();
    _updateOnlineStatus(true);
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final location = await GeoLocatorService.getCurrentLatLng();
    if (location != null) {
    setState(() {
        cLocation = location;
      });
    }
  }

  void _filterEvents(List<dynamic> allEvents, List<dynamic> allNearbyEvents) {
    if (selectedTags.isEmpty) {
      filteredEvents = allEvents;
      filteredNearbyEvents = allNearbyEvents;
      return;
    }

    filteredEvents = allEvents.where((event) {
        final eventTags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        return selectedTags.any((tag) => eventTags.contains(tag));
      }).toList();

    filteredNearbyEvents = allNearbyEvents.where((event) {
        final eventTags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        return selectedTags.any((tag) => eventTags.contains(tag));
      }).toList();
  }

  Set<String> _getAllTags(List<dynamic> events) {
    final Set<String> allTags = {};
    for (final event in events) {
      final tags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      allTags.addAll(tags);
    }
    return allTags;
  }

  List<String> _getSortedTags(List<dynamic> events) {
    final allTags = _getAllTags(events);
    return allTags.where((tag) => !preferredTags.contains(tag)).toList();
  }

  //fetch user data from Supa
  Future<Map<String, dynamic>?> _fetchUserData() async {
    final response = await Supabase.instance.client
        .from('Users')
        .select()
        .eq('user_id', userId.toString())
        .single();

    _logger.i("Fetched user data: $response");  // Debugging output
    return response;
  }

  // Function to fetch user data
  Future<void> _loadUserData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      _logger.i("No authenticated user found!");
      return;
    }

    userId = currentUser.id; // Set userId from Supabase auth

    final userData = await _fetchUserData();
    setState(() {
      username = userData?['username'] ?? 'Unknown'; // Set the username
      profilePic = userData?['profile_pic'] ?? ''; // Set the profile picture URL
      preferredTags = (userData?['pref_tags'] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      preferredCategories = (userData?['pref_cat'] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      private = userData?['private'] ?? false;

      _logger.i('Fetched profilePic: $profilePic');
      isLoading = false; // Stop loading
    });
  }

  Future<void> _loadBackgroundImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('background_image_path');
    setState(() {
      _backgroundPath = savedPath;
    });
  }

  ImageProvider _getBackgroundImage() {
    if (_backgroundPath != null) {
      final file = File(_backgroundPath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return const AssetImage('assets/images/Iceberg_bg.jpg');
  }
  Widget displayCategories(List<dynamic> categories) {
    if (categories != null &&
        categories.isNotEmpty) {
      return Wrap(
        spacing: 1,
        runSpacing: 1,
        children: categories
            .map<Widget>((tag) {
          return Container(
            decoration: BoxDecoration(
              
            ),
            child: Chip(
              label: Text(
                tag.toString(),
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  //int _currentIndex = 1;

  //final int _currentIndex = 1;

  Widget _buildEventSkeleton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,

      height: 160,
      width: 320,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[300]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  String _getEventTimeStatus(Map<String, dynamic> event) {
    try {
      final startDateStr = event['start_date'] as String?;
      final endDateStr = event['end_date'] as String?;
      final startTime = event['time_start'] as String?;
      final endTime = event['time_end'] as String?;

      // If any required field is null, return empty string
      if (startDateStr == null || endDateStr == null || startTime == null || endTime == null) {
        return '';
      }

      final now = DateTime.now();
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      try {
        final timeStart = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(startTime));
        final timeEnd = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(endTime));
        
        final eventStartDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          timeStart.hour,
          timeStart.minute,
        );
        
        final eventEndDateTime = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          timeEnd.hour,
          timeEnd.minute,
        );

        if (now.isBefore(eventStartDateTime)) {
          final difference = eventStartDateTime.difference(now);
          if (difference.inDays > 0) {
            return 'Starts in ${difference.inDays}d';
          } else if (difference.inHours > 0) {
            return 'Starts in ${difference.inHours}h';
          } else {
            return 'Starts in ${difference.inMinutes}m';
          }
        } else if (now.isAfter(eventStartDateTime) && now.isBefore(eventEndDateTime)) {
          return 'Ongoing';
        } else {
          return 'Ended';
        }
      } catch (e) {
        print('Error parsing time: $e');
        return '';
      }
    } catch (e) {
      print('Error in _getEventTimeStatus: $e');
      return '';
    }
  }

  Widget _buildEventsList(List<dynamic> events, bool isLoading) {
    if (isLoading && events.isEmpty) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => _buildEventSkeleton(),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events to display',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return event_popup.EventPopUp(
                    event: event,
                    onEventDeleted: _onEventDeleted,
                  );
                },
              );
            },
            child: Container(
              height: 160,
              width: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        event['image_url'] ?? 'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png',
                        height: 160,
                        width: 320,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 160,
                          width: 320,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event['title'] ?? "No title",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event['location'] ?? "No location",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${event_popup.formatTime(event['time_start'] ?? "00:00:00")} - ${event_popup.formatTime(event['time_end'] ?? "00:00:00")}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (event['days'] != null && (event['days'] as List).isNotEmpty) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDays(event['days'] as List),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getEventTimeStatus(event),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final containerColor = isDark ? Colors.black.withValues(alpha:0.7) : Colors.black.withValues(alpha:0.5);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu, color: theme.appBarTheme.foregroundColor),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );

                // Reload background image after returning
                await _loadBackgroundImagePath();
                setState(() {}); // Force a rebuild with the new background
              },
            );
          },
        ),
        title: Text('Home', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
        actions: <Widget>[
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.person, color: theme.appBarTheme.foregroundColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileSettingsPage()),
                  );
                },
              );
            },
          )
        ],
      ),
    
      bottomNavigationBar: BottomAppBar(
        color: theme.appBarTheme.backgroundColor,
        shape: const CircularNotchedRectangle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.chat, color: theme.bottomNavigationBarTheme.selectedItemColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ChatList(userId: userId, username: username)),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.add, color: theme.bottomNavigationBarTheme.selectedItemColor),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePage(
                        onEventCreated: () {
                          setState(() {
                            isEventsLoading = true;
                          });
                        },
                      ),
                    ),
                  );
                  // Reload events after returning from CreatePage
                  setState(() {
                    isEventsLoading = true;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.map, color: theme.bottomNavigationBarTheme.selectedItemColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoogleMapScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      body: isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Loading...', style: TextStyle(fontSize: 20, color: textColor)),
                const CircularProgressIndicator(),
              ],
            ),
          )
        : Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _getBackgroundImage(),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.black.withValues(alpha:0.7) : Colors.black.withValues(alpha:0.3),
                  BlendMode.darken,
                ),
              ),
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  isEventsLoading = true;
                });
                await _loadUserData();
                await _getCurrentLocation();
                setState(() {
                  isEventsLoading = false;
                });
              },
              child: ListView(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
                        child: Column(
                          children: [
                            StrokeText(
                              text: 'Welcome,',
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w500,
                              ),
                              strokeColor: Colors.grey,
                              strokeWidth: 2,
                            ),
                            StrokeText(
                              text: username,
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w500,
                              ),
                              strokeColor: Colors.grey,
                              strokeWidth: 2,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                    onTap: () async {
                      //Show users profile card
                      final user = await _fetchUserData();
                      showProfileCard(context, userId, false);
                    },
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 20, 0, 20),
                      child: SizedBox(
                        width: 144,
                        height: 144,
                        child: CircleAvatar(
                          backgroundColor: Colors.black,
                          backgroundImage: profilePic.isNotEmpty
                              ? NetworkImage(profilePic)
                              : NetworkImage('https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png'),
                        ),
                      ),
                    ),
                  ),
                      StreamBuilder<List<dynamic>>(
                        stream: eventsModel.getEventsStream(),
                        builder: (context, eventsSnapshot) {
                          return StreamBuilder<List<dynamic>>(
                            stream: eventsModel.getNearbyEventsStream(),
                            builder: (context, nearbySnapshot) {
                              final bool isStreamLoading = 
                                eventsSnapshot.connectionState == ConnectionState.waiting ||
                                nearbySnapshot.connectionState == ConnectionState.waiting;

                              final allEvents = eventsSnapshot.data ?? [];
                              final allNearbyEvents = nearbySnapshot.data ?? [];

                              if (allNearbyEvents.isEmpty) {
                                isNear = 'All Events';
                                _filterEvents(allEvents, allEvents);
                              } else {
                                isNear = 'Events near me';
                                _filterEvents(allEvents, allNearbyEvents);
                              }

                              return Container(
                        width: double.infinity,
                        height: selectedTags.isNotEmpty ? 250 : 230,
                        decoration: BoxDecoration(color: containerColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isNear,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.filter_list, color: Colors.white),
                                        onPressed: () {
                                          _showFilterDialog();
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.grid_view_rounded, color: Colors.white),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => EventsGridView(supabase: Supabase.instance.client)),
                                          );
                                        },
                                      ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                            if (selectedTags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
                                child: SizedBox(
                                  height: 40,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Wrap(
                                        spacing: 4,
                                        children: selectedTags.map((tag) {
                                          return Chip(
                                            label: Text(
                                              tag,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor: theme.primaryColor,
                                            deleteIconColor: Colors.white,
                                            onDeleted: () {
                                              setState(() {
                                                selectedTags.remove(tag);
                                                        if (allNearbyEvents.isEmpty) {
                                                          _filterEvents(allEvents, allEvents);
                                                        } else {
                                                          _filterEvents(allEvents, allNearbyEvents);
                                                        }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                                      child: _buildEventsList(
                                        allNearbyEvents.isEmpty ? filteredEvents : filteredNearbyEvents,
                                        isStreamLoading,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 130,
                        decoration: BoxDecoration(color: containerColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              child: Text(
                                'Users nearby',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future: cLocation != null
                                    ? UserInfo(supabase: Supabase.instance.client).getNearbyUsers(
                                        userId,
                                        cLocation!.latitude,
                                        cLocation!.longitude,
                                        1609.34,
                                      )
                                    : Future.value([]),
                                builder: (context, nearbySnapshot) {
                                  if (!nearbySnapshot.hasData) {
                                    return Center(
                                      child: CircularProgressIndicator(color: theme.primaryColor),
                                    );
                                  }

                                  final nearbyUsers = nearbySnapshot.data!;

                                  if (nearbyUsers.isEmpty) {
                                    return Center(
                                      child: Text(
                                        cLocation == null
                                            ? 'Location access required to see nearby users'
                                            : 'No users nearby',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: nearbyUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = nearbyUsers[index];
                                      final username = user['username'] as String;
                                      final profilePic = user['profile_pic'] as String?;

                                      return GestureDetector(
                                      onTap: () {
                                        showProfileCard(context, user['user_id'], true);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final textPainter = TextPainter(
                                              text: TextSpan(
                                                text: username,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                ),
                                              ),
                                              maxLines: 1,
                                              textDirection: ui.TextDirection.ltr,
                                            )..layout(maxWidth: double.infinity);

                                            final minWidth = 200.0;
                                            final maxWidth = 300.0;
                                            final calculatedWidth = textPainter.width + 100;
                                            final finalWidth = calculatedWidth.clamp(minWidth, maxWidth);

                                            return Container(
                                              width: finalWidth,
                                              decoration: BoxDecoration(
                                                color: cardColor,
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(11.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 50,
                                                          height: 50,
                                                          clipBehavior: Clip.antiAlias,
                                                          decoration: ShapeDecoration(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(9999),
                                                            ),
                                                          ),
                                                          child: (profilePic != null && profilePic.isNotEmpty)
                                                              ? Image.network(
                                                                  profilePic,
                                                                  fit: BoxFit.cover,
                                                                  errorBuilder: (context, error, stackTrace) {
                                                                    return CircleAvatar(
                                                                      backgroundColor: theme.primaryColor,
                                                                      child: Text(
                                                                        username[0].toUpperCase(),
                                                                        style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                )
                                                              : CircleAvatar(
                                                                  backgroundColor: theme.primaryColor,
                                                                  child: Text(
                                                                    username[0].toUpperCase(),
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Tooltip(
                                                            message: username,
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                RichText(
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  text: TextSpan(
                                                                    text: username,
                                                                    style: TextStyle(
                                                                      fontSize: 13,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: textColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                                StreamBuilder<bool>(
                                                                  stream: onlineStatus.subscribeToOnlineStatus(user['user_id']),
                                                                  builder: (context, snapshot) {
                                                                    final isOnline = snapshot.data ?? false;
                                                                    return Text(
                                                                      isOnline ? 'Online' : 'Offline',
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: isOnline ? Colors.green : Colors.grey,
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        FutureBuilder<bool>(
                                                          future: ChatDatabase().inChat(userId, user['user_id'] as String),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.data == true || private == false) {
                                                              return IconButton(
                                                                icon: Icon(
                                                                  Icons.chat_bubble_outline,
                                                                  color: theme.primaryColor,
                                                                ),
                                                                onPressed: () async {
                                                                  final currentUserId =
                                                                      Supabase.instance.client.auth.currentUser?.id;
                                                                  if (currentUserId == null) return;

                                                                  final chatInfo = await ChatDatabase()
                                                                      .getOrCreateChatBetween(
                                                                    currentUserId,
                                                                    user['user_id'] as String,
                                                                  );

                                                                  if (!context.mounted) return;

                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder: (_) => ChatPage(
                                                                        chatId: chatInfo['chat_id'],
                                                                        userId: currentUserId,
                                                                        username: username,
                                                                        profile: profilePic,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            }
                                                            return const SizedBox.shrink();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      );
                                    },
                                  );
                                },
                              ),

                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      displayDiscussions(),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 210,
                        decoration: BoxDecoration(color: containerColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              child: Text(
                                'Attending Events',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: FutureBuilder<List<Map<String, dynamic>>>(
                                future: EventQueries(supabase: Supabase.instance.client).getUserAttendingEvents(userId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator(color: theme.primaryColor));
                                  }
                                  
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Error loading events',
                                        style: TextStyle(color: Colors.white)
                                      )
                                    );
                                  }

                                  final attendingEvents = snapshot.data ?? [];
                                  
                                  if (attendingEvents.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No events to display',
                                        style: TextStyle(color: Colors.white)
                                      )
                                    );
                                  }

                                  return ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: attendingEvents.length,
                                    itemBuilder: (context, index) {
                                      final event = attendingEvents[index];
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return event_popup.EventPopUp(
                                                  event: event,
                                                  onEventDeleted: _onEventDeleted,
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            height: 160,
                                            width: 320,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white.withValues(alpha: 0.2)
                                                  : Colors.black.withValues(alpha: 0.1),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(15),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.3),
                                                        blurRadius: 10,
                                                        offset: Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(15),
                                                    child: Image.network(
                                                      event['image_url'] ?? 'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png',
                                                      height: 160,
                                                      width: 320,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        height: 160,
                                                        width: 320,
                                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                        child: Icon(
                                                          Icons.image_not_supported,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          size: 32,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(15),
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                        colors: [
                                                          Colors.transparent,
                                                          Colors.black.withValues(alpha: 0.7),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  left: 16,
                                                  right: 16,
                                                  bottom: 16,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        event['title'] ?? "No title",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                          shadows: [
                                                            Shadow(
                                                              offset: Offset(1, 1),
                                                              blurRadius: 3,
                                                              color: Colors.black.withValues(alpha: 0.5),
                                                            ),
                                                          ],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.location_on,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              event['location'] ?? "No location",
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 14,
                                                                shadows: [
                                                                  Shadow(
                                                                    offset: Offset(1, 1),
                                                                    blurRadius: 3,
                                                                    color: Colors.black.withValues(alpha: 0.5),
                                                                  ),
                                                                ],
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            '${event_popup.formatTime(event['time_start'] ?? "00:00:00")} - ${event_popup.formatTime(event['time_end'] ?? "00:00:00")}',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 14,
                                                              shadows: [
                                                                Shadow(
                                                                  offset: Offset(1, 1),
                                                                  blurRadius: 3,
                                                                  color: Colors.black.withValues(alpha: 0.5),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (event['days'] != null && (event['days'] as List).isNotEmpty) ...[
                                                        SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.calendar_today,
                                                              size: 16,
                                                              color: Colors.white,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                _formatDays(event['days'] as List),
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 14,
                                                                  shadows: [
                                                                    Shadow(
                                                                      offset: Offset(1, 1),
                                                                      blurRadius: 3,
                                                                      color: Colors.black.withValues(alpha: 0.5),
                                                                    ),
                                                                  ],
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.7),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      _getEventTimeStatus(event),
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
            return AlertDialog(
          title: Text('Filter Events'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Select Tags:'),
                      Wrap(
                  spacing: 8,
                  children: _getSortedTags(filteredEvents).map((tag) {
                          return FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (bool selected) {
                              setState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                        Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedTags.clear();
                    });
                    Navigator.pop(context);
                  },
              child: Text('Clear All'),
                ),
                TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
                  child: Text('Close'),
                ),
              ],
        );
      },
    );
  }

  Widget displayDiscussions() {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      height: selectedCategories.isNotEmpty ? 290 : 230,
      decoration: BoxDecoration(color: containerColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discussions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () {
                        _showDiscussionFilterDialog();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.grid_view_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DiscussionsGridView(supabase: Supabase.instance.client)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (selectedCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: selectedCategories.map((category) {
                        return Chip(
                          label: Text(
                            category,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: theme.primaryColor,
                          deleteIconColor: Colors.white,
                          onDeleted: () {
                            setState(() {
                              selectedCategories.remove(category);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: DiscussionQueries().fetchDiscussionsByCategories(selectedCategories.toList()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading discussions',
                      style: TextStyle(color: Colors.white)
                    )
                  );
                }

                final discussions = snapshot.data ?? [];
                
                if (discussions.isEmpty) {
                  return Center(
                    child: Text(
                      'No discussions to display',
                      style: TextStyle(color: Colors.white)
                    )
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: discussions.length,
                  itemBuilder: (context, index) {
                    final discussion = discussions[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return DiscussionPopUp(
                                discussion: discussion,
                                onDiscussionDeleted: _onEventDeleted,
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 320,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  discussion['title'] ?? "No title",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 15),
                                Row(
                                  children: [
                                    Icon(Icons.people, color: Colors.blueAccent),
                                    SizedBox(width: 4),
                                    FutureBuilder<int>(
                                      future: discussionQueries.getAttendeeCount(discussion['discussion_id']),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
                                        }                                    
                                        return Text(
                                          '${snapshot.data ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: 20),
                                    Icon(Icons.access_time, color: Colors.blueAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      discussion['duration'] != null && discussion['created_at'] != null
                                          ? _getRemainingTime(discussion['created_at'], discussion['duration'])
                                          : _formatDurationFromMinutes(discussion['duration']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: (discussion['categories'] as List<dynamic>?)
                                      ?.take(3)
                                      .map<Widget>((tag) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tag.toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    );
                                  }).toList() ?? [],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscussionFilterDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Filter by Categories'),
              backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preferredCategories.isNotEmpty) ...[
                      Text(
                        'Preferred Categories',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: preferredCategories.map((category) {
                          final isSelected = selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(category, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                            backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                            selectedColor: theme.colorScheme.brightness == Brightness.dark ? Colors.lightBlue : Colors.lightBlueAccent,
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedCategories.add(category);
                                } else {
                                  selectedCategories.remove(category);
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],
                    Text(
                      'All Categories',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: availableCategories.where((category) => !preferredCategories.contains(category)).map((category) {
                        final isSelected = selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                          backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                          selectedColor: theme.colorScheme.brightness == Brightness.dark ? Colors.lightBlue : Colors.lightBlueAccent,
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedCategories.add(category);
                              } else {
                                selectedCategories.remove(category);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCategories.clear();
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Clear Filters'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  String _formatDays(List days) {
    if (days.isEmpty) return '';
    
    // Sort days in order
    final dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    days.sort((a, b) => dayOrder.indexOf(a.toString().toLowerCase()).compareTo(dayOrder.indexOf(b.toString().toLowerCase())));
    
    // Capitalize first letter of each day
    final capitalizedDays = days.map((day) => day.toString().substring(0, 1).toUpperCase() + day.toString().substring(1).toLowerCase()).toList();
    
    if (capitalizedDays.length == 1) {
      return capitalizedDays[0];
    } else if (capitalizedDays.length == 2) {
      return '${capitalizedDays[0]} & ${capitalizedDays[1]}';
    } else {
      return '${capitalizedDays.first} - ${capitalizedDays.last}';
    }
  }

  String _formatDurationFromMinutes(int? minutes) {
    if (minutes == null || minutes == 0) {
      return 'No limit';
    } else if (minutes >= 1440) { // 24 hours or more
      final days = (minutes / 1440).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else if (minutes >= 60) {
      final hours = (minutes / 60).round();
      return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
    } else {
      return '$minutes min';
    }
  }

  String _getRemainingTime(String createdAt, int? durationMinutes) {
    if (durationMinutes == null || durationMinutes == 0) {
      return 'No limit';
    }

    final created = DateTime.parse(createdAt).toUtc();
    final expirationTime = created.add(Duration(minutes: durationMinutes));
    final now = DateTime.now().toUtc();
    final remaining = expirationTime.difference(now);

    if (remaining.isNegative) {
      return 'Expired';
    } else if (remaining.inDays > 0) {
      return '${remaining.inDays}d left';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h left';
    } else {
      return '${remaining.inMinutes}m left';
    }
  }

  void _onEventDeleted() {
    setState(() {
      isEventsLoading = true;
    });
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (userId.isNotEmpty) {
      await onlineStatus.updateOnlineStatus(userId, isOnline);
    }
  }
}


