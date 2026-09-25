import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule_category.dart';
import '../models/schedule_entry.dart';
import 'schedule_provider.dart';

/// Currently selected date in the calendar strip (defaults to today)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Optional category filter chip
final selectedCategoryFilterProvider = StateProvider<ScheduleCategory?>((ref) {
  return null; // null means "All categories"
});

/// Helper to parse "HH:mm" or "H:mm" into total minutes from midnight for robust numerical sorting
int _parseTimeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
  return 0;
}

/// Active schedule entries for the selected day of the week
final schedulesForSelectedDateProvider = Provider<List<ScheduleEntry>>((ref) {
  final allSchedules = ref.watch(scheduleListProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);

  final weekday = selectedDate.weekday; // 1 = Mon, 7 = Sun

  return allSchedules.where((entry) {
    final matchesDay = entry.daysOfWeek.contains(weekday);
    final matchesCategory = categoryFilter == null || entry.category == categoryFilter;
    return matchesDay && matchesCategory;
  }).toList()
    ..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
});

/// Schedules specifically for today's weekday
final schedulesForTodayProvider = Provider<List<ScheduleEntry>>((ref) {
  final allSchedules = ref.watch(scheduleListProvider);
  final weekday = DateTime.now().weekday;

  return allSchedules.where((entry) => entry.daysOfWeek.contains(weekday)).toList()
    ..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
});

/// Counts how many schedule entries exist for each weekday (1..7)
final weeklyScheduleCountsProvider = Provider<Map<int, int>>((ref) {
  final allSchedules = ref.watch(scheduleListProvider);
  final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

  for (final entry in allSchedules) {
    if (!entry.isActive) continue;
    for (final day in entry.daysOfWeek) {
      counts[day] = (counts[day] ?? 0) + 1;
    }
  }

  return counts;
});

/// Model representing the live status of a schedule item today (ongoing or upcoming)
class ScheduleLiveStatus {
  final ScheduleEntry entry;
  final bool isOngoing; // true if currently in progress right now
  final int startMinutes;
  final int endMinutes;

  const ScheduleLiveStatus({
    required this.entry,
    required this.isOngoing,
    required this.startMinutes,
    required this.endMinutes,
  });
}

/// Active ongoing or next upcoming schedule item for today
final activeOrUpcomingScheduleProvider = Provider<ScheduleLiveStatus?>((ref) {
  final allSchedules = ref.watch(scheduleListProvider);
  final now = DateTime.now();
  final currentWeekday = now.weekday;
  final currentMinutes = now.hour * 60 + now.minute;

  final yesterdayDate = now.subtract(const Duration(days: 1));
  final yesterdayWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1;

  final todayEntries = allSchedules
      .where((e) =>
          e.isActive &&
          e.daysOfWeek.contains(currentWeekday) &&
          !e.isMutedOnDate(now))
      .toList()
    ..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

  // Yesterday's entries that span next day (still potentially ongoing)
  final overnightFromYesterday = allSchedules
      .where((e) =>
          e.isActive &&
          e.spansNextDay &&
          e.daysOfWeek.contains(yesterdayWeekday) &&
          !e.isMutedOnDate(yesterdayDate))
      .toList();

  // 1. Check overnight entries from YESTERDAY that are still ongoing now
  for (final entry in overnightFromYesterday) {
    final endParts = entry.endTime.split(':');
    if (endParts.length == 2) {
      final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      // If current time is before the end time on this new day, it's ongoing
      if (currentMinutes < endMin) {
        final startParts = entry.startTime.split(':');
        final startMin = startParts.length == 2
            ? int.parse(startParts[0]) * 60 + int.parse(startParts[1])
            : 0;
        return ScheduleLiveStatus(
          entry: entry,
          isOngoing: true,
          startMinutes: startMin,
          endMinutes: endMin,
        );
      }
    }
  }

  // 2. Check for ONGOING class in today's entries (start <= now < end)
  for (final entry in todayEntries) {
    final startParts = entry.startTime.split(':');
    final endParts = entry.endTime.split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      int endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      if (endMin < startMin) endMin += 24 * 60; // Overnight

      final bool isOngoing = (currentMinutes >= startMin && currentMinutes < endMin);

      if (isOngoing) {
        return ScheduleLiveStatus(
          entry: entry,
          isOngoing: true,
          startMinutes: startMin,
          endMinutes: endMin,
        );
      }
    }
  }

  // 3. If no ongoing class, find the NEXT upcoming class today (start > now)
  for (final entry in todayEntries) {
    final startParts = entry.startTime.split(':');
    final endParts = entry.endTime.split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      if (startMin > currentMinutes) {
        return ScheduleLiveStatus(
          entry: entry,
          isOngoing: false,
          startMinutes: startMin,
          endMinutes: endMin,
        );
      }
    }
  }

  return null;
});

/// Model representing the very next upcoming schedule across any day of the week
class NextUpcomingScheduleResult {
  final ScheduleEntry entry;
  final DateTime targetDateTime;
  final int daysDifference; // 0 for today, 1 for tomorrow, etc.
  final bool isToday;

  const NextUpcomingScheduleResult({
    required this.entry,
    required this.targetDateTime,
    required this.daysDifference,
    required this.isToday,
  });
}

/// Computes the exact next upcoming schedule across all coming days (today, tomorrow, next week)
final nextUpcomingAcrossAllDaysProvider = Provider<NextUpcomingScheduleResult?>((ref) {
  final allSchedules = ref.watch(scheduleListProvider);
  if (allSchedules.isEmpty) return null;

  final now = DateTime.now();
  final currentWeekday = now.weekday;
  final currentMinutes = now.hour * 60 + now.minute;

  // 1. Check for upcoming class TODAY (start > now)
  final todayEntries = allSchedules
      .where((e) =>
          e.isActive &&
          e.daysOfWeek.contains(currentWeekday) &&
          !e.isMutedOnDate(now))
      .toList()
    ..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

  for (final entry in todayEntries) {
    final startParts = entry.startTime.split(':');
    if (startParts.length == 2) {
      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final totalStartMinutes = startHour * 60 + startMin;

      if (totalStartMinutes > currentMinutes) {
        final targetDate = DateTime(now.year, now.month, now.day, startHour, startMin);
        return NextUpcomingScheduleResult(
          entry: entry,
          targetDateTime: targetDate,
          daysDifference: 0,
          isToday: true,
        );
      }
    }
  }

  // 2. Search ahead for the next 7 days (i = 1..7)
  for (int i = 1; i <= 7; i++) {
    final candidateDate = now.add(Duration(days: i));
    final candidateWeekday = candidateDate.weekday;

    final candidateEntries = allSchedules
        .where((e) =>
            e.isActive &&
            e.daysOfWeek.contains(candidateWeekday) &&
            !e.isMutedOnDate(candidateDate))
        .toList()
      ..sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

    if (candidateEntries.isNotEmpty) {
      final nextEntry = candidateEntries.first;
      final startParts = nextEntry.startTime.split(':');
      final startHour = startParts.length == 2 ? int.parse(startParts[0]) : 8;
      final startMin = startParts.length == 2 ? int.parse(startParts[1]) : 0;

      final targetDate = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        startHour,
        startMin,
      );

      return NextUpcomingScheduleResult(
        entry: nextEntry,
        targetDateTime: targetDate,
        daysDifference: i,
        isToday: false,
      );
    }
  }

  return null;
});

/// Legacy Next upcoming schedule item for today
final upcomingTodayScheduleProvider = Provider<ScheduleEntry?>((ref) {
  final status = ref.watch(activeOrUpcomingScheduleProvider);
  return status?.entry;
});
