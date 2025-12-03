import 'package:intl/intl.dart';

/// Time utilities with proper localization using intl package

class TimeUtils {
  /// Formats time for speech using intl package for correct localization
  /// Automatically handles 12h/24h format and AM/PM based on locale
  static String formatTimeForSpeech(DateTime time, {String language = 'en-US'}) {
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
  
  /// Formats time for digital display (12-hour format with seconds)
  static String formatTimeDigital(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    int second = time.second;
    String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) hour = 12;
    else if (hour > 12) hour = hour - 12;
    
    String minuteStr = minute.toString().padLeft(2, '0');
    String secondStr = second.toString().padLeft(2, '0');
    
    return '$hour:$minuteStr:$secondStr $period';
  }
  
  /// Checks if current time is within quiet hours
  static bool isQuietTime(DateTime now, int quietStartHour, int quietStartMinute,
      int quietEndHour, int quietEndMinute) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietStartHour * 60 + quietStartMinute;
    final endMinutes = quietEndHour * 60 + quietEndMinute;
    
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }
  
  /// Formats a time picker value for display
  static String formatPickerTime(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour;
    
    if (displayHour == 0) displayHour = 12;
    else if (displayHour > 12) displayHour = displayHour - 12;
    
    String minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
  
  static double getHourAngle(DateTime time) {
    double hour = time.hour % 12 + time.minute / 60.0;
    return (hour / 12) * 2 * 3.14159265359;
  }
  
  static double getMinuteAngle(DateTime time) {
    double minute = time.minute + time.second / 60.0;
    return (minute / 60) * 2 * 3.14159265359;
  }
  
  static double getSecondAngle(DateTime time) {
    return (time.second / 60) * 2 * 3.14159265359;
  }
}
