import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/core/ai/pdf_text_extractor.dart';
import 'package:schedule_scanner/models/schedule_category.dart';
import 'package:schedule_scanner/models/schedule_entry.dart';
import 'package:schedule_scanner/core/utils/time_utils.dart';

void main() {
  group('ScheduleEntry Model Tests', () {
    test('ScheduleEntry serialization and deserialization', () {
      final entry = ScheduleEntry(
        id: 'test-123',
        title: 'Math 101 - Calculus',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [1, 3, 5],
        startTime: '08:30',
        endTime: '10:00',
        spansNextDay: false,
        location: 'Room 304',
        notes: 'Bring calculator',
        reminders: [15, 60],
        isActive: true,
      );

      final jsonMap = entry.toJson();
      final reconstructed = ScheduleEntry.fromJson(jsonMap);

      expect(reconstructed.id, equals(entry.id));
      expect(reconstructed.title, equals(entry.title));
      expect(reconstructed.category, equals(ScheduleCategory.classSchedule));
      expect(reconstructed.daysOfWeek, equals([1, 3, 5]));
      expect(reconstructed.startTime, equals('08:30'));
      expect(reconstructed.endTime, equals('10:00'));
      expect(reconstructed.spansNextDay, isFalse);
      expect(reconstructed.location, equals('Room 304'));
      expect(reconstructed.reminders, equals([15, 60]));
      expect(reconstructed.isActive, isTrue);
    });

    test('Overnight shift correctly flagged', () {
      final nightEntry = ScheduleEntry(
        title: 'Graveyard Shift',
        category: ScheduleCategory.workShift,
        daysOfWeek: [5, 6],
        startTime: '22:00',
        endTime: '06:00',
        spansNextDay: true,
      );

      expect(nightEntry.spansNextDay, isTrue);
      final duration = TimeUtils.calculateDuration(
        nightEntry.startTime,
        nightEntry.endTime,
        spansNextDay: nightEntry.spansNextDay,
      );
      expect(duration, equals('8h'));
    });
    test('daysOfWeek defaults to empty list when null or missing from JSON', () {
      final jsonWithoutDays = {
        'id': 'test-no-days',
        'title': 'Test Without Days',
        'startTime': '09:00',
        'endTime': '10:00',
      };

      final parsed = ScheduleEntry.fromJson(jsonWithoutDays);
      expect(parsed.daysOfWeek, isEmpty,
          reason: 'daysOfWeek should default to an empty list, not the current day');
    });

    test('daysOfWeek handles null value gracefully', () {
      final jsonWithNullDays = {
        'id': 'test-null-days',
        'title': 'Test Null Days',
        'daysOfWeek': null,
        'startTime': '09:00',
        'endTime': '10:00',
      };

      final parsed = ScheduleEntry.fromJson(jsonWithNullDays);
      expect(parsed.daysOfWeek, isEmpty);
    });
  });

  group('TimeUtils Tests', () {
    test('12-hour AM/PM formatting', () {
      expect(TimeUtils.formatTo12Hour('08:30'), equals('8:30 AM'));
      expect(TimeUtils.formatTo12Hour('12:00'), equals('12:00 PM'));
      expect(TimeUtils.formatTo12Hour('13:45'), equals('1:45 PM'));
      expect(TimeUtils.formatTo12Hour('22:00'), equals('10:00 PM'));
      expect(TimeUtils.formatTo12Hour('00:15'), equals('12:15 AM'));
    });

    test('Duration calculation', () {
      expect(TimeUtils.calculateDuration('08:00', '09:30'), equals('1h 30m'));
      expect(TimeUtils.calculateDuration('13:00', '17:00'), equals('4h'));
      expect(TimeUtils.calculateDuration('22:00', '06:00', spansNextDay: true), equals('8h'));
    });

    test('Weekday names conversion', () {
      expect(TimeUtils.getWeekdayShort(1), equals('Mon'));
      expect(TimeUtils.getWeekdayShort(7), equals('Sun'));
      expect(TimeUtils.getWeekdayFull(1), equals('Monday'));
      expect(TimeUtils.getWeekdayFull(5), equals('Friday'));
    });

    test('Reminder lead minutes formatting', () {
      expect(TimeUtils.formatLeadMinutes(0), equals('At event time'));
      expect(TimeUtils.formatLeadMinutes(15), equals('15 mins before'));
      expect(TimeUtils.formatLeadMinutes(60), equals('1 hour before'));
      expect(TimeUtils.formatLeadMinutes(120), equals('2 hours before'));
    });

    test('TimeUtils.findConflicts detects overlapping schedules on shared days', () {
      final existing = [
        ScheduleEntry(
          id: 'calc-1',
          title: 'Calculus 101',
          category: ScheduleCategory.classSchedule,
          daysOfWeek: [1, 3, 5],
          startTime: '08:30',
          endTime: '10:00',
          isActive: true,
        ),
        ScheduleEntry(
          id: 'phys-1',
          title: 'Physics Lab',
          category: ScheduleCategory.classSchedule,
          daysOfWeek: [2, 4],
          startTime: '09:00',
          endTime: '11:00',
          isActive: true,
        ),
      ];

      final conflicts = TimeUtils.findConflicts(
        ScheduleEntry(
          id: 'cand-1',
          title: 'Chemistry 101',
          category: ScheduleCategory.classSchedule,
          daysOfWeek: [1, 3],
          startTime: '09:15',
          endTime: '10:45',
        ),
        existing,
      );

      expect(conflicts.length, equals(1));
      expect(conflicts.first.conflictingEntry.id, equals('calc-1'));
      expect(conflicts.first.overlappingDays, equals([1, 3]));

      final nonConflicting = TimeUtils.findConflicts(
        ScheduleEntry(
          id: 'cand-2',
          title: 'Afternoon Seminar',
          category: ScheduleCategory.classSchedule,
          daysOfWeek: [1, 3],
          startTime: '10:00',
          endTime: '11:30',
        ),
        existing,
      );
      expect(nonConflicting, isEmpty);
    });
  });

  group('Skip Next / Holiday Mode (mutedDates) Tests', () {
    test('ScheduleEntry persists mutedDates and evaluates isMutedOnDate', () {
      final entry = ScheduleEntry(
        id: 'holiday-test',
        title: 'Monday Morning Lecture',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [1],
        startTime: '08:00',
        endTime: '09:30',
        mutedDates: ['2026-09-28'],
      );

      expect(entry.isMutedOnDate(DateTime(2026, 9, 28)), isTrue);
      expect(entry.isMutedOnDate(DateTime(2026, 10, 5)), isFalse);

      final roundTrip = ScheduleEntry.fromJson(entry.toJson());
      expect(roundTrip.mutedDates, equals(['2026-09-28']));
      expect(roundTrip.isMutedOnDate(DateTime(2026, 9, 28)), isTrue);
    });

    test('ScheduleEntry.updatedAt advances on copyWith and falls back to createdAt for legacy JSON', () {
      final original = ScheduleEntry(
        id: 'sync-test',
        title: 'Physics Lecture',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [2, 4],
        startTime: '10:00',
        endTime: '11:30',
        updatedAt: 1700000000000,
      );

      final modified = original.copyWith(location: 'Room 402');
      expect(modified.updatedAt, greaterThan(original.updatedAt));

      final legacyJson = {
        'id': 'legacy-1',
        'title': 'Legacy Class',
        'daysOfWeek': [1],
        'startTime': '08:00',
        'endTime': '09:00',
        'createdAt': '2026-01-15T08:00:00.000Z',
      };
      final parsedLegacy = ScheduleEntry.fromJson(legacyJson);
      expect(
        parsedLegacy.updatedAt,
        equals(DateTime.parse('2026-01-15T08:00:00.000Z').millisecondsSinceEpoch),
      );
    });
  });

  group('Direct PDF / COR Zero-Blur Extractor Tests', () {
    test('PdfTextExtractor extracts BT/ET text streams from synthetic PDF bytes', () {
      const samplePdf = '%PDF-1.4\n'
          '1 0 obj << /Length 88 >>\n'
          'stream\n'
          'BT\n'
          '/F1 12 Tf\n'
          '0 -14 Td\n'
          '(ITIAS2   Information Assurance   MWF   08:30 AM - 10:00 AM   Room 302) Tj\n'
          'ET\n'
          'endstream\n'
          'endobj\n'
          '%%EOF';
      final bytes = Uint8List.fromList(samplePdf.codeUnits);

      expect(PdfTextExtractor.isPdfBytes(bytes), isTrue);
      final extracted = PdfTextExtractor.extractText(bytes);
      expect(extracted, contains('ITIAS2'));
      expect(extracted, contains('08:30 AM - 10:00 AM'));
    });
  });
}
