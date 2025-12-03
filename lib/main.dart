import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/tts_service.dart';
import 'services/alarm_service.dart';
import 'services/settings_provider.dart';
import 'services/background_service.dart';
import 'screens/home_screen.dart';

/// Talk Time - Voice-based Clock Assistant
/// Works 24/7 in background with persistent notification

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize background service
  await BackgroundService().initialize();
  
  runApp(const TalkTimeApp());
}

class TalkTimeApp extends StatelessWidget {
  const TalkTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TtsService()),
        ChangeNotifierProvider(create: (_) => AlarmService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const TalkTimeMaterialApp(),
    );
  }
}

class TalkTimeMaterialApp extends StatefulWidget {
  const TalkTimeMaterialApp({super.key});

  @override
  State<TalkTimeMaterialApp> createState() => _TalkTimeMaterialAppState();
}

class _TalkTimeMaterialAppState extends State<TalkTimeMaterialApp> with WidgetsBindingObserver {
  bool _isInitialized = false;
  final BackgroundService _backgroundService = BackgroundService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final alarmService = context.read<AlarmService>();
    final ttsService = context.read<TtsService>();
    
    if (state == AppLifecycleState.paused) {
      debugPrint('App paused - background service active');
      _updateNotification(alarmService);
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed');
      alarmService.onAnnounce = (timeText) => ttsService.speak(timeText);
    }
  }

  void _updateNotification(AlarmService alarmService) {
    if (alarmService.intervalMinutes > 0) {
      _backgroundService.updateNotification(
        'Announcing time every ${alarmService.intervalMinutes} minutes',
      );
    }
  }

  Future<void> _initializeApp() async {
    final settings = context.read<SettingsProvider>();
    final alarmService = context.read<AlarmService>();
    final ttsService = context.read<TtsService>();
    
    await settings.loadSettings();
    await alarmService.loadSettings();
    
    alarmService.onAnnounce = (timeText) => ttsService.speak(timeText);
    
    ttsService.loadSettings(
      volume: settings.volume,
      rate: settings.rate,
      language: settings.language,
    );
    
    setState(() => _isInitialized = true);
    
    // Request permissions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsIfNeeded();
    });
  }

  Future<void> _requestPermissionsIfNeeded() async {
    final alreadyRequested = await BackgroundService.werePermissionsRequested();
    
    if (!alreadyRequested && mounted) {
      // Request notification permission first
      await BackgroundService.requestNotificationPermission();
      
      // Then request battery optimization
      if (mounted) {
        await BackgroundService.requestBatteryOptimization(context);
      }
      
      await BackgroundService.markPermissionsRequested();
      
      // Show persistent notification if interval is set
      final alarmService = context.read<AlarmService>();
      if (alarmService.intervalMinutes > 0) {
        _backgroundService.showPersistentNotification(
          title: '🕐 Talk Time Active',
          body: 'Announcing time every ${alarmService.intervalMinutes} minutes',
          intervalMinutes: alarmService.intervalMinutes,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: settings.getTheme(),
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1117),
                  const Color(0xFF161B22),
                ],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 100,
                    color: Color(0xFF00BFA5),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Talk Time',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Voice Clock Assistant',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ),
                  SizedBox(height: 32),
                  CircularProgressIndicator(
                    color: Color(0xFF00BFA5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return MaterialApp(
      title: 'Talk Time',
      debugShowCheckedModeBanner: false,
      theme: settings.getTheme(),
      home: const HomeScreen(),
    );
  }
}
