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
  int repeatCount = prefs.getInt('repeatCount') ?? 2; // Default: say time twice
  
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
      
      // Save to prefs
      await prefs.setString('language', language);
      await prefs.setDouble('volume', volume);
      await prefs.setDouble('rate', rate);
    }
  });

  service.on('updateRepeatCount').listen((event) {
    if (event != null) {
      repeatCount = event['count'] as int;
      prefs.setInt('repeatCount', repeatCount);
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
    await prefs.reload(); // Refresh prefs from disk
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
    final timeString = _formatTimeSimple(now, language);
    
    // Vibrate if enabled
    if (vibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(duration: 200);
      }
    }
    
    // Speak the time multiple times based on repeatCount setting
    for (int i = 0; i < repeatCount; i++) {
      await tts.speak(timeString);
      // Wait for speech to complete before repeating
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    
    // Update notification with last announcement time
    _updateNotification(service, notifications, intervalMinutes, quietEnabled, repeatCount: repeatCount, lastSpoken: timeString);
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

/// Format time for speech using intl package for correct localization
/// This ensures proper 12h/24h format and localized AM/PM for each language
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
  }

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '🕐 Talk Time Active',
      content: content,
    );
  }
}
