class Event{
  int? eventId;
  DateTime? timeCreated;
  String? title, description, organizer, location;
  double? latitude, longitude;
  String? imageUrl;
  String? timeStart, timeEnd;
  String? startDate, endDate;
  List<String>? days;
  List<String>? tags;

  Event({
    this.eventId,
    this.timeCreated,
    this.title,
    this.description,
    this.location,
    this.organizer,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.timeStart,
    this.timeEnd,
    this.startDate,
    this.endDate,
    this.days,
    this.tags,
  });

/*map to event*/
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      eventId: map['event_id'] as int?,
      timeCreated: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
      title: map['title'] as String?,
      description: map['description'] as String?,
      location: map['location'] as String?,
      organizer: map['user_id'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      imageUrl: map['image_url'] as String?,
      timeStart: map['time_start'] as String?,
      timeEnd: map['time_end'] as String?,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      days: map['days'] != null 
          ? (map['days'] as List).map((e) => e as String).toList() 
          : [],
      tags: map['tags'] != null 
          ? (map['tags'] as List).map((e) => e as String).toList() 
          : [],
    );
  }

  /*event to map*/
  Map<String, dynamic> toMap(){
    return {
      //'event_id': eventId,
      //'created_at': timeCreated,
      'title': title,
      'description': description,
      'location': location,
      'user_id': organizer,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'time_start': timeStart,
      'time_end': timeEnd,
      'start_date': startDate,
      'end_date': endDate,
      'days': days,
      'tags': tags,
    };
  }
}

