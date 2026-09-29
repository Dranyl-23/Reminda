import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/core/utils/schedule_deduplicator.dart';
import 'package:schedule_scanner/models/schedule_category.dart';
import 'package:schedule_scanner/models/schedule_entry.dart';

void main() {
  group('ScheduleDeduplicator Tests', () {
    final entry1 = ScheduleEntry(
      id: 'id-1',
      profileId: 'school-1',
      title: 'IT SAM',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [1],
      startTime: '16:00',
      endTime: '18:00',
      location: 'LAN LAB',
    );

    final entry2 = ScheduleEntry(
      id: 'id-2',
      profileId: 'school-1',
      title: 'IT SAM',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [1],
      startTime: '16:00',
      endTime: '18:00',
      location: 'LAN LAB',
    );

    final entry3Descriptive = ScheduleEntry(
      id: 'id-3',
      profileId: 'school-1',
      title: 'System Administration and Maintenance',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [1],
      startTime: '16:00',
      endTime: '18:00',
      location: null,
    );

    final entryDifferentTime = ScheduleEntry(
      id: 'id-4',
      profileId: 'school-1',
      title: 'IT SAM L',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [1],
      startTime: '18:00',
      endTime: '20:30',
      location: 'LAN LAB',
    );

    final entryDifferentSubjectDifferentProfile = ScheduleEntry(
      id: 'id-5',
      profileId: 'work-1',
      title: 'Barista Shift',
      category: ScheduleCategory.workShift,
      daysOfWeek: [1],
      startTime: '16:00',
      endTime: '18:00',
      location: 'Cafe Central',
    );

    final entryCrossProfileDuplicate = ScheduleEntry(
      id: 'id-6',
      profileId: 'duty-profile-3',
      title: 'IT SAM (System Administration and Maintenance)',
      category: ScheduleCategory.classSchedule,
      daysOfWeek: [1],
      startTime: '16:00',
      endTime: '18:00',
      location: 'LAN LAB',
    );

    test('areDuplicates returns true for exact duplicate entries', () {
      expect(ScheduleDeduplicator.areDuplicates(entry1, entry2), isTrue);
    });

    test('areDuplicates returns true for abbreviation vs full name in same slot', () {
      expect(ScheduleDeduplicator.areDuplicates(entry1, entry3Descriptive), isTrue);
    });

    test('areDuplicates returns true for cross-profile duplicate class', () {
      expect(ScheduleDeduplicator.areDuplicates(entry1, entryCrossProfileDuplicate), isTrue);
    });

    test('areDuplicates returns false for different time slots', () {
      expect(ScheduleDeduplicator.areDuplicates(entry1, entryDifferentTime), isFalse);
    });

    test('areDuplicates returns false for distinct independent activities across profiles', () {
      expect(ScheduleDeduplicator.areDuplicates(entry1, entryDifferentSubjectDifferentProfile), isFalse);
    });

    test('deduplicate eliminates redundant entries and preserves 1 unique entry', () {
      final list = [entry1, entry2, entry3Descriptive];
      final result = ScheduleDeduplicator.deduplicate(list);

      expect(result.kept.length, equals(1));
      expect(result.removed.length, equals(2));
      // Location should be preserved from entry1/entry2 even if entry3 had null location
      expect(result.kept.first.location, equals('LAN LAB'));
    });

    test('deduplicate handles independent non-overlapping classes correctly', () {
      final list = [entry1, entry2, entryDifferentTime];
      final result = ScheduleDeduplicator.deduplicate(list);

      expect(result.kept.length, equals(2));
      expect(result.removed.length, equals(1));
    });
  });
}
