import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/schedule_entry.dart';
import 'firestore_instance.dart';

class SharedScheduleBundle {
  final String shareCode;
  final String profileName;
  final String sharedBy;
  final List<ScheduleEntry> schedules;

  const SharedScheduleBundle({
    required this.shareCode,
    required this.profileName,
    required this.sharedBy,
    required this.schedules,
  });
}

class ScheduleShareService {
  ScheduleShareService._();
  static final ScheduleShareService instance = ScheduleShareService._();

  final FirebaseFirestore _firestore = appFirestore;
  static const _uuid = Uuid();

  /// Generates a 6-digit numeric share code and uploads the schedule bundle to Cloud Firestore.
  /// Retries on code collision and never exposes the user's raw email address.
  Future<String> publishScheduleBundle({
    required List<ScheduleEntry> schedules,
    String profileName = 'Class Schedule',
  }) async {
    final activeSchedules = schedules.where((e) => e.isActive).toList();
    if (activeSchedules.isEmpty) {
      throw Exception('No active schedules available to share.');
    }

    final user = FirebaseAuth.instance.currentUser;
    final rawName = user?.displayName?.trim();
    // Never fall back to user?.email here so the sharer's email address is not
    // exposed in a publicly readable shared_schedules document.
    final sharedBy = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'Reminda Student';

    final serialized = activeSchedules.map((e) {
      final json = e.toJson();
      // Reset mutedDates when sharing with classmates
      json['mutedDates'] = <String>[];
      return json;
    }).toList();

    final random = Random.secure();
    String? code;

    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = (100000 + random.nextInt(900000)).toString();
      final docRef = _firestore.collection('shared_schedules').doc(candidate);
      final existing = await docRef.get().timeout(const Duration(seconds: 8));
      if (!existing.exists) {
        code = candidate;
        break;
      }
    }

    if (code == null) {
      throw Exception('Could not allocate a unique share code. Please try again.');
    }

    await _firestore
        .collection('shared_schedules')
        .doc(code)
        .set({
          'shareCode': code,
          'profileName': profileName,
          'sharedBy': sharedBy,
          'entriesCount': serialized.length,
          'schedules': serialized,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14)),
          ),
        })
        .timeout(const Duration(seconds: 12));

    return code;
  }

  /// Retrieves a shared schedule bundle by its 6-digit code.
  Future<SharedScheduleBundle> fetchByShareCode(String rawCode) async {
    final cleanCode = rawCode.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleanCode.length != 6) {
      throw Exception('Please enter a valid 6-digit share code.');
    }

    final doc = await _firestore
        .collection('shared_schedules')
        .doc(cleanCode)
        .get()
        .timeout(const Duration(seconds: 12));

    if (!doc.exists || doc.data() == null) {
      throw Exception('Share code "$cleanCode" was not found or has expired.');
    }

    final data = doc.data()!;
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw Exception('Share code "$cleanCode" has expired.');
    }

    final rawList = data['schedules'] as List<dynamic>? ?? [];
    final entries = rawList
        .whereType<Map<String, dynamic>>()
        .map((item) => ScheduleEntry.fromJson(item).copyWith(
              // Assign fresh unique IDs on import so classmates don't collide
              id: _uuid.v4(),
              mutedDates: const [],
            ))
        .toList();

    if (entries.isEmpty) {
      throw Exception('This share code contains no schedules.');
    }

    return SharedScheduleBundle(
      shareCode: cleanCode,
      profileName: (data['profileName'] as String?) ?? 'Shared Schedule',
      sharedBy: (data['sharedBy'] as String?) ?? 'Classmate',
      schedules: entries,
    );
  }
}
