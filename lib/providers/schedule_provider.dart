import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/firestore_sync_service.dart';
import '../core/database/profile_repository.dart';
import '../core/database/schedule_repository.dart';
import '../core/notifications/home_widget_sync_service.dart';
import '../core/notifications/notification_service.dart';
import '../core/utils/schedule_deduplicator.dart';
import '../models/schedule_category.dart';
import '../models/schedule_entry.dart';
import 'profile_provider.dart';
import 'sync_provider.dart';

export 'ai_settings_provider.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// firestoreSyncServiceProvider is defined in sync_provider.dart
// and imported above — used by ScheduleNotifier below.

class ScheduleNotifier extends StateNotifier<List<ScheduleEntry>> {
  final ScheduleRepository _repository;
  final ProfileRepository _profileRepository;
  final NotificationService _notificationService;
  final FirestoreSyncService _syncService;
  final VoidCallback? _onProfilesChanged;

  ScheduleNotifier(
    this._repository,
    this._profileRepository,
    this._notificationService,
    this._syncService, {
    VoidCallback? onProfilesChanged,
  })  : _onProfilesChanged = onProfilesChanged,
        super([]) {
    _loadSchedules(syncHealedToCloud: true);
    _rescheduleAlarms();
    _syncService.startSync(onDataChanged: () {
      _onProfilesChanged?.call();
      _loadSchedules(syncHealedToCloud: false);
      _rescheduleAlarms();
    });
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  void _loadSchedules({bool syncHealedToCloud = false}) {
    var schedules = _repository.getAllSchedules();
    final profiles = _profileRepository.getAllProfiles();
    if (profiles.isNotEmpty && schedules.isNotEmpty) {
      final validProfileIds = profiles.map((p) => p.id).toSet();
      final activeProfile = _profileRepository.getActiveProfile() ?? profiles.first;

      final schoolProfile = profiles.firstWhere(
        (p) => p.type == 'school' && p.isActive,
        orElse: () => profiles.firstWhere(
          (p) => p.type == 'school',
          orElse: () => activeProfile,
        ),
      );
      final workProfile = profiles.firstWhere(
        (p) => p.type == 'work' && p.isActive,
        orElse: () => profiles.firstWhere(
          (p) => p.type == 'work',
          orElse: () => activeProfile,
        ),
      );
      final dutyProfile = profiles.firstWhere(
        (p) => p.type == 'duty' && p.isActive,
        orElse: () => profiles.firstWhere(
          (p) => p.type == 'duty',
          orElse: () => activeProfile,
        ),
      );

      final healed = <ScheduleEntry>[];
      final updatedList = <ScheduleEntry>[];

      for (final entry in schedules) {
        final pid = entry.profileId?.trim() ?? '';
        final linked = profiles.where((p) => p.id == pid).firstOrNull;

        String? targetPid;
        if (pid.isEmpty || !validProfileIds.contains(pid)) {
          if (entry.category == ScheduleCategory.classSchedule) {
            targetPid = schoolProfile.id;
          } else if (entry.category == ScheduleCategory.duty) {
            targetPid = dutyProfile.id;
          } else if (entry.category == ScheduleCategory.workShift) {
            targetPid = workProfile.id;
          } else {
            targetPid = activeProfile.id;
          }
        } else if (entry.category == ScheduleCategory.classSchedule && linked?.type == 'work') {
          targetPid = schoolProfile.id;
        }

        if (targetPid != null && targetPid != pid) {
          final fixed = entry.copyWith(profileId: targetPid);
          healed.add(fixed);
          updatedList.add(fixed);
        } else {
          updatedList.add(entry);
        }
      }

      if (healed.isNotEmpty) {
        schedules = updatedList;
        _repository.saveBatch(healed);
        if (syncHealedToCloud) {
          _syncService.syncBatchSchedulesToCloud(healed);
        }
      }

      // Self-healing: Automatically eliminate redundant duplicate schedules
      final dedupResult = ScheduleDeduplicator.deduplicate(schedules);
      if (dedupResult.removed.isNotEmpty) {
        for (final entry in dedupResult.removed) {
          _repository.deleteSchedule(entry.id);
        }
        if (dedupResult.updated.isNotEmpty) {
          _repository.saveBatch(dedupResult.updated);
        }
        if (syncHealedToCloud) {
          _syncService.deleteBatchSchedulesFromCloud(
            dedupResult.removed.map((e) => e.id).toList(),
          );
        }
        schedules = dedupResult.kept;
      }
    }

    state = schedules;
    HomeWidgetSyncService.instance.syncWithSchedules(schedules);
  }

  void _rescheduleAlarms() {
    final active = state.where((e) => e.isActive).toList();
    _notificationService.rescheduleAll(active);
  }

  Future<void> addSchedule(ScheduleEntry entry) async {
    await _repository.saveSchedule(entry);
    if (entry.isActive) {
      await _notificationService.scheduleEntryReminders(entry);
    }
    _loadSchedules();
    await _syncService.syncScheduleToCloud(entry);
  }

  Future<void> updateSchedule(ScheduleEntry updated) async {
    final existing = _repository.getScheduleById(updated.id);
    if (existing != null) {
      await _notificationService.cancelEntryReminders(existing);
    }
    await _repository.saveSchedule(updated);
    if (updated.isActive) {
      await _notificationService.scheduleEntryReminders(updated);
    }
    _loadSchedules();
    await _syncService.syncScheduleToCloud(updated);
  }

  Future<void> deleteSchedule(ScheduleEntry entry) async {
    await _notificationService.cancelEntryReminders(entry);
    await _repository.deleteSchedule(entry.id);
    _loadSchedules();
    await _syncService.deleteScheduleFromCloud(entry.id);
  }

  Future<void> toggleActive(String id) async {
    final entry = _repository.getScheduleById(id);
    if (entry == null) return;

    final updated = entry.copyWith(isActive: !entry.isActive);
    if (updated.isActive) {
      await _notificationService.scheduleEntryReminders(updated);
    } else {
      await _notificationService.cancelEntryReminders(entry);
    }
    await _repository.saveSchedule(updated);
    _loadSchedules();
    await _syncService.syncScheduleToCloud(updated);
  }

  /// Toggles skipping/muting a specific ISO date ("YYYY-MM-DD") for Holiday / Skip-Next mode
  Future<bool> toggleMuteDate(String id, String isoDate) async {
    final entry = _repository.getScheduleById(id);
    if (entry == null) return false;

    final updatedMuted = List<String>.from(entry.mutedDates);
    final bool isNowMuted;
    if (updatedMuted.contains(isoDate)) {
      updatedMuted.remove(isoDate);
      isNowMuted = false;
    } else {
      updatedMuted.add(isoDate);
      isNowMuted = true;
    }

    final updated = entry.copyWith(mutedDates: updatedMuted);
    await _notificationService.cancelEntryReminders(entry);
    await _repository.saveSchedule(updated);
    if (updated.isActive) {
      await _notificationService.scheduleEntryReminders(updated);
    }
    _loadSchedules();
    await _syncService.syncScheduleToCloud(updated);
    return isNowMuted;
  }

  Future<void> importBatch(List<ScheduleEntry> entries) => addBatch(entries);

  Future<void> addBatch(List<ScheduleEntry> entries) async {
    await _repository.saveBatch(entries);
    for (final entry in entries) {
      if (entry.isActive) {
        await _notificationService.scheduleEntryReminders(entry);
      }
    }
    _loadSchedules();
    await _syncService.syncBatchSchedulesToCloud(entries);
  }

  /// Adds a batch of schedules while intelligently merging with existing entries in the same profile.
  /// If an existing entry occupies the same days, start time, and end time in the same profile,
  /// it updates the existing entry in place instead of creating a duplicate.
  Future<int> mergeBatch(List<ScheduleEntry> entries) async {
    final existing = _repository.getAllSchedules();
    final toSave = <ScheduleEntry>[];
    int duplicateCount = 0;

    for (final newEntry in entries) {
      final matchIndex = existing.indexWhere((e) => ScheduleDeduplicator.areDuplicates(newEntry, e));
      if (matchIndex != -1) {
        final matched = existing[matchIndex];
        final updated = ScheduleDeduplicator.merge(newEntry, matched).copyWith(
          id: matched.id,
          createdAt: matched.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        toSave.add(updated);
        duplicateCount++;
      } else {
        toSave.add(newEntry);
      }
    }

    await addBatch(toSave);
    return duplicateCount;
  }

  /// Scans all local schedules and removes redundant duplicate entries
  /// (both exact duplicates and overlapping slot duplicates on the same profile).
  /// Deletes redundant entries from local Hive and Firestore in batch.
  /// Returns the count of deleted duplicates.
  Future<int> deduplicateSchedules({String? specificProfileId}) async {
    final all = _repository.getAllSchedules();
    if (all.length <= 1) return 0;

    final targetList = specificProfileId != null
        ? all.where((e) => e.profileId == specificProfileId).toList()
        : List<ScheduleEntry>.from(all);

    final dedupResult = ScheduleDeduplicator.deduplicate(targetList);

    if (dedupResult.removed.isNotEmpty) {
      final idsToRemove = dedupResult.removed.map((e) => e.id).toList();
      for (final entry in dedupResult.removed) {
        await _notificationService.cancelEntryReminders(entry);
        await _repository.deleteSchedule(entry.id);
      }
      if (dedupResult.updated.isNotEmpty) {
        await _repository.saveBatch(dedupResult.updated);
      }
      _loadSchedules();
      await _syncService.deleteBatchSchedulesFromCloud(idsToRemove);
      return dedupResult.removedCount;
    }

    return 0;
  }

  Future<void> clearAll() async {
    await _notificationService.rescheduleAll([]);
    final current = _repository.getAllSchedules();
    final ids = current.map((e) => e.id).toList();
    await _repository.clearAll();
    state = [];
    await _syncService.deleteBatchSchedulesFromCloud(ids);
  }

  Future<void> deleteSchedulesForProfile(String profileId) async {
    final all = _repository.getAllSchedules();
    final toDelete = all.where((e) => e.profileId == profileId || (e.profileId == null)).toList();
    for (final entry in toDelete) {
      await _notificationService.cancelEntryReminders(entry);
      await _repository.deleteSchedule(entry.id);
    }
    _loadSchedules();
    await _syncService.deleteBatchSchedulesFromCloud(
      toDelete.map((e) => e.id).toList(),
    );
  }

  Future<void> refreshFromCloud() async {
    await _syncService.pullAndSyncAll(onDataChanged: () {
      _onProfilesChanged?.call();
      _loadSchedules();
    });
    _onProfilesChanged?.call();
    _loadSchedules();
  }

  void clearLocalMemory() {
    state = [];
  }

  void refreshFromLocal() {
    _loadSchedules();
  }
}

final scheduleListProvider =
    StateNotifierProvider<ScheduleNotifier, List<ScheduleEntry>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final notif = ref.watch(notificationServiceProvider);
  final sync = ref.watch(firestoreSyncServiceProvider);
  return ScheduleNotifier(
    repo,
    profileRepo,
    notif,
    sync,
    onProfilesChanged: () {
      ref.read(profileListProvider.notifier).refreshFromLocal();
    },
  );
});
