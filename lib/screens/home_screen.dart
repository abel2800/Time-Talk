import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../services/tts_service.dart';
import '../services/alarm_service.dart';
import '../services/settings_provider.dart';
import '../utils/time_utils.dart';
import '../widgets/analog_clock.dart';
import 'settings_screen.dart';

/// Home Screen for TimeTalk
/// Main interface with analog wall clock and digital display
/// 
/// Features:
/// - Touch anywhere to hear time (except settings icon)
/// - Beautiful analog clock with smooth animation
/// - Digital time display at top
/// - Haptic feedback on touch
/// - Full accessibility support

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  DateTime _currentTime = DateTime.now();
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

    // Pulse animation for touch feedback
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Set up alarm service callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alarmService = context.read<AlarmService>();
      final ttsService = context.read<TtsService>();
      
      alarmService.onAnnounce = (timeText) {
        ttsService.speak(timeText);
      };
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Speak the current time with vibration feedback
  Future<void> _speakTime() async {
    final settings = context.read<SettingsProvider>();
    final alarmService = context.read<AlarmService>();
    final ttsService = context.read<TtsService>();

    // Check if touch-to-speak is enabled
    if (!settings.touchToSpeakEnabled) return;

    // Check quiet hours if blocking is enabled
    if (settings.blockTouchDuringQuiet && alarmService.isCurrentlyQuiet()) {
      return;
    }

    // Provide vibration feedback if enabled
    if (settings.vibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(duration: 200);
      }
    }

    // Speak the time
    final timeText = TimeUtils.formatTimeForSpeech(_currentTime);
    await ttsService.speak(timeText);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final alarmService = context.watch<AlarmService>();
    final screenSize = MediaQuery.of(context).size;
    // Make clock size responsive - use smaller of width or available height
    final availableHeight = screenSize.height - 250; // Account for digital clock and padding
    final clockSize = (screenSize.width * 0.85).clamp(200.0, availableHeight.clamp(200.0, 500.0));
    
    // Determine if we're in quiet hours
    final isQuiet = alarmService.isCurrentlyQuiet();

    return Scaffold(
      body: GestureDetector(
        // Touch anywhere to speak time
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _pulseController.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _pulseController.reverse();
          _speakTime();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _pulseController.reverse();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: settings.darkMode
                  ? [
                      const Color(0xFF0D1117),
                      const Color(0xFF161B22),
                      const Color(0xFF0D1117),
                    ]
                  : [
                      const Color(0xFFE0F2F1),
                      const Color(0xFFB2DFDB),
                      const Color(0xFFE0F2F1),
                    ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Main content - use LayoutBuilder for responsive sizing
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Digital clock display at top
                            _buildDigitalClock(settings),
                            
                            const SizedBox(height: 12),
                            
                            // Status indicators
                            _buildStatusIndicators(settings, isQuiet, alarmService),
                            
                            const SizedBox(height: 20),
                            
                            // Analog wall clock
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Semantics(
                                    label: 'Analog clock showing ${TimeUtils.formatTimeForSpeech(_currentTime)}. Tap anywhere on screen to hear the time.',
                                    child: AnalogClock(
                                      time: _currentTime,
                                      size: clockSize,
                                      isDarkMode: settings.darkMode,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Instruction text
                            _buildInstructionText(settings),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Settings button in top-right corner
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildSettingsButton(settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the digital clock display
  Widget _buildDigitalClock(SettingsProvider settings) {
    return Semantics(
      label: 'Digital time: ${TimeUtils.formatTimeForSpeech(_currentTime)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: settings.darkMode
              ? Colors.black.withOpacity(0.4)
              : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: settings.darkMode
                ? const Color(0xFF00BFA5).withOpacity(0.5)
                : const Color(0xFF00796B).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: settings.darkMode
                  ? const Color(0xFF00BFA5).withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          TimeUtils.formatTimeDigital(_currentTime),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
            fontFamily: 'monospace',
            color: settings.darkMode
                ? const Color(0xFF00E5CC)
                : const Color(0xFF00796B),
            shadows: [
              Shadow(
                color: settings.darkMode
                    ? const Color(0xFF00BFA5).withOpacity(0.6)
                    : Colors.transparent,
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build status indicators (quiet mode, auto-announce)
  Widget _buildStatusIndicators(
    SettingsProvider settings,
    bool isQuiet,
    AlarmService alarmService,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Quiet mode indicator
        if (isQuiet) ...[
          _buildStatusChip(
            icon: Icons.nights_stay_rounded,
            label: 'Quiet Mode',
            color: Colors.indigo,
            settings: settings,
          ),
          const SizedBox(width: 12),
        ],
        
        // Auto-announce indicator
        if (alarmService.intervalMinutes > 0) ...[
          _buildStatusChip(
            icon: Icons.timer_outlined,
            label: 'Every ${alarmService.intervalMinutes}m',
            color: const Color(0xFF00BFA5),
            settings: settings,
          ),
        ],
      ],
    );
  }

  /// Build a status indicator chip
  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required SettingsProvider settings,
  }) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build instruction text at bottom
  Widget _buildInstructionText(SettingsProvider settings) {
    return Semantics(
      label: 'Tap anywhere on screen to hear the current time',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 24,
              color: settings.darkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
            ),
            const SizedBox(width: 10),
            Text(
              'Tap anywhere to hear time',
              style: TextStyle(
                fontSize: 16,
                color: settings.darkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.4),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build settings button
  Widget _buildSettingsButton(SettingsProvider settings) {
    return Semantics(
      button: true,
      label: 'Settings. Double tap to open settings menu.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Prevent time speaking when tapping settings
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: settings.darkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: settings.darkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(
              Icons.settings_rounded,
              size: 32,
              color: settings.darkMode
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFF00796B),
            ),
          ),
        ),
      ),
    );
  }
}
