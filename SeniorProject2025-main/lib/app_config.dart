import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _themeKey = 'app_theme';
  static const String _backgroundKey = 'app_background';
  
  // Default values
  static const String defaultTheme = 'light';
  static const String defaultBackground = 'default';

  // Available themes
  static final Map<String, ThemeData> themes = {
    'light': ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    ),
    'dark': ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color.fromARGB(255, 125, 213, 233), // Purple accent
      scaffoldBackgroundColor: Color(0xFF121212), // Deep dark background
      cardColor: Color(0xFF1E1E1E), // Slightly lighter for cards
      colorScheme: const ColorScheme.dark(
        primary: Color.fromARGB(255, 125, 213, 233), // Purple accent
        secondary: Color.fromARGB(255, 31, 175, 207), // Secondary purple
        surface: Color(0xFF121212), // Main background
        surfaceTint: Color(0xFF1E1E1E), // Surface tint color
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121212),
        selectedItemColor: Color.fromARGB(255, 114, 213, 246),
        unselectedItemColor: Colors.grey,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Color.fromARGB(255, 125, 213, 233)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(255, 125, 213, 233),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    ),
  };

  // Available backgrounds
  static final Map<String, String> backgrounds = {
    'default': 'assets/images/default_background.jpg',
    'gradient': 'assets/images/gradient_background.jpg',
    'pattern': 'assets/images/pattern_background.jpg',
  };

  // Get current theme
  static Future<String> getCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? defaultTheme;
  }

  // Set theme
  static Future<void> setTheme(String themeName) async {
    if (!themes.containsKey(themeName)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }

  // Get current background
  static Future<String> getCurrentBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundKey) ?? defaultBackground;
  }

  // Set background
  static Future<void> setBackground(String backgroundName) async {
    if (!backgrounds.containsKey(backgroundName)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundKey, backgroundName);
  }
} 