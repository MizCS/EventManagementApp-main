import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:math';

class UserInfo {
  final SupabaseClient supabase;
  final _logger = Logger();

  UserInfo({required this.supabase});

  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final response = await supabase
          .from('Users')
          .select('user_id, username, profile_pic, bio, joined, private')
          .eq('user_id', userId)
          .single();

      return {
        'user_id': response['user_id'] as String? ?? '',
        'username': response['username'] as String? ?? 'Unknown User',
        'profile_pic': response['profile_pic'] as String? ?? '',
        'bio': response['bio'] as String?,
        'joined': response['joined'] as String? ?? '',
        'private': response['private'] as bool? ?? true,
      };
    } catch (e) {
      _logger.e('Error getting user info', error: e, stackTrace: StackTrace.current);
      return {
        'username': 'Unknown User',
        'profile_pic': '',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers(
      String currentUserId, double latitude, double longitude, double radiusInMeters) async {
    try {
      // First, get all users except the current user who have lat/lng
      final response = await supabase
          .from('Users')
          .select('user_id, username, user_lat, user_lng, profile_pic')
          .neq('private', true)
          .neq('user_id', currentUserId) // Exclude current user
          .not('user_lat', 'is', null)
          .not('user_lng', 'is', null);

      // Filter users based on distance
      final List<Map<String, dynamic>> nearbyUsers = [];
      for (var user in response) {
        double userLat = (user['user_lat'] as num).toDouble();
        double userLng = (user['user_lng'] as num).toDouble();
        
        // Calculate distance using Haversine formula
        double distance = _calculateDistance(
          latitude, longitude, userLat, userLng);
        
        if (distance <= radiusInMeters) {
          user['distance'] = distance;
          nearbyUsers.add(user);
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) => (a['distance'] as double)
          .compareTo(b['distance'] as double));
      
      return nearbyUsers;
    } catch (e) {
      _logger.e('Error getting nearby users', error: e, stackTrace: StackTrace.current);
      return [];
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    // Convert to radians
    double lat1Rad = _degreesToRadians(lat1);
    double lon1Rad = _degreesToRadians(lon1);
    double lat2Rad = _degreesToRadians(lat2);
    double lon2Rad = _degreesToRadians(lon2);

    // Differences
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    // Haversine formula
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in meters
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}


