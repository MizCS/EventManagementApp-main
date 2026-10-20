class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String createdBy;
  final double latitude;
  final double longitude;
  final List<String> tags;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.createdBy,
    required this.latitude,
    required this.longitude,
    required this.tags,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['event_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      date: DateTime.parse(json['start_date'] as String),
      createdBy: json['created_by'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      tags: List<String>.from(json['tags'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': id,
      'title': title,
      'description': description,
      'location': location,
      'start_date': date.toIso8601String(),
      'created_by': createdBy,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
    };
  }
} 