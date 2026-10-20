import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
//import 'package:icebreaker/assets/database/events_database.dart';
//import 'package:icebreaker/assets/database/events_map.dart';
import 'package:icebreaker/assets/geoloc.dart';
//import 'package:icebreaker/create_page.dart';
//import 'home_page.dart';
//import 'chat_page.dart';
import 'event_pop_up.dart';
import 'Models/events_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'Models/edit_radius.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart'; // Import intl package for date/time formatting
import 'discussion_pop_up.dart';
import 'assets/database/discussion_queries.dart';

final _logger = Logger();
/* Use this code to call the map page
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => GoogleMapScreen()),
);
*/

class GoogleMapScreen extends StatefulWidget {
  final int? initialEventIndex;

  const GoogleMapScreen({super.key, this.initialEventIndex});

  @override
  GoogleMapScreenState createState() => GoogleMapScreenState();
}

class GoogleMapScreenState extends State<GoogleMapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(26.306188175031327, -98.17458523021418), // Initial center (UTRGV)
    zoom: 18.95,
  );
  //final eventDB = EventsDatabase();
  Set<Marker> _eventMarkers = {};
  final Set<Marker> _postMarkers = {};
  final Set<Marker> _marketMarkers = {};
  Set<Marker> _discussionMarkers = {}; // Add discussion markers set
  late TabController _tabController;
  final eventsModel = EventsModel();
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> filteredEvents = [];
  Set<String> selectedTags = {};
  Set<String> preferredTags = {};
  double userRadius = 1000; // Default radius in meters
  bool isLoading = true;
  bool showAllEvents = true; // Default to showing all events
  LatLng? userLocation;
  bool _isListExpanded = true; // State for list expansion
  bool _showAllDiscussions = true; // State for discussions toggle
  
  
  // Discussion specific state
  final discussionQueries = DiscussionQueries();
  List<Map<String, dynamic>> discussions = [];
  List<Map<String, dynamic>> filteredDiscussions = [];
  Set<String> selectedCategories = {};
  Set<String> preferredCategories = {};

  // Helper function to calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Helper function to format distance
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${(distanceInMeters / 3.281).round()}ft';
    } else {
      return '${(distanceInMeters / 1609.34).toStringAsFixed(1)}mi';
    }
  }

  void _filterEvents() {
    if (!mounted) return;
    if (selectedTags.isEmpty) {
      _fetchEvents(); // Refetch all events without tag filtering
    } else {
      _fetchEvents(); // Refetch events with tag filtering
    }
  }

  Future<void> _fetchEvents() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    
    // Get user's radius setting and preferred tags
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final response = await Supabase.instance.client
          .from('Users')
          .select('radius_meters, pref_tags')
          .eq('user_id', currentUser.id)
          .single();
      if (response['radius_meters'] != null) {
        userRadius = response['radius_meters'].toDouble();
      }
      if (response['pref_tags'] != null) {
        preferredTags = (response['pref_tags'] as List<dynamic>).cast<String>().toSet();
      }
    }

    // Get current location
    userLocation = await GeoLocatorService.getCurrentLatLng();
    
    // Fetch events based on radius and tags
    List<dynamic> response;
    if (showAllEvents) {
      if (selectedTags.isEmpty) {
        response = await eventsModel.fetchEvents();
      } else {
        response = await eventsModel.fetchEventsByTags(selectedTags.toList());
      }
    } else {
      if (selectedTags.isEmpty) {
        response = await eventsModel.fetchNearbyEvents();
      } else {
        response = await eventsModel.fetchNearbyEventsByTags(selectedTags.toList());
      }
    }
    
    // Add distance to each event and sort by distance
    if (userLocation != null) {
      response = response.map((event) {
        final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
        if (eventMap['latitude'] != null && eventMap['longitude'] != null) {
          final eventLocation = LatLng(eventMap['latitude'], eventMap['longitude']);
          final distance = _calculateDistance(userLocation!, eventLocation);
          eventMap['distance'] = distance;
          return eventMap;
        }
        eventMap['distance'] = double.infinity;
        return eventMap; // Events without location will be sorted last
      }).toList();

      // Sort events by distance
      response.sort((a, b) {
        final distanceA = a['distance'] ?? double.infinity;
        final distanceB = b['distance'] ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
    }
    
    // Filter out events whose end_date has definitively passed
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day); 

    response = response.where((event) {
       if (event['end_date'] != null && event['end_date'] is String) {
           try {
               DateTime endDate = DateFormat('yyyy-MM-dd').parse(event['end_date'], true);
               if (endDate.isBefore(today)) {
                   _logger.d("Filtering out event ${event['event_id']} because its end date ($endDate) has passed.");
                   return false; // Exclude the event
               }
           } catch (e) {
               _logger.w("Could not parse end_date '${event['end_date']}' for event ${event['event_id']}, keeping it.", error: e);
           }
       }
       return true; // Keep the event if no end_date or parsing fails or end_date is not past
    }).toList();

    if (!mounted) return;
    setState(() {
      events = List<Map<String, dynamic>>.from(response);
      filteredEvents = List<Map<String, dynamic>>.from(response);
      _updateMarkers();
      isLoading = false;
    });
  }

  // --- Fetch Discussions Logic ---
  Future<void> _fetchDiscussions() async {
    if (!mounted) return;
    setState(() {
      isLoading = true; // Use the general isLoading flag for now
    });

    List<dynamic> response;
    try {
       if (_showAllDiscussions) {
          // TODO: Add category filtering if needed
          // For now, fetching all non-expired discussions
          Stream<List<dynamic>> discussionStream = discussionQueries.fetchDiscussions();
          response = await discussionStream.first; // Get the first list emitted
       } else {
          Stream<List<dynamic>> nearbyDiscussionStream = discussionQueries.fetchNearbyDiscussions();
          response = await nearbyDiscussionStream.first;
       }
    } catch (e) {
       _logger.e("Error fetching discussions: $e");
       response = []; // Set to empty list on error
       if (mounted) {
         setState(() {
           isLoading = false;
         });
       }
       return;
    }

    // Ensure userLocation is available for distance calculation
    userLocation ??= await GeoLocatorService.getCurrentLatLng();

    // Calculate distance for discussions with location
    if (userLocation != null) {
       response = response.map((discussion) {
          final Map<String, dynamic> discMap = Map<String, dynamic>.from(discussion);
          if (discMap['latitude'] != null && discMap['longitude'] != null) {
             try {
                final discLocation = LatLng(discMap['latitude'], discMap['longitude']);
                final distance = _calculateDistance(userLocation!, discLocation);
                discMap['distance'] = distance;
             } catch (e) {
                _logger.w("Error calculating distance for discussion ${discMap['discussion_id']}: $e");
                discMap['distance'] = double.infinity;
             }
          } else {
             discMap['distance'] = double.infinity;
          }
          return discMap;
       }).toList();

       // Sort discussions by distance
       response.sort((a, b) {
          final distanceA = a['distance'] ?? double.infinity;
          final distanceB = b['distance'] ?? double.infinity;
          return distanceA.compareTo(distanceB);
       });
    }

    // Apply category filtering
    if (selectedCategories.isNotEmpty) {
      response = response.where((discussion) {
        final categories = (discussion['categories'] as List<dynamic>?)?.cast<String>() ?? [];
        return categories.any((category) => selectedCategories.contains(category));
      }).toList();
    }

    if (!mounted) return;
    setState(() {
       discussions = List<Map<String, dynamic>>.from(response);
       filteredDiscussions = List<Map<String, dynamic>>.from(response);
       isLoading = false;
    });
    
    // Update markers after setting the discussions data
    await _updateDiscussionMarkers();
 }
 // --- End Fetch Discussions Logic ---

  void _updateMarkers() {
    if (!mounted) return;
    setState(() {
      _eventMarkers = filteredEvents.where((event) {
        // Ensure essential fields are present
        return event['event_id'] != null &&
               event['latitude'] != null &&
               event['longitude'] != null;
      }).map((event) {
        final distance = event['distance'] != null
            ? _formatDistance(event['distance'])
            : 'Distance unknown';

        // --- Logic to determine marker hue based on event status ---
        double markerHue = BitmapDescriptor.hueRed; // Default: Active/Upcoming/Recurring
        bool isInactive = false;

        try {
          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day); // Date part only
          TimeOfDay nowTime = TimeOfDay.fromDateTime(now);

          bool isRecurring = event['recurring_event'] ?? false;
          DateTime? endDate;
          DateTime? startDate;
          TimeOfDay? endTime;

          // Parse end_date (Format: YYYY-MM-DD)
          if (event['end_date'] != null && event['end_date'] is String) {
            endDate = DateFormat('yyyy-MM-dd').parse(event['end_date'], true); // Use UTC
          }

          // Parse start_date (Format: YYYY-MM-DD)
           if (event['start_date'] != null && event['start_date'] is String) {
             startDate = DateFormat('yyyy-MM-dd').parse(event['start_date'], true); // Use UTC
           }

          // Parse time_end (Format: HH:MM:SS, potentially with timezone)
          if (event['time_end'] != null && event['time_end'] is String) {
             try {
                // Try parsing ISO 8601 format first (common from Supabase)
                // Use a fixed date but correct time, convert to local timezone
                final dt = DateTime.parse("2000-01-01T${event['time_end']}Z").toLocal();
                endTime = TimeOfDay.fromDateTime(dt);
             } catch (e) {
                // Fallback for HH:MM:SS format
                final timeParts = event['time_end'].split(':');
                if (timeParts.length >= 2) {
                   endTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
                }
             }
          }

          // Get the days array
          List<String> days = [];
          if (event['days'] != null && event['days'] is List) {
            // Safely cast to List<String>
            try {
               days = (event['days'] as List).map((day) => day.toString()).toList();
            } catch (e) {
               _logger.w("Error casting 'days' array for event ${event['event_id']}: $e");
            }
          }

          String todayWeekdayName = DateFormat('EEEE').format(now); // e.g., "Monday"

          // --- Determine if event is inactive --- 

          // 1. Check if end_date has passed
          if (endDate != null && endDate.isBefore(today)) {
            isInactive = true;
            _logger.d("Event ${event['event_id']}: Past end date ($endDate)");
          }

          // 2. Check if today is NOT an allowed weekday (if days array exists)
          if (!isInactive && days.isNotEmpty && !days.contains(todayWeekdayName)) {
             isInactive = true;
             _logger.d("Event ${event['event_id']}: Not scheduled for today ($todayWeekdayName), allowed days: $days");
          }

          // 3. Check if non-recurring, no specific days, and start_date is not today
          if (!isInactive && !isRecurring && days.isEmpty && startDate != null && !startDate.isAtSameMomentAs(today)) {
             isInactive = true;
             _logger.d("Event ${event['event_id']}: Non-recurring, start date ($startDate) is not today");
          }

          // 4. Check if end time has passed for today (if considered active so far)
          if (!isInactive && endTime != null) {
             bool checkTime = false;
             bool isOnToday = startDate != null && startDate.isAtSameMomentAs(today);

             if (isRecurring) {
                 // For recurring, check time if today is an allowed day OR if no days specified (assume daily)
                 if (days.isEmpty || days.contains(todayWeekdayName)) {
                    checkTime = true;
                 }
             } else { // Not recurring
                 if (days.isNotEmpty && days.contains(todayWeekdayName)) {
                    // Non-recurring with specific days array, check time if today is in it
                    checkTime = true;
                 } else if (days.isEmpty && isOnToday) {
                    // Non-recurring without days array, check time only if start_date is today
                    checkTime = true;
                 }
             }

             if (checkTime) {
                double nowDouble = nowTime.hour + nowTime.minute / 60.0;
                double endDouble = endTime.hour + endTime.minute / 60.0;
                if (nowDouble > endDouble) {
                   isInactive = true;
                   _logger.d("Event ${event['event_id']}: Considered active today, but end time ($endTime) has passed.");
                }
             }
          }

          // --- End of Inactive Check ---

        } catch (e) {
          _logger.e("Error parsing date/time for event ${event['event_id']}: $e");
          // Keep default hue if parsing fails
        }

        if (isInactive) {
          markerHue = BitmapDescriptor.hueAzure; // Use Azure/Blue for inactive events
        }
        // --- End of marker hue logic ---


        return Marker(
          markerId: MarkerId(event['event_id'].toString()),
          position: LatLng(event['latitude'], event['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),// Use determined hue
          infoWindow: InfoWindow(
            title: event['title'] ?? 'No Title',
            snippet: '${event['description'] != null 
                ? '${event['description'].substring(0, event['description'].length > 30 ? 30 : event['description'].length)}${event['description'].length > 30 ? "..." : ""}\n'
                : ''}Distance: $distance',
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => EventPopUp(event: event),
            );
          },
        );
      }).toSet();
    });
  }

  // --- Update Discussion Markers Logic ---
  Future<void> _updateDiscussionMarkers() async {
    if (!mounted) return;
    
    // Group discussions by event_id
    Map<String, List<Map<String, dynamic>>> groupedDiscussions = {};
    for (final discussion in filteredDiscussions) {
      final eventId = discussion['event_id']?.toString() ?? 'no_event';
      if (!groupedDiscussions.containsKey(eventId)) {
        groupedDiscussions[eventId] = [];
      }
      groupedDiscussions[eventId]!.add(discussion);
    }

    final List<Marker> markers = [];
    
    // Process each group
    for (final entry in groupedDiscussions.entries) {
      final discussions = entry.value;
      if (discussions.isEmpty) continue;

      // Use the first discussion's location for the marker
      final firstDiscussion = discussions.first;
      if (firstDiscussion['discussion_id'] != null &&
          firstDiscussion['latitude'] != null &&
          firstDiscussion['longitude'] != null) {
        
        final distance = firstDiscussion['distance'] != null
            ? _formatDistance(firstDiscussion['distance'])
            : 'Distance unknown';

        // Use the custom marker icon
        final customIcon = await MyCustomMarker().createCustomMarkerIcon();

        markers.add(Marker(
          markerId: MarkerId("disc_group_${entry.key}"),
          position: LatLng(firstDiscussion['latitude'], firstDiscussion['longitude']),
          icon: customIcon,
          infoWindow: InfoWindow(
            title: 'Discussions',
            snippet: '${discussions.length} discussions - $distance',
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => GroupedDiscussionsPopUp(
                discussions: discussions,
                theme: Theme.of(context),
              ),
            );
          },
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _discussionMarkers = markers.toSet();
    });
  }

  Set<String> _getAllTags() {
    final Set<String> allTags = {};
    for (final event in events) {
      final tags = (event['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      allTags.addAll(tags);
    }
    return allTags;
  }

  List<String> _getSortedTags() {
    final allTags = _getAllTags();
    return allTags.where((tag) => !preferredTags.contains(tag)).toList();
  }

  // Map customization settings
  
  Set<Marker> get _currentMarkers {
    switch (_tabController.index) {
      case 0:
        return _eventMarkers;
      case 1:
        return _discussionMarkers; // Return discussion markers for tab 1
      case 2:
        return _marketMarkers;
      default:
        return {};
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update markers when tab changes
    });
    _fetchEvents().then((_) {
      // After events are loaded, center on initial event if specified
      if (widget.initialEventIndex != null && _mapController != null) {
        _centerOnInitialEvent();
      }
    });
    _fetchDiscussions();
    _loadUserPreferences();
  }

  Future<void> _centerOnInitialEvent() async {
    if (_mapController == null) return;

    final event = events.firstWhere(
      (e) => e['event_id'] == widget.initialEventIndex,
      orElse: () => {'event_id': -1},
    );
    
    if (event['event_id'] != -1 && event['latitude'] != null && event['longitude'] != null) {
      try {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(event['latitude'], event['longitude']),
            16.0,
          ),
        );
      } catch (e) {
        _logger.e('Error animating camera: $e');
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final response = await Supabase.instance.client
          .from('Users')
          .select('pref_cat')
          .eq('user_id', currentUser.id)
          .single();
      if (response['pref_cat'] != null) {
        setState(() {
          preferredCategories = (response['pref_cat'] as List<dynamic>).cast<String>().toSet();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Filter Events'),
              backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preferredTags.isNotEmpty) ...[
                      Text(
                        'Preferred Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: preferredTags.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                            backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                            selectedColor: theme.colorScheme.brightness == Brightness.dark ? Colors.lightBlue : Colors.lightBlueAccent,
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                              setState(() {
                                _filterEvents();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],
                    Text(
                      'All Tags',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: _getSortedTags().map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag, style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                          backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                          selectedColor: theme.colorScheme.brightness == Brightness.dark ? Colors.lightBlue : Colors.lightBlueAccent,
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                            setState(() {
                              _filterEvents();
                            });
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
                      _filterEvents();
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

  void _showDiscussionFilterDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Filter Discussions'),
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
                              setState(() {
                                _fetchDiscussions();
                              });
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
                      children: _getAllCategories().where((cat) => !preferredCategories.contains(cat)).map((category) {
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
                            setState(() {
                              _fetchDiscussions();
                            });
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
                      _fetchDiscussions();
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

  Set<String> _getAllCategories() {
    final Set<String> allCategories = {};
    for (final discussion in discussions) {
      final categories = (discussion['categories'] as List<dynamic>?)?.cast<String>() ?? [];
      allCategories.addAll(categories);
    }
    return allCategories;
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    // Define heights for expanded and compact states
    final screenHeight = MediaQuery.of(context).size.height;
    final double expandedHeight = screenHeight * 0.6; // 40% of screen height
    final double compactHeight = kToolbarHeight + 22; // Height for tab bar + toggle button

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            // flex: 2, // Removed flex to allow map to take remaining space
            child: Stack(
              children: [
                // if (isLoading)
                //   Center(child: CircularProgressIndicator(color: theme.primaryColor))
                // else if (filteredEvents.isEmpty && !showAllEvents)
                //   Center(
                //     child: Column(
                //       mainAxisAlignment: MainAxisAlignment.center,
                //       children: [
                //         Icon(Icons.event_busy, size: 48, color: textColor),
                //         SizedBox(height: 16),
                //         Text(
                //           'No events found nearby',
                //           style: TextStyle(
                //             fontSize: 18,
                //             fontWeight: FontWeight.bold,
                //             color: textColor,
                //           ),
                //         ),
                //         SizedBox(height: 8),
                //       ],
                //     ),
                //   )
                // else
                  Builder(
                    builder: (context) {
                      return GoogleMap(
                        initialCameraPosition: _initialPosition,
                        markers: _currentMarkers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        padding: EdgeInsets.only(top: 100, right: 10),
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                          // If events are already loaded, center on initial event
                          if (events.isNotEmpty && widget.initialEventIndex != null) {
                            _centerOnInitialEvent();
                          }
                        },
                      );
                    }
                  ),
                Positioned(
                  top: 40,
                  left: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: iconColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        
                        IconButton(
                          icon: Icon(Icons.radar, color: iconColor),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditRadius()), // Added const
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.my_location, color: iconColor),
                      onPressed: () => GeoLocatorService.getCurrentLocation(context, _mapController),
                      tooltip: 'Get Location',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Animated container for the bottom list/tabs
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isListExpanded ? expandedHeight : compactHeight,
            color: backgroundColor,
            child: Column(
              children: [
                // Toggle Button/Handle
                Material( // Added Material for InkWell splash effect
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isListExpanded = !_isListExpanded;
                      });
                    },
                    child: Container(
                      height: 30, // Height for the toggle area
                      alignment: Alignment.center,
                      child: Icon(
                        _isListExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
                // TabBar and TabBarView (wrapped in Expanded to fill AnimatedContainer)
                Expanded(
                  child: TabBarWidget(
                    mapController: _mapController,
                    tabController: _tabController,
                    events: filteredEvents,
                    discussions: filteredDiscussions,
                    theme: theme,
                    showAllEvents: showAllEvents,
                    onShowAllEventsChanged: (value) {
                      setState(() {
                        showAllEvents = value;
                      });
                      _fetchEvents();
                    },
                    showAllDiscussions: _showAllDiscussions,
                    onShowAllDiscussionsChanged: (value) {
                      setState(() {
                        _showAllDiscussions = value;
                      });
                      _fetchDiscussions();
                      _logger.i("Discussions toggle changed to: $value");
                    },
                    onShowFilterDialog: _showFilterDialog,
                    iconColor: iconColor,
                    selectedTags: selectedTags,
                    onRemoveTag: (tag) {
                      setState(() {
                        selectedTags.remove(tag);
                        _filterEvents();
                      });
                    },
                    discussionQueries: discussionQueries,
                    selectedCategories: selectedCategories,
                    onRemoveCategory: (category) {
                      setState(() {
                        selectedCategories.remove(category);
                        _fetchDiscussions();
                      });
                    },
                    onShowDiscussionFilterDialog: _showDiscussionFilterDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TabBarWidget extends StatelessWidget {
  final GoogleMapController? mapController;
  final TabController tabController;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> discussions;
  final ThemeData theme;
  final bool showAllEvents;
  final Function(bool) onShowAllEventsChanged;
  final bool showAllDiscussions;
  final Function(bool) onShowAllDiscussionsChanged;
  final VoidCallback onShowFilterDialog;
  final Color iconColor;
  final Set<String> selectedTags;
  final Function(String) onRemoveTag;
  final DiscussionQueries discussionQueries;
  final Set<String> selectedCategories;
  final Function(String) onRemoveCategory;
  final VoidCallback onShowDiscussionFilterDialog;

  const TabBarWidget({
    super.key,
    required this.mapController,
    required this.tabController,
    required this.events,
    required this.discussions,
    required this.theme,
    required this.showAllEvents,
    required this.onShowAllEventsChanged,
    required this.showAllDiscussions,
    required this.onShowAllDiscussionsChanged,
    required this.onShowFilterDialog,
    required this.iconColor,
    required this.selectedTags,
    required this.onRemoveTag,
    required this.discussionQueries,
    required this.selectedCategories,
    required this.onRemoveCategory,
    required this.onShowDiscussionFilterDialog,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey;

    return Column(
      children: [
        
        TabBar(
          controller: tabController,
          labelColor: textColor,
          unselectedLabelColor: unselectedColor,
          indicatorColor: theme.primaryColor,
          tabs: [
            Tab(child:Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tabController.index == 0)
                    Switch(
                      value: showAllEvents,
                      onChanged: onShowAllEventsChanged,
                      activeColor: theme.primaryColor,
                      inactiveThumbColor: theme.primaryColor.withValues(alpha:0.6),
                      inactiveTrackColor: Colors.grey,
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Events', style: TextStyle(fontSize: 12, color: textColor)),
                      Text(showAllEvents ? 'All' : 'Nearby', style: TextStyle(fontSize: 8, color: textColor)),
                    ],
                  ),
                ],
              ),),
            Tab(child:Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (tabController.index == 1)
                    Switch(
                      value: showAllDiscussions,
                      onChanged: onShowAllDiscussionsChanged,
                      activeColor: theme.primaryColor,
                      inactiveThumbColor: theme.primaryColor.withValues(alpha:0.6),
                      inactiveTrackColor: Colors.grey,
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Discussions', style: TextStyle(fontSize: 12, color: textColor)),
                      Text(showAllDiscussions ? 'All' : 'Nearby', style: TextStyle(fontSize: 8, color: textColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              EventsListWidget(
                mapController: mapController,
                events: events,
                theme: theme,
                showAllEvents: showAllEvents,
                onShowFilterDialog: onShowFilterDialog,
                iconColor: iconColor,
                selectedTags: selectedTags,
                onRemoveTag: onRemoveTag,
              ),
              DiscussionsListWidget(
                mapController: mapController,
                discussions: discussions,
                theme: theme,
                onShowFilterDialog: onShowDiscussionFilterDialog,
                iconColor: iconColor,
                selectedTags: selectedTags,
                onRemoveTag: onRemoveTag,
                discussionQueries: discussionQueries,
                selectedCategories: selectedCategories,
                onRemoveCategory: onRemoveCategory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EventsListWidget extends StatelessWidget {
  final GoogleMapController? mapController;
  final List<Map<String, dynamic>> events;
  final ThemeData theme;
  final bool showAllEvents;
  final VoidCallback onShowFilterDialog;
  final Color iconColor;
  final Set<String> selectedTags;
  final Function(String) onRemoveTag;

  const EventsListWidget({
    super.key,
    this.mapController,
    required this.events,
    required this.theme,
    required this.showAllEvents,
    required this.onShowFilterDialog,
    required this.iconColor,
    required this.selectedTags,
    required this.onRemoveTag,
  });

  // Helper to format time (consider moving to a utility file if used elsewhere)
  String _formatTime(String time24hr) {
     try {
       final dt = DateTime.parse("2000-01-01T${time24hr}Z").toLocal();
       return DateFormat.jm().format(dt);
     } catch (e) {
       try {
          final timeParts = time24hr.split(':');
          if (timeParts.length >= 2) {
            final dateTime = DateTime(2000, 1, 1, int.parse(timeParts[0]), int.parse(timeParts[1]));
            return DateFormat.jm().format(dateTime);
          }
       } catch (fallbackError) {
            _logger.e("Error formatting time '$time24hr' after fallback: $fallbackError");
       }
       return 'Invalid Time';
     }
  }

  // Helper function to determine event status string
  String _getEventStatus(Map<String, dynamic> event) {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      TimeOfDay nowTime = TimeOfDay.fromDateTime(now);
      String todayWeekdayName = DateFormat('EEEE').format(now); // e.g., "Monday"

      // --- Parse event details ---
      bool isRecurring = event['recurring_event'] ?? false;
      DateTime? startDate;
      DateTime? endDate;
      TimeOfDay? startTime;
      TimeOfDay? endTime;
      List<String> days = [];

      if (event['start_date'] != null && event['start_date'] is String) {
        try { startDate = DateFormat('yyyy-MM-dd').parse(event['start_date'], true); } catch (_) {}
      }
      if (event['end_date'] != null && event['end_date'] is String) {
        try { endDate = DateFormat('yyyy-MM-dd').parse(event['end_date'], true); } catch (_) {}
      }
      if (event['time_start'] != null && event['time_start'] is String) {
         try {
           final dt = DateTime.parse("2000-01-01T${event['time_start']}Z").toLocal();
           startTime = TimeOfDay.fromDateTime(dt);
         } catch (e) {
           try {
              final timeParts = event['time_start'].split(':');
              if (timeParts.length >= 2) {
                 startTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
              }
           } catch(_){}
         }
      }
       if (event['time_end'] != null && event['time_end'] is String) {
         try {
           final dt = DateTime.parse("2000-01-01T${event['time_end']}Z").toLocal();
           endTime = TimeOfDay.fromDateTime(dt);
         } catch (e) {
            try {
              final timeParts = event['time_end'].split(':');
              if (timeParts.length >= 2) {
                 endTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
              }
            } catch(_){}
         }
      }
      if (event['days'] != null && event['days'] is List) {
          try {
             days = (event['days'] as List).map((day) => day.toString()).toList();
          } catch (e) {
             _logger.w("Error casting 'days' array for event ${event['event_id']}: $e");
          }
      }

      // --- Determine Status --- 
      bool eventIsToday = false;
      bool eventIsCurrentlyHappening = false;

      // 1. Check if event is scheduled for today
      if (isRecurring) {
          if (days.isEmpty || days.contains(todayWeekdayName)) {
             // Recurring events are considered "today" if no days are specified (assume daily) 
             // or if today is one of the specified recurring days.
             // We also need to ensure we are within the start/end date range if provided.
             bool withinDateRange = true;
             if (startDate != null && today.isBefore(startDate)) withinDateRange = false;
             // End date check already happened in _fetchEvents, but double-check won't hurt
             if (endDate != null && today.isAfter(endDate)) withinDateRange = false; 
             
             if (withinDateRange) {
                eventIsToday = true;
             }
          }
      } else { // Not recurring
          if (days.isNotEmpty && days.contains(todayWeekdayName)) {
              // Non-recurring but happens on specific days (like a weekly meeting)
              bool withinDateRange = true;
              if (startDate != null && today.isBefore(startDate)) withinDateRange = false;
              if (endDate != null && today.isAfter(endDate)) withinDateRange = false; 
              if (withinDateRange) {
                  eventIsToday = true;
              }
          } else if (days.isEmpty && startDate != null && startDate.isAtSameMomentAs(today)) {
              // Standard non-recurring event happening today based on start_date
              eventIsToday = true;
          }
      }

      // 2. If it's today, check if it's currently happening
      if (eventIsToday && startTime != null && endTime != null) {
          double startDouble = startTime.hour + startTime.minute / 60.0;
          double endDouble = endTime.hour + endTime.minute / 60.0;
          double nowDouble = nowTime.hour + nowTime.minute / 60.0;

          if (nowDouble >= startDouble && nowDouble < endDouble) {
              eventIsCurrentlyHappening = true;
          }
      }

      // --- Return Status String ---
      if (eventIsCurrentlyHappening) {
          return "Ongoing Now";
      } else if (eventIsToday) {
          String timeInfo = "";
          if(startTime != null) timeInfo = " starting ${_formatTime(event['time_start'])}";
          return "Today$timeInfo";
      } else {
           // Default: show distance if not happening today or now
           final distance = event['distance'];
           if (distance != null && distance != double.infinity) {
              if (distance < 1000) {
                 return '${(distance / 3.281).round()}ft away';
              } else {
                 return '${(distance / 1609.34).toStringAsFixed(1)}mi away';
              }
           } else {
              return 'Distance unknown';
           }
      }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    if (events.isEmpty && !showAllEvents){
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: textColor),
            SizedBox(height: 16),
            Text(
              'No events found nearby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 5),
          height: 40,
          child: Row(
            children: [
              IconButton(
              icon: Icon(Icons.filter_list, color: iconColor,),
              onPressed: onShowFilterDialog,
            ),
            if (selectedTags.isNotEmpty)
              Expanded(
                child: Flexible(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0), // Add some space
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedTags.map((tag) {
                            return Chip(
                              label: Text(tag, style: TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: theme.primaryColor,
                              deleteIcon: Icon(Icons.close, size: 12, color: Colors.white),
                              onDeleted: () => onRemoveTag(tag), // Use passed callback
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final String status = _getEventStatus(event); // Calculate status
              return Card(
                color: cardColor,
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: textColor),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event['title'] ?? 'No Title',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(
                        event['description'] ?? 'No Description',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Location: ${event['location'] ?? 'No Location'}',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        status, // Display calculated status
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return EventPopUp(event: event);
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text("Open"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (event['latitude'] != null && event['longitude'] != null && mapController != null) {
                                Future.delayed(Duration(milliseconds: 500), () async {
                                  try {
                                    await mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(event['latitude'], event['longitude']),
                                        18.95,
                                      ),
                                    );
                                  } catch (e) {
                                    _logger.e('Error animating camera from event list: $e');
                                  }
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text("See on Map"),
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
      ],
    );
  }
}

// *** NEW WIDGET: DiscussionsListWidget ***
class DiscussionsListWidget extends StatelessWidget {
  final GoogleMapController? mapController;
  final List<Map<String, dynamic>> discussions;
  final ThemeData theme;
  final VoidCallback onShowFilterDialog;
  final Color iconColor;
  final Function(String) onRemoveTag;
  final Set<String> selectedTags;
  final DiscussionQueries discussionQueries;
  final Set<String> selectedCategories;
  final Function(String) onRemoveCategory;

  const DiscussionsListWidget({
    super.key,
    this.mapController,
    required this.discussions,
    required this.theme,
    required this.onShowFilterDialog,
    required this.iconColor,
    required this.onRemoveTag,
    required this.selectedTags,
    required this.discussionQueries,
    required this.selectedCategories,
    required this.onRemoveCategory,
  });

  String _getDiscussionStatus(Map<String, dynamic> discussion) {
    // For discussions, status is primarily distance-based for now
    final distance = discussion['distance'];
    if (distance != null && distance != double.infinity) {
      if (distance < 1000) {
        return '${(distance / 3.281).round()}ft away';
      } else {
        return '${(distance / 1609.34).toStringAsFixed(1)}mi away';
      }
    } else if (discussion['latitude'] != null && discussion['longitude'] != null) {
        return 'Location available'; // Has location but distance couldn't be calculated
    } else {
        return 'No location';
    }
  }

  Future<int> getAttendeeCount(String discussionId) async {
    try {
      final count = await discussionQueries.getAttendeeCount(discussionId);
      return count;
    } catch (e) {
      _logger.e('Error getting attendee count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    if (discussions.isEmpty) {
      // TODO: Add a specific message for discussions if needed
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: textColor),
            SizedBox(height: 16),
            Text(
              'No discussions found nearby', // Generic message for now
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 5),
          height: 40,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.filter_list, color: iconColor),
                onPressed: onShowFilterDialog,
              ),
              if (selectedCategories.isNotEmpty)
                Expanded(
                  child: Flexible(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedCategories.map((category) {
                              return Chip(
                                label: Text(category, style: TextStyle(color: Colors.white, fontSize: 12)),
                                backgroundColor: theme.primaryColor,
                                deleteIcon: Icon(Icons.close, size: 12, color: Colors.white),
                                onDeleted: () => onRemoveCategory(category),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: discussions.length,
            itemBuilder: (context, index) {
              final discussion = discussions[index];
              final String status = _getDiscussionStatus(discussion);
              
              return FutureBuilder<int>(
                future: getAttendeeCount(discussion['discussion_id']),
                builder: (context, snapshot) {
                  final participantCount = snapshot.data ?? 0;
                  
                  return Card(
                    color: cardColor,
                    margin: EdgeInsets.all(10),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.topic_outlined, color: textColor),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  discussion['title'] ?? 'No Title',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              // Participant count
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group_outlined, size: 16, color: textColor.withOpacity(0.7)),
                                  SizedBox(width: 4),
                                  Text(
                                    participantCount.toString(),
                                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
                                  ),
                                ],
                              )
                            ],
                          ),
                          SizedBox(height: 5),
                          if (discussion['description'] != null)
                            Text(
                              discussion['description'],
                              style: TextStyle(color: textColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          SizedBox(height: 5),
                          // Display Categories (if available)
                          if (discussion['categories'] != null && (discussion['categories'] as List).isNotEmpty)
                             Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: (discussion['categories'] as List).map((category) {
                                  return Chip(
                                    label: Text(category.toString(), style: TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: theme.primaryColor.withOpacity(0.8),
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                             ),

                          SizedBox(height: 8),
                          Text(
                            status, // Display calculated status (distance)
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  // TODO: Implement navigation/popup for discussion details
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      // Replace with actual discussion detail view/popup
                                      return DiscussionPopUp(discussion: discussion);
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text("View"),
                              ),
                              ElevatedButton(
                                onPressed: (discussion['latitude'] != null && discussion['longitude'] != null && mapController != null)
                                  ? () {
                                      mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(discussion['latitude'], discussion['longitude']),
                                          18.95,
                                        ),
                                      );
                                    }
                                  : null, // Disable if no location or controller
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey,
                                ),
                                child: Text("See on Map"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class GroupedDiscussionsPopUp extends StatelessWidget {
  final List<Map<String, dynamic>> discussions;
  final ThemeData theme;

  const GroupedDiscussionsPopUp({
    super.key,
    required this.discussions,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    return Dialog(
      backgroundColor: cardColor,
      child: Container(
        width: double.maxFinite,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discussions at this location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: discussions.length,
                itemBuilder: (context, index) {
                  final discussion = discussions[index];
                  return Card(
                    color: cardColor,
                    child: ListTile(
                      title: Text(
                        discussion['title'] ?? 'No Title',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        discussion['description'] ?? 'No Description',
                        style: TextStyle(color: textColor.withValues(alpha:0.7)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, color: textColor),
                      onTap: () {
                        Navigator.pop(context); // Close the group popup
                        showDialog(
                          context: context,
                          builder: (context) => DiscussionPopUp(discussion: discussion),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCustomMarker {
  Future<BitmapDescriptor> createCustomMarkerIcon() async {
    return await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(60, 50)),
      'assets/images/Ib_discussion_marker.png',
    );
  }
}
