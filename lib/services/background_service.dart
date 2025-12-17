import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

/// Background Service for Talk Time - BULLETPROOF VERSION
/// 
/// This service is designed to run 24/7 and announce time at set intervals.
/// It uses multiple mechanisms to ensure reliability:
/// 
/// 1. Flutter Background Service - Main foreground service with notification
/// 2. AlarmManager - Exact alarm backup for precise timing
/// 3. WorkManager (via Kotlin) - System-guaranteed periodic task
/// 4. Watchdog Timer - Detects and restarts dead service
/// 5. Boot Receiver - Restarts service after phone reboot
/// 
/// CRITICAL: All these mechanisms work together to ensure the app NEVER stops
/// announcing time unless the user explicitly disables it.

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static FlutterBackgroundService? _service;
  static const String _serviceRunningKey = 'service_running';
  static const String _nextAnnouncementKey = 'next_announcement_time';
  static const int _alarmId = 12345;
  
  /// Initialize and start the background service
  static Future<void> initialize() async {
    _service = FlutterBackgroundService();

    // Initialize AlarmManager as backup
    await AndroidAlarmManager.initialize();

    // Android notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'talk_time_service',
      'Talk Time Service',
      description: 'Announces time at regular intervals - keeps running 24/7',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service!.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true, // CRITICAL: restart on boot
        notificationChannelId: 'talk_time_service',
        initialNotificationTitle: '🕐 Talk Time Active',
        initialNotificationContent: 'Ready to announce time',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    // Mark service as intended to be running
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceRunningKey, true);
    
    // Schedule backup alarm
    final intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    if (intervalMinutes > 0) {
      await _scheduleBackupAlarm(intervalMinutes);
    }
  }

  /// Start the service with all backup mechanisms
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    
    // Mark service as intended to be running
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceRunningKey, true);
    
    // Schedule backup alarm
    final intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    if (intervalMinutes > 0) {
      await _scheduleBackupAlarm(intervalMinutes);
    }
  }

  /// Stop the service completely
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    
    // Mark service as stopped by user
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceRunningKey, false);
    
    // Cancel backup alarm
    await AndroidAlarmManager.cancel(_alarmId);
  }
  
  /// Schedule AlarmManager as backup mechanism
  /// This ensures time is announced even if the main service is killed
  static Future<void> _scheduleBackupAlarm(int intervalMinutes) async {
    if (intervalMinutes <= 0) return;
    
    try {
      // Cancel existing alarm first
      await AndroidAlarmManager.cancel(_alarmId);
      
      // Schedule periodic alarm
      await AndroidAlarmManager.periodic(
        Duration(minutes: intervalMinutes),
        _alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true, // CRITICAL: survive reboot
        allowWhileIdle: true, // Work in Doze mode
      );
      
      debugPrint('BackgroundService: Backup alarm scheduled for every $intervalMinutes minutes');
    } catch (e) {
      debugPrint('BackgroundService: Failed to schedule backup alarm: $e');
    }
  }
  
  /// Check if service should be running and restart if needed
  /// Called periodically and after boot
  static Future<void> ensureServiceRunning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Reload to get latest values
    
    final shouldRun = prefs.getBool(_serviceRunningKey) ?? false;
    final intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    
    debugPrint('BackgroundService.ensureServiceRunning: shouldRun=$shouldRun, interval=$intervalMinutes');
    
    if (shouldRun && intervalMinutes > 0) {
      final service = FlutterBackgroundService();
      var isRunning = await service.isRunning();
      
      if (!isRunning) {
        debugPrint('BackgroundService: Service was killed, restarting...');
        await service.startService();
        
        // Also ensure backup alarm is running
        await _scheduleBackupAlarm(intervalMinutes);
      }
      
      // Check if watchdog was triggered (from Kotlin WorkManager)
      final watchdogTriggered = prefs.getBool('watchdog_triggered') ?? false;
      if (watchdogTriggered) {
        await prefs.setBool('watchdog_triggered', false);
        debugPrint('BackgroundService: Watchdog triggered, service health check OK');
      }
    }
  }

  /// Update the interval
  static Future<void> updateInterval(int minutes) async {
    final service = FlutterBackgroundService();
    
    // Calculate and store the next announcement time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('intervalMinutes', minutes);
    
    if (minutes > 0) {
      final nextTime = _calculateNextAnnouncementTime(minutes);
      await prefs.setInt(_nextAnnouncementKey, nextTime.millisecondsSinceEpoch);
      
      // Update backup alarm
      await _scheduleBackupAlarm(minutes);
      
      // Ensure service is running
      await ensureServiceRunning();
    } else {
      // Cancel backup alarm if interval is 0
      await AndroidAlarmManager.cancel(_alarmId);
    }
    
    service.invoke('updateInterval', {'minutes': minutes});
  }
  
  /// Calculate the next announcement time aligned to minute boundaries
  static DateTime _calculateNextAnnouncementTime(int intervalMinutes) {
    final now = DateTime.now();
    
    // Round up to the next minute boundary
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    
    // Find the next announcement time that aligns with the interval
    // For example, if interval is 15 min, announce at :00, :15, :30, :45
    final currentMinuteOfDay = nextMinute.hour * 60 + nextMinute.minute;
    final minutesUntilNext = intervalMinutes - (currentMinuteOfDay % intervalMinutes);
    
    // If we're exactly on a boundary, wait for the next one
    final effectiveWait = minutesUntilNext == intervalMinutes ? intervalMinutes : minutesUntilNext;
    
    return nextMinute.add(Duration(minutes: effectiveWait - 1));
  }

  /// Update quiet hours settings
  static void updateQuietHours({
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    final service = FlutterBackgroundService();
    service.invoke('updateQuietHours', {
      'enabled': enabled,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    });
  }

  /// Update voice settings (language, volume, rate)
  static void updateVoiceSettings({
    required String language,
    required double volume,
    required double rate,
  }) {
    final service = FlutterBackgroundService();
    service.invoke('updateVoiceSettings', {
      'language': language,
      'volume': volume,
      'rate': rate,
    });
  }

  /// Update repeat count
  static void updateRepeatCount(int count) {
    final service = FlutterBackgroundService();
    service.invoke('updateRepeatCount', {'count': count});
  }

  /// Request battery optimization exemption - CRITICAL for 24/7 operation
  static Future<bool> requestBatteryOptimization(BuildContext context) async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Flexible(child: Text('Important Permission')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Talk Time needs special permission to announce time reliably.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ WITHOUT this permission:',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('• App may stop after a few hours'),
            Text('• App may stop after phone sleeps'),
            Text('• App may stop after reboot'),
            SizedBox(height: 16),
            Text(
              '✅ WITH this permission:',
              style: TextStyle(fontSize: 14, color: Colors.green),
            ),
            SizedBox(height: 8),
            Text('• App runs 24/7 without stopping'),
            Text('• App survives phone restart'),
            Text('• Time announced exactly on schedule'),
            SizedBox(height: 16),
            Text(
              'On the next screen, select "Allow" to enable 24/7 operation.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
            ),
            child: const Text('Enable Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      return result.isGranted;
    }
    return false;
  }

  /// Request notification permission
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }
}

