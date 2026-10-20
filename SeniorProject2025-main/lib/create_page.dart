import 'package:flutter/material.dart';
import 'package:icebreaker/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icebreaker/discussion_form.dart';
import 'package:icebreaker/Models/event_form.dart';

bool state = true;

class CreatePage extends StatefulWidget {
  final VoidCallback? onEventCreated;
  const CreatePage({super.key, this.onEventCreated});
  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  String formType = 'Event';
  String name = "Test";
  String image = "Test";
  bool poll = false;

  TextEditingController eventNameController = TextEditingController();
  TextEditingController eventLocationController = TextEditingController();
  TextEditingController eventLatitudeController = TextEditingController();
  TextEditingController eventLongitudeController = TextEditingController();
  TextEditingController eventDescriptionController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController startTimeController = TextEditingController();
  TextEditingController endTimeController = TextEditingController();

  //+++ User Data +++
  late String username = '';
  late String uEmail = '';
  late String profilePic = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final response = await Supabase.instance.client
        .from('Users')
        .select()
        .eq('user_id', userId.toString())
        .single();

    return response;
  }

  Future<void> _loadUserData() async {
    final userData = await _fetchUserData();
    setState(() {
      username = userData?['username'] ?? 'Unknown';
      profilePic = userData?['profile_pic'] ?? '';
      uEmail = userData?['email']?? 'No email';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    //final iconColor = isDark ? Colors.white : Colors.black;
    //final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    //final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
    //final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    final hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    //final dividerColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    final selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;
    final unselectedColor = isDark ? const Color(0xFF757575) : const Color(0xFF9E9E9E);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: backgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text("Create", style: TextStyle(color: textColor)),
          centerTitle: true,
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                formType = index == 0 ? 'Event' : 'Discussion';
              });
            },
            tabs: [
              Tab(text: 'Events'),
              Tab(text: 'Discussions'),
            ],
            labelColor: textColor,
            unselectedLabelColor: unselectedColor,
            indicatorColor: selectedColor,
          ),
        ),
        body: TabBarView(
          children: [
            // Events tab
            ListView(
              children: <Widget>[
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage:
                        profilePic.isNotEmpty ? NetworkImage(profilePic) : NetworkImage(
                            'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png'),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                                fontSize: 18,
                                color: textColor,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            uEmail,
                            style: TextStyle(fontSize: 14, color: hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                EventForm(
                  formType: formType,
                  name: name,
                  image: image,
                  eventNameController: eventNameController,
                  eventLocationController: eventLocationController,
                  eventLatitudeController: eventLatitudeController,
                  eventLongitudeController: eventLongitudeController,
                  eventDescriptionController: eventDescriptionController,
                  dateController: dateController,
                  startDateController: startDateController,
                  endDateController: endDateController,
                  startTimeController: startTimeController,
                  endTimeController: endTimeController,
                  onEventCreated: widget.onEventCreated,
                ),
              ],
            ),
            // Discussions tab
            ListView(
              children: <Widget>[
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage:
                        profilePic.isNotEmpty ? NetworkImage(profilePic) : NetworkImage(
                            'https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png'),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                                fontSize: 18,
                                color: textColor,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            uEmail,
                            style: TextStyle(fontSize: 14, color: hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DiscussionForm(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}