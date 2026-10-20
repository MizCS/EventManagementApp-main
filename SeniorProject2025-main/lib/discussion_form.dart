import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:icebreaker/assets/database/poll_queries.dart';
import 'dart:math';
import 'package:profanity_filter/profanity_filter.dart';

final _logger = Logger();

// Helper function for showing error snackbars
void _showErrorSnackbar(BuildContext context, String message) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    )
  );
}

// Helper function for showing success snackbars
void _showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    )
  );
}

class DiscussionForm extends StatefulWidget {
  const DiscussionForm({super.key});

  @override
  State<DiscussionForm> createState() => _DiscussionFormState();
}

class _DiscussionFormState extends State<DiscussionForm> {
  bool showTextField = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _selectedTags = [];
  bool isLoading = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  double? _longitude;
  double? _latitude;
  String _username = '';
  final ProfanityFilter _profanityFilter = ProfanityFilter();
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
  bool showLocation = false;
  bool showImage = false;

  // Poll related variables
  bool showPoll = false;
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [];

  // Define available categories for discussions
  final List<String> availableCategories = [
    'General',
    'Questions',
    'Ideas',
    'Feedback',
    'Announcements',
    'Help',
    'Other'
  ];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getuserinfo();
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

  Future<void> _getuserinfo() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      return;
    }
    final user = await Supabase.instance.client.from('Users').select('username').eq('user_id', currentUser.id).single();
    setState(() {
      _username = user['username'];
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
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
          final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
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
        _showErrorSnackbar(context, 'Poll option contains inappropriate language.');
        return; // Don't add if profanity found
      }
      setState(() {
        // Add a new empty controller for the next option
        _pollOptionControllers.add(TextEditingController());
      });
    } else {
      _showErrorSnackbar(context, 'Please enter text for the current option before adding a new one.');
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

  Future<void> setlocation() async {
    if (showLocation) {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _longitude = position.longitude;
        _latitude = position.latitude;
      });
    } else {
      setState(() {
        _longitude = null;
        _latitude = null;
      });
    }
  }

  // Helper method to format duration
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

  // Convert Duration to minutes for database
  int? _durationToMinutes(Duration? duration) {
    if (duration == null) return null;
    return duration.inMinutes;
  }

  // Convert minutes from database to Duration
  Duration? _minutesToDuration(int? minutes) {
    if (minutes == null) return null;
    return Duration(minutes: minutes);
  }

  Future<void> _createDiscussion() async {
    setState(() {
      isLoading = true;
    });

    // Store BuildContext-dependent objects before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showErrorSnackbar(context, 'Please log in to create a discussion');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Validate form fields first
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar(context, 'Please fix the errors in the form');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Perform additional validation (categories, poll)
    final additionalValidationError = _validateForm();
    if (additionalValidationError != null) {
      _showErrorSnackbar(context, additionalValidationError);
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Create discussion and poll
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
      final discussionResponse = await Supabase.instance.client
          .from('Discussions')
          .insert({
            'title': _titleController.text,
            'description': _descriptionController.text,
            'categories': _selectedTags,
            'image_url': imageUrl,
            'owner_id': currentUser.id,
            'duration': _durationToMinutes(_selectedDuration),
            'created_at': DateTime.now().toUtc().toIso8601String(),
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
      _showSuccessSnackbar(context, 'Discussion created successfully!');
    } catch (e) {
      if (!mounted) return;
      
      _showErrorSnackbar(context, e is Exception ? e.toString() : 'Error creating discussion: $e');
    } finally {
      // Ensure isLoading is set to false even if an error occurs
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _selectImage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
    final selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;
    final hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
          height: 100,
          width: 200,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
            color: inputColor,
          ),
          child: _image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_image!, fit: BoxFit.cover),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 50, color: hintColor),
                      SizedBox(height: 8),
                      Text("No image selected", style: TextStyle(color: hintColor)),
                    ],
                  ),
                ),
        ),
        SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text("Camera"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text("Gallery"),
            ),
          ],
        ),
      ],
      ),
      SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0);
    final hintColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final selectedColor = isDark ? const Color(0xFF64B5F6) : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: backgroundColor,
      child: Form(
        key: _formKey,
        child: Column( 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image upload section
            Container(
              decoration: BoxDecoration(
                border: showImage? Border.all(color: selectedColor) : Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                color: showImage? inputColor : Colors.transparent,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Switch(
                        activeColor: selectedColor,
                        activeTrackColor: isDark ? const Color(0xFF90CAF9) : const Color(0xFFBBDEFB),
                        inactiveTrackColor: isDark ? const Color(0xFF757575) : const Color(0xFFE0E0E0),
                        value: showImage,
                        onChanged: (value) {
                          setState(() {
                            showImage = value;
                            if (!value) {
                              _image = null;
                            }
                          });
                        },
                      ),
                      Text('Add Image', style: TextStyle(color: textColor)),
                    ],
                  ),
                  if (showImage) ...[
                    _selectImage(),
                  ],
                ],
                ),
              ),
            SizedBox(height: 10),
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
                labelStyle: TextStyle(fontSize: 16, color: hintColor),
                alignLabelWithHint: true,
                hintText: 'Enter your title here',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: inputColor,
              ),
              validator: (value) => _validateRequiredWithProfanity(value, 'Title'),
            ),
            SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _showCategoriesDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Select Categories", style: TextStyle(color: Colors.white, fontSize: 10))
                ),
                SizedBox(width: 10),
                Switch(
                  //switch to set location to current location
                  //otherwise set location to null
                  activeColor: selectedColor,
                  activeTrackColor: isDark ? const Color(0xFF90CAF9) : const Color(0xFFBBDEFB),
                  inactiveTrackColor: isDark ? const Color(0xFF757575) : const Color(0xFFE0E0E0),
                  value: showLocation,
                  onChanged: (value) {
                    setState(() {
                      showLocation = value;
                    });
                    setlocation();
                  },
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showLocation ? Icons.location_on : Icons.location_off,
                      color: showLocation ? selectedColor : hintColor,
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text('Show on map', style: TextStyle(color: textColor))
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            // Description field
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: textColor),
              maxLines: 5,
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
                labelText: 'Description',
                labelStyle: TextStyle(fontSize: 16, color: hintColor),
                alignLabelWithHint: true,
                hintText: 'Enter your description here',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: inputColor,
              ),
              validator: (value) => _validateRequiredWithProfanity(value, 'Description'),
            ),
            SizedBox(height:10),
            Row(
              children: [
                PopupMenuButton<Duration>(
                  onSelected: (Duration value) {
                    setState(() {
                      _selectedDuration = value;
                    });
                  },
                  constraints: BoxConstraints(maxWidth: 100, maxHeight: 100),
                  offset: Offset(0, -100),
                  popUpAnimationStyle: AnimationStyle(
                    reverseCurve: Curves.bounceInOut,
                    reverseDuration: Duration(milliseconds: 300),
                  ),
                  icon: Icon(
                    Icons.access_time_outlined, 
                    color: Colors.white, 
                    size: 24
                  ),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: selectedColor,
                    foregroundColor: Colors.white,
                  ),
                  itemBuilder: (BuildContext context) {
                    return duration!.map((Duration value) {
                      setState(() {
                      _selectedDuration = value;
                    });
                      return PopupMenuItem<Duration>(
                        value: value,
                        child: Text(_formatDuration(value)), 
                      );
                    }).toList();
                    
                  },
                ),
                Text(_selectedDuration != null ? _formatDuration(_selectedDuration!) : 'Duration', 
                  style: TextStyle(color: textColor)
                ),
              ],
            ),
            // Poll toggle
            Row(
              children: [
                Switch(
                  value: showPoll,
                  onChanged: (value) {
                    setState(() {
                      showPoll = value;
                      if (!value) {
                        _pollQuestionController.clear();
                        _pollOptionControllers.clear();
                      }
                    });
                  },
                  activeColor: selectedColor,
                  activeTrackColor: isDark ? const Color(0xFF90CAF9) : const Color(0xFFBBDEFB),
                  inactiveTrackColor: isDark ? const Color(0xFF757575) : const Color(0xFFE0E0E0),
                ),
                Text('Add Poll', style: TextStyle(color: textColor)),
              ],
            ),

            // Poll section
            if (showPoll) ...[
              SizedBox(height: 10),
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
              SizedBox(height: 10),
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
              SizedBox(height: 10),
            ],
            SizedBox(height: 20),
            // Categories and Post button
            Row(
              children: [
                Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _createDiscussion();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    fixedSize: Size(170, 50),
                    iconSize: 24,
                    backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.grey.shade800 : theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.brightness == Brightness.dark 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  child: isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      )
                    : Row(
                      children: [
                        Icon(
                          Icons.add, 
                          size: 24,
                          color: theme.colorScheme.brightness == Brightness.dark ? Colors.grey.shade400 : Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Discussion", 
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.brightness == Brightness.dark ? Colors.grey.shade400 : Colors.white,
                          )
                        ),
                      ],
                    )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 