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
    final parsedCreatedAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final rawUpdatedAt = json['updatedAt'];
    final parsedUpdatedAt = rawUpdatedAt is num
        ? rawUpdatedAt.toInt()
        : parsedCreatedAt.millisecondsSinceEpoch;

    return ScheduleEntry(
      id: json['id'] as String?,
      profileId: json['profileId'] as String?,
      title: json['title'] as String? ?? 'Untitled Schedule',
      category: ScheduleCategoryExtension.fromString(json['category'] as String?),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '09:00',
      spansNextDay: json['spansNextDay'] as bool? ?? false,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      colorHex: json['colorHex'] as String?,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
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
