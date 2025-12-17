import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../utils/time_utils.dart';
import 'background_service.dart';

/// Alarm Service for Talk Time
/// Manages settings and communicates with background service
/// 
/// FIXES APPLIED:
/// - Uses precise timing with exact minute boundaries (matching background service)
/// - Properly syncs with background service
/// - Handles in-app announcements without conflicts

class AlarmService extends ChangeNotifier {
  Timer? _announcementTimer;
  DateTime? _nextAnnouncementTime;
  
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
  Future<void> setInterval(int minutes) async {
    _intervalMinutes = minutes;
    await _saveSettings();
    
    // Update background service
    await BackgroundService.updateInterval(minutes);
    
    // Calculate next announcement time for in-app timer
    if (minutes > 0) {
      _nextAnnouncementTime = _calculateNextAnnouncementTime(minutes, DateTime.now());
      
      // Store next announcement time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('next_announcement_time', _nextAnnouncementTime!.millisecondsSinceEpoch);
    }
    
    // Start in-app timer for when app is in foreground
    _startInAppTimer();
    
    notifyListeners();
  }
  
  /// Calculate the next announcement time aligned to interval boundaries
  DateTime _calculateNextAnnouncementTime(int intervalMinutes, DateTime fromTime) {
    final now = fromTime;
    
    // Calculate minutes since midnight
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    
    // Find how many complete intervals have passed since midnight
    final completedIntervals = minutesSinceMidnight ~/ intervalMinutes;
    
    // Next interval minute mark
    final nextIntervalMinutes = (completedIntervals + 1) * intervalMinutes;
    
    // Handle day overflow
    if (nextIntervalMinutes >= 1440) { // 24 * 60 = 1440 minutes in a day
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final adjustedMinutes = nextIntervalMinutes % 1440;
      return tomorrow.add(Duration(minutes: adjustedMinutes));
    }
    
    // Create the next announcement time
    final nextHour = nextIntervalMinutes ~/ 60;
    final nextMinute = nextIntervalMinutes % 60;
    
    return DateTime(now.year, now.month, now.day, nextHour, nextMinute, 0);
  }
  
  /// Start in-app timer (for when app is open)
  /// NOTE: This is a BACKUP to the background service - the background service
  /// is the primary mechanism for announcements
  void _startInAppTimer() {
    _announcementTimer?.cancel();
    
    if (_intervalMinutes <= 0) return;
    
    // Initialize next announcement time if not set
    if (_nextAnnouncementTime == null || _nextAnnouncementTime!.isBefore(DateTime.now())) {
      _nextAnnouncementTime = _calculateNextAnnouncementTime(_intervalMinutes, DateTime.now());
    }
    
    // Check every 5 seconds for precise timing (matching background service)
    _announcementTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_intervalMinutes <= 0 || _nextAnnouncementTime == null) return;
      
      final now = DateTime.now();
      
      // Check if we've reached the announcement time
      if (now.millisecondsSinceEpoch >= _nextAnnouncementTime!.millisecondsSinceEpoch) {
        // Check quiet hours
        if (_quietModeEnabled && TimeUtils.isQuietTime(
          now, _quietStartHour, _quietStartMinute, _quietEndHour, _quietEndMinute,
        )) {
          // Update next announcement time even during quiet hours
          _nextAnnouncementTime = _calculateNextAnnouncementTime(_intervalMinutes, now);
          return;
        }
        
        // Calculate next announcement time BEFORE announcing (prevents double-announce)
        _nextAnnouncementTime = _calculateNextAnnouncementTime(_intervalMinutes, now);
        
        // Save updated next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('next_announcement_time', _nextAnnouncementTime!.millisecondsSinceEpoch);
        
        // Vibrate if enabled
        final vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
        final language = prefs.getString('language') ?? 'en-US';
        
        if (vibrationEnabled) {
          final hasVibrator = await Vibration.hasVibrator() ?? false;
          if (hasVibrator) {
            Vibration.vibrate(duration: 200);
          }
        }
        
        // Get repeat count setting
        final repeatCount = prefs.getInt('repeatCount') ?? 2;
        
        // Format time in the selected language
        final timeText = TimeUtils.formatTimeForSpeech(now, language: language);
        
        // Announce time based on repeat count
        for (int i = 0; i < repeatCount; i++) {
          onAnnounce?.call(timeText);
          if (i < repeatCount - 1) {
            await Future.delayed(const Duration(milliseconds: 2500));
          }
        }
      }
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
    
    // Load stored next announcement time
    final storedNextTime = prefs.getInt('next_announcement_time');
    if (storedNextTime != null && _intervalMinutes > 0) {
      _nextAnnouncementTime = DateTime.fromMillisecondsSinceEpoch(storedNextTime);
      
      // If stored time is in the past, recalculate
      if (_nextAnnouncementTime!.isBefore(DateTime.now())) {
        _nextAnnouncementTime = _calculateNextAnnouncementTime(_intervalMinutes, DateTime.now());
        await prefs.setInt('next_announcement_time', _nextAnnouncementTime!.millisecondsSinceEpoch);
      }
    }
    
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
