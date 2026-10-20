import 'package:flutter_test/flutter_test.dart';
import 'package:icebreaker/Models/event.dart';

void main() {
  group('Event Model Tests', () {
    test('Event creation with valid data', () {
      final event = Event(
        id: '123',
        title: 'Test Event',
        description: 'Test Description',
        location: 'Test Location',
        date: DateTime.now(),
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event'],
      );

      expect(event.id, '123');
      expect(event.title, 'Test Event');
      expect(event.description, 'Test Description');
      expect(event.location, 'Test Location');
      expect(event.createdBy, 'user123');
      expect(event.latitude, 37.7749);
      expect(event.longitude, -122.4194);
      expect(event.tags, ['test', 'event']);
    });

    test('Event date validation', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 1));
      final pastDate = now.subtract(const Duration(days: 1));

      // Test future date
      final futureEvent = Event(
        id: '123',
        title: 'Future Event',
        description: 'Test Description',
        location: 'Test Location',
        date: futureDate,
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event'],
      );

      expect(futureEvent.date.isAfter(now), true);

      // Test past date
      final pastEvent = Event(
        id: '123',
        title: 'Past Event',
        description: 'Test Description',
        location: 'Test Location',
        date: pastDate,
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event'],
      );

      expect(pastEvent.date.isBefore(now), true);
    });

    test('Event location coordinates validation', () {
      // Test valid coordinates
      final validEvent = Event(
        id: '123',
        title: 'Valid Location Event',
        description: 'Test Description',
        location: 'Test Location',
        date: DateTime.now(),
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event'],
      );

      expect(validEvent.latitude >= -90 && validEvent.latitude <= 90, true);
      expect(validEvent.longitude >= -180 && validEvent.longitude <= 180, true);
    });

    test('Event tags validation', () {
      final event = Event(
        id: '123',
        title: 'Tagged Event',
        description: 'Test Description',
        location: 'Test Location',
        date: DateTime.now(),
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event', 'social'],
      );

      expect(event.tags.length, 3);
      expect(event.tags.contains('test'), true);
      expect(event.tags.contains('event'), true);
      expect(event.tags.contains('social'), true);
    });

    test('Event JSON serialization', () {
      final event = Event(
        id: '123',
        title: 'Test Event',
        description: 'Test Description',
        location: 'Test Location',
        date: DateTime.parse('2024-03-20T10:00:00Z'),
        createdBy: 'user123',
        latitude: 37.7749,
        longitude: -122.4194,
        tags: ['test', 'event'],
      );

      final json = event.toJson();
      final fromJson = Event.fromJson(json);

      expect(fromJson.id, event.id);
      expect(fromJson.title, event.title);
      expect(fromJson.description, event.description);
      expect(fromJson.location, event.location);
      expect(fromJson.date, event.date);
      expect(fromJson.createdBy, event.createdBy);
      expect(fromJson.latitude, event.latitude);
      expect(fromJson.longitude, event.longitude);
      expect(fromJson.tags, event.tags);
    });
  });
} 