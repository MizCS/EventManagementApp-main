import 'dart:io';
import 'package:intl/intl.dart';
import 'package:day_picker/day_picker.dart';
import 'package:flutter/material.dart';
import 'package:icebreaker/assets/database/events_database.dart';
import 'package:icebreaker/assets/database/events_map.dart';
//import 'package:icebreaker/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icebreaker/Models/map_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:profanity_filter/profanity_filter.dart';

final _logger = Logger();

class EventForm extends StatefulWidget {
  final String formType;
  final String name;
  final String image;
  final TextEditingController eventNameController;
  final TextEditingController eventLocationController;
  final TextEditingController eventLatitudeController;
  final TextEditingController eventLongitudeController;
  final TextEditingController eventDescriptionController;
  final TextEditingController dateController;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final VoidCallback? onEventCreated;

  const EventForm({
    super.key,
    required this.formType,
    required this.name,
    required this.image,
    required this.eventNameController,
    required this.eventLocationController,
    required this.eventLatitudeController,
    required this.eventLongitudeController,
    required this.eventDescriptionController,
    required this.dateController,
    required this.startDateController,
    required this.endDateController,
    required this.startTimeController,
    required this.endTimeController,
    this.onEventCreated,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  bool showTextField = false;
  List<String> _selectedDays = [];
  final List<String> _selectedTags = [];
  bool isLoading = false;
  File? _image;
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ProfanityFilter _profanityFilter = ProfanityFilter();
  final List<DayInWeek> _days = [
    DayInWeek("Mo", dayKey: "monday"),
    DayInWeek("Tu", dayKey: "tuesday"),
    DayInWeek("We", dayKey: "wednesday"),
    DayInWeek("Th", dayKey: "thursday"),
    DayInWeek("Fr", dayKey: "friday"),
    DayInWeek("Sa", dayKey: "saturday"),
    DayInWeek("Su", dayKey: "sunday"),
  ];

  // Define available tags
  List<String> availableTags = [
    'Sports',
    'Music',
    'Food',
    'Art',
    'Technology',
    'Education',
    'Social',
    'Business'
  ];

  final _formKey = GlobalKey<FormState>();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _openMapDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MapDialog(initialLocation: _locationController.text),
    );

    if (result != null) {
      setState(() {
        widget.eventLatitudeController.text = result['lat'].toString();
        widget.eventLongitudeController.text = result['lng'].toString();
        _locationController.text = result['address'];
      });
    }
  }

