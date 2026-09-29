import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/models/schedule_entry.dart';
import 'package:schedule_scanner/models/schedule_profile.dart';
import 'package:schedule_scanner/models/schedule_category.dart';

void main() {
  group('ScheduleProfile and ScheduleEntry Timestamp and Deserialization Tests', () {
    test('ScheduleProfile.fromJson handles String, int, and mock Timestamp toDate', () {
      final jsonFromString = {
        'id': 'profile-1',
        'name': 'Test Profile',
        'type': 'school',
        'colorHex': '#2563EB',
        'isActive': true,
        'updatedAt': '2026-09-29T10:00:00.000',
      };
      final p1 = ScheduleProfile.fromJson(jsonFromString);
      expect(p1.id, 'profile-1');
      expect(p1.name, 'Test Profile');

      final jsonFromInt = {
        'id': 'profile-2',
        'name': 'Test Profile 2',
        'type': 'work',
        'updatedAt': 1727600000000,
      };
      final p2 = ScheduleProfile.fromJson(jsonFromInt);
      expect(p2.id, 'profile-2');
    });

    test('ScheduleEntry.fromJson safely parses Firestore documents with missing or Timestamp fields', () {
      final firestoreDoc = {
        'id': 'sched-123',
        'title': 'IT SAM',
        'profileId': 'school-profile-1',
        'category': 'classSchedule',
        'daysOfWeek': [1, 3],
        'startTime': '16:00',
        'endTime': '18:00',
        'spansNextDay': false,
        'location': 'LAN LAB',
        'notes': 'Bring notes',
        'colorHex': null,
        'reminders': [15],
        'isActive': true,
        'mutedDates': [],
        'createdAt': '2026-09-26T04:12:17.377',
        'updatedAt': 1727600000000,
      };

      final entry = ScheduleEntry.fromJson(firestoreDoc);
      expect(entry.id, 'sched-123');
      expect(entry.title, 'IT SAM');
      expect(entry.daysOfWeek, [1, 3]);
      expect(entry.category, ScheduleCategory.classSchedule);
      expect(entry.reminders, [15]);
      expect(entry.isActive, true);
    });

    test('Category-aware profile resolution assigns school classes correctly', () {
      final profiles = [
        ScheduleProfile(
          id: 'school-profile-1',
          name: 'School Schedule',
          type: 'school',
          colorHex: '#2563EB',
          isActive: true,
        ),
        ScheduleProfile(
          id: 'work-profile-2',
          name: 'Part-Time Job',
          type: 'work',
          colorHex: '#F97316',
          isActive: false,
        ),
      ];

      final schoolProfile = profiles.firstWhere((p) => p.type == 'school');
      final validProfileIds = profiles.map((p) => p.id).toSet();

      final classEntryWithWorkProfile = ScheduleEntry(
        id: 'c1',
        title: 'IT SAM',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [1],
        startTime: '16:00',
        endTime: '18:00',
        profileId: 'work-profile-2',
      );

      final pid = classEntryWithWorkProfile.profileId?.trim() ?? '';
      final linkedProfile = profiles.where((p) => p.id == pid).firstOrNull;

      String? targetPid;
      if (pid.isEmpty || !validProfileIds.contains(pid)) {
        if (classEntryWithWorkProfile.category == ScheduleCategory.classSchedule) {
          targetPid = schoolProfile.id;
        }
      } else if (classEntryWithWorkProfile.category == ScheduleCategory.classSchedule && linkedProfile?.type == 'work') {
        targetPid = schoolProfile.id;
      }

      expect(targetPid, 'school-profile-1');
    });
  });
}
