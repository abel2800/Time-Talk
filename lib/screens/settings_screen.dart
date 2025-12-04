import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../services/alarm_service.dart';
import '../services/settings_provider.dart';
import '../services/background_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/time_utils.dart';

/// Settings Screen with full localization support
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Available languages with native names
  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)', 'flag': '🇺🇸'},
    {'code': 'es-ES', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr-FR', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'de-DE', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'it-IT', 'name': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'pt-BR', 'name': 'Português', 'flag': '🇧🇷'},
    {'code': 'zh-CN', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'ja-JP', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko-KR', 'name': '한국어', 'flag': '🇰🇷'},
    {'code': 'hi-IN', 'name': 'हिन्दी', 'flag': '🇮🇳'},
    {'code': 'ar-SA', 'name': 'العربية', 'flag': '🇸🇦'},
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final alarmService = context.watch<AlarmService>();
    final ttsService = context.watch<TtsService>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Voice Settings
          _buildSectionHeader(l10n.voiceSettings, Icons.record_voice_over_rounded, settings),
          const SizedBox(height: 12),
          
          _buildSliderCard(
            title: l10n.voiceVolume,
            value: settings.volume,
            valueLabel: '${(settings.volume * 100).round()}%',
            onChanged: (v) {
              settings.setVolume(v);
              ttsService.setVolume(v);
              BackgroundService.updateVoiceSettings(language: settings.language, volume: v, rate: settings.rate);
            },
            settings: settings,
          ),
          const SizedBox(height: 12),
          
          _buildSliderCard(
            title: l10n.voiceSpeed,
            value: settings.rate,
            min: 0.1,
            valueLabel: _getSpeedLabel(settings.rate, l10n),
            onChanged: (v) {
              settings.setRate(v);
              ttsService.setRate(v);
              BackgroundService.updateVoiceSettings(language: settings.language, volume: settings.volume, rate: v);
            },
            settings: settings,
          ),
          const SizedBox(height: 12),
          
          // Language Selector
          _buildLanguageCard(settings, ttsService, l10n),
          const SizedBox(height: 12),
          
          // Test Voice
          _buildTestVoiceCard(ttsService, l10n, settings),
          const SizedBox(height: 24),
          
          // Auto Announcements
          _buildSectionHeader(l10n.autoAnnouncements, Icons.alarm_rounded, settings),
          const SizedBox(height: 12),
          _buildIntervalCard(alarmService, l10n, settings),
          const SizedBox(height: 12),
          _buildRepeatCountCard(settings, l10n),
          const SizedBox(height: 24),
          
          // Quiet Hours
          _buildSectionHeader(l10n.quietHours, Icons.nights_stay_rounded, settings),
          const SizedBox(height: 12),
          _buildQuietHoursCard(alarmService, settings, l10n),
          const SizedBox(height: 24),
          
          // Feedback
          _buildSectionHeader(l10n.feedbackInteraction, Icons.touch_app_rounded, settings),
          const SizedBox(height: 12),
          _buildSwitchCard(l10n.touchToSpeak, l10n.tapAnywhereToHear, settings.touchToSpeakEnabled, 
            (v) => settings.setTouchToSpeakEnabled(v), settings),
          const SizedBox(height: 12),
          _buildSwitchCard(l10n.vibrationFeedback, l10n.feelVibration, settings.vibrationEnabled,
            (v) => settings.setVibrationEnabled(v), settings),
          const SizedBox(height: 24),
          
          // Appearance
          _buildSectionHeader(l10n.appearance, Icons.palette_rounded, settings),
          const SizedBox(height: 12),
          _buildSwitchCard(l10n.darkMode, l10n.usesDarkTheme, settings.darkMode,
            (v) => settings.setDarkMode(v), settings),
          const SizedBox(height: 24),
          
          // About
          _buildSectionHeader(l10n.about, Icons.info_rounded, settings),
          const SizedBox(height: 12),
          _buildAboutCard(l10n, settings),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, SettingsProvider settings) {
    return Row(
      children: [
        Icon(icon, size: 24, color: settings.darkMode ? const Color(0xFF00BFA5) : const Color(0xFF00796B)),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
          color: settings.darkMode ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildSliderCard({
    required String title,
    required double value,
    required String valueLabel,
    required Function(double) onChanged,
    required SettingsProvider settings,
    double min = 0.0,
    double max = 1.0,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(valueLabel, style: const TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(SettingsProvider settings, TtsService ttsService, AppLocalizations l10n) {
    final currentLang = _languages.firstWhere((l) => l['code'] == settings.language, 
      orElse: () => _languages.first);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.voiceLanguage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: settings.darkMode ? Colors.grey[700]! : Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: settings.language,
                isExpanded: true,
                underline: const SizedBox(),
                items: _languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang['code'],
                    child: Row(
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(lang['name']!, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settings.setLanguage(value);
                    ttsService.setLanguage(value);
                    BackgroundService.updateVoiceSettings(
                      language: value, volume: settings.volume, rate: settings.rate);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestVoiceCard(TtsService ttsService, AppLocalizations l10n, SettingsProvider settings) {
    return Card(
      child: InkWell(
        onTap: () => ttsService.testVoice(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF00BFA5), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.testVoice, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(l10n.tapToHearSample, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF00BFA5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalCard(AlarmService alarmService, AppLocalizations l10n, SettingsProvider settings) {
    final intervals = [
      {'value': 0, 'label': l10n.noRepeat},
      {'value': 15, 'label': l10n.every15Minutes},
      {'value': 30, 'label': l10n.every30Minutes},
      {'value': 60, 'label': l10n.everyHour},
    ];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.announcementInterval, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(l10n.autoSpeakTime, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            ...intervals.map((interval) {
              final isSelected = alarmService.intervalMinutes == interval['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => alarmService.setInterval(interval['value'] as int),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00BFA5).withOpacity(0.2) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00BFA5) : (settings.darkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? const Color(0xFF00BFA5) : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(interval['label'] as String, style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF00BFA5) : null,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursCard(AlarmService alarmService, SettingsProvider settings, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.enableQuietHours, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(l10n.disableAnnouncements, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Switch(value: alarmService.quietModeEnabled, onChanged: (v) => alarmService.setQuietModeEnabled(v)),
              ],
            ),
            if (alarmService.quietModeEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimeButton(l10n.quietStartTime, alarmService.quietStartTimeString, () async {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: alarmService.quietStartHour, minute: alarmService.quietStartMinute));
                    if (time != null) alarmService.setQuietStartTime(time.hour, time.minute);
                  }, settings)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeButton(l10n.quietEndTime, alarmService.quietEndTimeString, () async {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: alarmService.quietEndHour, minute: alarmService.quietEndMinute));
                    if (time != null) alarmService.setQuietEndTime(time.hour, time.minute);
                  }, settings)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, String time, VoidCallback onTap, SettingsProvider settings) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: settings.darkMode ? Colors.grey[700]! : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 18, color: Color(0xFF00BFA5)),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard(String title, String subtitle, bool value, Function(bool) onChanged, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatCountCard(SettingsProvider settings, AppLocalizations l10n) {
    final repeatOptions = [
      {'value': 1, 'label': l10n.once},
      {'value': 2, 'label': l10n.twice},
      {'value': 3, 'label': l10n.threeTimes},
      {'value': 4, 'label': l10n.fourTimes},
      {'value': 5, 'label': l10n.fiveTimes},
    ];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.repeatCount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(l10n.howManyTimes, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: repeatOptions.map((option) {
                final isSelected = settings.repeatCount == option['value'];
                return InkWell(
                  onTap: () {
                    settings.setRepeatCount(option['value'] as int);
                    BackgroundService.updateRepeatCount(option['value'] as int);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00BFA5).withOpacity(0.2) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00BFA5) : (settings.darkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF00BFA5) : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(AppLocalizations l10n, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.version, style: const TextStyle(fontSize: 16)),
                const Text('1.1.0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.madeWithLove, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  String _getSpeedLabel(double rate, AppLocalizations l10n) {
    if (rate < 0.4) return l10n.slow;
    if (rate > 0.6) return l10n.fast;
    return l10n.normal;
  }
}