/// AlarmManager callback - runs even if app/service is killed
/// This is the BACKUP mechanism for time announcements
@pragma('vm:entry-point')
Future<void> _alarmCallback() async {
  debugPrint('=== ALARM CALLBACK TRIGGERED ===');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    final serviceRunning = prefs.getBool('service_running') ?? false;
    
    if (!serviceRunning || intervalMinutes <= 0) {
      debugPrint('AlarmCallback: Service disabled or interval is 0');
      return;
    }
    
    // Check quiet hours
    final quietEnabled = prefs.getBool('quietModeEnabled') ?? false;
    if (quietEnabled) {
      final now = DateTime.now();
      final quietStartHour = prefs.getInt('quietStartHour') ?? 22;
      final quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
      final quietEndHour = prefs.getInt('quietEndHour') ?? 7;
      final quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
      
      if (_isQuietTimeStatic(now, quietStartHour, quietStartMinute, quietEndHour, quietEndMinute)) {
        debugPrint('AlarmCallback: Quiet hours active, skipping announcement');
        return;
      }
    }
    
    // Try to restart main service if not running
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    
    if (!isRunning) {
      debugPrint('AlarmCallback: Main service not running, restarting...');
      await service.startService();
      // Give service time to start
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // The main service will handle the announcement
    // This callback mainly serves to restart the service if killed
    debugPrint('AlarmCallback: Service check complete');
    
  } catch (e) {
    debugPrint('AlarmCallback error: $e');
  }
}

