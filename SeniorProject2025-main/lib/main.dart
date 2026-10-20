import 'package:flutter/material.dart';
import 'package:icebreaker/app_config.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:icebreaker/assets/database/poll_cache.dart';

final _logger = Logger();

//global variable for user IDs
String? userId;

// Global ValueNotifier for theme changes
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

//get JWT from SharedPrefs
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt_token');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the saved theme preference
  final String savedTheme = await AppConfig.getCurrentTheme();
  themeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;

  await Supabase.initialize(
    url: 'https://qnsgvzqishmmzbgwymtb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFuc2d2enFpc2htbXpiZ3d5bXRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA2MzU1MDEsImV4cCI6MjA1NjIxMTUwMX0.dTdmJ6UJNstNm9ihkWECPFpjeadCcLgKeOnZsOtMKNw',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PollCache()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    bool authenticated = false;

    if (token != null && !JwtDecoder.isExpired(token)) {
      // Extract userId from token
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        userId = decodedToken['sub']; // Assuming 'sub' contains the userId
        authenticated = true;
      } catch (e) {
        _logger.e("Error decoding token: $e");
        await prefs.remove('jwt_token'); // Remove invalid token
      }
    } else {
      // Remove expired or invalid token if present
      if (token != null) {
         await prefs.remove('jwt_token');
      }
    }
    // Use mounted check before calling setState
    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking auth state
    if (_isAuthenticated == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Use ValueListenableBuilder to rebuild MaterialApp on theme change
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Icebreaker',
          theme: AppConfig.themes['light'],
          darkTheme: AppConfig.themes['dark'],
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: _isAuthenticated! ? const HomePage() : const LoginPage(),
        );
      },
    );
  }
}

