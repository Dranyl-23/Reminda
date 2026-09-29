import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_colors.dart';

class ScheduleProfile {
  final String id;
  final String name;
  final String type; // 'school' | 'work' | 'duty' | 'custom'
  final String colorHex;
  final bool isActive;
  final DateTime updatedAt;

  ScheduleProfile({
    String? id,
    required this.name,
    this.type = 'custom',
    String? colorHex,
    this.isActive = false,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        colorHex = colorHex ?? '#2563EB',
        updatedAt = updatedAt ?? DateTime.now();

  ScheduleProfile copyWith({
    String? id,
    String? name,
    String? type,
    String? colorHex,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return ScheduleProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'school':
      case 'class':
        return Icons.school_rounded;
      case 'work':
      case 'job':
        return Icons.work_rounded;
      case 'duty':
        return Icons.badge_rounded;
      default:
        return Icons.calendar_today_rounded;
    }
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'colorHex': colorHex,
      'isActive': isActive,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ScheduleProfile.fromJson(Map<String, dynamic> json) {
    DateTime parsedUpdatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated == null) {
      parsedUpdatedAt = DateTime.now();
    } else if (rawUpdated is DateTime) {
      parsedUpdatedAt = rawUpdated;
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    } else if (rawUpdated is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdated);
    } else {
      try {
        parsedUpdatedAt = (rawUpdated as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedUpdatedAt = DateTime.tryParse(rawUpdated.toString()) ?? DateTime.now();
      }
    }

    return ScheduleProfile(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Default Schedule',
      type: json['type'] as String? ?? 'custom',
      colorHex: json['colorHex'] as String? ?? '#2563EB',
      isActive: json['isActive'] as bool? ?? false,
      updatedAt: parsedUpdatedAt,
    );
  }
}