/// Static quiet time check for alarm callback
bool _isQuietTimeStatic(DateTime now, int startHour, int startMinute, int endHour, int endMinute) {
  final nowMinutes = now.hour * 60 + now.minute;
  final startMinutes = startHour * 60 + startMinute;
  final endMinutes = endHour * 60 + endMinute;
  
  if (startMinutes <= endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  } else {
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point - runs in isolate
/// This is the PRIMARY mechanism for time announcements
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  debugPrint('=== BACKGROUND SERVICE STARTED ===');
  
  final FlutterTts tts = FlutterTts();
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  // Load settings from shared preferences
  final prefs = await SharedPreferences.getInstance();
  int intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
  bool quietEnabled = prefs.getBool('quietModeEnabled') ?? false;
  int quietStartHour = prefs.getInt('quietStartHour') ?? 22;
  int quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
  int quietEndHour = prefs.getInt('quietEndHour') ?? 7;
  int quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
  bool vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
  String language = prefs.getString('language') ?? 'en-US';
  double volume = prefs.getDouble('volume') ?? 1.0;
  double rate = prefs.getDouble('rate') ?? 0.5;
  int repeatCount = prefs.getInt('repeatCount') ?? 2;
  
  debugPrint('Service started with interval: $intervalMinutes min, repeat: $repeatCount');
  
  // Initialize TTS with saved settings
  await tts.setLanguage(language);
  await tts.setSpeechRate(rate);
  await tts.setVolume(volume);
  
  // Enable TTS to work when screen is off (Android)
  try {
    await tts.awaitSpeakCompletion(true);
  } catch (e) {
    // Ignore if not supported
  }
  
  // Track announcement times precisely
  DateTime? lastAnnouncementTime;
  int? storedNextTime = prefs.getInt('next_announcement_time');
  DateTime nextAnnouncementTime;
  
  if (storedNextTime != null && intervalMinutes > 0) {
    nextAnnouncementTime = DateTime.fromMillisecondsSinceEpoch(storedNextTime);
    // If the stored time is in the past, recalculate
    if (nextAnnouncementTime.isBefore(DateTime.now())) {
      nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(intervalMinutes, DateTime.now());
      await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
    }
  } else if (intervalMinutes > 0) {
    nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(intervalMinutes, DateTime.now());
    await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
  } else {
    nextAnnouncementTime = DateTime.now().add(const Duration(days: 365)); // Far future if disabled
  }
  
  // Listen for updates from main app
  service.on('updateInterval').listen((event) async {
    if (event != null) {
      intervalMinutes = event['minutes'] as int;
      await prefs.setInt('intervalMinutes', intervalMinutes);
      
      debugPrint('Service: Interval updated to $intervalMinutes min');
      
      if (intervalMinutes > 0) {
        // Calculate new next announcement time
        nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(intervalMinutes, DateTime.now());
        await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
      }
      
      _updateNotification(service, notifications, intervalMinutes, quietEnabled, 
          nextTime: intervalMinutes > 0 ? nextAnnouncementTime : null);
    }
  });

  service.on('updateQuietHours').listen((event) async {
    if (event != null) {
      quietEnabled = event['enabled'] as bool;
      quietStartHour = event['startHour'] as int;
      quietStartMinute = event['startMinute'] as int;
      quietEndHour = event['endHour'] as int;
      quietEndMinute = event['endMinute'] as int;
      
      // Save to prefs for persistence
      await prefs.setBool('quietModeEnabled', quietEnabled);
      await prefs.setInt('quietStartHour', quietStartHour);
      await prefs.setInt('quietStartMinute', quietStartMinute);
      await prefs.setInt('quietEndHour', quietEndHour);
      await prefs.setInt('quietEndMinute', quietEndMinute);
      
      _updateNotification(service, notifications, intervalMinutes, quietEnabled);
    }
  });

  service.on('updateVoiceSettings').listen((event) async {
    if (event != null) {
      final newLanguage = event['language'] as String;
      final newVolume = event['volume'] as double;
      final newRate = event['rate'] as double;
      
      language = newLanguage;
      volume = newVolume;
      rate = newRate;
      
      await tts.setLanguage(language);
      await tts.setVolume(volume);
      await tts.setSpeechRate(rate);
      
      // Save to prefs for persistence
      await prefs.setString('language', language);
      await prefs.setDouble('volume', volume);
      await prefs.setDouble('rate', rate);
    }
  });

  service.on('updateRepeatCount').listen((event) async {
    if (event != null) {
      repeatCount = event['count'] as int;
      await prefs.setInt('repeatCount', repeatCount);
      debugPrint('Service: Repeat count updated to $repeatCount');
    }
  });

  service.on('stopService').listen((event) async {
    debugPrint('Service: Stop requested');
    await prefs.setBool('service_running', false);
    service.stopSelf();
  });

  // Initial notification
  _updateNotification(service, notifications, intervalMinutes, quietEnabled,
      nextTime: intervalMinutes > 0 ? nextAnnouncementTime : null);

  // HIGH-PRECISION TIMER: Check every 5 seconds for announcement time
  // This ensures we don't miss times even with some drift
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    // Reload settings periodically to catch any changes
    await prefs.reload();
    intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    quietEnabled = prefs.getBool('quietModeEnabled') ?? false;
    quietStartHour = prefs.getInt('quietStartHour') ?? 22;
    quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
    quietEndHour = prefs.getInt('quietEndHour') ?? 7;
    quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
    vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    repeatCount = prefs.getInt('repeatCount') ?? 2;
    
    // Reload voice settings
    final newLanguage = prefs.getString('language') ?? 'en-US';
    final newVolume = prefs.getDouble('volume') ?? 1.0;
    final newRate = prefs.getDouble('rate') ?? 0.5;
    
    // Apply if changed
    if (newLanguage != language) {
      language = newLanguage;
      await tts.setLanguage(language);
    }
    if (newVolume != volume) {
      volume = newVolume;
      await tts.setVolume(volume);
    }
    if (newRate != rate) {
      rate = newRate;
      await tts.setSpeechRate(rate);
    }
    
    // Skip if announcements disabled
    if (intervalMinutes <= 0) return;
    
    final now = DateTime.now();
    
    // Check if we've reached or passed the next announcement time
    if (now.millisecondsSinceEpoch >= nextAnnouncementTime.millisecondsSinceEpoch) {
      // Prevent double announcements - check if we already announced recently
      if (lastAnnouncementTime != null && 
          now.difference(lastAnnouncementTime!).inSeconds < 30) {
        debugPrint('Service: Skipping - already announced ${now.difference(lastAnnouncementTime!).inSeconds}s ago');
        return;
      }
      
      // Check quiet hours before announcing
      if (quietEnabled && _isQuietTime(now, quietStartHour, quietStartMinute, quietEndHour, quietEndMinute)) {
        // Still update next announcement time even during quiet hours
        nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(intervalMinutes, now);
        await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
        debugPrint('Service: Quiet hours active, skipping announcement');
        return;
      }
      
      // Calculate next announcement time BEFORE announcing
      nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(intervalMinutes, now);
      await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
      lastAnnouncementTime = now;
      
      // TIME TO ANNOUNCE!
      final timeString = _formatTimeSimple(now, language);
      debugPrint('Service: ANNOUNCING TIME: $timeString (repeat: $repeatCount)');
      
      // Vibrate if enabled
      if (vibrationEnabled) {
        try {
          final hasVibrator = await Vibration.hasVibrator() ?? false;
          if (hasVibrator) {
            Vibration.vibrate(duration: 200);
          }
        } catch (e) {
          debugPrint('Service: Vibration error: $e');
        }
      }
      
      // Speak the time multiple times based on repeatCount setting
      for (int i = 0; i < repeatCount; i++) {
        debugPrint('Service: Speaking time (${i + 1}/$repeatCount)');
        await tts.speak(timeString);
        // Wait for speech to complete before repeating
        if (i < repeatCount - 1) {
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      }
      
      // Update notification with last announcement time
      _updateNotification(service, notifications, intervalMinutes, quietEnabled, 
          repeatCount: repeatCount, 
          lastSpoken: timeString,
          nextTime: nextAnnouncementTime);
      
      debugPrint('Service: Announcement complete. Next: $nextAnnouncementTime');
    }
  });
  
  // HEALTH CHECK: Every 5 minutes, verify timing is accurate
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    await prefs.reload();
    final storedNextTime = prefs.getInt('next_announcement_time');
    final currentInterval = prefs.getInt('intervalMinutes') ?? 0;
    
    if (currentInterval > 0 && storedNextTime != null) {
      final storedNext = DateTime.fromMillisecondsSinceEpoch(storedNextTime);
      final now = DateTime.now();
      
      // If stored time is way in the past, recalculate
      if (storedNext.isBefore(now.subtract(Duration(minutes: currentInterval + 5)))) {
        debugPrint('Service: Health check - recalculating next announcement time');
        nextAnnouncementTime = _calculateNextAnnouncementTimeIsolate(currentInterval, now);
        await prefs.setInt('next_announcement_time', nextAnnouncementTime.millisecondsSinceEpoch);
      }
    }
    
    // Mark service as still running (for watchdog)
    await prefs.setInt('service_last_heartbeat', DateTime.now().millisecondsSinceEpoch);
  });
  
  debugPrint('Service: All timers initialized');
}

