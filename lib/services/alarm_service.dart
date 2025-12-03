import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/time_utils.dart';
import 'background_service.dart';

/// Alarm Service for Talk Time
/// Manages scheduled time announcements with 24/7 background support

class AlarmService extends ChangeNotifier {
  Timer? _announcementTimer;
  DateTime? _lastAnnouncement;
  final BackgroundService _backgroundService = BackgroundService();
  
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
  bool get isScheduled => _announcementTimer != null && _announcementTimer!.isActive;
  
  /// Start the announcement timer
  void startTimer() {
    stopTimer();
    
    if (_intervalMinutes <= 0) return;
    
    // Check every 30 seconds to ensure accurate timing
    _announcementTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndAnnounce();
    });
    
    _lastAnnouncement = DateTime.now();
    
    // Show persistent notification
    _backgroundService.showPersistentNotification(
      title: '🕐 Talk Time Active',
      body: 'Announcing time every $_intervalMinutes minutes',
      intervalMinutes: _intervalMinutes,
    );
    
    notifyListeners();
    debugPrint('AlarmService: Timer started - $_intervalMinutes min interval');
  }
  
  /// Check if it's time to announce
  void _checkAndAnnounce() {
    if (_intervalMinutes <= 0) return;
    
    final now = DateTime.now();
    
    // Check if enough time has passed
    if (_lastAnnouncement != null) {
      final elapsed = now.difference(_lastAnnouncement!).inMinutes;
      if (elapsed < _intervalMinutes) {
        return;
      }
    }
    
    // Check quiet hours
    if (_quietModeEnabled && TimeUtils.isQuietTime(
      now, _quietStartHour, _quietStartMinute, _quietEndHour, _quietEndMinute,
    )) {
      debugPrint('AlarmService: Quiet hours - skipping');
      return;
    }
    
    // Announce time!
    _lastAnnouncement = now;
    final timeText = TimeUtils.formatTimeForSpeech(now);
    onAnnounce?.call(timeText);
    debugPrint('AlarmService: Announced - $timeText');
  }
  
  /// Stop the timer
  void stopTimer() {
    _announcementTimer?.cancel();
    _announcementTimer = null;
    
    // Remove notification if no interval
    if (_intervalMinutes <= 0) {
      _backgroundService.removePersistentNotification();
    }
    
    notifyListeners();
    debugPrint('AlarmService: Timer stopped');
  }
  
  /// Set interval and update everything
  void setInterval(int minutes) {
    _intervalMinutes = minutes;
    
    if (minutes > 0) {
      startTimer();
    } else {
      stopTimer();
      _backgroundService.removePersistentNotification();
    }
    
    notifyListeners();
    _saveSettings();
  }
  
  void setQuietModeEnabled(bool enabled) {
    _quietModeEnabled = enabled;
    _updateNotificationStatus();
    notifyListeners();
    _saveSettings();
  }
  
  void setQuietStartTime(int hour, int minute) {
    _quietStartHour = hour;
    _quietStartMinute = minute;
    notifyListeners();
    _saveSettings();
  }
  
  void setQuietEndTime(int hour, int minute) {
    _quietEndHour = hour;
    _quietEndMinute = minute;
    notifyListeners();
    _saveSettings();
  }
  
  void _updateNotificationStatus() {
    if (_intervalMinutes > 0) {
      String status = 'Announcing time every $_intervalMinutes minutes';
      if (_quietModeEnabled) {
        status += ' (Quiet: ${quietStartTimeString} - ${quietEndTimeString})';
      }
      _backgroundService.updateNotification(status);
    }
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
      startTimer();
    }
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
