import 'package:flutter/material.dart';

class DetectedObject {
  /// Stable tracking ID (assigned by tracker / processor)
  final int id;

  /// Normalized bounding box (0–1)
  final Rect bbox;

  /// Class label (e.g. person)
  final String label;

  /// Confidence score
  final double confidence;

  const DetectedObject({
    required this.id,
    required this.bbox,
    required this.label,
    required this.confidence,
  });

  // ============================================================
  // GEOMETRY HELPERS
  // ============================================================

  /// Bottom-center point (used for footfall / ROI logic)
  Offset get footPoint =>
      Offset(bbox.center.dx, bbox.bottom);

  /// Center point (body centroid)
  Offset get centerPoint => bbox.center;

  /// Hybrid tracking point (adaptive based on visibility)
  Offset get hybridPoint => _calculateHybridPoint();

  /// Calculate optimal tracking point based on bounding box characteristics
  Offset _calculateHybridPoint() {
    // Use center point for tall/narrow boxes (likely crowded)
    // Use foot point for normal/wide boxes (better for footfall)
    final aspectRatio = bbox.width / bbox.height;

    if (aspectRatio < 0.3) {
      // Tall/narrow - likely crowded, use center
      return centerPoint;
    } else {
      // Normal width - use foot point for better footfall accuracy
      return footPoint;
    }
  }

  // ============================================================
  // COPY
  // ============================================================
  DetectedObject copyWith({
    int? id,
    Rect? bbox,
    String? label,
    double? confidence,
  }) {
    return DetectedObject(
      id: id ?? this.id,
      bbox: bbox ?? this.bbox,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() =>
      'DetectedObject(id: $id, label: $label, conf: ${confidence.toStringAsFixed(2)})';
}
