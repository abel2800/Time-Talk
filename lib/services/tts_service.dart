import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Text-to-Speech Service for Talk Time
/// Simple approach: set language, speak numbers - TTS does the rest

class TtsService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  
  double _volume = 1.0;
  double _rate = 0.5;
  double _pitch = 1.0;
  String _language = 'en-US';
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  double get volume => _volume;
  double get rate => _rate;
  double get pitch => _pitch;
  String get language => _language;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  
  TtsService() {
    _initTts();
  }
  
  Future<void> _initTts() async {
    try {
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
      });
      
      await _applyAllSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }
  
  Future<void> _applyAllSettings() async {
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setLanguage(_language);
    debugPrint('TTS settings applied: lang=$_language, vol=$_volume, rate=$_rate');
  }
  
  /// Speak text - language must already be set
  Future<void> speak(String text) async {
    if (!_isInitialized) await _initTts();
    
    try {
      // Make sure language is set before speaking
      await _flutterTts.setLanguage(_language);
      await _flutterTts.speak(text);
      debugPrint('TTS speaking "$text" in $_language');
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    notifyListeners();
  }
  
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
    notifyListeners();
  }
  
  Future<void> setRate(double value) async {
    _rate = value.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_rate);
    notifyListeners();
  }
  
  Future<void> setPitch(double value) async {
    _pitch = value.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
    notifyListeners();
  }
  
  /// Set language for TTS
  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    debugPrint('TTS language set to: $languageCode');
    
    try {
      await _flutterTts.stop();
      final result = await _flutterTts.setLanguage(languageCode);
      debugPrint('TTS setLanguage result: $result');
    } catch (e) {
      debugPrint('TTS setLanguage error: $e');
    }
    notifyListeners();
  }
  
  /// Test voice - say localized time using intl DateFormat
  Future<void> testVoice() async {
    final sampleTime = DateTime(2024, 1, 1, 12, 30);
    try {
      String locale = _language.replaceAll('-', '_');
      final formatted = DateFormat.jm(locale).format(sampleTime);
      await speak(formatted);
    } catch (e) {
      await speak('12:30 PM');
    }
  }
  
  void loadSettings({
    required double volume,
    required double rate,
    required String language,
  }) {
    _volume = volume;
    _rate = rate;
    _language = language;
    _applyAllSettings();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
