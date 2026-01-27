import 'dart:ui';

class GeometryUtils {
  GeometryUtils._();

  /// Calculate overlap between two bounding boxes (0-1, where 1 is full overlap)
  static double calculateOverlap(Rect box1, Rect box2) {
    final intersection = box1.intersect(box2);
    if (intersection.isEmpty) return 0.0;

    final intersectionArea = intersection.width * intersection.height;
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;

    // Use the area of the smaller box as the denominator for consistent results
    return intersectionArea / (box1Area < box2Area ? box1Area : box2Area);
  }

  /// Check if a person is in a crowded area (overlapping with others)
  static bool isInCrowd(Rect personBox, List<Rect> allBoxes,
      {double overlapThreshold = 0.15}) {
    for (final otherBox in allBoxes) {
      if (personBox == otherBox) continue;
      if (calculateOverlap(personBox, otherBox) > overlapThreshold) {
        return true;
      }
    }
    return false;
  }

  /// Get crowd density around a person (0-1, where 1 is very crowded)
  static double getCrowdDensity(Rect personBox, List<Rect> allBoxes,
      {double radius = 0.2}) {
    final personCenter = personBox.center;
    int nearbyCount = 0;

    for (final box in allBoxes) {
      if (box == personBox) continue;
      final distance = (box.center - personCenter).distance;
      if (distance <= radius) {
        nearbyCount++;
      }
    }

    // Normalize to 0-1 range (assuming max 5 nearby people is very crowded)
    return (nearbyCount / 5.0).clamp(0.0, 1.0);
  }

  /// Check if a moving point crossed a line in a given direction
  static bool crossedLine({
    required Offset prev,
    required Offset curr,
    required Offset lineStart,
    required Offset lineEnd,
    required Offset direction,
    double minMovement = 0.005,
  }) {
    final movement = curr - prev;

    // Ignore jitter
    if (movement.distance < minMovement) return false;

    // Side-of-line sign flip detection
    final s1 = _side(prev, lineStart, lineEnd);
    final s2 = _side(curr, lineStart, lineEnd);

    // If both points are on the same side, it didn't cross
    if (s1 * s2 >= 0) return false;

    // Direction check using dot product
    final dir = _normalize(direction);
    final dot = movement.dx * dir.dx + movement.dy * dir.dy;

    return dot > 0;
  }

  /// Internal helper to determine which side of a line a point is on
  static double _side(Offset p, Offset a, Offset b) {
    return (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
  }

  /// Internal helper to normalize an offset/vector
  static Offset _normalize(Offset v) {
    final len = v.distance;
    if (len < 1e-6) return const Offset(1, 0);
    return v / len;
  }
}
