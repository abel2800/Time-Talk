import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Background Service for Talk Time
/// Runs 24/7 and announces time at set intervals

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static FlutterBackgroundService? _service;
  
  /// Initialize and start the background service
  static Future<void> initialize() async {
    _service = FlutterBackgroundService();

    // Android notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'talk_time_service',
      'Talk Time Service',
      description: 'Announces time at regular intervals',
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
        autoStartOnBoot: true,
        notificationChannelId: 'talk_time_service',
        initialNotificationTitle: '🕐 Talk Time',
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
  }

  /// Start the service
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  /// Stop the service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Update the interval
  static void updateInterval(int minutes) {
    final service = FlutterBackgroundService();
    service.invoke('updateInterval', {'minutes': minutes});
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

  /// Request battery optimization exemption
  static Future<bool> requestBatteryOptimization(BuildContext context) async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_saver, color: Color(0xFF00BFA5), size: 28),
            SizedBox(width: 12),
            Text('Background Permission'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Talk Time needs to run in the background to announce the time at your set intervals.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Please select "Allow" on the next screen to enable 24/7 time announcements.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
            child: const Text('Enable'),
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

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point - runs in isolate
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterTts tts = FlutterTts();
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  // Initialize TTS
  await tts.setLanguage('en-US');
  await tts.setSpeechRate(0.5);
  await tts.setVolume(1.0);
  
  // Load settings from shared preferences
  final prefs = await SharedPreferences.getInstance();
  int intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
  bool quietEnabled = prefs.getBool('quietModeEnabled') ?? false;
  int quietStartHour = prefs.getInt('quietStartHour') ?? 22;
  int quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
  int quietEndHour = prefs.getInt('quietEndHour') ?? 7;
  int quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
  
  DateTime? lastAnnouncement;
  
  // Listen for updates from main app
  service.on('updateInterval').listen((event) {
    if (event != null) {
      intervalMinutes = event['minutes'] as int;
      prefs.setInt('intervalMinutes', intervalMinutes);
      lastAnnouncement = DateTime.now(); // Reset timer
      _updateNotification(service, notifications, intervalMinutes, quietEnabled);
    }
  });

  service.on('updateQuietHours').listen((event) {
    if (event != null) {
      quietEnabled = event['enabled'] as bool;
      quietStartHour = event['startHour'] as int;
      quietStartMinute = event['startMinute'] as int;
      quietEndHour = event['endHour'] as int;
      quietEndMinute = event['endMinute'] as int;
      _updateNotification(service, notifications, intervalMinutes, quietEnabled);
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Initial notification
  _updateNotification(service, notifications, intervalMinutes, quietEnabled);

  // Main loop - checks every 30 seconds for precise timing
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Reload settings in case they changed
    intervalMinutes = prefs.getInt('intervalMinutes') ?? 0;
    quietEnabled = prefs.getBool('quietModeEnabled') ?? false;
    quietStartHour = prefs.getInt('quietStartHour') ?? 22;
    quietStartMinute = prefs.getInt('quietStartMinute') ?? 0;
    quietEndHour = prefs.getInt('quietEndHour') ?? 7;
    quietEndMinute = prefs.getInt('quietEndMinute') ?? 0;
    
    if (intervalMinutes <= 0) return;
    
    final now = DateTime.now();
    
    // Check if enough time has passed since last announcement
    if (lastAnnouncement != null) {
      final elapsed = now.difference(lastAnnouncement!).inMinutes;
      if (elapsed < intervalMinutes) {
        return; // Not time yet
      }
    }
    
    // Check quiet hours
    if (quietEnabled && _isQuietTime(now, quietStartHour, quietStartMinute, quietEndHour, quietEndMinute)) {
      return; // In quiet hours, don't announce
    }
    
    // TIME TO ANNOUNCE!
    lastAnnouncement = now;
    final timeString = _formatTime(now);
    
    // Speak the time
    await tts.speak(timeString);
    
    // Update notification with last announcement time
    _updateNotification(service, notifications, intervalMinutes, quietEnabled, lastSpoken: timeString);
  });
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

/// Format time for speech (e.g., "10:30 PM")
String _formatTime(DateTime time) {
  final hour = time.hour;
  final minute = time.minute;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}

/// Update the foreground notification
void _updateNotification(
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
  int intervalMinutes,
  bool quietEnabled, {
  String? lastSpoken,
}) {
  String content;
  if (intervalMinutes <= 0) {
    content = 'Tap to set announcement interval';
  } else {
    content = 'Announcing every $intervalMinutes min';
    if (quietEnabled) {
      content += ' (Quiet hours enabled)';
    }
    if (lastSpoken != null) {
      content += '\nLast: $lastSpoken';
    }
  }

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '🕐 Talk Time Active',
      content: content,
    );
  }
}
