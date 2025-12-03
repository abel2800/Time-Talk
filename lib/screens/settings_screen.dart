import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../services/alarm_service.dart';
import '../services/settings_provider.dart';
import '../services/background_service.dart';
import '../utils/time_utils.dart';

/// Settings Screen for TimeTalk
/// Complete configuration interface with accessibility focus
/// 
/// Features:
/// - Voice volume and speed controls
/// - Auto-announce interval selection
/// - Quiet hours configuration
/// - Toggle switches for features
/// - Language selection
/// - Test voice button

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _customIntervalController = TextEditingController();
  
  // Available interval options
  final List<Map<String, dynamic>> _intervalOptions = [
    {'label': 'No repeat', 'value': 0},
    {'label': 'Every 15 minutes', 'value': 15},
    {'label': 'Every 30 minutes', 'value': 30},
    {'label': 'Every hour', 'value': 60},
    {'label': 'Custom', 'value': -1},
  ];
  
  // Available languages (subset for demo)
  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
    {'code': 'es-ES', 'name': 'Spanish'},
    {'code': 'fr-FR', 'name': 'French'},
    {'code': 'de-DE', 'name': 'German'},
    {'code': 'it-IT', 'name': 'Italian'},
    {'code': 'pt-BR', 'name': 'Portuguese (Brazil)'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
    {'code': 'ja-JP', 'name': 'Japanese'},
    {'code': 'ko-KR', 'name': 'Korean'},
    {'code': 'hi-IN', 'name': 'Hindi'},
    {'code': 'ar-SA', 'name': 'Arabic'},
  ];

  @override
  void dispose() {
    _customIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final alarmService = context.watch<AlarmService>();
    final ttsService = context.watch<TtsService>();

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leading: Semantics(
          button: true,
          label: 'Go back to clock',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Voice Settings Section
          _buildSectionHeader('Voice Settings', Icons.record_voice_over_rounded),
          const SizedBox(height: 12),
          
          // Volume slider
          _buildSliderCard(
            title: 'Voice Volume',
            semanticsLabel: 'Voice volume slider. Current value: ${(settings.volume * 100).round()}%',
            value: settings.volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            valueLabel: '${(settings.volume * 100).round()}%',
            onChanged: (value) {
              settings.setVolume(value);
              ttsService.setVolume(value);
              // Update background service
              BackgroundService.updateVoiceSettings(
                language: settings.language,
                volume: value,
                rate: settings.rate,
              );
            },
            settings: settings,
          ),
          
          const SizedBox(height: 12),
          
          // Speed slider
          _buildSliderCard(
            title: 'Voice Speed',
            semanticsLabel: 'Voice speed slider. Current value: ${_getSpeedLabel(settings.rate)}',
            value: settings.rate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            valueLabel: _getSpeedLabel(settings.rate),
            onChanged: (value) {
              settings.setRate(value);
              ttsService.setRate(value);
              // Update background service
              BackgroundService.updateVoiceSettings(
                language: settings.language,
                volume: settings.volume,
                rate: value,
              );
            },
            settings: settings,
          ),
          
          const SizedBox(height: 12),
          
          // Language selector
          _buildLanguageSelector(settings, ttsService),
          
          const SizedBox(height: 12),
          
          // Test voice button
          _buildTestVoiceButton(ttsService, settings),
          
          const SizedBox(height: 24),
          
          // Auto Announcements Section
          _buildSectionHeader('Auto Announcements', Icons.timer_rounded),
          const SizedBox(height: 12),
          
          // Interval selector
          _buildIntervalSelector(alarmService, settings),
          
          const SizedBox(height: 24),
          
          // Quiet Hours Section
          _buildSectionHeader('Quiet Hours', Icons.nights_stay_rounded),
          const SizedBox(height: 12),
          
          // Quiet mode toggle
          _buildSwitchCard(
            title: 'Enable Quiet Hours',
            subtitle: 'Disable announcements during set times',
            semanticsLabel: 'Enable quiet hours. ${alarmService.quietModeEnabled ? "Currently enabled" : "Currently disabled"}',
            value: alarmService.quietModeEnabled,
            onChanged: (value) {
              alarmService.setQuietModeEnabled(value);
            },
            settings: settings,
          ),
          
          if (alarmService.quietModeEnabled) ...[
            const SizedBox(height: 12),
            
            // Quiet start time
            _buildTimePicker(
              title: 'Quiet Start Time',
              time: alarmService.quietStartTimeString,
              semanticsLabel: 'Quiet hours start time. Currently set to ${alarmService.quietStartTimeString}',
              onTap: () => _selectQuietStartTime(alarmService),
              settings: settings,
            ),
            
            const SizedBox(height: 12),
            
            // Quiet end time
            _buildTimePicker(
              title: 'Quiet End Time',
              time: alarmService.quietEndTimeString,
              semanticsLabel: 'Quiet hours end time. Currently set to ${alarmService.quietEndTimeString}',
              onTap: () => _selectQuietEndTime(alarmService),
              settings: settings,
            ),
            
            const SizedBox(height: 12),
            
            // Block touch during quiet
            _buildSwitchCard(
              title: 'Block Touch During Quiet',
              subtitle: 'Also disable tap-to-speak during quiet hours',
              semanticsLabel: 'Block touch during quiet hours. ${settings.blockTouchDuringQuiet ? "Currently enabled" : "Currently disabled"}',
              value: settings.blockTouchDuringQuiet,
              onChanged: (value) {
                settings.setBlockTouchDuringQuiet(value);
              },
              settings: settings,
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Feedback Settings Section
          _buildSectionHeader('Feedback & Interaction', Icons.touch_app_rounded),
          const SizedBox(height: 12),
          
          // Touch to speak toggle
          _buildSwitchCard(
            title: 'Touch to Speak',
            subtitle: 'Tap anywhere on screen to hear time',
            semanticsLabel: 'Touch to speak. ${settings.touchToSpeakEnabled ? "Currently enabled" : "Currently disabled"}',
            value: settings.touchToSpeakEnabled,
            onChanged: (value) {
              settings.setTouchToSpeakEnabled(value);
            },
            settings: settings,
          ),
          
          const SizedBox(height: 12),
          
          // Vibration toggle
          _buildSwitchCard(
            title: 'Vibration Feedback',
            subtitle: 'Feel a vibration when time is spoken',
            semanticsLabel: 'Vibration feedback. ${settings.vibrationEnabled ? "Currently enabled" : "Currently disabled"}',
            value: settings.vibrationEnabled,
            onChanged: (value) {
              settings.setVibrationEnabled(value);
            },
            settings: settings,
          ),
          
          const SizedBox(height: 24),
          
          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette_rounded),
          const SizedBox(height: 12),
          
          // Dark mode toggle
          _buildSwitchCard(
            title: 'Dark Mode',
            subtitle: 'Use dark theme for better visibility',
            semanticsLabel: 'Dark mode. ${settings.darkMode ? "Currently enabled" : "Currently disabled"}',
            value: settings.darkMode,
            onChanged: (value) {
              settings.setDarkMode(value);
            },
            settings: settings,
          ),
          
          const SizedBox(height: 40),
          
          // About section
          _buildAboutSection(settings),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build a section header with icon
  Widget _buildSectionHeader(String title, IconData icon) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a slider card with label and value display
  Widget _buildSliderCard({
    required String title,
    required String semanticsLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required Function(double) onChanged,
    required SettingsProvider settings,
  }) {
    return Semantics(
      label: semanticsLabel,
      slider: true,
      value: valueLabel,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: settings.darkMode
                          ? const Color(0xFF00BFA5).withOpacity(0.2)
                          : const Color(0xFF00796B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      valueLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: settings.darkMode
                            ? const Color(0xFF00BFA5)
                            : const Color(0xFF00796B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get speed label from rate value
  String _getSpeedLabel(double rate) {
    if (rate < 0.3) return 'Very Slow';
    if (rate < 0.4) return 'Slow';
    if (rate < 0.6) return 'Normal';
    if (rate < 0.8) return 'Fast';
    return 'Very Fast';
  }

  /// Build language selector dropdown
  Widget _buildLanguageSelector(SettingsProvider settings, TtsService ttsService) {
    return Semantics(
      label: 'Language selector. Currently set to ${_getLanguageName(settings.language)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voice Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: settings.darkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: settings.darkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settings.language,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    style: TextStyle(
                      fontSize: 16,
                      color: settings.darkMode ? Colors.white : Colors.black87,
                    ),
                    dropdownColor: settings.darkMode
                        ? const Color(0xFF1A2332)
                        : Colors.white,
                    items: _languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(lang['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        settings.setLanguage(value);
                        ttsService.setLanguage(value);
                        // Update background service immediately
                        BackgroundService.updateVoiceSettings(
                          language: value,
                          volume: settings.volume,
                          rate: settings.rate,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get language name from code
  String _getLanguageName(String code) {
    return _languages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': code},
    )['name']!;
  }

  /// Build test voice button
  Widget _buildTestVoiceButton(TtsService ttsService, SettingsProvider settings) {
    return Semantics(
      button: true,
      label: 'Test voice. Double tap to hear a sample.',
      child: Card(
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            ttsService.testVoice();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: settings.darkMode
                        ? const Color(0xFF00BFA5).withOpacity(0.2)
                        : const Color(0xFF00796B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    size: 28,
                    color: settings.darkMode
                        ? const Color(0xFF00BFA5)
                        : const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Voice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to hear a voice sample',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build interval selector
  Widget _buildIntervalSelector(AlarmService alarmService, SettingsProvider settings) {
    // Find the matching option or use custom
    int selectedValue = alarmService.intervalMinutes;
    bool isCustom = !_intervalOptions.any((opt) => 
      opt['value'] == selectedValue && opt['value'] != -1
    );
    if (isCustom && selectedValue > 0) {
      selectedValue = -1;
    }

    return Semantics(
      label: 'Auto announcement interval. Currently set to ${_getIntervalLabel(alarmService.intervalMinutes)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Announcement Interval',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Automatically speak time at regular intervals',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
              // Radio buttons for interval options
              ...List.generate(_intervalOptions.length, (index) {
                final option = _intervalOptions[index];
                final isSelected = option['value'] == selectedValue ||
                    (option['value'] == -1 && isCustom && alarmService.intervalMinutes > 0);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      if (option['value'] == -1) {
                        _showCustomIntervalDialog(alarmService);
                      } else {
                        alarmService.setInterval(option['value']);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (settings.darkMode
                                ? const Color(0xFF00BFA5).withOpacity(0.15)
                                : const Color(0xFF00796B).withOpacity(0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (settings.darkMode
                                  ? const Color(0xFF00BFA5)
                                  : const Color(0xFF00796B))
                              : Colors.grey.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected
                                ? (settings.darkMode
                                    ? const Color(0xFF00BFA5)
                                    : const Color(0xFF00796B))
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            option['value'] == -1 && isCustom && alarmService.intervalMinutes > 0
                                ? 'Custom: ${alarmService.intervalMinutes} minutes'
                                : option['label'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Get interval label from minutes
  String _getIntervalLabel(int minutes) {
    if (minutes == 0) return 'No repeat';
    if (minutes == 15) return 'Every 15 minutes';
    if (minutes == 30) return 'Every 30 minutes';
    if (minutes == 60) return 'Every hour';
    return 'Every $minutes minutes';
  }

  /// Show custom interval input dialog
  Future<void> _showCustomIntervalDialog(AlarmService alarmService) async {
    _customIntervalController.text = alarmService.intervalMinutes > 0
        ? alarmService.intervalMinutes.toString()
        : '';
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        final settings = context.watch<SettingsProvider>();
        return AlertDialog(
          title: const Text('Custom Interval'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter interval in minutes:'),
              const SizedBox(height: 16),
              TextField(
                controller: _customIntervalController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., 5, 10, 45',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixText: 'minutes',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(_customIntervalController.text);
                if (value != null && value > 0) {
                  Navigator.pop(context, value);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: settings.darkMode
                    ? const Color(0xFF00BFA5)
                    : const Color(0xFF00796B),
              ),
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      alarmService.setInterval(result);
    }
  }

  /// Build switch card for toggle settings
  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required String semanticsLabel,
    required bool value,
    required Function(bool) onChanged,
    required SettingsProvider settings,
  }) {
    return Semantics(
      label: semanticsLabel,
      toggled: value,
      child: Card(
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build time picker card
  Widget _buildTimePicker({
    required String title,
    required String time,
    required String semanticsLabel,
    required VoidCallback onTap,
    required SettingsProvider settings,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: settings.darkMode
                        ? const Color(0xFF00BFA5).withOpacity(0.2)
                        : const Color(0xFF00796B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: settings.darkMode
                            ? const Color(0xFF00BFA5)
                            : const Color(0xFF00796B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: settings.darkMode
                              ? const Color(0xFF00BFA5)
                              : const Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show time picker for quiet start time
  Future<void> _selectQuietStartTime(AlarmService alarmService) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: alarmService.quietStartHour,
        minute: alarmService.quietStartMinute,
      ),
      helpText: 'Select quiet hours start time',
    );
    
    if (picked != null) {
      alarmService.setQuietStartTime(picked.hour, picked.minute);
    }
  }

  /// Show time picker for quiet end time
  Future<void> _selectQuietEndTime(AlarmService alarmService) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: alarmService.quietEndHour,
        minute: alarmService.quietEndMinute,
      ),
      helpText: 'Select quiet hours end time',
    );
    
    if (picked != null) {
      alarmService.setQuietEndTime(picked.hour, picked.minute);
    }
  }

  /// Build about section
  Widget _buildAboutSection(SettingsProvider settings) {
    return Semantics(
      label: 'About TimeTalk. Version 1.0.0. A voice-based clock assistant for blind and visually impaired users.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                size: 48,
                color: settings.darkMode
                    ? const Color(0xFF00BFA5)
                    : const Color(0xFF00796B),
              ),
              const SizedBox(height: 16),
              const Text(
                'TimeTalk',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A voice-based clock assistant designed for blind and visually impaired users.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

