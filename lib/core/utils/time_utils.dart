import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeUtils {
  /// Formats a time string (HH:mm:ss) to display format (hh:mm AM/PM)
  static String formatToDisplay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      // Handles HH:mm:ss or HH:mm
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final time = TimeOfDay(hour: hour, minute: minute);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  /// Converts TimeOfDay to backend format (HH:mm)
  static String toBackendFormat(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
