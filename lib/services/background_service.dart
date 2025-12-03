import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background Service for Talk Time
/// Manages foreground notification and battery optimization permissions

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Show persistent notification to keep app alive
  Future<void> showPersistentNotification({
    required String title,
    required String body,
    required int intervalMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'talktime_foreground',
      'Talk Time Service',
      channelDescription: 'Keeps Talk Time running in background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Can't be swiped away
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.service,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1, // Notification ID
      title,
      body,
      notificationDetails,
    );
  }

  /// Update the persistent notification
  Future<void> updateNotification(String body) async {
    await showPersistentNotification(
      title: '🕐 Talk Time Active',
      body: body,
      intervalMinutes: 0,
    );
  }

  /// Remove the persistent notification
  Future<void> removePersistentNotification() async {
    await _notifications.cancel(1);
  }

  /// Request battery optimization exemption
  static Future<bool> requestBatteryOptimization(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.ignoreBatteryOptimizations.status;
    
    if (status.isGranted) {
      return true;
    }

    // Show explanation dialog first
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
              'Please select "Allow" or "Unrestricted" on the next screen to enable 24/7 operation.',
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
            child: const Text('Enable Background'),
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

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Check if all permissions are granted
  static Future<bool> checkAllPermissions() async {
    if (!Platform.isAndroid) return true;
    
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    final notification = await Permission.notification.isGranted;
    
    return battery && notification;
  }

  /// Check if this is the first launch
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('first_launch') ?? true;
    if (isFirst) {
      await prefs.setBool('first_launch', false);
    }
    return isFirst;
  }

  /// Mark permissions as requested
  static Future<void> markPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
  }

  /// Check if permissions were already requested
  static Future<bool> werePermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('permissions_requested') ?? false;
  }
}

