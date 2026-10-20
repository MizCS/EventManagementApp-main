
import 'package:flutter/material.dart';
import 'package:icebreaker/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

//show profile card
void showProfileCard(BuildContext context, String user_id, bool message) async {

  final logger = Logger();

    String monthToString(int month) {
    const months = [
      '', // index 0 unused
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month] : 'Unknown';
  }
    String formatDateToEnglish(String dateString) {
    try {
      DateTime parsedDate = DateTime.parse(dateString);
      return "${monthToString(parsedDate.month)} ${parsedDate.day}, ${parsedDate.year}";
    } catch (e) {
      return "Invalid date";
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final response = await Supabase.instance.client
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
        'private': response['private'] as bool? ?? false,
      };
    } catch (e) {
      logger.e('Error getting user info', error: e, stackTrace: StackTrace.current);
      return {
        'username': 'Unknown User',
        'profile_pic': '',
      };
    }
  }
  


  showDialog(
    context: context,
    builder: (BuildContext context) {
      return FutureBuilder<Map<String, dynamic>>(
        future: getUserInfo(user_id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('Failed to load user info.'),
            );
          }

          final user = snapshot.data!;
         String formattedDate = formatDateToEnglish(user['joined']);


          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.black,
                          backgroundImage: user['profile_pic'].isNotEmpty
                              ? NetworkImage(user['profile_pic'])
                              : NetworkImage('https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png'),
                        ),
                        const SizedBox(height: 10),

                        // Joined
                         Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Joined $formattedDate',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                )
                              ),
                         ),
                        const SizedBox(height: 10),
                        if (user['private'] == false)...[
                          // Username
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              user['username'],
                              style: TextStyle(color: Colors.black, fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bio (conditionally)
                          if (user['bio'] != null)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                user['bio'],
                                style: TextStyle(color: Colors.black, fontSize: 14),
                              ),
                            ),
                        ]
                        else...[
                          SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.lock_outline, color: Colors.grey, size: 24),
                                Text('This user is private', style: TextStyle(color: Colors.grey, fontSize: 16),),
                              ],
                            ),
                          ),
                        ],
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                  if (user['private'] == false)...[
                    if (message && user['user_id'] != userId)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () {
                            // Send chat request
                          },
                          child: Container(
                            padding: EdgeInsets.all(14),
                            child: Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 28),
                          ),
                      ),
                    ),
                  ],
              ],
            ),
          );
        },
      );
    },
  );
}