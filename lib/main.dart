import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/tts_service.dart';
import 'services/alarm_service.dart';
import 'services/settings_provider.dart';
import 'services/background_service.dart';
import 'screens/home_screen.dart';
import 'l10n/app_localizations.dart';

/// Talk Time - Voice-based Clock Assistant
/// Full multi-language support

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize background service for 24/7 operation
  await BackgroundService.initialize();
  
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

class _TalkTimeMaterialAppState extends State<TalkTimeMaterialApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final settings = context.read<SettingsProvider>();
    final alarmService = context.read<AlarmService>();
    final ttsService = context.read<TtsService>();
    
    await settings.loadSettings();
    await alarmService.loadSettings();
    
    // Connect alarm service to TTS for in-app announcements
    alarmService.onAnnounce = (timeText) => ttsService.speak(timeText);
    
    ttsService.loadSettings(
      volume: settings.volume,
      rate: settings.rate,
      language: settings.language,
    );
    
    // Start background service
    await BackgroundService.startService();
    
    setState(() => _isInitialized = true);
    
    // Request permissions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    if (!mounted) return;
    
    // Request notification permission first
    await BackgroundService.requestNotificationPermission();
    
    // Then request battery optimization
    if (mounted) {
      await BackgroundService.requestBatteryOptimization(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    // Get locale from language setting
    final locale = _getLocaleFromLanguage(settings.language);
    
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: settings.getTheme(),
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1117), Color(0xFF161B22)],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 100, color: Color(0xFF00BFA5)),
                  SizedBox(height: 24),
                  Text('Talk Time', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text('Voice Clock Assistant', style: TextStyle(fontSize: 16, color: Colors.white54)),
                  SizedBox(height: 32),
                  CircularProgressIndicator(color: Color(0xFF00BFA5)),
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
      
      // Localization support
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('de', 'DE'),
        Locale('ar', 'SA'),
        Locale('zh', 'CN'),
        Locale('hi', 'IN'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
        Locale('pt', 'BR'),
        Locale('it', 'IT'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      home: const HomeScreen(),
    );
  }
  
  Locale _getLocaleFromLanguage(String language) {
    switch (language) {
      case 'es-ES':
        return const Locale('es', 'ES');
      case 'fr-FR':
        return const Locale('fr', 'FR');
      case 'de-DE':
        return const Locale('de', 'DE');
      case 'ar-SA':
        return const Locale('ar', 'SA');
      case 'zh-CN':
        return const Locale('zh', 'CN');
      case 'hi-IN':
        return const Locale('hi', 'IN');
      case 'ja-JP':
        return const Locale('ja', 'JP');
      case 'ko-KR':
        return const Locale('ko', 'KR');
      case 'pt-BR':
        return const Locale('pt', 'BR');
      case 'it-IT':
        return const Locale('it', 'IT');
      case 'en-GB':
      case 'en-US':
      default:
        return const Locale('en', 'US');
    }
  }
}
