import 'package:flutter/material.dart';
import 'package:icebreaker/Models/edit_radius.dart';
import 'package:icebreaker/main.dart';
import 'package:icebreaker/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:icebreaker/Models/my_event.dart';
import 'package:icebreaker/Models/user_preferrences.dart';
final _logger = Logger();
  
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  
  String? _backgroundPath;
  


  @override
  void initState() {
    super.initState();
    _loadBackgroundPath();
  }

  Future<void> _loadBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundPath = prefs.getString('background_image_path');
    });
  }

  Future<void> _pickAndSaveBackgroundImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    final localPath = pickedFile.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_image_path', pickedFile.path);
    
    setState(() {
      _backgroundPath = pickedFile.path;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Background updated!')),
    );
  }

  void _showImagePickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Select Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndSaveBackgroundImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndSaveBackgroundImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Reset to Default'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('background_image_path');
                  setState(() {
                    _backgroundPath = null;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancel'),
                onTap: () {
                  Navigator.of(context).pop();
                 },
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to handle theme change
  void _handleThemeChange(ThemeMode value, BuildContext dialogContext) {
    if (value == ThemeMode.light) {
      AppConfig.setTheme('light');
    } else {
      AppConfig.setTheme('dark');
    }
    themeNotifier.value = value;
    Navigator.of(dialogContext).pop();
  }

  // Function to show theme selection dialog
  void _showThemeDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: themeNotifier.value,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    _handleThemeChange(value, dialogContext);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: themeNotifier.value,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    _handleThemeChange(value, dialogContext);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme brightness to adjust text/icon colors
    final Brightness currentBrightness = Theme.of(context).brightness;
    final Color textColor = currentBrightness == Brightness.dark ? Colors.white : Colors.black;
    final Color iconColor = currentBrightness == Brightness.dark ? Colors.white : Colors.black;
    final Color appBarColor = currentBrightness == Brightness.dark ? AppConfig.themes['dark']!.appBarTheme.backgroundColor! : AppConfig.themes['light']!.appBarTheme.backgroundColor!;
    final Color appBarForegroundColor = currentBrightness == Brightness.dark ? AppConfig.themes['dark']!.appBarTheme.foregroundColor! : AppConfig.themes['light']!.appBarTheme.foregroundColor!;

    return Scaffold(
      appBar: AppBar(
        // Use theme color
        backgroundColor: appBarColor,
        leading: IconButton(
          // Use theme color
          icon: Icon(Icons.arrow_back, color: appBarForegroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Use theme color
        title: Text('Settings', style: TextStyle(color: appBarForegroundColor)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ListTile(
            // Use theme color
            title: Text('Edit Theme', style: TextStyle(fontSize: 15, color: textColor)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor), // Added trailing icon
            onTap: _showThemeDialog, // Updated onTap
          ),
          ListTile(
            // Use theme color
            title: Text('Edit Background', style: TextStyle(fontSize: 15, color: textColor)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor), // Added trailing icon
            onTap: () {
              _showImagePickerModal(context);
            },
          ),
          ListTile(
            // Use theme color
            title: Text('My Events', style: TextStyle(fontSize: 15, color: textColor)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor), // Added trailing icon
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyEvent()));
            },
          ),
          
           Divider(color: iconColor.withValues(alpha: 0.5)), // Added divider
          ListTile(
            // Use theme color
            title: Text('Sign Out', style: TextStyle(fontSize: 15, color: Colors.redAccent)), // Changed color for emphasis
             trailing: Icon(Icons.logout, size: 16, color: Colors.redAccent), // Added trailing icon
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              // Clear global userId
              userId = null;

              // Use pushAndRemoveUntil for cleaner navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()), // Added const
                (Route<dynamic> route) => false, // Remove all previous routes
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late String username = '';
  late String profilePic = '';
  late String userBio = '';
  late int userRadius = 0;
  late bool isPrivate = false;
  

  bool isLoading = true;

  late String _originalUsername;
  late String _originalBio;
  late int _originalRadius;
  late bool _originalPrivate;

  //controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final _radiusController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _loadUserData();
    //_loadTagsAndCategories();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  //fetch user data from Supa
  Future<Map<String, dynamic>?> _fetchUserData() async {
    final response = await Supabase.instance.client
        .from('Users')
        .select()
        .eq('user_id', userId.toString())
        .single();

    return response;
  }

  // Function to fetch user data
  Future<void> _loadUserData() async {
    try {
      final userData = await _fetchUserData(); 
      if (!mounted) return;
      
      setState(() {
        username = userData?['username'] ?? 'Unknown';
        profilePic = userData?['profile_pic'] ?? '';
        userBio = userData?['bio'] ?? '';
        userRadius = userData?['radius_meters'] ?? 0;
        isPrivate = userData?['private'] ?? false;

        _originalUsername = username;
        _originalBio = userBio;
        _originalRadius = userRadius;
        _originalPrivate = isPrivate;

        _usernameController.text = username;
        _bioController.text = userBio;
        _radiusController.text = userRadius.toString();

        isLoading = false; 
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  //fetch images
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (!mounted) return;
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image was selected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Function to upload image to Supabase storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload the file
      await Supabase.instance.client.storage.from('prof_images').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
            ),
          );

      // Get public URL
      final imageUrl = Supabase.instance.client.storage
          .from('prof_images')
          .getPublicUrl(fileName);
      
      if (!mounted) return null;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully uploaded image'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      return imageUrl;
    } catch (e) {
      if (!mounted) return null;
      
      String errorMessage = 'Error uploading image';
      if (e is StorageException) {
        errorMessage = 'Storage error: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (!mounted) return;

    // Get current values from the text fields
    final newUsername = _usernameController.text.trim();
    final newBio = _bioController.text.trim();
    final newRadiusText = _radiusController.text.trim();
    final newRadius = int.tryParse(newRadiusText);

    // Compare and only update if there's a change
    if (newUsername != username || newBio != userBio || newRadius != userRadius || isPrivate != _originalPrivate) {
      await Supabase.instance.client
        .from('Users')
        .update({
          if (newUsername != username) 'username': newUsername,
          if (newBio != userBio) 'bio': newBio,
          if (newRadius != userRadius) 'radius_meters': newRadius,
          if (isPrivate != _originalPrivate) 'private': isPrivate,
        })
        .eq('user_id', userId.toString());
    }

    if (_image != null) {
      String? imageUrl = await _uploadImage(_image!);
      if (imageUrl != null && mounted) {
        await Supabase.instance.client
            .from('Users')
            .update({'profile_pic': imageUrl})
            .eq('user_id', userId.toString());
      }
    }
  }

  Future<bool?> _showSaveDialog() async {
    if (!mounted) return null;
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Save Changes?"),
          content: Text("Do you want to save your changes before leaving?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("Discard"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

 

  @override
  Widget build(BuildContext context) {
    // Get current theme colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final appBarColor = isDark ? Colors.grey[900] : Colors.white;
    final appBarForegroundColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            final currentUsername = _usernameController.text.trim();
            final currentBio = _bioController.text.trim();
            final currentRadius = int.tryParse(_radiusController.text.trim());

            if (currentUsername == _originalUsername && 
                currentBio == _originalBio && 
                _image == null && 
                currentRadius == _originalRadius && 
                isPrivate == _originalPrivate) {
              if (!mounted) return;
              Navigator.of(context).pop();
              return;
            }
            
            final result = await _showSaveDialog();
            if (result == null) return;

            if (result) {
              await _saveChanges();
            }

            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ),
        title: Text('Profile Settings', style: TextStyle(color: appBarForegroundColor)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      builder: (BuildContext context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(Icons.photo_library),
                                title: Text('Select Photo'),
                                onTap: () {
                                  //Choose from gallery
                                  _pickImage(ImageSource.gallery);
                                  Navigator.of(context).pop();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.camera_alt),
                                title: Text('Take Photo'),
                                onTap: () {
                                  // Use camera
                                  
                                  _pickImage(ImageSource.camera);
                                  Navigator.of(context).pop();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.cancel),
                                title: Text('Cancel'),
                                onTap: () {
                                  
                                  Navigator.of(context).pop();
                                  
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Stack(
                    children: [
                      // Circle Avatar
                      CircleAvatar(
                        radius: 80,
                        backgroundColor: cardColor,
                        backgroundImage: _image != null
                              ? FileImage(_image!) as ImageProvider 
                              : (profilePic.isNotEmpty
                              ? NetworkImage(profilePic)
                              : NetworkImage('https://cdn4.iconfinder.com/data/icons/miscellaneous-icons-4/200/powerups_ice_cube-512.png')),
                      ),
                      // Darker overlay
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha:0.6),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                    
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username 
                      TextFormField(
                        controller: _usernameController,
                        maxLength: 30,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cardColor,
                          hintText: username,
                          hintStyle: TextStyle(color: textColor),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      //Description
                      Stack(
                        children: [
                          TextFormField(
                            controller: _bioController,
                            minLines: 4,

                            maxLines: 6,
                            maxLength: 132,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cardColor,
                              hintText: "Bio...",
                              hintStyle: TextStyle(color: textColor),
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(Icons.edit, color: iconColor),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Edit confirmed'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            UserPreferences(),
            SizedBox(height: 80),
            // List Options
            SizedBox(
              height: 400,
              child: ListView(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock, color: iconColor),
                    title: Text('Change Email', style: TextStyle(color: textColor)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChangeEmailPage()),
                       );
                    },
                  ),
                  Divider(color: iconColor.withValues(alpha:0.5)),
                  ListTile(
                    leading: Icon(Icons.lock, color: iconColor),
                    title: Text('Change Password', style: TextStyle(color: textColor)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChangePasswordPage()),
                       );
                    },
                  ),
                  Divider(),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                  title: Text('Privacy Settings'),
                  leading: Icon(Icons.privacy_tip),
                  children: [
                    SwitchListTile(
                      title: Text('Privacy Mode'),
                      value: isPrivate,
                      onChanged: (bool value) {
                        setState(() {
                          isPrivate = value;
                        });
                      },
                    ),
                    SizedBox(height: 10),

                    ListTile(
                      title: Text('Edit Find radius', style: TextStyle(fontSize: 15, color: textColor)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor), // Added trailing icon
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditRadius()), // Added const
                        );
                      },
                    ),

                    SizedBox(height: 10),
                  ],
                ),),
                  
                  // Divider(),

                  // ListTile(
                  //   leading: Icon(Icons.notifications, color: iconColor),
                  //   title: Text('Notification Settings', style: TextStyle(color: textColor)),
                  //   trailing: Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
                  //   onTap: () {
                  //     _logger.i("Navigate to Notification Settings");
                  //   },
                  // ),
                ],
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }
}



class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _updateEmail() async {
    if (!mounted) return;
    
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: email),
        );

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email updated successfully',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            SizedBox(height: 60),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Email',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          ElevatedButton(
                            onPressed: _updateEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              'Send Email',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _updatePassword() async {
    if (!mounted) return;
    
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final newPassword = _passwordController.text.trim();
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password updated successfully',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            SizedBox(height: 60),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Password',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              } else if (value.length < 6) {
                                return 'Password must be at least 6 characters long';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Confirm Password',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              } else if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          ElevatedButton(
                            onPressed: _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              'Change Password',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
