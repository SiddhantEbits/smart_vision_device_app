import 'package:flutter/material.dart';

class RoiAlertConfig {
  final Rect roi;
  final Offset lineStart;
  final Offset lineEnd;
  final Offset direction;

  const RoiAlertConfig({
    required this.roi,
    required this.lineStart,
    required this.lineEnd,
    required this.direction,
  });

  factory RoiAlertConfig.forFootfall() {
    return const RoiAlertConfig(
      roi: Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
      lineStart: Offset(0.3, 0.5),
      lineEnd: Offset(0.7, 0.5),
      direction: Offset(0, 1),
    );
  }

  factory RoiAlertConfig.forRestrictedArea() {
    return const RoiAlertConfig(
      roi: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
      lineStart: Offset.zero,
      lineEnd: Offset.zero,
      direction: Offset.zero,
    );
  }

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoiAlertConfig &&
          runtimeType == other.runtimeType &&
          roi == other.roi &&
          lineStart == other.lineStart &&
          lineEnd == other.lineEnd &&
          direction == other.direction;

  @override
  int get hashCode => roi.hashCode ^ lineStart.hashCode ^ lineEnd.hashCode ^ direction.hashCode;

  /// True when config is intended for FOOTFALL
  bool get isFootfall =>
      lineStart != Offset.zero &&
          lineEnd != Offset.zero &&
          direction != Offset.zero;

  /// True when config is intended for ROI-only alerts
  bool get isRestrictedArea => !isFootfall;
}
