import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:icebreaker/assets/database/discussion_queries.dart';
import 'package:icebreaker/assets/database/poll_queries.dart';
import 'dart:math';
import 'package:profanity_filter/profanity_filter.dart';

// This is the form for creating a new discussion for an event 
// It is used in the event_pop_up.dart file
class EventDiscussionForm extends StatefulWidget {
  final String eventId;

  const EventDiscussionForm({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDiscussionForm> createState() => _EventDiscussionFormState();
}


class _EventDiscussionFormState extends State<EventDiscussionForm> {
  final _logger = Logger();
  bool showTextField = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _selectedTags = [];
  bool isLoading = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final ProfanityFilter _profanityFilter = ProfanityFilter();
  

  // Theme-related variables
  late ThemeData theme;
  late bool isDark;
  late Color backgroundColor;
  late Color textColor;
  late Color inputColor;
  late Color borderColor;
  late Color hintColor;
  late Color selectedColor;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getuserinfo();
    _getlocationfromevent();
    // Initialize with two empty options
    _pollOptionControllers.add(TextEditingController());
    _pollOptionControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pollQuestionController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeTheme() {
    theme = Theme.of(context);
    isDark = theme.brightness == Brightness.dark;
    backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    textColor = isDark ? Colors.white : Colors.black;
    inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
    borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeTheme();
  }

  // Poll related variables
  bool showPoll = false;
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [];
  String _username = '';
  double _longitude = 0.0;
  double _latitude = 0.0;
  // Define available categories for discussions
  final List<Duration>? duration = [
    const Duration(minutes: 0),
    const Duration(minutes: 30),
    const Duration(minutes: 60),
    const Duration(minutes: 120),
    const Duration(minutes: 240),
    const Duration(minutes: 480),
    const Duration(minutes: 720),
  ];
  Duration? _selectedDuration;
  final List<String> availableCategories = [
    'General',
    'Questions',
    'Ideas',
    'Feedback',
    'Announcements',
    'Help',
    'Other'
  ];

  Future<void> _getuserinfo() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final userInfo = await Supabase.instance.client.from('Users').select('username').eq('user_id', currentUser.id).single();
      setState(() {
        _username = userInfo['username'];
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes == 0) {
      return 'No Time Limit';
    } else if (duration.inHours >= 24) {
      return '${duration.inDays} days';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours} hrs';
    } else {
      return '${duration.inMinutes} min';
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _getlocationfromevent() async {
    final event = await Supabase.instance.client.from('Events').select('longitude, latitude').eq('event_id', widget.eventId).single();
    setState(() {
      _longitude = event['longitude'];
      _latitude = event['latitude'];
    });
  }

  int? _durationToMinutes(Duration? duration) {
    if (duration == null) return null;
    return duration.inMinutes;
  }

  Future<void> _showCategoriesDialog() async {
    final customCategoryController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black;
          final iconColor = isDark ? Colors.white : Colors.black;
          final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
          final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
          final hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
          final dividerColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
          final selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Categories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: hintColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              height: 400,
              width: 350,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inputColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customCategoryController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Add custom category...',
                              hintStyle: TextStyle(color: hintColor),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add, color: Colors.white),
                            onPressed: () {
                              final newCategory = customCategoryController.text.trim();
                              if (newCategory.isNotEmpty && !availableCategories.contains(newCategory)) {
                                setDialogState(() {
                                  if (_profanityFilter.hasProfanity(newCategory)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Custom category contains inappropriate language.'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      )
                                    );
                                  } else {
                                    availableCategories.add(newCategory);
                                    _selectedTags.add(newCategory);
                                    customCategoryController.clear();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Available Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: availableCategories.map((category) {
                          return ChoiceChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: _selectedTags.contains(category) ? Colors.white : textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: _selectedTags.contains(category),
                            selectedColor: selectedColor,
                            backgroundColor: inputColor,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  _selectedTags.add(category);
                                } else {
                                  _selectedTags.remove(category);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selectedColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  // Validator for required fields with profanity check
  String? _validateRequiredWithProfanity(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    if (_profanityFilter.hasProfanity(value)) {
      return '$fieldName contains inappropriate language.';
    }
    return null;
  }

  // Function to upload image to Supabase storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await Supabase.instance.client.storage
          .from('discussionpics')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
            ),
          );
      
      final imageUrl = Supabase.instance.client.storage
          .from('discussionpics')
          .getPublicUrl(fileName);
      
      return imageUrl;
    } catch (e) {
      _logger.e('Error uploading image: $e');
      return null;
    }
  }

  // Function to add a new poll option
  void _addPollOption() {
    final newOptionText = _pollOptionControllers.last.text.trim();
    if (newOptionText.isNotEmpty) {
      if (_profanityFilter.hasProfanity(newOptionText)) {
        // Show error - Ideally use the snackbar helper, but need ScaffoldMessenger context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Poll option contains inappropriate language.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        );
        return; // Don't add the new controller if profanity is found
      }
      setState(() {
        // Add a new empty controller for the next option entry
        _pollOptionControllers.add(TextEditingController());
      });
    } else {
      // Show error if the current option is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter text for the current option before adding a new one.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
      );
    }
  }

  // Function to remove a poll option
  void _removePollOption(int index) {
    setState(() {
      _pollOptionControllers.removeAt(index);
    });
  }

  // Function to validate poll
  String? _validatePoll() {
    if (_pollQuestionController.text.isEmpty) {
      return 'Please enter a poll question';
    }
    if (_profanityFilter.hasProfanity(_pollQuestionController.text)) {
      return 'Poll question contains inappropriate language.';
    }
    if (_pollOptionControllers.length < 2) {
      return 'Please add at least two poll options';
    }
    for (var controller in _pollOptionControllers) {
      if (controller.text.isEmpty) {
        return 'Please fill in all poll options';
      }
      if (_profanityFilter.hasProfanity(controller.text)) {
        return 'Poll option "${controller.text}" contains inappropriate language.';
      }
    }
    return null;
  }

  // Function to validate form
  String? _validateForm() {
    if (_selectedTags.isEmpty) {
      return 'Please select at least one category';
    }
    if (showPoll) {
      final pollError = _validatePoll();
      if (pollError != null) {
        return pollError;
      }
    }
    return null;
  }
  
  void _createDiscussion() {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
    });

    // Store BuildContext-dependent objects before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showErrorSnackbar(scaffoldMessenger, theme, 'Please log in to create a discussion');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Validate form using field validators first
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar(scaffoldMessenger, theme, 'Please fix the errors in the form');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Then perform additional validation (categories, poll)
    final additionalValidationError = _validateForm();
    if (additionalValidationError != null) {
      _showErrorSnackbar(scaffoldMessenger, theme, additionalValidationError);
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Create discussion and poll
    () async {
      try {
        // Upload image if selected
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _uploadImage(_image!);
          if (imageUrl == null) {
            throw Exception('Failed to upload image');
          }
        }
        
        // Create discussion
        await _getlocationfromevent();
        final discussionResponse = await Supabase.instance.client
            .from('Discussions')
            .insert({
              'title': _titleController.text,
              'description': _descriptionController.text,
              'categories': _selectedTags,
              'image_url': imageUrl,
              'owner_id': currentUser.id,
              'event_id': int.parse(widget.eventId),
              'duration': _durationToMinutes(_selectedDuration),
              'created_at': DateTime.now().toIso8601String(),
              'longitude': _longitude,
              'latitude': _latitude,
            })
            .select()
            .single();

        // Add owner as participant
        await _getuserinfo();
        await Supabase.instance.client
            .from('Disc_participants')
            .insert({
              'discussion_id': discussionResponse['discussion_id'],
              'user_id': currentUser.id,
              'username': _username,
              'msg_color': '#${(Random().nextInt(0xFFFFFF)).toRadixString(16).padLeft(6, '0')}',
              'is_owner': true
            });

        // Create poll if one was added
        if (showPoll) {
          final pollDatabase = PollQueries();
          await pollDatabase.createPoll(
            discussionId: discussionResponse['discussion_id'],
            question: _pollQuestionController.text,
            options: _pollOptionControllers.map((controller) => controller.text).toList(),
          );
        }

        if (!mounted) return;
        
        // Show success message and navigate back
        navigator.pop();
        _showSuccessSnackbar(scaffoldMessenger, theme, 'Discussion created successfully!');
      } catch (e) {
        if (!mounted) return;
        
        _showErrorSnackbar(scaffoldMessenger, theme, e is Exception ? e.toString() : 'Error creating discussion: $e');
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }();
  }

  Widget addOns() {
    return Row(
      //crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
          Container(
            //height: 50
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.blue.shade300,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200,
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: PopupMenuButton<Duration>(
              onSelected: (Duration value) {
                setState(() {
                  _selectedDuration = value;
                });
              },
              icon: Icon(
                Icons.access_time_outlined, 
                color: textColor, 
                size: 24
              ),
              style: IconButton.styleFrom(
                backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                elevation: theme.brightness == Brightness.dark ? 3 : 4,
                shadowColor: theme.brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.grey.shade200),                  
                ),
              ),
              itemBuilder: (BuildContext context) {
                return duration!.map((Duration value) { 
                    return PopupMenuItem<Duration>(
                      value: value,
                      child: Text(_formatDuration(value)), 
                      );
                  }
                ).toList();
              },
            ),
          ),
          SizedBox(width: 5),
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200,),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200,
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child:Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                
                borderRadius: BorderRadius.circular(15),
                color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.blue.shade300,
              ),
              child: ElevatedButton.icon(
              onPressed: _showPollcard,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.transparent,),
                ),
                //side: BorderSide(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.transparent,),
                backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                elevation: theme.brightness == Brightness.dark ? 3 : 4,
                shadowColor: theme.brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
              ),
              label: Text('Poll', style: TextStyle(color: textColor, fontSize: 14)),
              icon: Icon(
                Icons.list_alt_outlined,
                color: textColor,
                size: 20,
              ),
              ),
            ),
          ),        
          SizedBox(width: 5),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.blue.shade300,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark ? Colors.transparent : Colors.grey.shade200,
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(
                    Icons.image_outlined,
                    color: textColor,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.grey.shade200),
                    ),
                    backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                    elevation: theme.brightness == Brightness.dark ? 4 : 4,
                    shadowColor: theme.brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
                  ),
                ),
                SizedBox(width: 5),
                IconButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: textColor,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.grey.shade200),
                    ),
                    backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                    elevation: theme.brightness == Brightness.dark ? 3 : 4,
                    shadowColor: theme.brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
                  ),
                ),
                //SizedBox(width: 10),
                if (_image != null) ...[
                  SizedBox(width: 5),
                  Container(
                    height: 42,
                    width: 42,
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      border: Border.all(color: theme.brightness == Brightness.dark ? Colors.blue : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: theme.brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
                          //spreadRadius: 1,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            _image!,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: 4),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _image = null;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha:0.5),
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _showPollcard() {
    setState(() {
      showPoll = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.grey.withValues(alpha: 0.5),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _createDiscussion();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.blue),
                ),
                shadowColor: Colors.blueAccent,
              ),
              label: Text('Discussion', style: TextStyle(color: textColor)),
              icon: Icon(Icons.add, color: textColor),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.withValues(alpha: 1),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
            SizedBox(height: 30),
            Container(
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Event Discussion', 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 32, 
                  fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
        Container(
          constraints: BoxConstraints(
            maxWidth: 800,
            minWidth: 300,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
          ),
          margin: EdgeInsets.all(16),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Title field
                        TextFormField(
                          controller: _titleController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: selectedColor),
                            ),
                            labelText: "Title",
                            labelStyle: TextStyle(fontSize: 24, color: hintColor, fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          validator: (value) => _validateRequiredWithProfanity(value, 'Title'),
                        ),
                        SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton.icon(
                            onPressed: _showCategoriesDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.blue),
                              ),
                              shadowColor: Colors.blueAccent,
                            ),
                            label: Text("Categories", style: TextStyle(color: textColor, fontSize: 12)),
                            icon: Icon(Icons.tag, color: textColor, size: 16),
                          ),
                        ),
                        SizedBox(height: 10),
                        // Description field
                        TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(color: textColor),
                          maxLines: 8,
                          autocorrect: true,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: selectedColor),
                            ),
                            labelText: 'Body',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(fontSize: 16, color: hintColor),
                            filled: true,
                            fillColor: Colors.transparent,
                            hintText: 'Enter your body here',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                          ),
                          validator: (value) => _validateRequiredWithProfanity(value, 'Body'),
                        ),
                        SizedBox(height: 50),
                        addOns(),
                      ],
                    ),
                  ),
                ),
              ),
              if (showPoll)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: _buildPollCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildPollCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(
                    "Create Poll",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: hintColor),
                    onPressed: () {
                    setState(() {
                        showPoll = false;
                    });
                  },
                ),
              ],
            ),
              SizedBox(height: 16),
              TextFormField(
                controller: _pollQuestionController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: selectedColor),
                  ),
                  labelText: "Poll Question",
                  labelStyle: TextStyle(fontSize: 16, color: hintColor),
                  filled: true,
                  fillColor: inputColor,
                ),
                validator: (value) => _validateRequiredWithProfanity(value, 'Poll Question'),
              ),
              SizedBox(height: 16),
              Text(
                "Poll Options",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10),
              ..._pollOptionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: selectedColor),
                            ),
                            labelText: "Option ${index + 1}",
                            labelStyle: TextStyle(fontSize: 16, color: hintColor),
                            filled: true,
                            fillColor: inputColor,
                          ),
                          validator: (value) => _validateRequiredWithProfanity(value, 'Option ${index + 1}'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removePollOption(index),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pollOptionControllers.last,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: selectedColor),
                        ),
                        labelText: "New Option",
                        labelStyle: TextStyle(fontSize: 16, color: hintColor),
                        filled: true,
                        fillColor: inputColor,
                      ),
                      validator: (value) => _validateRequiredWithProfanity(value, 'New Option'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: selectedColor),
                    onPressed: _addPollOption,
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      showPoll = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text("Add Poll"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showErrorSnackbar(ScaffoldMessengerState messenger, ThemeData theme, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    )
  );
}

void _showSuccessSnackbar(ScaffoldMessengerState messenger, ThemeData theme, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    )
  );
}
