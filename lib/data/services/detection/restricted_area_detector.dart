import 'dart:ui';
import '../../models/detected_object.dart';
import '../../../core/logging/logger_service.dart';

class RestrictedAreaDetector {
  // Person tracking state
  final Map<int, bool> _personInsideRestricted = {};
  final Map<int, DateTime> _lastSeenTime = {};
  
  // Stats
  int _totalViolations = 0;

  RestrictedAreaDetector();

  void reset() {
    _personInsideRestricted.clear();
    _lastSeenTime.clear();
    _totalViolations = 0;
    LoggerService.d('RestrictedAreaDetector: Reset');
  }

  /// Process detections and identify violations
  /// Returns list of detected object IDs that just entered the restricted area
  List<int> processDetections({
    required List<DetectedObject> detections,
    required Rect restrictedRoi,
  }) {
    final newViolations = <int>[];
    final now = DateTime.now();
    
    for (final detection in detections) {
      _lastSeenTime[detection.id] = now;
      
      // Use footPoint for immediate detection
      final isInside = restrictedRoi.contains(detection.footPoint);
      final wasInside = _personInsideRestricted[detection.id] ?? false;

      // Update state
      _personInsideRestricted[detection.id] = isInside;

      // Detect state flip (Entry)
      if (!wasInside && isInside) {
        newViolations.add(detection.id);
        _totalViolations++;
        LoggerService.i('Restricted area breach: Person ID ${detection.id}');
      }
    }

    _cleanupUndetectedPersons(now);
    return newViolations;
  }

  void _cleanupUndetectedPersons(DateTime now) {
    const cleanupTimeout = Duration(seconds: 5);
    final personIdsToRemove = <int>[];
    
    for (final entry in _lastSeenTime.entries) {
      if (now.difference(entry.value) > cleanupTimeout) {
        personIdsToRemove.add(entry.key);
      }
    }
    
    for (final personId in personIdsToRemove) {
      _personInsideRestricted.remove(personId);
      _lastSeenTime.remove(personId);
    }
  }

  /// IDs of people currently inside restricted area
  Set<int> getRestrictedIds() {
    return _personInsideRestricted.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
  }

  int get totalViolations => _totalViolations;
}
