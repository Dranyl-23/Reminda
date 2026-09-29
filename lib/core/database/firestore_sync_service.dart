import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../../models/schedule_profile.dart';
import '../config/remote_config_service.dart';
import '../utils/schedule_deduplicator.dart';
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

  bool _isSyncing = false;
  Completer<void>? _activeSyncCompleter;

  Future<void> pullAndSyncAll({VoidCallback? onDataChanged}) async {
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Cloud sync paused due to active server maintenance mode.');
      return;
    }

    // If a sync is already running, await it so caller doesn't return before data is saved
    if (_isSyncing && _activeSyncCompleter != null) {
      debugPrint('FirestoreSyncService: Sync already in progress, awaiting existing sync...');
      await _activeSyncCompleter!.future;
      onDataChanged?.call();
      return;
    }
    _isSyncing = true;
    _activeSyncCompleter = Completer<void>();

    final uid = _currentUserId;
    if (uid == null) {
      _isSyncing = false;
      _activeSyncCompleter?.complete();
      _activeSyncCompleter = null;
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

      // 1. Sync Profiles first so incoming schedules can reference valid profile IDs
      final profRef = _userProfilesRef;
      if (profRef != null) {
        final snapshot = await profRef.get().timeout(const Duration(seconds: 15));
        final cloudProfiles = <ScheduleProfile>[];

        for (final doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            if (!data.containsKey('id') || (data['id'] as String?)?.isEmpty == true) {
              data['id'] = doc.id;
            }
            final profile = ScheduleProfile.fromJson(data);
            cloudProfiles.add(profile);
          } catch (e, st) {
            debugPrint('FirestoreSyncService: Failed to parse cloud profile doc ${doc.id}: $e\n$st');
          }
        }
        debugPrint('FirestoreSyncService: Successfully parsed ${cloudProfiles.length}/${snapshot.docs.length} cloud profiles.');

        if (cloudProfiles.isNotEmpty) {
          await _profileRepo.clearAll();
          for (final p in cloudProfiles) {
            await _profileRepo.saveProfile(p);
          }
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
        }
      }

      // 2. Sync Schedules with Per-Item Timestamp Conflict Resolution (updatedAt)
      final schedRef = _userSchedulesRef;
      if (schedRef != null) {
        final snapshot = await schedRef.get().timeout(const Duration(seconds: 15));

        final cloudMap = <String, ScheduleEntry>{};
        for (final doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            if (!data.containsKey('id') || (data['id'] as String?)?.isEmpty == true) {
              data['id'] = doc.id;
            }
            final entry = ScheduleEntry.fromJson(data);
            cloudMap[entry.id] = entry;
          } catch (e, st) {
            debugPrint('FirestoreSyncService: Failed to parse cloud schedule doc ${doc.id}: $e\n$st');
          }
        }
        debugPrint('FirestoreSyncService: Successfully parsed ${cloudMap.length}/${snapshot.docs.length} cloud schedules.');

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

        // Deduplicate merged schedules so that duplicates in local or cloud are eliminated
        final dedupResult = ScheduleDeduplicator.deduplicate(mergedEntries);

        if (dedupResult.removed.isNotEmpty) {
          final duplicateIds = dedupResult.removed.map((e) => e.id).toList();
          for (final entry in dedupResult.removed) {
            await _scheduleRepo.deleteSchedule(entry.id);
          }
          await deleteBatchSchedulesFromCloud(duplicateIds);
          debugPrint('FirestoreSyncService: Purged ${duplicateIds.length} duplicate schedules from local and cloud.');
        }

        if (dedupResult.kept.isNotEmpty) {
          await _scheduleRepo.saveBatch(dedupResult.kept);
          debugPrint('FirestoreSyncService: Saved ${dedupResult.kept.length} unique schedules to local repository.');
        }
        if (toUploadToCloud.isNotEmpty) {
          // Only upload kept or updated entries to cloud, never deleted duplicates
          final keptIds = dedupResult.kept.map((e) => e.id).toSet();
          final validUploads = toUploadToCloud.where((e) => keptIds.contains(e.id)).toList();
          if (validUploads.isNotEmpty) {
            await syncBatchSchedulesToCloud(validUploads);
          }
        }
      }

      // 3. Reconcile schedule profileIds intelligently by category & active profile
      final currentProfiles = _profileRepo.getAllProfiles();
      if (currentProfiles.isNotEmpty) {
        final validProfileIds = currentProfiles.map((p) => p.id).toSet();
        final activeProfile = _profileRepo.getActiveProfile() ?? currentProfiles.first;

        final schoolProfile = currentProfiles.firstWhere(
          (p) => p.type == 'school' && p.isActive,
          orElse: () => currentProfiles.firstWhere(
            (p) => p.type == 'school',
            orElse: () => activeProfile,
          ),
        );
        final workProfile = currentProfiles.firstWhere(
          (p) => p.type == 'work' && p.isActive,
          orElse: () => currentProfiles.firstWhere(
            (p) => p.type == 'work',
            orElse: () => activeProfile,
          ),
        );
        final dutyProfile = currentProfiles.firstWhere(
          (p) => p.type == 'duty' && p.isActive,
          orElse: () => currentProfiles.firstWhere(
            (p) => p.type == 'duty',
            orElse: () => activeProfile,
          ),
        );

        final currentSchedules = _scheduleRepo.getAllSchedules();
        final healedSchedules = <ScheduleEntry>[];

        for (final entry in currentSchedules) {
          final pid = entry.profileId?.trim() ?? '';
          final linkedProfile = currentProfiles.where((p) => p.id == pid).firstOrNull;

          String? targetPid;
          if (pid.isEmpty || !validProfileIds.contains(pid)) {
            // Unassigned or pointing to a deleted profile
            if (entry.category == ScheduleCategory.classSchedule) {
              targetPid = schoolProfile.id;
            } else if (entry.category == ScheduleCategory.duty) {
              targetPid = dutyProfile.id;
            } else if (entry.category == ScheduleCategory.workShift) {
              targetPid = workProfile.id;
            } else {
              targetPid = activeProfile.id;
            }
          } else if (entry.category == ScheduleCategory.classSchedule && linkedProfile?.type == 'work') {
            // Mismatch: School class attached to a Work profile
            targetPid = schoolProfile.id;
          }

          if (targetPid != null && targetPid != pid) {
            healedSchedules.add(entry.copyWith(profileId: targetPid));
          }
        }

        if (healedSchedules.isNotEmpty) {
          await _scheduleRepo.saveBatch(healedSchedules);
          await syncBatchSchedulesToCloud(healedSchedules);
        }
      }

      onDataChanged?.call();
    } catch (e) {
      debugPrint('FirestoreSyncService: Handled error/timeout during pullAndSyncAll: $e');
    } finally {
      // Always release the sync lock and complete awaiting callers
      _isSyncing = false;
      _activeSyncCompleter?.complete();
      _activeSyncCompleter = null;
    }
  }

  void _listenToCloudChanges(VoidCallback? onDataChanged) {
    _cancelSubscriptions();

    final schedRef = _userSchedulesRef;
    if (schedRef != null) {
      _schedulesSubscription = schedRef.snapshots().listen((snapshot) async {
        bool changed = false;
        for (final change in snapshot.docChanges) {
          final rawData = change.doc.data();
          if (rawData == null) continue;
          final data = Map<String, dynamic>.from(rawData);
          if (!data.containsKey('id') || (data['id'] as String?)?.isEmpty == true) {
            data['id'] = change.doc.id;
          }

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
          final rawData = change.doc.data();
          if (rawData == null) continue;
          final data = Map<String, dynamic>.from(rawData);
          if (!data.containsKey('id') || (data['id'] as String?)?.isEmpty == true) {
            data['id'] = change.doc.id;
          }

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
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Schedule syncToCloud skipped due to active server maintenance mode.');
      return;
    }
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
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Batch cloud sync paused due to active server maintenance mode.');
      return;
    }
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
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Schedule deleteFromCloud skipped due to active server maintenance mode.');
      return;
    }
    final ref = _userSchedulesRef;
    if (ref == null) return;
    try {
      await ref.doc(scheduleId).delete();
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed to delete schedule $scheduleId: $e');
    }
  }

  /// Delete a batch of schedules from Cloud Firestore atomically (safely chunked under 500 ops)
  Future<void> deleteBatchSchedulesFromCloud(List<String> scheduleIds) async {
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Batch delete skipped due to active server maintenance mode.');
      return;
    }
    final ref = _userSchedulesRef;
    if (ref == null || scheduleIds.isEmpty) return;

    const int batchLimit = 400; // Safe threshold well below Firestore's 500 ops cap
    try {
      for (var i = 0; i < scheduleIds.length; i += batchLimit) {
        final chunk = scheduleIds.sublist(i, min(i + batchLimit, scheduleIds.length));
        final batch = _firestore.batch();
        for (final id in chunk) {
          batch.delete(ref.doc(id));
        }
        await batch.commit();
      }
      debugPrint('FirestoreSyncService: Batch-deleted ${scheduleIds.length} schedules from cloud.');
    } catch (e) {
      debugPrint('FirestoreSyncService: Failed batch delete: $e');
    }
  }

  /// Upload or update a profile to Cloud Firestore
  Future<void> syncProfileToCloud(ScheduleProfile profile) async {
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Profile syncToCloud skipped due to active server maintenance mode.');
      return;
    }
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
    if (RemoteConfigService.instance.maintenanceMode) {
      debugPrint('FirestoreSyncService: Profile deleteFromCloud skipped due to active server maintenance mode.');
      return;
    }
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
