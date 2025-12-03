import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Text-to-Speech Service for TimeTalk
/// Handles all voice output functionality with accessibility focus
/// 
/// This service provides:
/// - Time announcements
/// - Settings feedback
/// - Language support
/// - Volume and rate control

class TtsService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  
  // TTS Settings
  double _volume = 1.0;
  double _rate = 0.5;
  double _pitch = 1.0;
  String _language = 'en-US';
  List<dynamic> _availableLanguages = [];
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // Getters
  double get volume => _volume;
  double get rate => _rate;
  double get pitch => _pitch;
  String get language => _language;
  List<dynamic> get availableLanguages => _availableLanguages;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  
  TtsService() {
    _initTts();
  }
  
  /// Initialize TTS engine with default settings
  Future<void> _initTts() async {
    try {
      // Set up completion handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
        notifyListeners();
      });
      
      // Get available languages
      _availableLanguages = await _flutterTts.getLanguages ?? [];
      
      // Apply initial settings
      await _applySettings();
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }
  
  /// Apply current settings to TTS engine
  Future<void> _applySettings() async {
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setLanguage(_language);
    
    // Android-specific settings for better accessibility
    // These may not be available on all platforms
    try {
      await _flutterTts.setQueueMode(1); // Add to queue instead of flushing
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      // Ignore if not supported on this platform
      debugPrint('TTS platform-specific settings not available: $e');
    }
  }
  
  /// Speak the given text
  /// Primary method for all voice output
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }
  
  /// Speak the current time
  /// Formats and announces the time clearly
  Future<void> speakTime(String formattedTime) async {
    await speak(formattedTime);
  }
  
  /// Stop any ongoing speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
    notifyListeners();
  }
  
  /// Set speech rate (0.0 to 1.0)
  /// 0.5 is normal speed
  Future<void> setRate(double value) async {
    _rate = value.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_rate);
    notifyListeners();
  }
  
  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double value) async {
    _pitch = value.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
    notifyListeners();
  }
  
  /// Set language
  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    await _flutterTts.setLanguage(_language);
    notifyListeners();
  }
  
  /// Test voice with sample text
  Future<void> testVoice() async {
    await speak('12:30 PM');
  }
  
  /// Load settings from stored preferences
  void loadSettings({
    required double volume,
    required double rate,
    required String language,
  }) {
    _volume = volume;
    _rate = rate;
    _language = language;
    _applySettings();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

