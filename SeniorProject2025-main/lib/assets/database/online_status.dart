import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineStatus {
  final SupabaseClient supabase;

  OnlineStatus({required this.supabase});

  // Update user's online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await supabase
          .from('Users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Get user's online status
  Future<bool> getUserOnlineStatus(String userId) async {
    try {
      final response = await supabase
          .from('Users')
          .select('is_online')
          .eq('user_id', userId)
          .single();
      return response['is_online'] ?? false;
    } catch (e) {
      print('Error getting online status: $e');
      return false;
    }
  }

  // Subscribe to online status changes
  Stream<bool> subscribeToOnlineStatus(String userId) {
    return supabase
        .from('Users')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((event) => event.first['is_online'] ?? false);
  }
} 