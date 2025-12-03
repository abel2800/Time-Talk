/// Utility functions for time formatting and calculations
/// Used throughout TimeTalk for consistent time handling

class TimeUtils {
  /// Formats time for speech output
  /// Example: "9:13 PM"
  static String formatTimeForSpeech(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    String period = hour >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    String minuteStr = minute.toString().padLeft(2, '0');
    
    return '$hour:$minuteStr $period';
  }
  
  /// Formats time for digital display (12-hour format)
  /// Example: "7:32 PM"
  static String formatTimeDigital(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    int second = time.second;
    String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    String minuteStr = minute.toString().padLeft(2, '0');
    String secondStr = second.toString().padLeft(2, '0');
    
    return '$hour:$minuteStr:$secondStr $period';
  }
  
  /// Formats time for digital display without seconds
  static String formatTimeDigitalShort(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    String minuteStr = minute.toString().padLeft(2, '0');
    
    return '$hour:$minuteStr $period';
  }
  
  /// Checks if current time is within quiet hours
  /// Returns true if we should be quiet
  static bool isQuietTime(DateTime now, int quietStartHour, int quietStartMinute,
      int quietEndHour, int quietEndMinute) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietStartHour * 60 + quietStartMinute;
    final endMinutes = quietEndHour * 60 + quietEndMinute;
    
    // Handle overnight quiet period (e.g., 10 PM to 7 AM)
    if (startMinutes > endMinutes) {
      // Quiet period crosses midnight
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // Normal period within same day
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }
  
  /// Formats a time picker value for display
  static String formatPickerTime(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour;
    
    if (displayHour == 0) {
      displayHour = 12;
    } else if (displayHour > 12) {
      displayHour = displayHour - 12;
    }
    
    String minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
  
  /// Gets the angle for the hour hand (in radians)
  static double getHourAngle(DateTime time) {
    double hour = time.hour % 12 + time.minute / 60.0;
    return (hour / 12) * 2 * 3.14159265359;
  }
  
  /// Gets the angle for the minute hand (in radians)
  static double getMinuteAngle(DateTime time) {
    double minute = time.minute + time.second / 60.0;
    return (minute / 60) * 2 * 3.14159265359;
  }
  
  /// Gets the angle for the second hand (in radians)
  static double getSecondAngle(DateTime time) {
    return (time.second / 60) * 2 * 3.14159265359;
  }
}

