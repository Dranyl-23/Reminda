import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/schedule_entry.dart';
import '../utils/hive_encryption_helper.dart';

class ScheduleRepository {
  static const String boxName = 'schedules_box';
  static ScheduleRepository? _instance;

  factory ScheduleRepository() => _instance ??= ScheduleRepository._internal();
  ScheduleRepository._internal();

  Box<String>? _box;

  /// Synchronized in-memory cache so getAllSchedules() and getScheduleById()
  /// execute in O(1) / 0ms without repeated jsonDecode parsing on the main thread.
  Map<String, ScheduleEntry>? _memoryCache;

  Box<String>? get _safeBox {
    if (_box != null && _box!.isOpen) return _box;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
      return _box;
    }
    return null;
  }

  Future<void> init() async {
    await Hive.initFlutter();
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
    } else {
      HiveAesCipher? cipher;
      try {
        cipher = await HiveEncryptionHelper.getCipher();
      } catch (e) {
        debugPrint('ScheduleRepository: Encryption cipher lookup failed: $e');
      }

      if (cipher != null) {
        try {
          _box = await Hive.openBox<String>(boxName, encryptionCipher: cipher);
        } catch (e) {
          debugPrint(
            'ScheduleRepository: Encrypted open failed ($e), opening unencrypted box for backward compatibility',
          );
          _box = await Hive.openBox<String>(boxName);
        }
      } else {
        _box = await Hive.openBox<String>(boxName);
      }
    }
    _rebuildCacheFromDisk();
  }

  Map<String, ScheduleEntry> _ensureCache() {
    if (_memoryCache != null) return _memoryCache!;
    return _rebuildCacheFromDisk();
  }

  Map<String, ScheduleEntry> _rebuildCacheFromDisk() {
    final box = _safeBox;
    if (box == null) return const {};
    final cache = <String, ScheduleEntry>{};
    for (final rawJson in box.values) {
      try {
        final Map<String, dynamic> map =
            jsonDecode(rawJson) as Map<String, dynamic>;
        final entry = ScheduleEntry.fromJson(map);
        cache[entry.id] = entry;
      } catch (e) {
        debugPrint('ScheduleRepository: Skipped corrupted entry from disk: $e');
      }
    }
    _memoryCache = cache;
    return cache;
  }

  List<ScheduleEntry> getAllSchedules() {
    final cache = _ensureCache();
    if (cache.isEmpty) return [];
    final entries = cache.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return entries;
  }

  ScheduleEntry? getScheduleById(String id) {
    return _ensureCache()[id];
  }

  Future<void> saveSchedule(ScheduleEntry entry) async {
    final box = _safeBox;
    if (box == null) return;
    _ensureCache()[entry.id] = entry;
    final jsonStr = jsonEncode(entry.toJson());
    await box.put(entry.id, jsonStr);
  }

  Future<void> saveBatch(List<ScheduleEntry> entries) async {
    final box = _safeBox;
    if (box == null) return;
    final cache = _ensureCache();
    final Map<String, String> map = {};
    for (final entry in entries) {
      cache[entry.id] = entry;
      map[entry.id] = jsonEncode(entry.toJson());
    }
    await box.putAll(map);
  }

  Future<void> deleteSchedule(String id) async {
    _memoryCache?.remove(id);
    await _safeBox?.delete(id);
  }

  Future<void> toggleActive(String id) async {
    final entry = getScheduleById(id);
    if (entry != null) {
      final updated = entry.copyWith(isActive: !entry.isActive);
      await saveSchedule(updated);
    }
  }

  Future<void> clearAll() async {
    _memoryCache?.clear();
    await _safeBox?.clear();
  }
}
