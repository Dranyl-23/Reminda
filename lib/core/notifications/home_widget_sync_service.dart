import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../utils/time_utils.dart';

class HomeWidgetSyncService {
  HomeWidgetSyncService._();
  static final HomeWidgetSyncService instance = HomeWidgetSyncService._();

  static const MethodChannel _channel =
      MethodChannel('com.schedly.app/home_widget');

  /// Computes the next active or ongoing schedule and updates the native Android Home Screen Widget.
  Future<void> syncWithSchedules(List<ScheduleEntry> allSchedules) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final now = DateTime.now();
      final todayIso = ScheduleEntry.dateToIso(now);
      final currentWeekday = now.weekday;
      final currentMinutes = now.hour * 60 + now.minute;

      final todayEntries = allSchedules
          .where((e) =>
              e.isActive &&
              e.daysOfWeek.contains(currentWeekday) &&
              !e.mutedDates.contains(todayIso))
          .toList()
        ..sort((a, b) => TimeUtils.timeToMinutes(a.startTime)
            .compareTo(TimeUtils.timeToMinutes(b.startTime)));

      ScheduleEntry? target;
      String statusBadge = 'UP NEXT';
      String dayBadge = 'TODAY';

      // 1. Check ongoing right now
      for (final entry in todayEntries) {
        final startMin = TimeUtils.timeToMinutes(entry.startTime);
        int endMin = TimeUtils.timeToMinutes(entry.endTime);
        if (entry.spansNextDay || endMin < startMin) endMin += 24 * 60;
        if (currentMinutes >= startMin && currentMinutes < endMin) {
          target = entry;
          statusBadge = 'ONGOING NOW';
          break;
        }
      }

      // 2. Check upcoming later today
      if (target == null) {
        for (final entry in todayEntries) {
          final startMin = TimeUtils.timeToMinutes(entry.startTime);
          if (startMin > currentMinutes) {
            target = entry;
            statusBadge = 'UP NEXT TODAY';
            break;
          }
        }
      }

      // 3. Look ahead up to 7 days
      if (target == null) {
        for (int i = 1; i <= 7; i++) {
          final candidateDate = now.add(Duration(days: i));
          final candidateIso = ScheduleEntry.dateToIso(candidateDate);
          final candidateWeekday = candidateDate.weekday;
          final matches = allSchedules
              .where((e) =>
                  e.isActive &&
                  e.daysOfWeek.contains(candidateWeekday) &&
                  !e.mutedDates.contains(candidateIso))
              .toList()
            ..sort((a, b) => TimeUtils.timeToMinutes(a.startTime)
                .compareTo(TimeUtils.timeToMinutes(b.startTime)));

          if (matches.isNotEmpty) {
            target = matches.first;
            statusBadge = i == 1
                ? 'TOMORROW'
                : TimeUtils.getWeekdayFull(candidateWeekday).toUpperCase();
            dayBadge = TimeUtils.getDayAbbr(candidateWeekday);
            break;
          }
        }
      }

      if (target != null) {
        final timeFormatted =
            '${TimeUtils.formatTo12Hour(target.startTime)} – ${TimeUtils.formatTo12Hour(target.endTime)}';
        final roomText =
            (target.location != null && target.location!.trim().isNotEmpty)
                ? target.location!.trim()
                : target.category.displayName;
        final isOngoing = statusBadge == 'ONGOING NOW';

        await _channel.invokeMethod('updateHomeWidget', {
          'hasSchedule': true,
          'title': target.title,
          'subtitle': '$dayBadge • $timeFormatted • $roomText',
          'timeRange': timeFormatted,
          'location': roomText,
          'status': statusBadge,
          'statusBadge': statusBadge,
          'dayBadge': dayBadge,
          'isOngoing': isOngoing,
          'activeCount': allSchedules.where((e) => e.isActive).length,
        });
      } else {
        await _channel.invokeMethod('updateHomeWidget', {
          'hasSchedule': false,
          'title': 'No Upcoming Classes',
          'subtitle': 'Tap to open Reminda & scan your schedule',
          'timeRange': 'Tap to open Reminda & scan your schedule',
          'location': 'All clear',
          'status': 'FREE',
          'statusBadge': 'REMINDA',
          'dayBadge': TimeUtils.getDayAbbr(currentWeekday),
          'isOngoing': false,
          'activeCount': 0,
        });
      }
    } catch (e) {
      debugPrint('HomeWidgetSyncService: Widget sync skipped ($e)');
    }
  }
}
