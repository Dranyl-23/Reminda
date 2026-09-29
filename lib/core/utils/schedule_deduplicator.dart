import 'package:flutter/foundation.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';

class DeduplicationResult {
  final List<ScheduleEntry> kept;
  final List<ScheduleEntry> removed;
  final List<ScheduleEntry> updated;

  const DeduplicationResult({
    required this.kept,
    required this.removed,
    required this.updated,
  });

  int get removedCount => removed.length;
}

class ScheduleDeduplicator {
  const ScheduleDeduplicator._();

  /// Determines if two schedules represent the exact same slot/class.
  static bool areDuplicates(ScheduleEntry a, ScheduleEntry b) {
    if (a.id == b.id) return false;

    // Must have identical start and end time
    if (a.startTime != b.startTime || a.endTime != b.endTime) return false;

    // Must share at least one day
    final sharedDays = a.daysOfWeek.where((d) => b.daysOfWeek.contains(d)).toList();
    if (sharedDays.isEmpty) return false;

    final aDaysSorted = [...a.daysOfWeek]..sort();
    final bDaysSorted = [...b.daysOfWeek]..sort();
    final bool sameDays = listEquals(aDaysSorted, bDaysSorted);
    if (!sameDays) return false;

    final aProfile = a.profileId?.trim() ?? '';
    final bProfile = b.profileId?.trim() ?? '';
    final bool sameProfile = aProfile.isNotEmpty && bProfile.isNotEmpty && aProfile == bProfile;

    // 1. Exact title match (case-insensitive) -> Always duplicate, even across profiles
    if (a.title.trim().toLowerCase() == b.title.trim().toLowerCase()) {
      return true;
    }

    // 2. Abbreviation or substring match -> Always duplicate
    final aClean = a.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final bClean = b.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (aClean.isNotEmpty && bClean.isNotEmpty && (aClean.contains(bClean) || bClean.contains(aClean))) {
      return true;
    }

    // 3. Matching location / room AND same category -> Duplicate
    final bool sameLocation = a.location != null &&
        b.location != null &&
        a.location!.trim().isNotEmpty &&
        a.location!.trim().toLowerCase() != 'null' &&
        b.location!.trim().toLowerCase() != 'null' &&
        a.location!.trim().toLowerCase() == b.location!.trim().toLowerCase();

    if (sameLocation && a.category == b.category) {
      return true;
    }

    // 4. Same category in the exact same time slot on the SAME profile
    if (sameProfile && a.category == b.category) {
      return true;
    }

    return false;
  }

  /// Calculates a quality / detail score for a schedule entry.
  /// Higher score means more complete title, location, notes, etc.
  static int calculateScore(ScheduleEntry e) {
    int score = 0;
    score += e.title.length;
    if (e.location != null &&
        e.location!.trim().isNotEmpty &&
        e.location!.trim().toLowerCase() != 'null') {
      score += 25;
    }
    if (e.notes != null &&
        e.notes!.trim().isNotEmpty &&
        e.notes!.trim().toLowerCase() != 'null') {
      score += 15;
    }
    if (e.reminders.isNotEmpty) score += 5;
    score += (e.updatedAt % 1000);
    return score;
  }

  /// Merges two duplicate entries, retaining the superior record and inheriting
  /// any missing details (such as room or notes) from the other.
  static ScheduleEntry merge(ScheduleEntry primary, ScheduleEntry secondary) {
    String? location = primary.location;
    if ((location == null || location.trim().isEmpty || location.trim().toLowerCase() == 'null') &&
        (secondary.location != null &&
            secondary.location!.trim().isNotEmpty &&
            secondary.location!.trim().toLowerCase() != 'null')) {
      location = secondary.location;
    }

    String? notes = primary.notes;
    if ((notes == null || notes.trim().isEmpty || notes.trim().toLowerCase() == 'null') &&
        (secondary.notes != null &&
            secondary.notes!.trim().isNotEmpty &&
            secondary.notes!.trim().toLowerCase() != 'null')) {
      notes = secondary.notes;
    }

    // If merging across profiles, prefer school profile for classSchedule
    String? profileId = primary.profileId;
    if (primary.profileId != secondary.profileId && secondary.profileId != null) {
      if (primary.category == ScheduleCategory.classSchedule) {
        if (secondary.profileId!.toLowerCase().contains('school') ||
            secondary.profileId!.toLowerCase().contains('cjc')) {
          profileId = secondary.profileId;
        }
      }
    }

    return primary.copyWith(
      profileId: profileId,
      location: location,
      notes: notes,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Deduplicates a list of schedule entries, returning the kept unique entries,
  /// redundant entries to remove, and updated entries that inherited fields.
  static DeduplicationResult deduplicate(List<ScheduleEntry> entries) {
    if (entries.length <= 1) {
      return DeduplicationResult(
        kept: List.from(entries),
        removed: const [],
        updated: const [],
      );
    }

    final kept = <ScheduleEntry>[];
    final removed = <ScheduleEntry>[];
    final updated = <ScheduleEntry>[];

    for (final candidate in entries) {
      int matchIndex = -1;
      for (int i = 0; i < kept.length; i++) {
        if (areDuplicates(candidate, kept[i])) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex != -1) {
        final existing = kept[matchIndex];
        final candidateScore = calculateScore(candidate);
        final existingScore = calculateScore(existing);

        if (candidateScore > existingScore) {
          final merged = merge(candidate, existing);
          kept[matchIndex] = merged;
          updated.add(merged);
          removed.add(existing);
        } else {
          final merged = merge(existing, candidate);
          kept[matchIndex] = merged;
          updated.add(merged);
          removed.add(candidate);
        }
      } else {
        kept.add(candidate);
      }
    }

    return DeduplicationResult(
      kept: kept,
      removed: removed,
      updated: updated,
    );
  }
}
