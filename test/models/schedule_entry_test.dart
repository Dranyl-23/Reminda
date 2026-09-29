import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/models/schedule_entry.dart';
import 'package:schedule_scanner/models/schedule_category.dart';

void main() {
  group('ScheduleEntry', () {
    test('fromJson handles different types and defaults', () {
      final jsonWithStrings = {
        'id': '1',
        'title': 'Test Title',
        'daysOfWeek': ['1', '2'],
        'reminders': ['15', '30'],
        'mutedDates': ['2023-01-01'],
        'createdAt': '2023-01-01T00:00:00.000Z',
        'updatedAt': '2023-01-01T00:00:00.000Z',
      };
      
      final entry1 = ScheduleEntry.fromJson(jsonWithStrings);
      expect(entry1.id, '1');
      expect(entry1.title, 'Test Title');
      expect(entry1.daysOfWeek, [1, 2]);
      expect(entry1.reminders, [15, 30]);
      expect(entry1.mutedDates, ['2023-01-01']);
      expect(entry1.createdAt, isA<DateTime>());
      expect(entry1.updatedAt, isA<int>());

      final jsonWithInts = {
        'daysOfWeek': [3, 4],
        'reminders': [45, 60],
        'createdAt': 1672531200000,
        'updatedAt': 1672531200000,
      };

      final entry2 = ScheduleEntry.fromJson(jsonWithInts);
      expect(entry2.title, 'Untitled Schedule');
      expect(entry2.daysOfWeek, [3, 4]);
      expect(entry2.reminders, [45, 60]);
      expect(entry2.createdAt.millisecondsSinceEpoch, 1672531200000);
      expect(entry2.updatedAt, 1672531200000);

      final jsonEmpty = <String, dynamic>{};
      final entry3 = ScheduleEntry.fromJson(jsonEmpty);
      expect(entry3.title, 'Untitled Schedule');
      expect(entry3.daysOfWeek, isEmpty);
      expect(entry3.reminders, [15]);
      expect(entry3.isActive, isTrue);
    });

    test('toJson produces correct output and round-trips', () {
      final entry = ScheduleEntry(
        id: '123',
        profileId: 'prof1',
        title: 'Math Class',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [1, 3, 5],
        startTime: '08:00',
        endTime: '09:00',
        spansNextDay: false,
        location: 'Room 101',
        notes: 'Bring calculator',
        colorHex: '#ff0000',
        reminders: [10, 20],
        isActive: false,
        mutedDates: ['2023-01-01'],
        createdAt: DateTime(2023, 1, 1),
        updatedAt: 1672531200000,
        sourceImageId: 'img1',
      );

      final json = entry.toJson();
      expect(json['id'], '123');
      expect(json['profileId'], 'prof1');
      expect(json['title'], 'Math Class');
      expect(json['category'], 'classSchedule');
      expect(json['daysOfWeek'], [1, 3, 5]);
      expect(json['startTime'], '08:00');
      expect(json['endTime'], '09:00');
      expect(json['spansNextDay'], false);
      expect(json['location'], 'Room 101');
      expect(json['notes'], 'Bring calculator');
      expect(json['colorHex'], '#ff0000');
      expect(json['reminders'], [10, 20]);
      expect(json['isActive'], false);
      expect(json['mutedDates'], ['2023-01-01']);
      expect(json['createdAt'], DateTime(2023, 1, 1).toIso8601String());
      expect(json['updatedAt'], 1672531200000);
      expect(json['sourceImageId'], 'img1');

      final roundTrip = ScheduleEntry.fromJson(json);
      expect(roundTrip.id, entry.id);
      expect(roundTrip.title, entry.title);
      expect(roundTrip.category, entry.category);
    });

    test('copyWith correctly copies and overrides fields', () {
      final entry = ScheduleEntry(
        title: 'Old Title',
        daysOfWeek: [1],
        startTime: '10:00',
        endTime: '11:00',
        updatedAt: 1000000,
      );

      final copied = entry.copyWith(
        title: 'New Title',
        daysOfWeek: [2],
      );

      expect(copied.id, entry.id);
      expect(copied.title, 'New Title');
      expect(copied.daysOfWeek, [2]);
      expect(copied.startTime, '10:00');
      
      // updatedAt should be updated when copying
      expect(copied.updatedAt, isNot(equals(entry.updatedAt)));
      // allow some buffer for test execution time, or just verify it's changed
    });

    test('dateToIso formatting', () {
      final date1 = DateTime(2023, 5, 4);
      expect(ScheduleEntry.dateToIso(date1), '2023-05-04');

      final date2 = DateTime(2023, 12, 15);
      expect(ScheduleEntry.dateToIso(date2), '2023-12-15');
    });

    test('isMutedOnDate returns correct results', () {
      final entry = ScheduleEntry(
        title: 'Test',
        daysOfWeek: [1],
        startTime: '10:00',
        endTime: '11:00',
        mutedDates: ['2023-10-10'],
      );

      expect(entry.isMutedOnDate(DateTime(2023, 10, 10)), isTrue);
      expect(entry.isMutedOnDate(DateTime(2023, 10, 11)), isFalse);
    });

    test('nextOccurrenceDate calculates correct next date', () {
      final entry = ScheduleEntry(
        title: 'Test',
        daysOfWeek: [3], // Wednesday
        startTime: '14:30',
        endTime: '15:30',
      );

      // 2023-10-09 is a Monday
      final from = DateTime(2023, 10, 9, 12, 0);
      
      final next = entry.nextOccurrenceDate(from);
      expect(next, isNotNull);
      expect(next!.year, 2023);
      expect(next.month, 10);
      expect(next.day, 11); // Wednesday
      expect(next.hour, 14);
      expect(next.minute, 30);
    });
    
    test('nextOccurrenceDate handles empty daysOfWeek', () {
      final entry = ScheduleEntry(
        title: 'Test',
        daysOfWeek: [], 
        startTime: '14:30',
        endTime: '15:30',
      );

      expect(entry.nextOccurrenceDate(), isNull);
    });

    test('isNextOccurrenceMuted computes correctly', () {
      // 2023-10-11 is a Wednesday
      final entry = ScheduleEntry(
        title: 'Test',
        daysOfWeek: [3], // Wednesday
        startTime: '14:30',
        endTime: '15:30',
        mutedDates: ['2023-10-11'],
      );

      // From Monday
      final from = DateTime(2023, 10, 9, 12, 0);
      final nextIso = entry.nextOccurrenceIsoDate(from);
      expect(nextIso, '2023-10-11');
      
      // Wait, isNextOccurrenceMuted uses DateTime.now() internally for nextOccurrenceIsoDate()
      // We can't mock DateTime.now() easily without a clock injection, but we can test
      // if it handles the logic correctly by setting mutedDates to today's or tomorrow's expected occurrence.
      
      // Let's create an entry that happens today, later in the day
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      
      final entry2 = ScheduleEntry(
        title: 'Test',
        daysOfWeek: [now.weekday],
        startTime: '${later.hour.toString().padLeft(2, '0')}:${later.minute.toString().padLeft(2, '0')}',
        endTime: '${(later.hour + 1).toString().padLeft(2, '0')}:${later.minute.toString().padLeft(2, '0')}',
      );
      final nextIso2 = entry2.nextOccurrenceIsoDate();
      expect(nextIso2, isNotNull);
      final mutedEntry = entry2.copyWith(mutedDates: [nextIso2!]);
      expect(mutedEntry.isNextOccurrenceMuted, isTrue);
    });
  });
}
