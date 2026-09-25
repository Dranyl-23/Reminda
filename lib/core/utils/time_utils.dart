import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/schedule_entry.dart';

class TimeUtils {
  static const List<String> weekdayShortNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  static const List<String> weekdayFullNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  /// Returns 3-letter abbreviation (1 = Mon, 7 = Sun)
  static String getWeekdayShort(int day) {
    if (day >= 1 && day <= 7) {
      return weekdayShortNames[day - 1];
    }
    return '';
  }

  /// Returns full weekday name (1 = Monday, 7 = Sunday)
  static String getWeekdayFull(int day) {
    if (day >= 1 && day <= 7) {
      return weekdayFullNames[day - 1];
    }
    return '';
  }

  /// Returns 3-letter uppercase abbreviation (1 = MON, 7 = SUN)
  static String getDayAbbr(int weekday) {
    switch (weekday) {
      case 1:
        return 'MON';
      case 2:
        return 'TUE';
      case 3:
        return 'WED';
      case 4:
        return 'THU';
      case 5:
        return 'FRI';
      case 6:
        return 'SAT';
      case 7:
        return 'SUN';
      default:
        return 'DAY';
    }
  }

  /// Formats multiple days into a standard abbreviation (e.g. "TTH", "MWF", "M-F", "MON")
  static String formatDaysAbbr(List<int> days) {
    if (days.isEmpty) return 'DAY';
    final sorted = List<int>.from(days)..sort();
    if (sorted.length == 7) return 'DAILY';
    if (sorted.length == 5 && sorted.join(',') == '1,2,3,4,5') return 'M-F';
    if (sorted.length == 3 && sorted.join(',') == '1,3,5') return 'MWF';
    if (sorted.length == 2 && sorted.join(',') == '2,4') return 'TTH';
    if (sorted.length == 2 && sorted.join(',') == '1,4') return 'M-TH';
    if (sorted.length == 2 && sorted.join(',') == '2,5') return 'T-F';
    if (sorted.length == 2 && sorted.join(',') == '3,6') return 'W-S';
    if (sorted.length == 2 && sorted.join(',') == '5,6') return 'F-S';
    if (sorted.length == 2 && sorted.join(',') == '6,7') return 'S-S';
    if (sorted.length == 1) return getDayAbbr(sorted.first);
    return sorted.map((d) => getDayAbbr(d)).join('/');
  }

  /// Returns standard color palette for a given weekday
  static Color getDayColor(int weekday) {
    switch (weekday) {
      case 1:
        return const Color(0xFF10B981); // MON - Green
      case 2:
        return const Color(0xFF2563EB); // TUE - Blue
      case 3:
        return const Color(0xFFF59E0B); // WED - Amber
      case 4:
        return const Color(0xFFF43F5E); // THU - Rose
      case 5:
        return const Color(0xFF06B6D4); // FRI - Cyan
      case 6:
        return const Color(0xFF8B5CF6); // SAT - Purple
      case 7:
        return const Color(0xFF6366F1); // SUN - Indigo
      default:
        return const Color(0xFF2563EB);
    }
  }

  /// Formats HH:mm string (24h) to 12h display e.g. "8:30 AM" or "10:00 PM"
  static String formatTo12Hour(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return time24;
    }
  }

  /// Converts TimeOfDay to "HH:mm" string
  static String timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Converts "HH:mm" string to TimeOfDay
  static TimeOfDay stringToTimeOfDay(String time24) {
    try {
      final parts = time24.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  /// Calculates duration in hours and minutes (e.g. "1h 30m" or "8h")
  static String calculateDuration(String startTime, String endTime, {bool spansNextDay = false}) {
    try {
      final start = stringToTimeOfDay(startTime);
      final end = stringToTimeOfDay(endTime);

      int startMinutes = start.hour * 60 + start.minute;
      int endMinutes = end.hour * 60 + end.minute;

      if (spansNextDay || endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }

      int diffMinutes = endMinutes - startMinutes;
      if (diffMinutes <= 0) return '';

      int hours = diffMinutes ~/ 60;
      int minutes = diffMinutes % 60;

      if (hours > 0 && minutes > 0) {
        return '${hours}h ${minutes}m';
      } else if (hours > 0) {
        return '${hours}h';
      } else {
        return '${minutes}m';
      }
    } catch (_) {
      return '';
    }
  }

  /// Checks if time string spans overnight (end is before start)
  static bool checkSpansOvernight(String startTime, String endTime) {
    try {
      final start = stringToTimeOfDay(startTime);
      final end = stringToTimeOfDay(endTime);
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;
      return endMinutes < startMinutes;
    } catch (_) {
      return false;
    }
  }

  /// Formats reminder lead time minutes into friendly label
  static String formatLeadMinutes(int minutes) {
    if (minutes == 0) return 'At event time';
    if (minutes < 60) return '$minutes mins before';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return hours == 1 ? '1 hour before' : '$hours hours before';
    }
    return '$hours hr $remainingMins min before';
  }

  /// Parses "HH:mm" into minutes from midnight (0..1439)
  static int timeToMinutes(String time24) {
    final tod = stringToTimeOfDay(time24);
    return tod.hour * 60 + tod.minute;
  }

  /// Formats a DateTime into a friendly short date (e.g. "Mon, Sep 28")
  static String formatShortDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  /// Detects time overlaps between a candidate schedule and a list of existing schedules
  static List<ScheduleConflict> findConflicts(
    ScheduleEntry candidate,
    List<ScheduleEntry> existingSchedules,
  ) {
    final List<ScheduleConflict> conflicts = [];
    final int candStart = timeToMinutes(candidate.startTime);
    int candEnd = timeToMinutes(candidate.endTime);
    if (candidate.spansNextDay || candEnd <= candStart) {
      candEnd += 24 * 60;
    }

    for (final other in existingSchedules) {
      if (!other.isActive) continue;
      if (other.id == candidate.id) continue;
      if (candidate.profileId != null &&
          other.profileId != null &&
          candidate.profileId != other.profileId) {
        continue;
      }

      final int otherStart = timeToMinutes(other.startTime);
      int otherEnd = timeToMinutes(other.endTime);
      if (other.spansNextDay || otherEnd <= otherStart) {
        otherEnd += 24 * 60;
      }

      final overlappingDays = <int>[];
      for (final day in candidate.daysOfWeek) {
        if (other.daysOfWeek.contains(day)) {
          // Both start on the same day: check [candStart, candEnd) vs [otherStart, otherEnd)
          if (candStart < otherEnd && otherStart < candEnd) {
            overlappingDays.add(day);
          }
        }
      }

      if (overlappingDays.isNotEmpty) {
        conflicts.add(
          ScheduleConflict(
            conflictingEntry: other,
            overlappingDays: overlappingDays,
          ),
        );
      }
    }

    return conflicts;
  }
}

class ScheduleConflict {
  final ScheduleEntry conflictingEntry;
  final List<int> overlappingDays;

  const ScheduleConflict({
    required this.conflictingEntry,
    required this.overlappingDays,
  });

  String get summaryText {
    final daysStr = TimeUtils.formatDaysAbbr(overlappingDays);
    final startStr = TimeUtils.formatTo12Hour(conflictingEntry.startTime);
    final endStr = TimeUtils.formatTo12Hour(conflictingEntry.endTime);
    return '$daysStr • ${conflictingEntry.title} ($startStr – $endStr)';
  }
}
