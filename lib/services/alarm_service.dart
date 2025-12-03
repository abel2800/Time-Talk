import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../utils/time_utils.dart';
import 'background_service.dart';

/// Alarm Service for Talk Time
/// Manages settings and communicates with background service

class AlarmService extends ChangeNotifier {
  Timer? _announcementTimer;
  DateTime? _lastAnnouncement;
  
  int _intervalMinutes = 0;
  bool _quietModeEnabled = false;
  int _quietStartHour = 22;
  int _quietStartMinute = 0;
  int _quietEndHour = 7;
  int _quietEndMinute = 0;
  
  Function(String)? onAnnounce;
  
  // Getters
  int get intervalMinutes => _intervalMinutes;
  bool get quietModeEnabled => _quietModeEnabled;
  int get quietStartHour => _quietStartHour;
  int get quietStartMinute => _quietStartMinute;
  int get quietEndHour => _quietEndHour;
  int get quietEndMinute => _quietEndMinute;
  bool get isScheduled => _intervalMinutes > 0;
  
  /// Set interval and update background service
  void setInterval(int minutes) {
    _intervalMinutes = minutes;
    _saveSettings();
    
    // Update background service
    BackgroundService.updateInterval(minutes);
    
    // Also run in-app timer for when app is in foreground
    _startInAppTimer();
    
    notifyListeners();
  }
  
  /// Start in-app timer (for when app is open)
  void _startInAppTimer() {
    _announcementTimer?.cancel();
    
    if (_intervalMinutes <= 0) return;
    
    _lastAnnouncement = DateTime.now();
    
    _announcementTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_intervalMinutes <= 0) return;
      
      final now = DateTime.now();
      
      if (_lastAnnouncement != null) {
        final elapsed = now.difference(_lastAnnouncement!).inMinutes;
        if (elapsed < _intervalMinutes) return;
      }
      
      if (_quietModeEnabled && TimeUtils.isQuietTime(
        now, _quietStartHour, _quietStartMinute, _quietEndHour, _quietEndMinute,
      )) {
        return;
      }
      
      _lastAnnouncement = now;
      
      // Vibrate if enabled (reload from prefs)
      final prefs = await SharedPreferences.getInstance();
      final vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      if (vibrationEnabled) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          Vibration.vibrate(duration: 200);
        }
      }
      
      final timeText = TimeUtils.formatTimeForSpeech(now);
      onAnnounce?.call(timeText);
    });
  }
  
  void setQuietModeEnabled(bool enabled) {
    _quietModeEnabled = enabled;
    _saveSettings();
    _updateQuietHours();
    notifyListeners();
  }
  
  void setQuietStartTime(int hour, int minute) {
    _quietStartHour = hour;
    _quietStartMinute = minute;
    _saveSettings();
    _updateQuietHours();
    notifyListeners();
  }
  
  void setQuietEndTime(int hour, int minute) {
    _quietEndHour = hour;
    _quietEndMinute = minute;
    _saveSettings();
    _updateQuietHours();
    notifyListeners();
  }
  
  void _updateQuietHours() {
    BackgroundService.updateQuietHours(
      enabled: _quietModeEnabled,
      startHour: _quietStartHour,
      startMinute: _quietStartMinute,
      endHour: _quietEndHour,
      endMinute: _quietEndMinute,
    );
  }
  
  bool isCurrentlyQuiet() {
    if (!_quietModeEnabled) return false;
    return TimeUtils.isQuietTime(
      DateTime.now(), _quietStartHour, _quietStartMinute, _quietEndHour, _quietEndMinute,
    );
  }
  
  String get quietStartTimeString => 
    TimeUtils.formatPickerTime(_quietStartHour, _quietStartMinute);
  
  String get quietEndTimeString => 
    TimeUtils.formatPickerTime(_quietEndHour, _quietEndMinute);
  
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('intervalMinutes', _intervalMinutes);
    await prefs.setBool('quietModeEnabled', _quietModeEnabled);
    await prefs.setInt('quietStartHour', _quietStartHour);
    await prefs.setInt('quietStartMinute', _quietStartMinute);
    await prefs.setInt('quietEndHour', _quietEndHour);
    await prefs.setInt('quietEndMinute', _quietEndMinute);
  }
  
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    _quietModeEnabled = prefs.getBool('quietModeEnabled') ?? false;
    _quietStartHour = prefs.getInt('quietStartHour') ?? 22;
    _quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
    _quietEndHour = prefs.getInt('quietEndHour') ?? 7;
    _quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
    
    if (_intervalMinutes > 0) {
      _startInAppTimer();
    }
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _announcementTimer?.cancel();
    super.dispose();
  }
}
