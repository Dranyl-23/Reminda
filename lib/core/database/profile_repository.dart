import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/schedule_profile.dart';

class ProfileRepository {
  static const String boxName = 'profiles_box';
  Box<String>? _box;
  List<ScheduleProfile>? _cachedProfiles;

  Box<String> get _safeBox {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    throw StateError('ProfileRepository box has not been initialized');
  }

  Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);

    // If empty, initialize default profiles from design
    if (_box!.isEmpty) {
      final defaultProfiles = [
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
        ScheduleProfile(
          id: 'duty-profile-3',
          name: 'Duty Roster',
          type: 'duty',
          colorHex: '#10B981',
          isActive: false,
        ),
      ];

      final batchMap = <String, String>{
        for (final p in defaultProfiles) p.id: jsonEncode(p.toJson()),
      };
      await _box!.putAll(batchMap);
      _cachedProfiles = List<ScheduleProfile>.unmodifiable(defaultProfiles);
    } else {
      _rebuildCacheFromDisk();
    }
  }

  List<ScheduleProfile> _rebuildCacheFromDisk() {
    final List<ScheduleProfile> list = [];
    try {
      final box = _safeBox;
      for (final raw in box.values) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          list.add(ScheduleProfile.fromJson(map));
        } catch (_) {}
      }
      _cachedProfiles = List<ScheduleProfile>.unmodifiable(list);
    } catch (_) {}
    return _cachedProfiles ?? list;
  }

  List<ScheduleProfile> getAllProfiles() {
    if (_cachedProfiles != null) return _cachedProfiles!;
    return _rebuildCacheFromDisk();
  }

  ScheduleProfile? getActiveProfile() {
    final all = getAllProfiles();
    try {
      return all.firstWhere((p) => p.isActive);
    } catch (_) {
      return all.isNotEmpty ? all.first : null;
    }
  }

  Future<void> setActiveProfile(String profileId) async {
    final all = getAllProfiles();
    final box = _safeBox;
    final updatedList = <ScheduleProfile>[];
    final batchMap = <String, String>{};
    for (final p in all) {
      final updated = p.copyWith(isActive: p.id == profileId);
      updatedList.add(updated);
      batchMap[p.id] = jsonEncode(updated.toJson());
    }
    _cachedProfiles = List<ScheduleProfile>.unmodifiable(updatedList);
    await box.putAll(batchMap);
  }

  Future<void> saveProfile(ScheduleProfile profile) async {
    await _safeBox.put(profile.id, jsonEncode(profile.toJson()));
    _rebuildCacheFromDisk();
  }

  Future<void> deleteProfile(String id) async {
    await _safeBox.delete(id);
    _rebuildCacheFromDisk();
  }

  Future<void> clearAll() async {
    _cachedProfiles = const [];
    try {
      await _safeBox.clear();
    } catch (_) {}
  }

  Future<void> resetDefaultProfiles() async {
    await clearAll();
    final defaultProfiles = [
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
      ScheduleProfile(
        id: 'duty-profile-3',
        name: 'Duty Roster',
        type: 'duty',
        colorHex: '#10B981',
        isActive: false,
      ),
    ];

    for (final p in defaultProfiles) {
      await _safeBox.put(p.id, jsonEncode(p.toJson()));
    }
  }
}
