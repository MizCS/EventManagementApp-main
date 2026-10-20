import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:icebreaker/assets/geoloc.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'disc_database.dart';

class DiscussionQueries {
  //final SupabaseClient supabase;
  final Logger _logger = Logger();
  final DiscDatabase discDB = DiscDatabase();


  Future<bool> isUserAttendingDiscussion(String discussionId, String userId) async {
    try {
      //check if the user is in the participants array
       final result = await Supabase.instance.client
        .from('Disc_participants')
        .select('user_id')
        .eq('discussion_id', discussionId)
        .eq('user_id', userId)
        .maybeSingle();

      return result != null;
      
    } catch (e) {
      _logger.e('Error checking user attendance: $e');
      return false;
    }
  }
                                                                                                                                                                                                                                                                                                                                                                                                                   
  Future<bool> toggleAttendance(String discussionId, String userId) async {
    try {
      final isAttending = await isUserAttendingDiscussion(discussionId, userId);
      bool success;

      if (isAttending) {
        success = await discDB.removeUserFromDiscussion(discussionId, userId);
      } else {
        success = await discDB.addUserToDiscussion(discussionId, userId);
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error toggling attendance', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> deleteDiscussion(String discussionId) async {
    try {
      // Delete related messages first
      await Supabase.instance.client
          .from('Disc_msg')
          .delete()
          .eq('discussion_id', discussionId);
          
      // Delete participants
      await Supabase.instance.client
          .from('Disc_participants')
          .delete()
          .eq('discussion_id', discussionId);
          
      // Finally delete the discussion
      await Supabase.instance.client
          .from('Discussions')
          .delete()
          .eq('discussion_id', discussionId);
    } catch (e) {
      _logger.e('Error deleting discussion: $e');
      throw Exception('Failed to delete discussion: $e');
    }
  }

  Future<int> getAttendeeCount(String discussionId) async {
    try {
      final response = await Supabase.instance.client
          .from('Disc_participants')
          .select()
          .eq('discussion_id', discussionId);
      return response.length;
    } catch (e) {
      _logger.e('Error getting attendee count: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getDiscussionAttendees(String discussionId) async {
    try {
      final response = await Supabase.instance.client
          .from('Disc_participants')
          .select('*, Users:user_id(username, profile_pic, private)')
          .eq('discussion_id', discussionId);
      
      // Ensure private is properly cast to boolean
      return List<Map<String, dynamic>>.from(response).map((attendee) {
        if (attendee['Users'] != null) {
          attendee['Users']['private'] = attendee['Users']['private'] == true;
        }
        return attendee;
      }).toList();
    } catch (e) {
      _logger.e('Error getting discussion attendees: $e');
      return [];
    }
  }

  Stream<List<dynamic>> fetchDiscussions() async* {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    try {
      // Get all discussions
      final discussions = await Supabase.instance.client
          .from('Discussions')
          .select()
          .order('created_at', ascending: false);

      // Get all events with their attendees
      final events = await Supabase.instance.client
          .from('Events')
          .select('event_id, attendees');

      // Create a map of event IDs to their attendees
      final eventAttendees = <String, Set<String>>{};
      for (final event in events) {
        try {
          final eventId = event['event_id'];
          final attendees = event['attendees'];
          
          if (eventId != null && attendees != null) {
            if (attendees is List) {
              eventAttendees[eventId.toString()] = attendees
                  .where((a) => a is Map && a['user_id'] != null)
                  .map((a) => a['user_id'].toString())
                  .toSet();
            } else {
              _logger.w('Attendees is not a list for event $eventId: $attendees');
            }
          }
        } catch (e) {
          _logger.e('Error processing event: $e');
          continue;
        }
      }
      
      // Filter discussions
      yield discussions.where((discussion) {
        // Check duration/expiration
        final durationMinutes = discussion['duration_minutes'];
        if (durationMinutes == null || durationMinutes == 0) {
          return true; // Keep discussions with no duration
        }
        
        final createdAt = DateTime.parse(discussion['created_at']);
        final now = DateTime.now();
        
        // Calculate expiration time based on duration in minutes
        final expirationTime = createdAt.add(Duration(minutes: durationMinutes));
        if (!now.isBefore(expirationTime)) {
          return false; // Discussion has expired
        }

        // Check if discussion is linked to an event
        final eventId = discussion['event_id'];
        if (eventId != null) {
          final attendees = eventAttendees[eventId.toString()] ?? {};
          return attendees.contains(currentUser.id); // Only show if user is in attendees
        }

        return true; // Show discussions not linked to events
      }).toList();
    } catch (e) {
      _logger.e('Error in fetchDiscussions: $e');
      yield [];
    }
  }

  Stream<List<dynamic>> fetchNearbyDiscussions() async* {
    final currentLocation = await GeoLocatorService.getCurrentLatLng();
    if (currentLocation == null) {
      yield [];
    }

    // Get user's radius setting
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      yield [];
    }

    final userResponse = await Supabase.instance.client
        .from('Users')
        .select('radius_meters')
        .eq('user_id', currentUser?.id ?? '')
        .single();

    final radius = userResponse['radius_meters']?.toDouble() ?? 1000.0;

    final discussions = await Supabase.instance.client
        .from('Discussions')
        .select()
        .order('created_at', ascending: false);

    yield discussions.where((discussion) {
      if (discussion['latitude'] == null || discussion['longitude'] == null) {
        return false;
      }
      final discussionLocation = LatLng(
        discussion['latitude'] as double,
        discussion['longitude'] as double
      );
      final distance = _calculateDistance(currentLocation!, discussionLocation);
      return distance <= radius;
    }).toList();
  }

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

  Stream<List<dynamic>> fetchDiscussionsByCategories(List<String> categories) async* {
    if (categories.isEmpty) {
      yield* fetchDiscussions();
    }
    final response = await Supabase.instance.client
        .from('Discussions')
        .select()
        .contains('categories', categories)
        .order('created_at', ascending: false);
    
    // Filter out expired discussions
    yield response.where((discussion) {
      final durationMinutes = discussion['duration_minutes'];
      if (durationMinutes == null || durationMinutes == 0) {
        return true; // Keep discussions with no duration
      }
      
      final createdAt = DateTime.parse(discussion['created_at']);
      final now = DateTime.now();
      
      // Calculate expiration time based on duration in minutes
      final expirationTime = createdAt.add(Duration(minutes: durationMinutes));
      return now.isBefore(expirationTime);
    }).toList();
  }
}