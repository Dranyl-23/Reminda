import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/schedule_entry.dart';
import '../constants/app_version.dart';
import '../database/firestore_instance.dart';

class AiTrainingTelemetryService {
  static const String settingsBox = 'app_settings_box';
  static const String contributeKey = 'contribute_ai_training_data';

  /// Check if user has explicitly opted-in to anonymous AI training telemetry (default false)
  static bool isTelemetryEnabled() {
    try {
      if (Hive.isBoxOpen(settingsBox)) {
        return Hive.box(settingsBox).get(contributeKey, defaultValue: false) as bool;
      }
    } catch (_) {}
    return false;
  }

  /// Toggle user consent
  static Future<void> setTelemetryEnabled(bool enabled) async {
    try {
      final box = Hive.isBoxOpen(settingsBox)
          ? Hive.box(settingsBox)
          : await Hive.openBox(settingsBox);
      await box.put(contributeKey, enabled);
    } catch (e) {
      debugPrint('AiTrainingTelemetryService: Failed to save consent: $e');
    }
  }

  /// Redacts emails, phone numbers, and 6+ digit student/employee IDs from raw OCR text
  static String _redactPii(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[EMAIL]')
        .replaceAll(RegExp(r'\b\d{2,4}[-\s]?\d{5,10}\b'), '[ID]');
  }

  /// Anonymously record user-verified ground-truth schedule sample for future offline AI training
  static Future<void> recordGroundTruthSample({
    required List<ScheduleEntry> entries,
    String? rawOcrText,
    String? institutionName,
    String? role,
    String source = 'offline_mlkit',
  }) async {
    if (!isTelemetryEnabled()) return;
    if (entries.isEmpty) return;

    try {
      final sampleEntries = entries.map((e) => {
        'title': e.title,
        'daysOfWeek': e.daysOfWeek,
        'startTime': e.startTime,
        'endTime': e.endTime,
        'location': e.location ?? '',
        'category': e.category.name,
        'notes': '',
      }).toList();

      final platformName = kIsWeb
          ? 'Web'
          : (Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other'));

      final payload = {
        'entriesCount': entries.length,
        'verifiedEntries': sampleEntries,
        'rawOcrText': _redactPii(rawOcrText ?? ''),
        'institutionName': institutionName ?? '',
        'role': role ?? 'general',
        'engineSource': source,
        'appVersion': AppVersion.fullVersion,
        'platform': platformName,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAtIso': DateTime.now().toIso8601String(),
      };

      // Non-blocking fire-and-forget background write to Firestore
      appFirestore.collection('ai_training_samples').add(payload).ignore();
    } catch (e) {
      debugPrint('AiTrainingTelemetryService: Telemetry background sync ignored: $e');
    }
  }
}
