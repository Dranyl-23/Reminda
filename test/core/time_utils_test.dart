import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/core/utils/time_utils.dart';
import 'package:schedule_scanner/models/schedule_entry.dart';

void main() {
  group('TimeUtils', () {
    test('formatTo12Hour formats correctly', () {
      expect(TimeUtils.formatTo12Hour('08:00'), '8:00 AM');
      expect(TimeUtils.formatTo12Hour('13:30'), '1:30 PM');
      expect(TimeUtils.formatTo12Hour('00:00'), '12:00 AM');
      expect(TimeUtils.formatTo12Hour('23:59'), '11:59 PM');
      expect(TimeUtils.formatTo12Hour('12:00'), '12:00 PM');
      expect(TimeUtils.formatTo12Hour('invalid'), 'invalid');
    });

    test('timeOfDayToString formats correctly', () {
      expect(TimeUtils.timeOfDayToString(const TimeOfDay(hour: 8, minute: 5)), '08:05');
      expect(TimeUtils.timeOfDayToString(const TimeOfDay(hour: 15, minute: 30)), '15:30');
    });

    test('stringToTimeOfDay parses correctly', () {
      final t1 = TimeUtils.stringToTimeOfDay('08:30');
      expect(t1.hour, 8);
      expect(t1.minute, 30);

      final t2 = TimeUtils.stringToTimeOfDay('invalid');
      expect(t2.hour, 8);
      expect(t2.minute, 0);
    });

    test('calculateDuration works for normal and overnight', () {
      expect(TimeUtils.calculateDuration('08:00', '09:30'), '1h 30m');
      expect(TimeUtils.calculateDuration('09:00', '17:00'), '8h');
      expect(TimeUtils.calculateDuration('08:00', '08:45'), '45m');
      
      // Overnight
      expect(TimeUtils.calculateDuration('22:00', '06:00', spansNextDay: true), '8h');
      expect(TimeUtils.calculateDuration('22:00', '06:00'), '8h'); // Auto-detects
      
      expect(TimeUtils.calculateDuration('invalid', 'invalid'), '');
    });

    test('formatDaysAbbr formats known patterns', () {
      expect(TimeUtils.formatDaysAbbr([1, 2, 3, 4, 5, 6, 7]), 'DAILY');
      expect(TimeUtils.formatDaysAbbr([1, 2, 3, 4, 5]), 'M-F');
      expect(TimeUtils.formatDaysAbbr([1, 3, 5]), 'MWF');
      expect(TimeUtils.formatDaysAbbr([2, 4]), 'TTH');
      expect(TimeUtils.formatDaysAbbr([1]), 'MON');
      expect(TimeUtils.formatDaysAbbr([1, 2]), 'MON/TUE');
      expect(TimeUtils.formatDaysAbbr([]), 'DAY');
    });

    test('getWeekdayShort and getWeekdayFull return correct strings', () {
      expect(TimeUtils.getWeekdayShort(1), 'Mon');
      expect(TimeUtils.getWeekdayShort(7), 'Sun');
      expect(TimeUtils.getWeekdayShort(8), '');
      
      expect(TimeUtils.getWeekdayFull(2), 'Tuesday');
      expect(TimeUtils.getWeekdayFull(6), 'Saturday');
      expect(TimeUtils.getWeekdayFull(0), '');
    });

    test('getDayAbbr handles all values', () {
      expect(TimeUtils.getDayAbbr(1), 'MON');
      expect(TimeUtils.getDayAbbr(7), 'SUN');
      expect(TimeUtils.getDayAbbr(99), 'DAY');
    });

    test('formatLeadMinutes returns friendly label', () {
      expect(TimeUtils.formatLeadMinutes(0), 'At event time');
      expect(TimeUtils.formatLeadMinutes(15), '15 mins before');
      expect(TimeUtils.formatLeadMinutes(60), '1 hour before');
      expect(TimeUtils.formatLeadMinutes(120), '2 hours before');
      expect(TimeUtils.formatLeadMinutes(90), '1 hr 30 min before');
    });

    test('checkSpansOvernight returns true/false', () {
      expect(TimeUtils.checkSpansOvernight('08:00', '17:00'), isFalse);
      expect(TimeUtils.checkSpansOvernight('22:00', '06:00'), isTrue);
      expect(TimeUtils.checkSpansOvernight('invalid', 'time'), isFalse);
    });

    test('findConflicts detects overlaps correctly', () {
      final entry1 = ScheduleEntry(
        id: '1',
        title: 'Morning Class',
        daysOfWeek: [1, 3, 5],
        startTime: '08:00',
        endTime: '10:00',
        isActive: true,
      );
      
      final entry2 = ScheduleEntry(
        id: '2',
        title: 'Late Morning Class',
        daysOfWeek: [1], // Monday
        startTime: '09:00',
        endTime: '11:00',
        isActive: true,
      );

      final entry3 = ScheduleEntry(
        id: '3',
        title: 'Afternoon Class',
        daysOfWeek: [1], // Monday
        startTime: '13:00',
        endTime: '15:00',
        isActive: true,
      );
      
      // Candidate overlaps with entry1 on Monday
      final conflicts1 = TimeUtils.findConflicts(entry2, [entry1, entry3]);
      expect(conflicts1.length, 1);
      expect(conflicts1.first.conflictingEntry.id, '1');
      expect(conflicts1.first.overlappingDays, [1]);
      
      // Candidate doesn't overlap
      final conflicts2 = TimeUtils.findConflicts(entry3, [entry1, entry2]);
      expect(conflicts2, isEmpty);
      
      // Different profileId test
      final entry4 = ScheduleEntry(
        id: '4',
        profileId: 'p1',
        title: 'P1 Class',
        daysOfWeek: [2],
        startTime: '08:00',
        endTime: '10:00',
        isActive: true,
      );
      final entry5 = ScheduleEntry(
        id: '5',
        profileId: 'p2',
        title: 'P2 Class',
        daysOfWeek: [2],
        startTime: '08:00',
        endTime: '10:00',
        isActive: true,
      );
      
      // Should ignore conflict if profiles are different
      final conflicts3 = TimeUtils.findConflicts(entry4, [entry5]);
      expect(conflicts3, isEmpty);
    });
  });
}
