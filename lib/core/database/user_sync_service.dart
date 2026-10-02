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
      final cachedName = (box.get('userName') as String?)?.trim();
      final cachedEmail = (box.get('userEmail') as String?)?.trim();
      final cachedPhoto = (box.get('userPhotoUrl') as String?)?.trim();

      final rawUserDisplayName = user?.displayName?.trim();

      String displayName;
      if (rawUserDisplayName != null &&
          rawUserDisplayName.isNotEmpty &&
          rawUserDisplayName != 'User' &&
          rawUserDisplayName != 'Reminda User') {
        displayName = rawUserDisplayName;
      } else if (cachedName != null &&
          cachedName.isNotEmpty &&
          cachedName != 'User' &&
          cachedName != 'Reminda User') {
        displayName = cachedName;
      } else if (user?.email != null && user!.email!.contains('@')) {
        displayName = _formatNameFromEmail(user.email!);
      } else if (cachedEmail != null && cachedEmail.contains('@') && !cachedEmail.startsWith('guest_')) {
        displayName = _formatNameFromEmail(cachedEmail);
      } else {
        displayName = isGuest ? 'Guest ($devId)' : 'Reminda User';
      }

      final email = (user?.email != null && user!.email!.isNotEmpty)
          ? user.email!
          : (cachedEmail != null && cachedEmail.isNotEmpty
              ? cachedEmail
              : 'guest_$devId@reminda.app');

      final photoUrl = (user?.photoURL != null && user!.photoURL!.isNotEmpty)
          ? user.photoURL!
          : (cachedPhoto ?? '');

      // Keep Firebase Auth profile in sync if missing
      if (user != null && (user.displayName == null || user.displayName!.isEmpty || user.displayName == 'User' || user.displayName == 'Reminda User')) {
        if (displayName != 'Reminda User' && !displayName.startsWith('Guest')) {
          try {
            await user.updateDisplayName(displayName);
            if (photoUrl.isNotEmpty && (user.photoURL == null || user.photoURL!.isEmpty)) {
              await user.updatePhotoURL(photoUrl);
            }
            await user.reload();
          } catch (_) {}
        }
      }

      // 1. Sync User Document
      final userDocRef = _firestore.collection('users').doc(userId);
      await userDocRef.set({
        'id': userId,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
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

  static String _formatNameFromEmail(String email) {
    if (!email.contains('@')) return email;
    final handle = email.split('@').first;
    final parts = handle
        .replaceAll(RegExp(r'[._\-]'), ' ')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
        .toList();
    return parts.isNotEmpty ? parts.join(' ') : handle;
  }
}
