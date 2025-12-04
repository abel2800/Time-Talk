import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings Provider for TimeTalk
/// Manages all app settings with persistence
/// 
/// Features:
/// - Touch-to-speak toggle
/// - Vibration feedback toggle
/// - Dark mode
/// - Volume and rate settings
/// - Language preference

class SettingsProvider extends ChangeNotifier {
  // Touch and feedback settings
  bool _touchToSpeakEnabled = true;
  bool _vibrationEnabled = true;
  bool _blockTouchDuringQuiet = false;
  
  // Appearance
  bool _darkMode = true;
  
  // Voice settings
  double _volume = 1.0;
  double _rate = 0.5;
  String _language = 'en-US';
  
  // Repeat settings - how many times to say the time
  int _repeatCount = 2; // Default: say time twice
  
  // Getters
  bool get touchToSpeakEnabled => _touchToSpeakEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get blockTouchDuringQuiet => _blockTouchDuringQuiet;
  bool get darkMode => _darkMode;
  double get volume => _volume;
  double get rate => _rate;
  String get language => _language;
  int get repeatCount => _repeatCount;
  
  /// Set touch-to-speak enabled
  void setTouchToSpeakEnabled(bool value) {
    _touchToSpeakEnabled = value;
    notifyListeners();
    _saveSettings();
  }
  
  /// Set vibration feedback enabled
  void setVibrationEnabled(bool value) {
    _vibrationEnabled = value;
    notifyListeners();
    _saveSettings();
  }
  
  /// Set whether to block touch during quiet hours
  void setBlockTouchDuringQuiet(bool value) {
    _blockTouchDuringQuiet = value;
    notifyListeners();
    _saveSettings();
  }
  
  /// Set dark mode
  void setDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
    _saveSettings();
  }
  
  /// Set voice volume
  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
    _saveSettings();
  }
  
  /// Set voice rate/speed
  void setRate(double value) {
    _rate = value.clamp(0.1, 1.0);
    notifyListeners();
    _saveSettings();
  }
  
  /// Set language
  void setLanguage(String value) {
    _language = value;
    notifyListeners();
    _saveSettings();
  }
  
  /// Set repeat count (how many times to say the time)
  void setRepeatCount(int value) {
    _repeatCount = value.clamp(1, 5); // 1 to 5 times
    notifyListeners();
    _saveSettings();
  }
  
  /// Save all settings to shared preferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('touchToSpeakEnabled', _touchToSpeakEnabled);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
    await prefs.setBool('blockTouchDuringQuiet', _blockTouchDuringQuiet);
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setDouble('volume', _volume);
    await prefs.setDouble('rate', _rate);
    await prefs.setString('language', _language);
    await prefs.setInt('repeatCount', _repeatCount);
  }
  
  /// Load all settings from shared preferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _touchToSpeakEnabled = prefs.getBool('touchToSpeakEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    _blockTouchDuringQuiet = prefs.getBool('blockTouchDuringQuiet') ?? false;
    _darkMode = prefs.getBool('darkMode') ?? true;
    _volume = prefs.getDouble('volume') ?? 1.0;
    _rate = prefs.getDouble('rate') ?? 0.5;
    _language = prefs.getString('language') ?? 'en-US';
    _repeatCount = prefs.getInt('repeatCount') ?? 2; // Default: twice
    notifyListeners();
  }
  
  /// Get appropriate theme data
  ThemeData getTheme() {
    if (_darkMode) {
      return ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF161B22),
          elevation: 4,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.teal[400],
          inactiveTrackColor: Colors.grey[700],
          thumbColor: Colors.teal[300],
          overlayColor: Colors.teal.withOpacity(0.2),
          trackHeight: 8,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 14,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.teal[300];
            }
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.teal[700];
            }
            return Colors.grey[800];
          }),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(
          color: Colors.teal[300],
          size: 28,
        ),
        useMaterial3: true,
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.teal[600],
          inactiveTrackColor: Colors.grey[300],
          thumbColor: Colors.teal[700],
          overlayColor: Colors.teal.withOpacity(0.2),
          trackHeight: 8,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 14,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(
          color: Colors.teal[700],
          size: 28,
        ),
        useMaterial3: true,
      );
    }
  }
}

