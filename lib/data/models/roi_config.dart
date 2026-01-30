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

  // ============================================================
  // FIREBASE CONVERSION METHODS
  // ============================================================
  
  /// Convert ROI config to Firebase format
  Map<String, dynamic> toFirebaseMap() {
    return {
      'roi': {
        'left': roi.left,
        'top': roi.top,
        'right': roi.right,
        'bottom': roi.bottom,
      },
      'lineStart': {
        'dx': lineStart.dx,
        'dy': lineStart.dy,
      },
      'lineEnd': {
        'dx': lineEnd.dx,
        'dy': lineEnd.dy,
      },
      'direction': {
        'dx': direction.dx,
        'dy': direction.dy,
      },
      'roiType': isFootfall ? 'line' : 'rectangle',
      'roiCoordinates': [roi.left, roi.top, roi.right, roi.bottom],
      'lineCoordinates': [lineStart.dx, lineStart.dy, lineEnd.dx, lineEnd.dy],
    };
  }
  
  /// Create ROI config from Firebase format
  factory RoiAlertConfig.fromFirebaseMap(Map<String, dynamic> data) {
    final roiData = data['roi'] as Map<String, dynamic>? ?? {};
    final lineStartData = data['lineStart'] as Map<String, dynamic>? ?? {};
    final lineEndData = data['lineEnd'] as Map<String, dynamic>? ?? {};
    final directionData = data['direction'] as Map<String, dynamic>? ?? {};
    
    return RoiAlertConfig(
      roi: Rect.fromLTWH(
        roiData['left']?.toDouble() ?? 0.0,
        roiData['top']?.toDouble() ?? 0.0,
        (roiData['right']?.toDouble() ?? 1.0) - (roiData['left']?.toDouble() ?? 0.0),
        (roiData['bottom']?.toDouble() ?? 1.0) - (roiData['top']?.toDouble() ?? 0.0),
      ),
      lineStart: Offset(
        lineStartData['dx']?.toDouble() ?? 0.0,
        lineStartData['dy']?.toDouble() ?? 0.0,
      ),
      lineEnd: Offset(
        lineEndData['dx']?.toDouble() ?? 0.0,
        lineEndData['dy']?.toDouble() ?? 0.0,
      ),
      direction: Offset(
        directionData['dx']?.toDouble() ?? 0.0,
        directionData['dy']?.toDouble() ?? 0.0,
      ),
    );
  }
  
  /// Create ROI config from simplified Firebase format (for backward compatibility)
  factory RoiAlertConfig.fromSimplifiedFirebaseMap(Map<String, dynamic> data) {
    final roiCoords = data['roiCoordinates'] as List<dynamic>? ?? [0.0, 0.0, 1.0, 1.0];
    final lineCoords = data['lineCoordinates'] as List<dynamic>? ?? [0.0, 0.5, 1.0, 0.5];
    final roiType = data['roiType'] as String? ?? 'rectangle';
    
    return RoiAlertConfig(
      roi: Rect.fromLTWH(
        roiCoords[0].toDouble(),
        roiCoords[1].toDouble(),
        roiCoords[2].toDouble() - roiCoords[0].toDouble(),
        roiCoords[3].toDouble() - roiCoords[1].toDouble(),
      ),
      lineStart: Offset(lineCoords[0].toDouble(), lineCoords[1].toDouble()),
      lineEnd: Offset(lineCoords[2].toDouble(), lineCoords[3].toDouble()),
      direction: roiType == 'line' ? const Offset(0, 1) : Offset.zero,
    );
  }
}
