import 'dart:ui';
import '../../data/models/detected_object.dart';
import '../constants/app_constants.dart';

class DetectionProcessor {
  int _nextId = 0;

  void reset() {
    _nextId = 0;
  }

  List<DetectedObject> process({
    required List boxes,
    required double confidenceThreshold,
  }) {
    final detections = <DetectedObject>[];

    for (final b in boxes) {
      final m = b as Map<String, dynamic>;

      // Only process required class (person)
      if (m["className"] != AppConstants.defaultDetectClass) {
        continue;
      }

      final conf = (m["confidence"] as num).toDouble();
      if (conf < confidenceThreshold) {
        continue;
      }

      // Extract normalized coordinates from YOLO output
      final bbox = Rect.fromLTRB(
        (m["x1_norm"] as num).toDouble(),
        (m["y1_norm"] as num).toDouble(),
        (m["x2_norm"] as num).toDouble(),
        (m["y2_norm"] as num).toDouble(),
      );

      detections.add(
        DetectedObject(
          id: _nextId++,
          bbox: bbox,
          label: (m["className"] as String? ?? AppConstants.defaultDetectClass),
          confidence: conf,
        ),
      );
    }

    return detections;
  }
}
