import 'dart:io';
import 'package:intl/intl.dart';
import 'package:day_picker/day_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icebreaker/Models/map_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:profanity_filter/profanity_filter.dart';

// Constants
const _maxYear = 2100;
const _borderRadius = 30.0;
const _imageHeight = 200.0;
const _spacing = 10.0;

final _logger = Logger();

class EditForm extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onEventUpdated;

  const EditForm({
    super.key,
    required this.event,
    this.onEventUpdated,
  });

  @override
  State<EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<EditForm> {
  // Form key and state
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showTextField = false;
  List<String> _selectedDays = [];
  final List<String> _selectedTags = [];
  File? _image;
  
  // Controllers
  final _controllers = {
    'location': TextEditingController(),
    'eventName': TextEditingController(),
    'description': TextEditingController(),
    'latitude': TextEditingController(),
    'longitude': TextEditingController(),
    'startDate': TextEditingController(),
    'endDate': TextEditingController(),
    'startTime': TextEditingController(),
    'endTime': TextEditingController(),
  };

  // Services
  final _picker = ImagePicker();
  final _profanityFilter = ProfanityFilter();

  // Available tags
  static const List<String> availableTags = [
    'Sports', 'Music', 'Food', 'Art',
    'Technology', 'Education', 'Social', 'Business'
  ];

  // Days of week
  static final List<DayInWeek> _days = [
    DayInWeek("Mo", dayKey: "monday"),
    DayInWeek("Tu", dayKey: "tuesday"),
    DayInWeek("We", dayKey: "wednesday"),
    DayInWeek("Th", dayKey: "thursday"),
    DayInWeek("Fr", dayKey: "friday"),
    DayInWeek("Sa", dayKey: "saturday"),
    DayInWeek("Su", dayKey: "sunday"),
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _formatDateTime();
  }

  void _initializeForm() {
    final event = widget.event;
    _controllers['eventName']!.text = event['title'] ?? '';
    _controllers['description']!.text = event['description'] ?? '';
    _controllers['location']!.text = event['location'] ?? '';
    _controllers['latitude']!.text = event['latitude']?.toString() ?? '';
    _controllers['longitude']!.text = event['longitude']?.toString() ?? '';
    _controllers['startTime']!.text = event['time_start'] ?? '';
    _controllers['endTime']!.text = event['time_end'] ?? '';
    
    if (event['days'] != null && event['days'].isNotEmpty) {
      _showTextField = true;
      _selectedDays = List<String>.from(event['days']);
      _controllers['startDate']!.text = event['start_date'] ?? '';
      _controllers['endDate']!.text = event['end_date'] ?? '';

      for (var day in _days) {
        day.isSelected = _selectedDays.contains(day.dayKey);
      }
    } else {
      _controllers['startDate']!.text = event['start_date'] ?? '';
      _controllers['endDate']!.text = event['end_date'] ?? '';
      
      for (var day in _days) {
        day.isSelected = false;
      }
    }

    if (event['tags'] != null) {
      _selectedTags.addAll(List<String>.from(event['tags']));
    }
  }

  void _formatDateTime() {
    final event = widget.event;
    
    if (event['time_start'] != null) {
      final time = TimeOfDay(
        hour: int.parse(event['time_start'].split(':')[0]),
        minute: int.parse(event['time_start'].split(':')[1]),
      );
      _controllers['startTime']!.text = time.format(context);
    }
    
    if (event['time_end'] != null) {
      final time = TimeOfDay(
        hour: int.parse(event['time_end'].split(':')[0]),
        minute: int.parse(event['time_end'].split(':')[1]),
      );
      _controllers['endTime']!.text = time.format(context);
    }

    if (event['start_date'] != null) {
      final date = DateTime.parse(event['start_date']);
      _controllers['startDate']!.text = DateFormat('yyyy-MM-dd').format(date);
    }
    
    if (event['end_date'] != null) {
      final date = DateTime.parse(event['end_date']);
      _controllers['endDate']!.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      await _handleError(e, 'picking image');
    }
  }

  void _openMapDialog() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => MapDialog(
          initialLocation: _controllers['location']!.text
        ),
      );

      if (result != null) {
        setState(() {
          _controllers['latitude']!.text = result['lat'].toString();
          _controllers['longitude']!.text = result['lng'].toString();
          _controllers['location']!.text = result['address'];
        });
      }
    } catch (e) {
      _handleError(e, 'opening map dialog');
    }
  }

  Future<void> _tagsbox() async {
    final customTagController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => _TagsDialog(
        customTagController: customTagController,
        selectedTags: _selectedTags,
        availableTags: availableTags,
        profanityFilter: _profanityFilter,
      ),
    );
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
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      
      return Supabase.instance.client.storage
          .from('eventpics')
          .getPublicUrl(fileName);
    } catch (e) {
      _logger.e('Error uploading image: $e');
      return null;
    }
  }

  String? _validateForm() {
    if (_showTextField) {
      if (_controllers['startDate']!.text.isEmpty || 
          _controllers['endDate']!.text.isEmpty) {
        return 'Please select start and end dates';
      }
      if (_selectedDays.isEmpty) {
        return 'Please select at least one day for recurring event';
      }
    } else if (_controllers['startDate']!.text.isEmpty) {
        return 'Please select a date';
      }

    if (_controllers['startTime']!.text.isEmpty || 
        _controllers['endTime']!.text.isEmpty) {
      return 'Please select start and end times';
    }

    try {
      final startTime = TimeOfDay(
        hour: int.parse(_controllers['startTime']!.text.split(':')[0].split(' ')[0]),
        minute: int.parse(_controllers['startTime']!.text.split(':')[1].split(' ')[0]),
      );
      final endTime = TimeOfDay(
        hour: int.parse(_controllers['endTime']!.text.split(':')[0].split(' ')[0]),
        minute: int.parse(_controllers['endTime']!.text.split(':')[1].split(' ')[0]),
      );

      // Convert to minutes for comparison
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      
    } catch (e) {
      _logger.e('Error parsing time: $e');
      return 'Invalid time format';
    }

    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter $fieldName';
    }
    if (_profanityFilter.hasProfanity(value)) {
      return '$fieldName contains inappropriate language.';
    }
    return null;
  }

  String? _validateLocation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a location';
    }
    if (_profanityFilter.hasProfanity(value)) {
      return 'Location contains inappropriate language.';
    }
    if (_controllers['latitude']!.text.isEmpty || 
        _controllers['longitude']!.text.isEmpty) {
      return 'Please confirm location on the map';
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)
        ),
      )
    );
  }

  Future<void> _handleError(dynamic error, String operation) async {
    _logger.e('Error during $operation: $error');
    if (!mounted) return;
    
    String errorMessage = error is Exception ? error.toString() :
                         error is String ? error :
                         'An unexpected error occurred during $operation';

    _showMessage(errorMessage, isError: true);
  }

  Future<void> _updateEvent(Map<String, dynamic> updateData) async {
    try {
      await Supabase.instance.client
          .from('Events')
          .update(updateData)
          .eq('event_id', widget.event['event_id']);
    } catch (e) {
      await _handleError(e, 'updating event');
      rethrow;
    }
  }

  Future<String?> _handleImageUpload() async {
    if (_image == null) return widget.event['image_url'];
    
    try {
      final imageUrl = await _uploadImage(_image!);
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }
      return imageUrl;
    } catch (e) {
      await _handleError(e, 'uploading image');
      rethrow;
    }
  }

  Future<void> _handleSave() async {
    if (!mounted) return;

              final currentUser = Supabase.instance.client.auth.currentUser;
              if (currentUser == null) {
      _showMessage('Please log in to edit an event', isError: true);
                return;
              }

              if (!_formKey.currentState!.validate()) {
      _showMessage('Please fill in all required fields correctly', isError: true);
                return;
              }

              final validationError = _validateForm();
              if (validationError != null) {
      _showMessage(validationError, isError: true);
                return;
              }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _handleImageUpload();
      final selectedDays = _showTextField && _selectedDays.isNotEmpty 
          ? _selectedDays 
          : [];

      final updateData = {
        'title': _controllers['eventName']!.text,
        'description': _controllers['description']!.text,
        'location': _controllers['location']!.text,
        'latitude': double.tryParse(_controllers['latitude']!.text),
        'longitude': double.tryParse(_controllers['longitude']!.text),
                  'image_url': imageUrl,
        'time_start': _controllers['startTime']!.text,
        'time_end': _controllers['endTime']!.text,
                  'days': selectedDays,
                  'tags': _selectedTags,
        'recurring_event': _showTextField,
        'start_date': _controllers['startDate']!.text,
        'end_date': _showTextField 
            ? _controllers['endDate']!.text 
            : _controllers['startDate']!.text,
      };

                await _updateEvent(updateData);

                if (widget.onEventUpdated != null) {
                  widget.onEventUpdated!();
                }

      _showMessage('Event updated successfully!');
      Navigator.pop(context);
              } catch (e) {
      _showMessage(
        e is Exception ? e.toString() : 'Error updating event: $e',
        isError: true
      );
              } finally {
                if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _getThemeColors(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _handleSave,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          color: colors['backgroundColor'],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(colors),
                const SizedBox(height: _spacing),
                _buildEventDetails(colors),
                const SizedBox(height: _spacing),
                _buildLocationField(colors),
                const SizedBox(height: _spacing),
                _buildDescriptionField(colors),
                const SizedBox(height: _spacing),
                _buildRecurringEventToggle(colors),
                if (_showTextField) ...[
                  _buildWeekDaysPicker(),
                  const SizedBox(height: _spacing),
                  _buildDateFields(colors),
                ] else
                  _buildSingleDateField(colors),
                const SizedBox(height: _spacing),
                _buildTimeFields(colors),
                const SizedBox(height: _spacing),
                _buildTagsButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getThemeColors(bool isDark) {
    return {
      'backgroundColor': isDark ? const Color(0xFF1A1A1A) : Colors.white,
      'textColor': isDark ? Colors.white : Colors.black,
      'iconColor': isDark ? Colors.white : Colors.black,
      'inputColor': isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
      'borderColor': isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0),
      'hintColor': isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
      'selectedColor': isDark ? const Color(0xFF64B5F6) : Colors.blue,
    };
  }

  Widget _buildImageSection(Map<String, Color> colors) {
    return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
          height: _imageHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
            border: Border.all(color: colors['borderColor']!),
            borderRadius: BorderRadius.circular(_borderRadius),
            color: colors['inputColor'],
          ),
          child: _buildImageContent(colors),
        ),
        const SizedBox(height: _spacing),
        _buildImageButtons(colors),
      ],
    );
  }

  Widget _buildImageContent(Map<String, Color> colors) {
    if (_image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
                              child: Image.file(_image!, fit: BoxFit.cover),
      );
    }
    
    if (widget.event['image_url'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
                                  child: Image.network(
                                    widget.event['image_url'],
                                    fit: BoxFit.cover,
                                  ),
      );
    }
    
    return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
          Icon(Icons.image, size: 50, color: colors['hintColor']),
          const SizedBox(height: 8),
          Text(
            "No image selected",
            style: TextStyle(color: colors['hintColor'])
                                      ),
                                    ],
                                  ),
    );
  }

  Widget _buildImageButtons(Map<String, Color> colors) {
    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
        _buildImageButton(
          "Camera",
          () => _pickImage(ImageSource.camera),
          colors,
        ),
        const SizedBox(width: 20),
        _buildImageButton(
          "Gallery",
          () => _pickImage(ImageSource.gallery),
          colors,
        ),
      ],
    );
  }

  Widget _buildImageButton(
    String text,
    VoidCallback onPressed,
    Map<String, Color> colors,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
                          style: ElevatedButton.styleFrom(
        backgroundColor: colors['selectedColor'],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
      child: Text(text),
    );
  }

  Widget _buildEventDetails(Map<String, Color> colors) {
    return TextFormField(
      controller: _controllers['eventName'],
      style: TextStyle(color: colors['textColor']),
                  validator: (value) => _validateRequired(value, 'event name'),
      decoration: _getInputDecoration(
        'Event name',
        colors,
      ),
    );
  }

  Widget _buildLocationField(Map<String, Color> colors) {
    return TextFormField(
      controller: _controllers['location'],
      style: TextStyle(color: colors['textColor']),
                  validator: _validateLocation,
      decoration: _getInputDecoration(
        'Location',
        colors,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map_outlined),
          color: colors['iconColor'],
                      onPressed: _openMapDialog,
                    ),
      ),
    );
  }

  Widget _buildDescriptionField(Map<String, Color> colors) {
    return TextFormField(
      controller: _controllers['description'],
      style: TextStyle(color: colors['textColor']),
                  maxLines: 3,
                  keyboardType: TextInputType.text,
                  validator: (value) => _validateRequired(value, 'description'),
      decoration: _getInputDecoration(
        'Description',
        colors,
      ),
    );
  }

  Widget _buildRecurringEventToggle(Map<String, Color> colors) {
    return Row(
                  children: [
                    Switch(
          value: _showTextField,
                      onChanged: (value) {
                        setState(() {
              _showTextField = value;
                          if (!value) {
                            _selectedDays = [];
                          }
                        });
                      },
          activeColor: colors['selectedColor'],
          activeTrackColor: colors['selectedColor']!.withOpacity(0.5),
          inactiveTrackColor: colors['borderColor'],
        ),
        Text(
          'Recurring Event',
          style: TextStyle(color: colors['textColor']),
        ),
      ],
    );
  }

  Widget _buildWeekDaysPicker() {
    return SelectWeekDays(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    days: _days,
                    border: false,
                    width: MediaQuery.of(context).size.width / 0.5,
                    boxDecoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                    onSelect: (values) {
        setState(() => _selectedDays = values);
      },
    );
  }

  Widget _buildDateFields(Map<String, Color> colors) {
    return Column(
      children: [
        _buildDateField(
          _controllers['startDate']!,
          'Start Date',
          colors,
          (value) => _validateDate(value, 'start date'),
        ),
        SizedBox(height: _spacing),
        _buildDateField(
          _controllers['endDate']!,
          'End Date',
          colors,
          (value) => _validateDate(value, 'end date'),
        ),
      ],
    );
  }

  Widget _buildSingleDateField(Map<String, Color> colors) {
    return _buildDateField(
      _controllers['startDate']!,
      'Date',
      colors,
      (value) => _validateDate(value, 'date'),
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String label,
    Map<String, Color> colors,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colors['textColor']),
      validator: validator,
      readOnly: true,
      decoration: _getInputDecoration(
        label,
        colors,
                    ),
                    onTap: () async {
        final now = DateTime.now();
        final firstDate = DateTime(now.year, now.month, now.day);
        
        DateTime initialDate;
        if (controller.text.isEmpty) {
          initialDate = now;
        } else {
          try {
            initialDate = DateTime.parse(controller.text);
            if (initialDate.isBefore(firstDate)) {
              initialDate = now;
            }
          } catch (e) {
            initialDate = now;
          }
        }

        final datetime = await showDatePicker(
                        context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: DateTime(_maxYear),
                      );

                      if (datetime != null) {
          final formattedDate = DateFormat('yyyy-MM-dd').format(datetime);
                        setState(() {
            controller.text = formattedDate;
                        });
                      }
                    },
    );
  }

  Widget _buildTimeFields(Map<String, Color> colors) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeField(
            _controllers['startTime']!,
            'Start Time',
            colors,
          ),
        ),
        const SizedBox(width: _spacing),
        Expanded(
          child: _buildTimeField(
            _controllers['endTime']!,
            'End Time',
            colors,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(
    TextEditingController controller,
    String label,
    Map<String, Color> colors,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colors['textColor']),
      validator: (value) => _validateTime(value, label.toLowerCase()),
      readOnly: true,
      decoration: _getInputDecoration(
        label,
        colors,
                    ),
                    onTap: () async {
        final time = await showTimePicker(
                        context: context,
          initialTime: TimeOfDay.now(),
        );

        if (time != null) {
                        setState(() {
            controller.text = time.format(context);
                        });
                      }
                    },
    );
  }

  Widget _buildTagsButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _tagsbox,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      child: const Text("Edit Tags"),
    );
  }

  InputDecoration _getInputDecoration(
    String label,
    Map<String, Color> colors, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: colors['borderColor']!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: colors['borderColor']!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide(color: colors['selectedColor']!),
      ),
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 16,
        color: colors['hintColor'],
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors['inputColor'],
    );
  }

  String? _validateDate(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please select $fieldName';
    }
    return null;
  }

  String? _validateTime(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please select $fieldName';
    }
    return null;
  }
}

