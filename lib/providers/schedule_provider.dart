import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/firestore_sync_service.dart';
import '../core/database/profile_repository.dart';
import '../core/database/schedule_repository.dart';
import '../core/notifications/home_widget_sync_service.dart';
import '../core/notifications/notification_service.dart';
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
    _loadSchedules();
    _rescheduleAlarms();
    _syncService.startSync(onDataChanged: () {
      _onProfilesChanged?.call();
      _loadSchedules();
      _rescheduleAlarms();
    });
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  void _loadSchedules() {
    var schedules = _repository.getAllSchedules();
    final profiles = _profileRepository.getAllProfiles();
    if (profiles.isNotEmpty && schedules.isNotEmpty) {
      final validProfileIds = profiles.map((p) => p.id).toSet();
      final activeProfile = _profileRepository.getActiveProfile() ?? profiles.first;
      final healed = <ScheduleEntry>[];
      final updatedList = <ScheduleEntry>[];

      for (final entry in schedules) {
        final pid = entry.profileId?.trim() ?? '';
        if (pid.isEmpty || !validProfileIds.contains(pid)) {
          final fixed = entry.copyWith(profileId: activeProfile.id);
          healed.add(fixed);
          updatedList.add(fixed);
        } else {
          updatedList.add(entry);
        }
      }

      if (healed.isNotEmpty) {
        schedules = updatedList;
        _repository.saveBatch(healed);
        _syncService.syncBatchSchedulesToCloud(healed);
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

  Future<void> clearAll() async {
    await _notificationService.rescheduleAll([]);
    final current = _repository.getAllSchedules();
    for (final entry in current) {
      _syncService.deleteScheduleFromCloud(entry.id);
    }
    await _repository.clearAll();
    state = [];
  }

  Future<void> deleteSchedulesForProfile(String profileId) async {
    final all = _repository.getAllSchedules();
    final toDelete = all.where((e) => e.profileId == profileId || (e.profileId == null)).toList();
    for (final entry in toDelete) {
      await _notificationService.cancelEntryReminders(entry);
      await _repository.deleteSchedule(entry.id);
      await _syncService.deleteScheduleFromCloud(entry.id);
    }
    _loadSchedules();
  }

  Future<void> refreshFromCloud() async {
    await _syncService.pullAndSyncAll(onDataChanged: () => _loadSchedules());
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
