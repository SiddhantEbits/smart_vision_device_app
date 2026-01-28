import 'dart:ui';
import '../../models/detected_object.dart';
import '../../../core/utils/geometry_utils.dart';
import '../../../data/models/camera_config.dart';

class FootfallTracker {
  final Map<int, _TrackedPerson> _tracks = {};
  int _nextId = 0;

  // Matching and tracking parameters
  static const double _matchRadius = 0.18;
  static const int _timeoutSec = 4;

  // Velocity-based detection parameters
  static const double _minVelocity = 0.02; // Minimum velocity for crossing
  static const double _maxVelocity = 0.8;  // Maximum velocity (filter noise)
  static const double _minMovement = 0.008; // Minimum movement between frames
  static const int _minFramesForVelocity = 2; // Frames needed for velocity calc

  // Crowd handling parameters
  static const double _crowdOverlapThreshold = 0.15; // Overlap threshold for crowd detection
  static const double _crowdDensityRadius = 0.2; // Radius for crowd density calculation
  static const double _crowdVelocityMultiplier = 1.5; // Velocity multiplier in crowds 

  /// Returns number of active tracked persons
  int update({
    required List<DetectedObject> detections,
    required CameraConfig cam,
    required DateTime now,
    required void Function() onCount,
  }) {
    final used = <int>{};

    // Extract all bounding boxes for crowd analysis
    final allBoxes = detections.map((d) => d.bbox).toList();

    for (final d in detections) {
      // Use hybrid tracking point for better crowd handling
      final trackPoint = d.hybridPoint;
      int? match;

      // ---------------- MATCH EXISTING TRACK ----------------
      for (final e in _tracks.entries) {
        if (used.contains(e.key)) continue;

        if ((e.value.lastPosition - trackPoint).distance < _matchRadius) {
          match = e.key;
          used.add(match);
          break;
        }
      }

      // ---------------- NEW TRACK ----------------
      if (match == null) {
        _tracks[_nextId++] = _TrackedPerson(
          lastPosition: trackPoint,
          lastFootPosition: d.footPoint,
          lastCenterPosition: d.centerPoint,
          lastSeen: now,
        );
        continue;
      }

      final p = _tracks[match]!;

        // ---------------- HYBRID FOOTFALL DETECTION ----------------
      if (!p.counted &&
          cam.footfallEnabled &&
          cam.footfallConfig.isFootfall) {

        // Analyze crowd conditions
        final crowdDensity = GeometryUtils.getCrowdDensity(
          d.bbox,
          allBoxes,
          radius: _crowdDensityRadius,
        );
        final isInCrowd = GeometryUtils.isInCrowd(
          d.bbox,
          allBoxes,
          overlapThreshold: _crowdOverlapThreshold,
        );

        // Check foot crossing (traditional method)
        final footCrossed = _checkLineCrossing(
          prev: p.lastFootPosition,
          curr: d.footPoint,
          lineStart: cam.footfallConfig.lineStart,
          lineEnd: cam.footfallConfig.lineEnd,
          direction: cam.footfallConfig.direction,
        );

        // Check center crossing with velocity (enhanced method)
        final centerCrossed = _checkVelocityBasedCrossing(
          prev: p.lastCenterPosition,
          curr: d.centerPoint,
          lineStart: cam.footfallConfig.lineStart,
          lineEnd: cam.footfallConfig.lineEnd,
          direction: cam.footfallConfig.direction,
          person: p,
          currentTime: now,
          crowdDensity: crowdDensity,
          isInCrowd: isInCrowd,
        );

        print('[FOOTFALL] Track ID: ${match}, Foot crossed: $footCrossed, Center crossed: $centerCrossed');
        print('[FOOTFALL] Prev foot: ${p.lastFootPosition}, Curr foot: ${d.footPoint}');
        print('[FOOTFALL] Prev center: ${p.lastCenterPosition}, Curr center: ${d.centerPoint}');
        print('[FOOTFALL] Line: ${cam.footfallConfig.lineStart} -> ${cam.footfallConfig.lineEnd}');
        print('[FOOTFALL] Direction: ${cam.footfallConfig.direction}');

        // Increment footfall if EITHER method detects crossing
        if (footCrossed || centerCrossed) {
          p.counted = true;
          print('[FOOTFALL] ✅ Line crossing detected! Incrementing count.');
          onCount();
        } else {
          print('[FOOTFALL] ❌ No line crossing detected.');
        }
      }

      // ---------------- UPDATE TRACK ----------------
      p.lastPosition = trackPoint;
      p.lastFootPosition = d.footPoint;
      p.lastCenterPosition = d.centerPoint;
      p.lastSeen = now;
      p.frameCount++;
    }

    // ---------------- CLEANUP LOST PERSONS ----------------
    _tracks.removeWhere(
          (_, p) =>
      now.difference(p.lastSeen).inSeconds > _timeoutSec,
    );

    return _tracks.length;
  }