  Future<void> _tagsbox() async {
    final customTagController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black;
          final iconColor = isDark ? Colors.white : Colors.black;
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
                    'Select Tags',
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
                            controller: customTagController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Add custom tag...',
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
                              final newTag = customTagController.text.trim();
                              if (newTag.isNotEmpty && !availableTags.contains(newTag)) {
                                setDialogState(() {
                                  if (_profanityFilter.hasProfanity(newTag)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Custom tag contains inappropriate language.'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      )
                                    );
                                  } else {
                                    availableTags.add(newTag);
                                    _selectedTags.add(newTag);
                                    customTagController.clear();
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
                    'Available Tags',
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
                        children: availableTags.map((tag) {
                          return ChoiceChip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                color: _selectedTags.contains(tag) ? Colors.white : textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: _selectedTags.contains(tag),
                            selectedColor: selectedColor,
                            backgroundColor: inputColor,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
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
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    if (_profanityFilter.hasProfanity(value)) {
      return '$fieldName contains inappropriate language.';
    }
    return null;
  }

  // Validator for location field with profanity check and map confirmation
  String? _validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a location';
    }
    if (_profanityFilter.hasProfanity(value)) {
      return 'Location contains inappropriate language.';
    }
    // The map confirmation check is handled separately in the button logic
    return null;
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await Supabase.instance.client.storage
          .from('eventpics')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
            ),
          );
      
      final imageUrl = Supabase.instance.client.storage
          .from('eventpics')
          .getPublicUrl(fileName);
      
      return imageUrl;
    } catch (e) {
      _logger.e('Error uploading image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
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
                              Text("No image selected", 
                                style: TextStyle(color: hintColor)
                              ),
                            ],
                          ),
                        ),
                ),
                SizedBox(height: 10),
                Row(
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
                    SizedBox(width: 20),
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

            // Event details
            TextFormField(
              controller: widget.eventNameController,
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
                labelText: "${widget.formType} name",
                labelStyle: TextStyle(fontSize: 16, color: hintColor),
                filled: true,
                fillColor: inputColor,
              ),
              validator: (value) => _validateRequired(value, 'event name'),
            ),
            SizedBox(height: 10),

            // Location
            TextFormField(
              controller: _locationController,
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
                labelText: "Location",
                labelStyle: TextStyle(fontSize: 16, color: hintColor),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  color: iconColor,
                  onPressed: _openMapDialog,
                ),
                filled: true,
                fillColor: inputColor,
              ),
              validator: _validateLocation,
            ),
            SizedBox(height: 10),

            // Description
            TextFormField(
              controller: widget.eventDescriptionController,
              style: TextStyle(color: textColor),
              maxLines: 3,
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
                filled: true,
                fillColor: inputColor,
              ),
              validator: (value) => _validateRequired(value, 'description'),
            ),
            SizedBox(height: 10),

            // Recurring event toggle
            Row(
              children: [
                Switch(
                  value: showTextField,
                  onChanged: (value) {
                    setState(() {
                      showTextField = value;
                      if (!value) {
                        _selectedDays = [];
                      }
                    });
                  },
                  activeColor: selectedColor,
                  activeTrackColor: isDark ? const Color(0xFF90CAF9) : const Color(0xFFBBDEFB),
                  inactiveTrackColor: isDark ? const Color(0xFF757575) : const Color(0xFFE0E0E0),
                ),
                Text('Recurring Event', style: TextStyle(color: textColor)),
              ],
            ),

            // Date selection
            if (showTextField) ...[
              SelectWeekDays(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                days: _days,
                border: false,
                width: MediaQuery.of(context).size.width / 0.5,
                boxDecoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                onSelect: (values) {
                  setState(() {
                    _selectedDays = values;
                  });
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: widget.startDateController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  labelText: 'Start Date',
                  labelStyle: TextStyle(fontSize: 16, color: textColor),
                  filled: true,
                  fillColor: inputColor,
                ),
                onTap: () async {
                  DateTime? datetime = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (datetime != null) {
                    String formattedDate = DateFormat('yyyy-MM-dd').format(datetime);
                    setState(() {
                      widget.startDateController.text = formattedDate;
                    });
                  }
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: widget.endDateController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  labelText: 'End Date',
                  labelStyle: TextStyle(fontSize: 16, color: textColor),
                  filled: true,
                  fillColor: inputColor,
                ),
                onTap: () async {
                  DateTime? datetime = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(widget.startDateController.text),
                    firstDate: DateTime.parse(widget.startDateController.text),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (datetime != null) {
                    String formattedDate = DateFormat('yyyy-MM-dd').format(datetime);
                    setState(() {
                      widget.endDateController.text = formattedDate;
                    });
                  }
                },
              ),
            ] else
              TextFormField(
                controller: widget.startDateController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  labelText: 'Date',
                  labelStyle: TextStyle(fontSize: 16, color: textColor),
                  filled: true,
                  fillColor: inputColor,
                ),
                onTap: () async {
                  DateTime? datetime = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (datetime != null) {
                    String formattedDate = DateFormat('yyyy-MM-dd').format(datetime);
                    setState(() {
                      // For single date events, set both start and end dates to the same date
                      widget.startDateController.text = formattedDate;
                      widget.endDateController.text = formattedDate;
                      int dayOfWeek = datetime.weekday;
                      String dayKey = _days[dayOfWeek - 1].dayKey;
                      if (!_selectedDays.contains(dayKey)) {
                        _selectedDays.add(dayKey);
                      }
                    });
                  }
                },
              ),

            SizedBox(height: 10),

            // Time selection
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.startTimeController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      labelText: 'Start Time',
                      labelStyle: TextStyle(fontSize: 16, color: textColor),
                      filled: true,
                      fillColor: inputColor,
                    ),
                    onTap: () async {
                      var time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (time != null) {
                        setState(() {
                          widget.startTimeController.text = time.format(context);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: widget.endTimeController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      labelText: 'End Time',
                      labelStyle: TextStyle(fontSize: 16, color: textColor),
                      filled: true,
                      fillColor: inputColor,
                    ),
                    onTap: () async {
                      var time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (time != null) {
                        setState(() {
                          widget.endTimeController.text = time.format(context);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Tags and Post button
            Row(
              children: [
                ElevatedButton(
                  onPressed: _tagsbox,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Insert Tags")
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final currentUser = Supabase.instance.client.auth.currentUser;

                    // Store BuildContext before async operations for ScaffoldMessenger and Navigator
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final theme = Theme.of(context); // Get theme for snackbar styling

                    if (currentUser == null) {
                      _showErrorSnackbar(scaffoldMessenger, theme, 'Please log in to create an event');
                      return;
                    }

                    // Use form field validators first
                    if (!_formKey.currentState!.validate()) {
                      _showErrorSnackbar(scaffoldMessenger, theme, 'Please fix the errors in the form');
                      return;
                    }

                    // Additional custom validation (not covered by field validators)
                    if (widget.eventLatitudeController.text.isEmpty || widget.eventLongitudeController.text.isEmpty) {
                      _showErrorSnackbar(scaffoldMessenger, theme, 'Please confirm location on the map');
                      return;
                    }
                    if (showTextField) {
                      if (widget.startDateController.text.isEmpty || widget.endDateController.text.isEmpty) {
                        _showErrorSnackbar(scaffoldMessenger, theme, 'Please select start and end dates');
                        return;
                      }
                      if (_selectedDays.isEmpty) {
                        _showErrorSnackbar(scaffoldMessenger, theme, 'Please select at least one day for recurring event');
                        return;
                      }
                    } else {
                      if (widget.startDateController.text.isEmpty) {
                        _showErrorSnackbar(scaffoldMessenger, theme, 'Please select a date');
                        return;
                      }
                    }
                    if (widget.startTimeController.text.isEmpty || widget.endTimeController.text.isEmpty) {
                      _showErrorSnackbar(scaffoldMessenger, theme, 'Please select start and end times');
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      String? imageUrl;
                      if (_image != null) {
                        imageUrl = await _uploadImage(_image!);
                        if (imageUrl == null) {
                          throw Exception('Failed to upload image');
                        }
                      }

                      List<String> selectedDays = [];
                      if (showTextField) {
                        // For recurring events, use all selected days
                        selectedDays = _selectedDays;
                      } else {
                        // For single events, use the day of the selected date
                        selectedDays = _selectedDays;
                      }

                      final event = Event(
                        title: widget.eventNameController.text,
                        description: widget.eventDescriptionController.text,
                        location: _locationController.text,
                        latitude: double.tryParse(widget.eventLatitudeController.text),
                        longitude: double.tryParse(widget.eventLongitudeController.text),
                        imageUrl: imageUrl,
                        organizer: currentUser.id,
                        timeStart: widget.startTimeController.text,
                        timeEnd: widget.endTimeController.text,
                        startDate: widget.startDateController.text,
                        endDate: widget.endDateController.text,
                        days: selectedDays,
                        tags: _selectedTags,
                      );

                      final eventDB = EventsDatabase();
                      await eventDB.createEvent(event);

                      if (!mounted) return;
                      
                      navigator.pop();
                      _showSuccessSnackbar(scaffoldMessenger, theme, 'Event created successfully!');

                      if (widget.onEventCreated != null) {
                        widget.onEventCreated!();
                      }
                    } catch (e) {
                      if (!mounted) return;
                      
                       _showErrorSnackbar(scaffoldMessenger, theme, e is Exception ? e.toString() : 'Error creating event: $e');
                    } finally {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
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
                    : Text("Create ${widget.formType}")
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
} 