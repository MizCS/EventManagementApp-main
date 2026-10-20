import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class EventQueries {
  final SupabaseClient supabase;
  final _logger = Logger();

  EventQueries({required this.supabase});

  // Get all users attending a specific event
  Future<List<Map<String, dynamic>>> getEventAttendees(int eventId) async {
    try {
      // First get the attendees array from the event
      final eventResponse = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();
      
      if ((eventResponse['attendees'] as List).isEmpty) {
        return [];
      }

      // Then get the user details for all attendees in a single query
      final attendeesResponse = await supabase
          .from('Users')
          .select('user_id, username, email, profile_pic, bio, joined, private')
          .inFilter('user_id', eventResponse['attendees']);

      return attendeesResponse;
    } catch (e, stackTrace) {
      _logger.e('Error getting event attendees', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Get all events a user is attending
  Future<List<Map<String, dynamic>>> getUserAttendingEvents(String userId) async {
    try {
      final response = await supabase
          .from('Users')
          .select('attending, Events!inner(*)')
          .eq('user_id', userId)
          .single();

      if (response['attending'] == null) {
        return [];
      }

      // Get event details for each event ID
      final events = await Future.wait(
        (response['attending'] as List).map((eventId) async {
          final eventResponse = await supabase
              .from('Events')
              .select('*')
              .eq('event_id', eventId)
              .single();
          return eventResponse;
        }),
      );

      return events;
    } catch (e, stackTrace) {
      _logger.e('Error getting user attending events', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Add a user to an event's attendees
  Future<bool> addUserToEvent(int eventId, String userId) async {
    try {
      // First get the current attendees array
      final eventResponse = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();

      List<String> attendees = List<String>.from(eventResponse['attendees'] ?? []);
      
      // Add the new user if not already present
      if (!attendees.contains(userId)) {
        attendees.add(userId);
        
        // Update the event's attendees array
        await supabase
            .from('Events')
            .update({'attendees': attendees})
            .eq('event_id', eventId);

        // Update the user's attending array
        final userResponse = await supabase
            .from('Users')
            .select('attending')
            .eq('user_id', userId)
            .single();

        List<String> attending = List<String>.from(userResponse['attending'] ?? []);
        if (!attending.contains(eventId.toString())) {
          attending.add(eventId.toString());
          await supabase
              .from('Users')
              .update({'attending': attending})
              .eq('user_id', userId);
        }
      }
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error adding user to event', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Remove a user from an event's attendees
  Future<bool> removeUserFromEvent(int eventId, String userId) async {
    try {
      // First get the current attendees array
      final eventResponse = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();

      List<String> attendees = List<String>.from(eventResponse['attendees'] ?? []);
      
      // Remove the user if present
      if (attendees.contains(userId)) {
        attendees.remove(userId);
        
        // Update the event's attendees array
        await supabase
            .from('Events')
            .update({'attendees': attendees})
            .eq('event_id', eventId);

        // Update the user's attending array
        final userResponse = await supabase
            .from('Users')
            .select('attending')
            .eq('user_id', userId)
            .single();

        List<String> attending = List<String>.from(userResponse['attending'] ?? []);
        if (attending.contains(eventId.toString())) {
          attending.remove(eventId.toString());
          await supabase
              .from('Users')
              .update({'attending': attending})
              .eq('user_id', userId);
        }
      }
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error removing user from event', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Get count of attendees for a specific event
  Future<int> getAttendeeCount(int eventId) async {
    try {
      final response = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();
      
      if (response['attendees'] == null) {
        return 0;
      }

      return (response['attendees'] as List).length;
    } catch (e, stackTrace) {
      _logger.e('Error getting attendee count', error: e, stackTrace: stackTrace);
      return 0;
    }
  }

  // Check if a user is attending an event
  Future<bool> isUserAttendingEvent(int eventId, String userId) async {
    try {
      final eventResponse = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();

      return (eventResponse['attendees'] as List?)?.contains(userId) ?? false;
    } catch (e, stackTrace) {
      _logger.e('Error checking attendance status', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Toggle user's attendance status for an event
  Future<bool> toggleAttendance(int eventId, String userId) async {
    try {
      final isAttending = await isUserAttendingEvent(eventId, userId);
      bool success;

      if (isAttending) {
        success = await removeUserFromEvent(eventId, userId);
      } else {
        success = await addUserToEvent(eventId, userId);
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error toggling attendance', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent(int eventId) async {
    try {
      // First get all attendees of the event
      final eventResponse = await supabase
          .from('Events')
          .select('attendees')
          .eq('event_id', eventId)
          .single();

      List<String> attendees = List<String>.from(eventResponse['attendees'] ?? []);
      
      // Remove the event from each attendee's attending array
      for (String userId in attendees) {
        final userResponse = await supabase
            .from('Users')
            .select('attending')
            .eq('user_id', userId)
            .single();

        List<String> attending = List<String>.from(userResponse['attending'] ?? []);
        if (attending.contains(eventId.toString())) {
          attending.remove(eventId.toString());
          await supabase
              .from('Users')
              .update({'attending': attending})
              .eq('user_id', userId);
        }
      }

      // Finally delete the event
      await supabase
          .from('Events')
          .delete()
          .eq('event_id', eventId);
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error deleting event', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Get all discussions for an event
  Future<List<Map<String, dynamic>>> getDiscussionsForEvent(int eventId) async {
    try {
      final response = await supabase
          .from('Discussions')
          .select('*')
          .eq('event_id', eventId);
      return response;
    } catch (e, stackTrace) {
      _logger.e('Error getting discussions for event', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getDiscussionsForEventStream(String eventId) {
    return supabase
        .from('Discussions')
        .stream(primaryKey: ['discussion_id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .map((events) => events);
  }
} 