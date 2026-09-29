import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/models/schedule_profile.dart';
import 'package:schedule_scanner/core/constants/app_colors.dart';

void main() {
  group('ScheduleProfile', () {
    test('fromJson handles different types of updatedAt', () {
      final jsonWithString = {
        'id': '1',
        'name': 'Profile 1',
        'updatedAt': '2023-01-01T00:00:00.000Z',
      };
      
      final profile1 = ScheduleProfile.fromJson(jsonWithString);
      expect(profile1.updatedAt, isA<DateTime>());
      expect(profile1.updatedAt.year, 2023);

      final jsonWithInt = {
        'name': 'Profile 2',
        'updatedAt': 1672531200000,
      };

      final profile2 = ScheduleProfile.fromJson(jsonWithInt);
      expect(profile2.updatedAt.millisecondsSinceEpoch, 1672531200000);

      final jsonWithNull = {
        'name': 'Profile 3',
        'updatedAt': null,
      };

      final profile3 = ScheduleProfile.fromJson(jsonWithNull);
      expect(profile3.updatedAt, isA<DateTime>());
      
      // Missing fields
      final emptyJson = <String, dynamic>{};
      final profile4 = ScheduleProfile.fromJson(emptyJson);
      expect(profile4.name, 'Default Schedule');
      expect(profile4.type, 'custom');
      expect(profile4.colorHex, '#2563EB');
      expect(profile4.isActive, false);
    });

    test('toJson round-trips correctly', () {
      final profile = ScheduleProfile(
        id: '123',
        name: 'My Profile',
        type: 'school',
        colorHex: '#ff0000',
        isActive: true,
        updatedAt: DateTime(2023, 1, 1),
      );

      final json = profile.toJson();
      expect(json['id'], '123');
      expect(json['name'], 'My Profile');
      expect(json['type'], 'school');
      expect(json['colorHex'], '#ff0000');
      expect(json['isActive'], true);
      expect(json['updatedAt'], DateTime(2023, 1, 1).toIso8601String());

      final roundTrip = ScheduleProfile.fromJson(json);
      expect(roundTrip.id, profile.id);
      expect(roundTrip.name, profile.name);
      expect(roundTrip.type, profile.type);
    });

    test('copyWith correctly copies and overrides fields', () {
      final profile = ScheduleProfile(
        name: 'Old Name',
        type: 'work',
        isActive: false,
      );

      final copied = profile.copyWith(
        name: 'New Name',
        isActive: true,
      );

      expect(copied.id, profile.id);
      expect(copied.name, 'New Name');
      expect(copied.type, 'work');
      expect(copied.isActive, true);
    });

    test('icon getter returns correct IconData based on type', () {
      expect(ScheduleProfile(name: 'a', type: 'school').icon, Icons.school_rounded);
      expect(ScheduleProfile(name: 'a', type: 'class').icon, Icons.school_rounded);
      
      expect(ScheduleProfile(name: 'a', type: 'work').icon, Icons.work_rounded);
      expect(ScheduleProfile(name: 'a', type: 'job').icon, Icons.work_rounded);
      
      expect(ScheduleProfile(name: 'a', type: 'duty').icon, Icons.badge_rounded);
      
      expect(ScheduleProfile(name: 'a', type: 'custom').icon, Icons.calendar_today_rounded);
      expect(ScheduleProfile(name: 'a', type: 'unknown').icon, Icons.calendar_today_rounded);
    });

    test('color getter parses hex correctly', () {
      final p1 = ScheduleProfile(name: 'a', colorHex: '#FF0000');
      expect(p1.color, const Color(0xFFFF0000));
      
      final p2 = ScheduleProfile(name: 'a', colorHex: '00FF00'); // Without #
      expect(p2.color, const Color(0xFF00FF00));
      
      final p3 = ScheduleProfile(name: 'a', colorHex: 'invalid');
      expect(p3.color, AppColors.primary); // Default fallback
    });
  });
}
