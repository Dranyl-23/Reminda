import 'package:uuid/uuid.dart';
import 'schedule_category.dart';

class ScheduleEntry {
  final String id;
  final String? profileId;    // Linked profile ID (e.g. School, Work, Duty)
  final String title;
  final ScheduleCategory category;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday (ISO-8601)
  final String startTime;     // "HH:mm" (24-hour format)
  final String endTime;       // "HH:mm" (24-hour format)
  final bool spansNextDay;     // true if shift crosses midnight (e.g. 22:00 -> 06:00)
  final String? location;      // e.g. "Room 302", "Counter 1", "Main Branch"
  final String? notes;         // e.g. "Bring lab gown / submit assignment"
  final String? colorHex;      // Optional custom color override
  final List<int> reminders;   // Lead times in minutes: [15, 60]
  final bool isActive;         // Toggle schedule & notification alarms
  final List<String> mutedDates; // ISO dates ("YYYY-MM-DD") skipped for holiday/one-off mute
  final DateTime createdAt;
  final int updatedAt;         // Epoch milliseconds for last modification (offline vs. cloud sync)
  final String? sourceImageId; // Reference to original screenshot if scanned

  ScheduleEntry({
    String? id,
    this.profileId,
    required this.title,
    this.category = ScheduleCategory.custom,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.spansNextDay = false,
    this.location,
    this.notes,
    this.colorHex,
    List<int>? reminders,
    this.isActive = true,
    List<String>? mutedDates,
    DateTime? createdAt,
    int? updatedAt,
    this.sourceImageId,
  })  : id = id ?? const Uuid().v4(),
        reminders = reminders ?? [15],
        mutedDates = mutedDates ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  static String dateToIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isMutedOnDate(DateTime date) => mutedDates.contains(dateToIso(date));

  /// Whether this schedule is currently active/ongoing right now.
  bool isCurrentlyOngoing([DateTime? now]) {
    final n = now ?? DateTime.now();
    final currentWeekday = n.weekday;
    final currentMinutes = n.hour * 60 + n.minute;
    final yesterdayDate = n.subtract(const Duration(days: 1));
    final yesterdayWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1;

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startH = startParts.length >= 2 ? int.tryParse(startParts[0]) : null;
    final startM = startParts.length >= 2 ? int.tryParse(startParts[1]) : null;
    final endH = endParts.length >= 2 ? int.tryParse(endParts[0]) : null;
    final endM = endParts.length >= 2 ? int.tryParse(endParts[1]) : null;

    if (startH == null || startM == null || endH == null || endM == null) {
      return false;
    }

    final startMin = startH * 60 + startM;
    final rawEndMin = endH * 60 + endM;
    final isOvernight = spansNextDay || (rawEndMin < startMin);

    bool isOngoing = false;

    // Check 1: Did this shift start YESTERDAY and is still ongoing past midnight today?
    if (isOvernight &&
        daysOfWeek.contains(yesterdayWeekday) &&
        !isMutedOnDate(yesterdayDate)) {
      if (currentMinutes < rawEndMin) {
        isOngoing = true;
      }
    }

    // Check 2: Does this shift start TODAY and is currently ongoing?
    if (!isOngoing &&
        daysOfWeek.contains(currentWeekday) &&
        !isMutedOnDate(n)) {
      if (isOvernight) {
        // Active from startMin through end of day (23:59)
        isOngoing = (currentMinutes >= startMin);
      } else {
        // Normal daytime shift
        isOngoing = (currentMinutes >= startMin && currentMinutes < rawEndMin);
      }
    }

    return isOngoing;
  }

  /// Computes the calendar date (year, month, day, startHour, startMin) of the next occurrence
  DateTime? nextOccurrenceDate([DateTime? from]) {
    if (daysOfWeek.isEmpty) return null;
    final now = from ?? DateTime.now();
    final parts = startTime.split(':');
    final startHour = parts.length >= 2 ? (int.tryParse(parts[0]) ?? 8) : 8;
    final startMin = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    for (int offset = 0; offset <= 7; offset++) {
      final candidate = DateTime(now.year, now.month, now.day + offset, startHour, startMin);
      if (daysOfWeek.contains(candidate.weekday)) {
        if (offset > 0 || candidate.isAfter(now)) {
          return candidate;
        }
      }
    }
    return null;
  }