/// Calculate the next announcement time aligned to interval boundaries
DateTime _calculateNextAnnouncementTimeIsolate(int intervalMinutes, DateTime fromTime) {
  final now = fromTime;
  
  // Calculate minutes since midnight
  final minutesSinceMidnight = now.hour * 60 + now.minute;
  
  // Find how many complete intervals have passed since midnight
  final completedIntervals = minutesSinceMidnight ~/ intervalMinutes;
  
  // Next interval minute mark
  final nextIntervalMinutes = (completedIntervals + 1) * intervalMinutes;
  
  // Handle day overflow
  if (nextIntervalMinutes >= 1440) { // 24 * 60 = 1440 minutes in a day
    // Next announcement is tomorrow at interval boundary
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final adjustedMinutes = nextIntervalMinutes % 1440;
    return tomorrow.add(Duration(minutes: adjustedMinutes));
  }
  
  // Create the next announcement time
  final nextHour = nextIntervalMinutes ~/ 60;
  final nextMinute = nextIntervalMinutes % 60;
  
  return DateTime(now.year, now.month, now.day, nextHour, nextMinute, 0);
}

/// Check if current time is in quiet hours
bool _isQuietTime(DateTime now, int startHour, int startMinute, int endHour, int endMinute) {
  final nowMinutes = now.hour * 60 + now.minute;
  final startMinutes = startHour * 60 + startMinute;
  final endMinutes = endHour * 60 + endMinute;
  
  if (startMinutes <= endMinutes) {
    // Same day range (e.g., 9:00 - 17:00)
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  } else {
    // Overnight range (e.g., 22:00 - 07:00)
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }
}

/// Format time for speech using intl package for correct localization
String _formatTimeSimple(DateTime time, String language) {
  try {
    // Convert language code format: 'es-ES' -> 'es_ES' for intl
    String locale = language.replaceAll('-', '_');
    
    // DateFormat.jm() creates localized time with hour:minute AM/PM
    return DateFormat.jm(locale).format(time);
  } catch (e) {
    // Fallback to English if locale not supported
    return DateFormat.jm('en_US').format(time);
  }
}

/// Update the foreground notification
void _updateNotification(
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
  int intervalMinutes,
  bool quietEnabled, {
  int repeatCount = 2,
  String? lastSpoken,
  DateTime? nextTime,
}) {
  String content;
  if (intervalMinutes <= 0) {
    content = 'Tap to set announcement interval';
  } else {
    content = 'Every $intervalMinutes min × $repeatCount';
    if (quietEnabled) {
      content += ' (Quiet on)';
    }
    if (lastSpoken != null) {
      content += '\nLast: $lastSpoken';
    }
    if (nextTime != null) {
      final nextStr = DateFormat('h:mm a').format(nextTime);
      content += '\nNext: $nextStr';
    }
  }

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '🕐 Talk Time Active',
      content: content,
    );
  }
}