class _TagsDialog extends StatefulWidget {
  final TextEditingController customTagController;
  final List<String> selectedTags;
  final List<String> availableTags;
  final ProfanityFilter profanityFilter;

  const _TagsDialog({
    required this.customTagController,
    required this.selectedTags,
    required this.availableTags,
    required this.profanityFilter,
  });

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _getThemeColors(isDark);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: _buildTitle(colors),
      content: SizedBox(
        height: 400,
        width: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomTagInput(colors),
            const SizedBox(height: 20),
            _buildAvailableTags(colors),
          ],
        ),
      ),
      actions: [
        _buildActions(colors),
      ],
    );
  }

  Map<String, Color> _getThemeColors(bool isDark) {
    return {
      'textColor': isDark ? Colors.white : Colors.black,
      'inputColor': isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
      'hintColor': isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
      'dividerColor': isDark ? const Color(0xFF404040) : const Color(0xFFE0E0E0),
      'selectedColor': isDark ? const Color(0xFF64B5F6) : Colors.blue,
    };
  }

  Widget _buildTitle(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors['dividerColor']!,
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
              color: colors['textColor'],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors['hintColor']),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTagInput(Map<String, Color> colors) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors['inputColor'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
              controller: widget.customTagController,
              style: TextStyle(color: colors['textColor']),
                        decoration: InputDecoration(
                hintText: 'Add custom tag...',
                hintStyle: TextStyle(color: colors['hintColor']),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors['selectedColor'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: _addCustomTag,
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomTag() {
    final newTag = widget.customTagController.text.trim();
    if (newTag.isNotEmpty && !widget.availableTags.contains(newTag)) {
      if (widget.profanityFilter.hasProfanity(newTag)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom tag contains inappropriate language.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
                            setState(() {
          widget.availableTags.add(newTag);
          _selectedTags.add(newTag);
          widget.customTagController.clear();
        });
      }
    }
  }

  Widget _buildAvailableTags(Map<String, Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Tags',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors['textColor'],
          ),
        ),
        SizedBox(height: 10),
                    Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: widget.availableTags.map((tag) {
                return ChoiceChip(
                  label: Text(
                    tag,
                    style: TextStyle(
                      color: _selectedTags.contains(tag)
                          ? Colors.white
                          : colors['textColor'],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: _selectedTags.contains(tag),
                  selectedColor: colors['selectedColor'],
                  backgroundColor: colors['inputColor'],
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (selected) {
                            setState(() {
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
    );
  }

  Widget _buildActions(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors['dividerColor']!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_selectedTags);
            },
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors['selectedColor'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