  /// Traditional line crossing check (foot-based)
  bool _checkLineCrossing({
    required Offset prev,
    required Offset curr,
    required Offset lineStart,
    required Offset lineEnd,
    required Offset direction,
  }) {
    return GeometryUtils.crossedLine(
      prev: prev,
      curr: curr,
      lineStart: lineStart,
      lineEnd: lineEnd,
      direction: direction,
      minMovement: _minMovement,
    );
  }

  /// Enhanced velocity-based crossing check (center-based)
  bool _checkVelocityBasedCrossing({
    required Offset prev,
    required Offset curr,
    required Offset lineStart,
    required Offset lineEnd,
    required Offset direction,
    required _TrackedPerson person,
    required DateTime currentTime,
    required double crowdDensity,
    required bool isInCrowd,
  }) {
    // Calculate velocity
    final movement = curr - prev;
    final timeDelta = currentTime.difference(person.lastSeen).inMilliseconds;

    if (timeDelta <= 0) return false;

    final velocity = movement.distance / (timeDelta / 1000.0); // pixels per second

    // Update velocity history
    person.velocityHistory.add(velocity);
    if (person.velocityHistory.length > 5) {
      person.velocityHistory.removeAt(0);
    }

    // Use average velocity for stability
    final avgVelocity = person.velocityHistory.reduce((a, b) => a + b) / person.velocityHistory.length;

    // Adjust velocity thresholds based on crowd conditions
    final adjustedMinVelocity = isInCrowd ? _minVelocity * 0.7 : _minVelocity; // Lower threshold in crowds
    final adjustedMaxVelocity = isInCrowd ? _maxVelocity * _crowdVelocityMultiplier : _maxVelocity; // Higher threshold in crowds

    // Filter out unrealistic velocities
    if (avgVelocity < adjustedMinVelocity || avgVelocity > adjustedMaxVelocity) {
      return false;
    }

    // Check line crossing with enhanced movement threshold
    // In crowds, require less movement due to partial visibility
    // For fast movement, require more movement to avoid false positives
    final crowdFactor = isInCrowd ? 0.8 : 1.0;
    final velocityFactor = 1.0 + (avgVelocity * 1.5); // Scale with velocity
    final enhancedMovement = _minMovement * crowdFactor * velocityFactor;

    return GeometryUtils.crossedLine(
      prev: prev,
      curr: curr,
      lineStart: lineStart,
      lineEnd: lineEnd,
      direction: direction,
      minMovement: enhancedMovement,
    );
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
  int frameCount;
  List<double> velocityHistory;

  _TrackedPerson({
    required this.lastPosition,
    required this.lastFootPosition,
    required this.lastCenterPosition,
    required this.lastSeen,
    this.counted = false,
    this.frameCount = 0,
    List<double>? velocityHistory,
  }) : velocityHistory = velocityHistory ?? [];
}