  String? nextOccurrenceIsoDate([DateTime? from]) {
    final next = nextOccurrenceDate(from);
    return next != null ? dateToIso(next) : null;
  }

  bool get isNextOccurrenceMuted {
    final iso = nextOccurrenceIsoDate();
    return iso != null && mutedDates.contains(iso);
  }

  ScheduleEntry copyWith({
    String? id,
    String? profileId,
    String? title,
    ScheduleCategory? category,
    List<int>? daysOfWeek,
    String? startTime,
    String? endTime,
    bool? spansNextDay,
    String? location,
    String? notes,
    String? colorHex,
    List<int>? reminders,
    bool? isActive,
    List<String>? mutedDates,
    DateTime? createdAt,
    int? updatedAt,
    String? sourceImageId,
  }) {
    return ScheduleEntry(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      category: category ?? this.category,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      spansNextDay: spansNextDay ?? this.spansNextDay,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      colorHex: colorHex ?? this.colorHex,
      reminders: reminders ?? this.reminders,
      isActive: isActive ?? this.isActive,
      mutedDates: mutedDates ?? this.mutedDates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      sourceImageId: sourceImageId ?? this.sourceImageId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'category': category.name,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'spansNextDay': spansNextDay,
      'location': location,
      'notes': notes,
      'colorHex': colorHex,
      'reminders': reminders,
      'isActive': isActive,
      'mutedDates': mutedDates,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt,
      'sourceImageId': sourceImageId,
    };
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt;
    final rawCreated = json['createdAt'];
    if (rawCreated == null) {
      parsedCreatedAt = DateTime.now();
    } else if (rawCreated is DateTime) {
      parsedCreatedAt = rawCreated;
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      try {
        parsedCreatedAt = (rawCreated as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedCreatedAt = DateTime.tryParse(rawCreated.toString()) ?? DateTime.now();
      }
    }

    int parsedUpdatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated == null) {
      parsedUpdatedAt = parsedCreatedAt.millisecondsSinceEpoch;
    } else if (rawUpdated is num) {
      parsedUpdatedAt = rawUpdated.toInt();
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated)?.millisecondsSinceEpoch ??
          parsedCreatedAt.millisecondsSinceEpoch;
    } else if (rawUpdated is DateTime) {
      parsedUpdatedAt = rawUpdated.millisecondsSinceEpoch;
    } else {
      try {
        final dynamic dyn = rawUpdated;
        if (dyn.millisecondsSinceEpoch is int) {
          parsedUpdatedAt = dyn.millisecondsSinceEpoch as int;
        } else if (dyn.toDate is Function) {
          parsedUpdatedAt = (dyn.toDate() as DateTime).millisecondsSinceEpoch;
        } else {
          parsedUpdatedAt = parsedCreatedAt.millisecondsSinceEpoch;
        }
      } catch (_) {
        parsedUpdatedAt = parsedCreatedAt.millisecondsSinceEpoch;
      }
    }

    final rawId = json['id'];
    final finalId = (rawId is String && rawId.isNotEmpty) ? rawId : null;

    return ScheduleEntry(
      id: finalId,
      profileId: json['profileId'] as String?,
      title: json['title'] as String? ?? 'Untitled Schedule',
      category: ScheduleCategoryExtension.fromString(json['category'] as String?),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) {
                if (e is num) return e.toInt();
                return int.tryParse(e.toString()) ?? 1;
              })
              .toList() ??
          [],
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '09:00',
      spansNextDay: json['spansNextDay'] as bool? ?? false,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      colorHex: json['colorHex'] as String?,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) {
                if (e is num) return e.toInt();
                return int.tryParse(e.toString()) ?? 15;
              })
              .toList() ??
          [15],
      isActive: json['isActive'] as bool? ?? true,
      mutedDates: (json['mutedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      sourceImageId: json['sourceImageId'] as String?,
    );
  }
}
