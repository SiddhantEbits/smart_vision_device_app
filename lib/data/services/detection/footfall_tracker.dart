import 'dart:ui';
import '../../models/detected_object.dart';
import '../../../core/utils/geometry_utils.dart';

class FootfallTracker {
  final Map<int, _TrackedPerson> _tracks = {};
  int _nextId = 0;

  // Matching and tracking parameters
  static const double _matchRadius = 0.18;
  static const int _timeoutSec = 4;

  // Detection parameters
  static const double _minMovement = 0.008; 

  int processDetections({
    required List<DetectedObject> detections,
    required Offset lineStart,
    required Offset lineEnd,
    required Offset direction,
    required DateTime now,
  }) {
    int count = 0;
    final used = <int>{};

    for (final d in detections) {
      final trackPoint = d.hybridPoint;
      int? matchedId;

      // ---------------- MATCH EXISTING TRACK ----------------
      for (final e in _tracks.entries) {
        if (used.contains(e.key)) continue;

        if ((e.value.lastPosition - trackPoint).distance < _matchRadius) {
          matchedId = e.key;
          used.add(matchedId);
          break;
        }
      }

      // ---------------- NEW TRACK ----------------
      if (matchedId == null) {
        _tracks[_nextId++] = _TrackedPerson(
          lastPosition: trackPoint,
          lastFootPosition: d.footPoint,
          lastCenterPosition: d.centerPoint,
          lastSeen: now,
        );
        continue;
      }

      final p = _tracks[matchedId]!;

      // ---------------- LINE CROSSING DETECTION ----------------
      if (!p.counted) {
        // We use both foot and center crossing for higher accuracy
        final footCrossed = GeometryUtils.crossedLine(
          prev: p.lastFootPosition,
          curr: d.footPoint,
          lineStart: lineStart,
          lineEnd: lineEnd,
          direction: direction,
          minMovement: _minMovement,
        );

        final centerCrossed = GeometryUtils.crossedLine(
          prev: p.lastCenterPosition,
          curr: d.centerPoint,
          lineStart: lineStart,
          lineEnd: lineEnd,
          direction: direction,
          minMovement: _minMovement,
        );

        if (footCrossed || centerCrossed) {
          p.counted = true;
          count++;
        }
      }

      // ---------------- UPDATE TRACK ----------------
      p.lastPosition = trackPoint;
      p.lastFootPosition = d.footPoint;
      p.lastCenterPosition = d.centerPoint;
      p.lastSeen = now;
    }

    // ---------------- CLEANUP ----------------
    _tracks.removeWhere(
      (_, p) => now.difference(p.lastSeen).inSeconds > _timeoutSec,
    );

    return count;
  }

  void reset() {
    _tracks.clear();
    _nextId = 0;
  }
}

class _TrackedPerson {
  Offset lastPosition;
  Offset lastFootPosition;
  Offset lastCenterPosition;
  DateTime lastSeen;
  bool counted;

  _TrackedPerson({
    required this.lastPosition,
    required this.lastFootPosition,
    required this.lastCenterPosition,
    required this.lastSeen,
    this.counted = false,
  });
}
