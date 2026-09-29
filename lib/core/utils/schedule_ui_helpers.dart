import 'package:flutter/material.dart';
import '../../models/schedule_category.dart';

class ScheduleUIHelpers {
  static IconData getIconForSubject(String title, ScheduleCategory category) {
    final lower = title.toLowerCase();
    if (lower.contains('program') || lower.contains('code') || lower.contains('cs') || lower.contains('it') || lower.contains('software')) {
      return Icons.computer_rounded;
    }
    if (lower.contains('math') || lower.contains('calc') || lower.contains('stat') || lower.contains('algebra')) {
      return Icons.calculate_rounded;
    }
    if (lower.contains('data') || lower.contains('db') || lower.contains('sql') || lower.contains('network')) {
      return Icons.storage_rounded;
    }
    if (lower.contains('free') || lower.contains('break') || lower.contains('lunch') || lower.contains('vacant')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('duty') || lower.contains('medic') || lower.contains('nurs') || lower.contains('hospital')) {
      return Icons.medical_services_rounded;
    }
    return category.icon;
  }
}
