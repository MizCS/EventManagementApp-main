//import 'dart:ffi';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icebreaker/assets/database/events_map.dart';

class EventsDatabase {
  final database = Supabase.instance.client.from('Events');
  //Creating Events
  Future createEvent(Event newEvent) async {
    await database.insert(newEvent.toMap());
  }
  //Read Events
  Stream<List<Event>> getEventsStream() {
    return database.stream(
      primaryKey: ['event_id'],
    ).map((data) => data.map((eventMap) => Event.fromMap(eventMap)).toList());
  }
  //Update Events
  Future updateEvent(Event oldEvent,
    String? newDESC,
    String? newLOC,
    double? newLAT,
    double? newLON,
    String? newImg,
    String? newTimeStart,
    String? newTimeEnd,
    List<String>? newDays,
    List<String>? newTags,
    String? newStartDate,
    String? newEndDate) async {
      await database.update({
        'description': newDESC,
        'location': newLOC,
        'latitude': newLAT,
        'longitude': newLON,
        'image_url': newImg,
        'time_start': newTimeStart,
        'time_end': newTimeEnd,
        'days': newDays,
        'tags': newTags,
        'start_date': newStartDate,
        'end_date': newEndDate,
      }).eq('event_id', oldEvent.eventId!);
  }
  //Delete
  Future deleteEvent(Event event) async {
    await database.delete().eq('event_id',event.eventId!);
  }

}
