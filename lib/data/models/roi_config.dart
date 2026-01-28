import 'package:flutter/foundation.dart';
import 'dart:ui';

@immutable
class RoiAlertConfig {
  /// Normalized 0–1
  final Rect roi;

  /// Normalized 0–1 (used by line-based alerts like footfall)
  final Offset lineStart;
  final Offset lineEnd;

  /// Normalized unit vector (used by line-based alerts)
  final Offset direction;

  const RoiAlertConfig({
    required this.roi,
    required this.lineStart,
    required this.lineEnd,
    required this.direction,
  });

  // ============================================================
  // COPY
  // ============================================================
  RoiAlertConfig copyWith({
    Rect? roi,
    Offset? lineStart,
    Offset? lineEnd,
    Offset? direction,
  }) {
    return RoiAlertConfig(
      roi: roi ?? this.roi,
      lineStart: lineStart ?? this.lineStart,
      lineEnd: lineEnd ?? this.lineEnd,
      direction: direction ?? this.direction,
    );
  }

  // ============================================================
  // FOOTFALL (PRIMARY DEFAULT)
  // ============================================================
  factory RoiAlertConfig.forFootfall() {
    return const RoiAlertConfig(
      roi: Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
      lineStart: Offset(0.3, 0.5),
      lineEnd: Offset(0.7, 0.5),
      direction: Offset(0, 1),
    );
  }

  /// 🔁 BACKWARD COMPATIBILITY (DO NOT REMOVE)
  factory RoiAlertConfig.defaultConfig() {
    return RoiAlertConfig.forFootfall();
  }

  // ============================================================
  // RESTRICTED AREA (ROI ONLY)
  // ============================================================
  factory RoiAlertConfig.forRestrictedArea({
    required Rect roi,
  }) {
    return RoiAlertConfig(
      roi: roi,
      lineStart: Offset.zero,
      lineEnd: Offset.zero,
      direction: Offset.zero,
    );
  }

  // ============================================================
  // SEMANTIC HELPERS (IMPORTANT)
  // ============================================================

  /// True when config is intended for FOOTFALL
  bool get isFootfall =>
      lineStart != Offset.zero &&
          lineEnd != Offset.zero &&
          direction != Offset.zero;

  /// True when config is intended for ROI-only alerts
  bool get isRestrictedArea => !isFootfall;

  /// Alias (internal readability)
  bool get usesLineCrossing => isFootfall;

  /// Alias (internal readability)
  bool get isRoiOnly => isRestrictedArea;

  // ============================================================
  // EQUALITY
  // ============================================================
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RoiAlertConfig &&
            roi == other.roi &&
            lineStart == other.lineStart &&
            lineEnd == other.lineEnd &&
            direction == other.direction;
  }

  @override
  int get hashCode =>
      roi.hashCode ^
      lineStart.hashCode ^
      lineEnd.hashCode ^
      direction.hashCode;
}
