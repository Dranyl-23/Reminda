import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/schedule_entry.dart';
import '../../models/schedule_profile.dart';
import 'firestore_instance.dart';
import 'profile_repository.dart';
import 'schedule_repository.dart';

class FirestoreSyncService {
  final FirebaseFirestore _firestore = appFirestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScheduleRepository _scheduleRepo;
  final ProfileRepository _profileRepo;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _schedulesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _profilesSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  FirestoreSyncService(this._scheduleRepo, this._profileRepo);

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _userSchedulesRef {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('schedules');
  }

  CollectionReference<Map<String, dynamic>>? get _userProfilesRef {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('profiles');
  }

  /// Initialize real-time synchronization between Hive and Cloud Firestore
  void startSync({
    VoidCallback? onDataChanged,
  }) {
    _authStateSubscription?.cancel();
    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        debugPrint('FirestoreSyncService: User logged in (${user.uid}). Pulling cloud schedules & profiles...');
        await pullAndSyncAll(onDataChanged: onDataChanged);
        _listenToCloudChanges(onDataChanged);
      } else {
        debugPrint('FirestoreSyncService: User logged out. Cancelling realtime subscriptions.');
        _cancelSubscriptions();
      }
    });
  }

  /// Pull all cloud data and bidirectional merge with local Hive database.
  ///
  /// BUG FIX (Critical #1): `clearAll()` is now only called when the cloud
  /// actually has data. Previously it was called unconditionally, wiping ALL
  /// local schedules whenever the cloud returned 0 results (e.g. new user,
  /// network glitch, or empty collection after login).
  ///
  /// BUG FIX (Critical #2): A `_isSyncing` guard prevents `UserSyncService`
  /// and this method from running concurrently during login, which could cause
  /// a race where local data is deleted while it is still being uploaded.
  bool _isSyncing = false;

  Future<void> pullAndSyncAll({VoidCallback? onDataChanged}) async {
    // Race condition guard — only one sync can run at a time
    if (_isSyncing) {
      debugPrint('FirestoreSyncService: Sync already in progress, skipping duplicate call.');
      return;
    }
    _isSyncing = true;

    final uid = _currentUserId;
    if (uid == null) {
      _isSyncing = false;
      return;
    }

    try {
      // 0. Ensure user root document exists so it shows visibly in Firestore Console
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': user.displayName ?? 'User',
          'email': user.email ?? '',
          'lastSyncAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      bool hasChanges = false;

      // 1. Sync Schedules with Per-Item Timestamp Conflict Resolution (updatedAt)
      final schedRef = _userSchedulesRef;
      if (schedRef != null) {
        final snapshot = await schedRef.get().timeout(const Duration(seconds: 10));

        final cloudMap = <String, ScheduleEntry>{};
        for (final doc in snapshot.docs) {
          try {
            final entry = ScheduleEntry.fromJson(doc.data());
            cloudMap[entry.id] = entry;
          } catch (e) {
            debugPrint('Failed to parse cloud schedule doc ${doc.id}: $e');
          }
        }

        final localEntries = _scheduleRepo.getAllSchedules();
        final localMap = <String, ScheduleEntry>{
          for (final entry in localEntries) entry.id: entry,
        };

        final mergedEntries = <ScheduleEntry>[];
        final toUploadToCloud = <ScheduleEntry>[];

        final allIds = <String>{...localMap.keys, ...cloudMap.keys};
        for (final id in allIds) {
          final local = localMap[id];
          final cloud = cloudMap[id];

          if (local != null && cloud != null) {
            if (local.updatedAt > cloud.updatedAt) {
              mergedEntries.add(local);
              toUploadToCloud.add(local);
            } else {
              mergedEntries.add(cloud);
            }
          } else if (local != null) {
            // Created offline or pre-login: preserve locally and upload to cloud
            mergedEntries.add(local);
            toUploadToCloud.add(local);
          } else if (cloud != null) {
            mergedEntries.add(cloud);
          }
        }

        if (mergedEntries.isNotEmpty) {
          await _scheduleRepo.saveBatch(mergedEntries);
          hasChanges = true;
        }
        if (toUploadToCloud.isNotEmpty) {
          await syncBatchSchedulesToCloud(toUploadToCloud);
        }
      }

      // 2. Sync Profiles
      final profRef = _userProfilesRef;
      if (profRef != null) {
        final snapshot = await profRef.get().timeout(const Duration(seconds: 10));
        final cloudProfiles = <ScheduleProfile>[];

        for (final doc in snapshot.docs) {
          try {
            final profile = ScheduleProfile.fromJson(doc.data());
            cloudProfiles.add(profile);
          } catch (e) {
            debugPrint('Failed to parse cloud profile doc ${doc.id}: $e');
          }
        }

        if (cloudProfiles.isNotEmpty) {
          await _profileRepo.clearAll();
          for (final p in cloudProfiles) {
            await _profileRepo.saveProfile(p);
          }
          hasChanges = true;
        } else {
          // Fresh profile setup
          final localProfiles = _profileRepo.getAllProfiles();
          if (localProfiles.isEmpty) {
            await _profileRepo.resetDefaultProfiles();
          }
          final refreshed = _profileRepo.getAllProfiles();
          for (final p in refreshed) {
            await syncProfileToCloud(p);
          }
          hasChanges = true;
        }
      }

      // 3. Reconcile any orphaned or unassigned schedule profileIds to the active profile
      final currentProfiles = _profileRepo.getAllProfiles();
      if (currentProfiles.isNotEmpty) {
        final validProfileIds = currentProfiles.map((p) => p.id).toSet();
        final activeProfile = _profileRepo.getActiveProfile() ?? currentProfiles.first;
        final currentSchedules = _scheduleRepo.getAllSchedules();
        final healedSchedules = <ScheduleEntry>[];

        for (final entry in currentSchedules) {
          final pid = entry.profileId?.trim() ?? '';
          if (pid.isEmpty || !validProfileIds.contains(pid)) {
            healedSchedules.add(entry.copyWith(profileId: activeProfile.id));
          }
        }

        if (healedSchedules.isNotEmpty) {
          await _scheduleRepo.saveBatch(healedSchedules);
          await syncBatchSchedulesToCloud(healedSchedules);
          hasChanges = true;
        }
      }

      if (hasChanges && onDataChanged != null) {
        onDataChanged();
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Handled error/timeout during pullAndSyncAll: $e');
    } finally {
      // Always release the sync lock so future syncs can proceed
      _isSyncing = false;
    }
  }

  void _listenToCloudChanges(VoidCallback? onDataChanged) {
    _cancelSubscriptions();

    final schedRef = _userSchedulesRef;
    if (schedRef != null) {
      _schedulesSubscription = schedRef.snapshots().listen((snapshot) async {
        bool changed = false;
        for (final change in snapshot.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            try {
              final incoming = ScheduleEntry.fromJson(data);
              final existing = _scheduleRepo.getScheduleById(incoming.id);
              if (existing == null || incoming.updatedAt >= existing.updatedAt) {
                await _scheduleRepo.saveSchedule(incoming);
                changed = true;
              }
            } catch (_) {}
          } else if (change.type == DocumentChangeType.removed) {
            await _scheduleRepo.deleteSchedule(change.doc.id);
            changed = true;
          }
        }
        if (changed && onDataChanged != null) {
          onDataChanged();
        }
      }, onError: (e) {
        debugPrint('FirestoreSyncService: Schedules realtime error: $e');
      });
    }

    final profRef = _userProfilesRef;
    if (profRef != null) {
      _profilesSubscription = profRef.snapshots().listen((snapshot) async {
        bool changed = false;
        for (final change in snapshot.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            try {
              final profile = ScheduleProfile.fromJson(data);
              await _profileRepo.saveProfile(profile);
              changed = true;
            } catch (_) {}
          } else if (change.type == DocumentChangeType.removed) {
            await _profileRepo.deleteProfile(change.doc.id);
            changed = true;
          }
        }
        if (changed && onDataChanged != null) {
          onDataChanged();
        }
      }, onError: (e) {
        debugPrint('FirestoreSyncService: Profiles realtime error: $e');
      });
    }
  }

  /// Upload or update a single schedule entry to Cloud Firestore
  Future<void> syncScheduleToCloud(ScheduleEntry entry) async {
    final ref = _userSchedulesRef;
    if (ref == null) return;
    try {
      await ref.doc(entry.id).set(entry.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed to sync schedule ${entry.id}: $e');
    }
  }

  /// Upload a batch of schedules to Cloud Firestore atomically (safely chunked under 500 ops)
  Future<void> syncBatchSchedulesToCloud(List<ScheduleEntry> entries) async {
    final ref = _userSchedulesRef;
    if (ref == null || entries.isEmpty) return;

    const int batchLimit = 400; // Safe threshold well below Firestore's 500 ops cap
    try {
      for (var i = 0; i < entries.length; i += batchLimit) {
        final chunk = entries.sublist(i, min(i + batchLimit, entries.length));
        final batch = _firestore.batch();
        for (final entry in chunk) {
          final docRef = ref.doc(entry.id);
          batch.set(docRef, entry.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      }
      debugPrint('FirestoreSyncService: Synced ${entries.length} schedules to cloud in batches.');
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed batch upload: $e');
    }
  }

  /// Delete a schedule from Cloud Firestore
  Future<void> deleteScheduleFromCloud(String scheduleId) async {
    final ref = _userSchedulesRef;
    if (ref == null) return;
    try {
      await ref.doc(scheduleId).delete();
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed to delete schedule $scheduleId: $e');
    }
  }

  /// Upload or update a profile to Cloud Firestore
  Future<void> syncProfileToCloud(ScheduleProfile profile) async {
    final ref = _userProfilesRef;
    if (ref == null) return;
    try {
      await ref.doc(profile.id).set(profile.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed to sync profile ${profile.id}: $e');
    }
  }

  /// Delete a profile from Cloud Firestore
  Future<void> deleteProfileFromCloud(String profileId) async {
    final ref = _userProfilesRef;
    if (ref == null) return;
    try {
      await ref.doc(profileId).delete();
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed to delete profile $profileId: $e');
    }
  }

  void _cancelSubscriptions() {
    _schedulesSubscription?.cancel();
    _schedulesSubscription = null;
    _profilesSubscription?.cancel();
    _profilesSubscription = null;
  }

  void dispose() {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _cancelSubscriptions();
  }
}
