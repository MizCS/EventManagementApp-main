import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:icebreaker/assets/geoloc.dart';
//import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventsModel {
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


  Future<List<dynamic>> fetchEvents() async {
    final response = await Supabase.instance.client
        .from('Events')
        .select();
    return response;
  }

  Future<List<dynamic>> fetchNearbyEvents() async {
    final currentLocation = await GeoLocatorService.getCurrentLatLng();
    if (currentLocation == null) {
      return [];
    }

    // Get user's radius setting
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      return [];
    }

    final userResponse = await Supabase.instance.client
        .from('Users')
        .select('radius_meters')
        .eq('user_id', currentUser.id)
        .single();

    final radius = userResponse['radius_meters']?.toDouble() ?? 1000.0;

    // Get today's date and day of week
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    //final currentDayOfWeek = now.weekday;
    //final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    //final currentDayName = dayNames[currentDayOfWeek - 1];

    // Fetch events and filter by date
    final response = await Supabase.instance.client
        .from('Events')
        .select()
        //.or('start_date.eq.$today,days.cs.{$currentDayName}') // Event starts today OR is recurring on current day
        //.lte('start_date', today) // Event hasn't ended yet
        .gte('end_date', today);

    // Filter events by distance
    return response.where((event) {
      if (event['latitude'] == null || event['longitude'] == null) {
        return false;
      }
      final eventLocation = LatLng(event['latitude'], event['longitude']);
      final distance = _calculateDistance(currentLocation, eventLocation);
      return distance <= radius;
    }).toList();
  }

  Future<List<dynamic>> fetchEventsByTags(List<String> tags) async {
    if (tags.isEmpty) {
      return fetchEvents();
    }

    // Use OR logic by checking if any of the tags match
    final response = await Supabase.instance.client
        .from('Events')
        .select()
        .or(tags.map((tag) => 'tags.cs.{$tag}').join(','));
    return response;
  }

  Future<List<dynamic>> fetchNearbyEventsByTags(List<String> tags) async {
    final currentLocation = await GeoLocatorService.getCurrentLatLng();
    if (currentLocation == null) {
      return [];
    }

    // Get user's radius setting
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      return [];
    }

    final userResponse = await Supabase.instance.client
        .from('Users')
        .select('radius_meters')
        .eq('user_id', currentUser.id)
        .single();

    final radius = userResponse['radius_meters']?.toDouble() ?? 1000.0;

    // Get today's date and day of week
    //final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // final currentDayOfWeek = now.weekday;
    // final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    // final currentDayName = dayNames[currentDayOfWeek - 1];

    if (tags.isEmpty) {
      return fetchNearbyEvents();
    }

    // Fetch events with tags and filter by date
    final response = await Supabase.instance.client
        .from('Events')
        .select()
        .or(tags.map((tag) => 'tags.cs.{$tag}').join(','))
        //.or('start_date.eq.$today,days.cs.{$currentDayName}') // Event starts today OR is recurring on current day
        //.lte('start_date', today) // Event hasn't ended yet
        .gte('end_date', today);

    // Filter events by distance
    return response.where((event) {
      if (event['latitude'] == null || event['longitude'] == null) {
        return false;
      }
      final eventLocation = LatLng(event['latitude'], event['longitude']);
      final distance = _calculateDistance(currentLocation, eventLocation);
      return distance <= radius;
    }).toList();
  }

  Stream<List<dynamic>> getEventsStream() async* {
    try {
      await for (final events in Supabase.instance.client
          .from('Events')
          .stream(primaryKey: ['event_id'])
          .handleError((error) {
            print('Error in events stream: $error');
            return [];
          })) {
        yield events;
      }
    } catch (e) {
      print('Error establishing events stream: $e');
      yield [];
      
      // Add a delay before retrying
      await Future.delayed(Duration(seconds: 2));
      yield* getEventsStream(); // Retry the stream
    }
  }

  Stream<List<dynamic>> getNearbyEventsStream() async* {
    try {
      final currentLocation = await GeoLocatorService.getCurrentLatLng();
      if (currentLocation == null) {
        yield [];
        return;
      }

      // Get user's radius setting
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        yield [];
        return;
      }

      final userResponse = await Supabase.instance.client
          .from('Users')
          .select('radius_meters')
          .eq('user_id', currentUser.id)
          .single();

      final radius = userResponse['radius_meters']?.toDouble() ?? 1000.0;

      // Get today's date and day of week
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final currentDayOfWeek = now.weekday;
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final currentDayName = dayNames[currentDayOfWeek - 1];

      await for (final events in Supabase.instance.client
          .from('Events')
          .stream(primaryKey: ['event_id'])
          .handleError((error) {
            print('Error in nearby events stream: $error');
            return [];
          })) {
        
        final filteredEvents = events.where((event) {
          try {
            // Check if event is valid for today
            final eventStartDate = event['start_date'] as String?;
            final eventEndDate = event['end_date'] as String?;
            final eventDays = (event['days'] as List<dynamic>?)?.cast<String>() ?? [];
            
            if (eventStartDate == null || eventEndDate == null) {
              return false;
            }

            // Check if event is within date range
            if (eventStartDate.compareTo(today) > 0 || eventEndDate.compareTo(today) < 0) {
              return false;
            }

            // Check if event is recurring on current day
            if (!eventDays.contains(currentDayName) && eventStartDate != today) {
              return false;
            }

            // Check if event is within radius
            if (event['latitude'] == null || event['longitude'] == null) {
              return false;
            }
            final eventLocation = LatLng(event['latitude'], event['longitude']);
            final distance = _calculateDistance(currentLocation, eventLocation);
            return distance <= radius;
          } catch (e) {
            print('Error filtering event: $e');
            return false;
          }
        }).toList();

        yield filteredEvents;
      }
    } catch (e) {
      print('Error establishing nearby events stream: $e');
      yield [];
      
      // Add a delay before retrying
      await Future.delayed(Duration(seconds: 2));
      yield* getNearbyEventsStream(); // Retry the stream
    }
  }
}
