import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_version.dart';
import 'profile_repository.dart';
import 'schedule_repository.dart';

class UserSyncService {
  UserSyncService._();
  static final UserSyncService instance = UserSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate or retrieve stable device installation ID
  Future<String> getInstallationDeviceId() async {
    try {
      final box = await Hive.openBox('app_settings_box');
      var devId = box.get('installation_device_id') as String?;
      if (devId == null || devId.isEmpty) {
        devId = const Uuid().v4().substring(0, 12);
        await box.put('installation_device_id', devId);
      }
      return devId;
    } catch (e) {
      debugPrint('UserSyncService: Failed to get device ID from Hive: $e');
      return const Uuid().v4().substring(0, 12);
    }
  }

  /// Sync User profile, device telemetry, and schedules to Cloud Firestore
  Future<void> syncCurrentUser() async {
    try {
      final devId = await getInstallationDeviceId();
      final user = _auth.currentUser;
      final isGuest = user == null;
      final userId = user?.uid ?? 'guest_$devId';

      final box = await Hive.openBox('app_settings_box');
      final cachedName = box.get('userName', defaultValue: isGuest ? 'Guest ($devId)' : 'Reminda User') as String;
      final cachedEmail = box.get('userEmail', defaultValue: isGuest ? 'guest_$devId@reminda.app' : '') as String;

      final displayName = user?.displayName ?? (cachedName.isNotEmpty ? cachedName : 'Reminda User');
      final email = user?.email ?? (cachedEmail.isNotEmpty ? cachedEmail : 'guest_$devId@reminda.app');

      // 1. Sync User Document
      final userDocRef = _firestore.collection('users').doc(userId);
      await userDocRef.set({
        'id': userId,
        'displayName': displayName,
        'email': email,
        'photoUrl': user?.photoURL ?? '',
        'platform': defaultTargetPlatform.name,
        'appVersion': AppVersion.fullVersion,
        'isGuest': isGuest,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('UserSyncService: Synced user telemetry ($userId) to cloud.');

      // 2. Sync Profiles in background
      final profileRepo = ProfileRepository();
      await profileRepo.init();
      final profiles = profileRepo.getAllProfiles();

      for (final p in profiles) {
        await userDocRef.collection('profiles').doc(p.id).set({
          'id': p.id,
          'name': p.name,
          'type': p.type,
          'colorHex': p.colorHex,
          'isActive': p.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Sync Schedules in background
      final scheduleRepo = ScheduleRepository();
      await scheduleRepo.init();
      final schedules = scheduleRepo.getAllSchedules();

      for (final s in schedules) {
        await userDocRef.collection('schedules').doc(s.id).set({
          'id': s.id,
          'title': s.title,
          'profileId': s.profileId,
          'daysOfWeek': s.daysOfWeek,
          'startTime': s.startTime,
          'endTime': s.endTime,
          'location': s.location,
          'category': s.category.name,
          'notes': s.notes,
          'colorHex': s.colorHex,
          'reminders': s.reminders,
          'isActive': s.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('UserSyncService: Sync warning ($e)');
    }
  }
}
