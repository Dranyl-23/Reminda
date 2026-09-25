import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Generates a 6-digit numeric share code and uploads the schedule bundle to Cloud Firestore.
  Future<String> publishScheduleBundle({
    required List<ScheduleEntry> schedules,
    String profileName = 'Class Schedule',
  }) async {
    final activeSchedules = schedules.where((e) => e.isActive).toList();
    if (activeSchedules.isEmpty) {
      throw Exception('No active schedules available to share.');
    }

    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    final user = FirebaseAuth.instance.currentUser;
    final sharedBy = user?.displayName ?? user?.email ?? 'Reminda Student';

    final serialized = activeSchedules.map((e) {
      final json = e.toJson();
      // Reset mutedDates when sharing with classmates
      json['mutedDates'] = <String>[];
      return json;
    }).toList();

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
    final rawList = data['schedules'] as List<dynamic>? ?? [];
    final entries = rawList
        .whereType<Map<String, dynamic>>()
        .map((item) => ScheduleEntry.fromJson(item).copyWith(
              // Assign fresh unique IDs on import so classmates don't collide
              id: null,
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
