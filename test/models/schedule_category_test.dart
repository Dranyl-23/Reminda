import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/models/schedule_category.dart';
import 'package:schedule_scanner/core/constants/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleCategory', () {
    test('fromString parses all valid aliases correctly', () {
      // classSchedule aliases
      for (final alias in ['class', 'classschedule', 'school', 'subject', 'course', 'lecture', 'lab']) {
        expect(ScheduleCategoryExtension.fromString(alias), ScheduleCategory.classSchedule);
        expect(ScheduleCategoryExtension.fromString(alias.toUpperCase()), ScheduleCategory.classSchedule);
      }

      // workShift aliases
      for (final alias in ['work', 'workshift', 'shift', 'job', 'office']) {
        expect(ScheduleCategoryExtension.fromString(alias), ScheduleCategory.workShift);
      }

      // duty aliases
      for (final alias in ['duty', 'dutyroster', 'station', 'hospital', 'clinical', 'rotation']) {
        expect(ScheduleCategoryExtension.fromString(alias), ScheduleCategory.duty);
      }
    });

    test('fromString handles null, empty, and unknown values', () {
      expect(ScheduleCategoryExtension.fromString(null), ScheduleCategory.custom);
      expect(ScheduleCategoryExtension.fromString(''), ScheduleCategory.custom);
      expect(ScheduleCategoryExtension.fromString('unknown_category'), ScheduleCategory.custom);
    });

    test('displayName returns correct string', () {
      expect(ScheduleCategory.classSchedule.displayName, 'Class / Subject');
      expect(ScheduleCategory.workShift.displayName, 'Work Shift');
      expect(ScheduleCategory.duty.displayName, 'Duty Roster');
      expect(ScheduleCategory.custom.displayName, 'Custom / Other');
    });

    test('shortLabel returns correct string', () {
      expect(ScheduleCategory.classSchedule.shortLabel, 'Class');
      expect(ScheduleCategory.workShift.shortLabel, 'Shift');
      expect(ScheduleCategory.duty.shortLabel, 'Duty');
      expect(ScheduleCategory.custom.shortLabel, 'Custom');
    });
    
    test('icon returns correct IconData', () {
      expect(ScheduleCategory.classSchedule.icon, Icons.school_rounded);
      expect(ScheduleCategory.workShift.icon, Icons.work_rounded);
      expect(ScheduleCategory.duty.icon, Icons.badge_rounded);
      expect(ScheduleCategory.custom.icon, Icons.event_rounded);
    });
    
    test('color returns correct Color', () {
      expect(ScheduleCategory.classSchedule.color, AppColors.categoryClass);
      expect(ScheduleCategory.workShift.color, AppColors.categoryWork);
      expect(ScheduleCategory.duty.color, AppColors.categoryDuty);
      expect(ScheduleCategory.custom.color, AppColors.categoryCustom);
    });

    test('defaultReminderLeadMinutes returns correct int', () {
      expect(ScheduleCategory.classSchedule.defaultReminderLeadMinutes, 15);
      expect(ScheduleCategory.workShift.defaultReminderLeadMinutes, 60);
      expect(ScheduleCategory.duty.defaultReminderLeadMinutes, 30);
      expect(ScheduleCategory.custom.defaultReminderLeadMinutes, 15);
    });
  });
}
