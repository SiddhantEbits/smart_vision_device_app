import 'package:flutter/material.dart';

/// ===========================================================
/// ALERT SCHEDULE MODEL
/// ===========================================================
class AlertSchedule {
  /// Start time (inclusive)
  final TimeOfDay start;

  /// End time (inclusive)
  final TimeOfDay end;

  /// Active weekdays: 1=Mon ... 7=Sun
  final List<int> activeDays;

  const AlertSchedule({
    required this.start,
    required this.end,
    required this.activeDays,
  });

  /// ===========================================================
  /// RUNTIME CHECK (overnight-safe)
  /// ===========================================================
  bool isActiveNow({DateTime? now}) {
    final current = now ?? DateTime.now();

    if (activeDays.isEmpty) return false;
    if (!activeDays.contains(current.weekday)) return false;

    final minutesNow = current.hour * 60 + current.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    // Same-day window (09:00 → 18:00)
    if (startMin <= endMin) {
      return minutesNow >= startMin && minutesNow <= endMin;
    }

    // Overnight window (22:00 → 06:00)
    return minutesNow >= startMin || minutesNow <= endMin;
  }

  /// ===========================================================
  /// ALWAYS ACTIVE FACTORY (24x7)
  /// ===========================================================
  static AlertSchedule always() => const AlertSchedule(
    start: TimeOfDay(hour: 0, minute: 0),
    end: TimeOfDay(hour: 23, minute: 59),
    activeDays: [1, 2, 3, 4, 5, 6, 7],
  );

  /// ===========================================================
  /// VALIDATION
  /// ===========================================================
  bool get isValid => activeDays.isNotEmpty;

  /// ===========================================================
  /// COPY
  /// ===========================================================
  AlertSchedule copyWith({
    TimeOfDay? start,
    TimeOfDay? end,
    List<int>? activeDays,
  }) {
    return AlertSchedule(
      start: start ?? this.start,
      end: end ?? this.end,
      activeDays: activeDays ?? List.from(this.activeDays),
    );
  }

  /// ===========================================================
  /// HUMAN READABLE (OPTIONAL UI USE)
  /// ===========================================================
  String summary() {
    final days = activeDays
        .map((d) => _dayLabel(d))
        .join(', ');

    return "$days • ${start.format(_fakeContext)} → ${end.format(_fakeContext)}";
  }

  static String _dayLabel(int d) {
    const map = {
      1: "Mon",
      2: "Tue",
      3: "Wed",
      4: "Thu",
      5: "Fri",
      6: "Sat",
      7: "Sun",
    };
    return map[d] ?? "?";
  }

  /// ===========================================================
  /// JSON
  /// ===========================================================
  factory AlertSchedule.fromJson(Map<String, dynamic> json) {
    return AlertSchedule(
      start: TimeOfDay(
        hour: json['startHour'],
        minute: json['startMinute'],
      ),
      end: TimeOfDay(
        hour: json['endHour'],
        minute: json['endMinute'],
      ),
      activeDays: List<int>.from(json['activeDays'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
    'activeDays': activeDays,
  };
}

final BuildContext _fakeContext =
WidgetsBinding.instance.rootElement!;
