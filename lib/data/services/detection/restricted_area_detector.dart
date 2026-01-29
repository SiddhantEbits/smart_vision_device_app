import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../models/detected_object.dart';
import '../../models/restriction_violation.dart';
import '../../../core/logging/logger_service.dart';

/// Different types of restricted area violations
enum RestrictionType {
  entry,          // Person enters restricted area
  exit,           // Person exits restricted area
  loitering,      // Person stays too long in restricted area
  occupancy,      // Too many people in restricted area
  proximity,      // Person gets too close to restricted zone boundary
}

/// Violation event with detailed information
class RestrictionViolation {
  final RestrictionType type;
  final int personId;
  final String personLabel;
  final double confidence;
  final DateTime timestamp;
  final Rect violationArea;
  final String description;
  final Duration? loiteringDuration; 
  final int? occupancyCount; 

  RestrictionViolation({
    required this.type,
    required this.personId,
    required this.personLabel,
    required this.confidence,
    required this.timestamp,
    required this.violationArea,
    required this.description,
    this.loiteringDuration,
    this.occupancyCount,
  });

  @override
  String toString() => 'RestrictionViolation($type: $personId at $timestamp)';
}

/// Enhanced restricted area detector with temporal stability
class RestrictedAreaDetector {
  // Person tracking state
  final Map<int, bool> _personInsideRestricted = {};
  final Map<int, DateTime> _personEntryTime = {};
  final Map<int, DateTime> _lastSeenTime = {};
  
  // Violation tracking
  final Map<int, DateTime> _lastViolationTime = {};
  final Queue<RestrictionViolation> _recentViolations = Queue();
  
  // Stats
  int _totalViolations = 0;
  final Map<RestrictionType, int> _violationCounts = {};

  RestrictedAreaDetector();

  /// Reset all tracking state
  void reset() {
    _personInsideRestricted.clear();
    _personEntryTime.clear();
    _lastSeenTime.clear();
    _lastViolationTime.clear();
    _recentViolations.clear();
    _totalViolations = 0;
    _violationCounts.clear();
    LoggerService.d('RestrictedAreaDetector: Reset');
  }

  /// Process detections and identify violations
  List<RestrictionViolation> processDetections({
    required List<DetectedObject> detections,
    required Rect restrictedRoi,
  }) {
    final violations = <RestrictionViolation>[];
    final now = DateTime.now();
    
    LoggerService.i('RestrictedAreaDetector: Processing ${detections.length} detections');
    LoggerService.i('RestrictedAreaDetector: ROI: $restrictedRoi');
    
    _cleanupOldViolations(now);
    
    // Get current detection IDs for real-time tracking
    final currentDetectionIds = detections.map((d) => d.id).toSet();
    
    // Immediately remove people who are no longer detected (real-time cleanup)
    final idsToRemove = _personInsideRestricted.keys.where((id) => !currentDetectionIds.contains(id)).toList();
    for (final id in idsToRemove) {
      LoggerService.i('RestrictedAreaDetector: Removing undetected person $id from restricted tracking');
      _personInsideRestricted.remove(id);
      _personEntryTime.remove(id);
      _lastSeenTime.remove(id);
      _lastViolationTime.remove(id);
    }
    
    for (final detection in detections) {
      _lastSeenTime[detection.id] = now;
      
      // Use footPoint for immediate "touch" detection as feet enter first
      final isInside = restrictedRoi.contains(detection.footPoint);
      final wasInside = _personInsideRestricted[detection.id] ?? false;
      
      LoggerService.i('RestrictedAreaDetector: Person ${detection.id} - Inside: $isInside, Was Inside: $wasInside, Foot Point: ${detection.footPoint}');

      // Update state immediately for instant Red Box feedback
      _personInsideRestricted[detection.id] = isInside;

      // 1. ENTRY VIOLATION (Triggered on the scan where state flips to inside)
      if (!wasInside && isInside) {
        _personEntryTime[detection.id] = now;
        violations.add(_createViolation(
          type: RestrictionType.entry,
          detection: detection,
          timestamp: now,
          violationArea: restrictedRoi,
          description: 'Restricted area breach detected',
        ));
        LoggerService.i('RestrictedAreaDetector: ENTRY VIOLATION for person ${detection.id}');
      }

      if (!isInside) {
        _personEntryTime.remove(detection.id);
      }
    }
    
    final currentInside = getRestrictedIds();
    LoggerService.i('RestrictedAreaDetector: Currently inside: ${currentInside.length} people - IDs: $currentInside');

    _cleanupUndetectedPersons(now);

    for (final violation in violations) {
      _totalViolations++;
      _violationCounts[violation.type] = (_violationCounts[violation.type] ?? 0) + 1;
    }

    return violations;
  }

  bool _shouldTriggerViolation(int personId, RestrictionType type, DateTime now, int cooldownSec) {
    final lastViolation = _lastViolationTime[personId];
    return lastViolation == null ||
        now.difference(lastViolation).inSeconds >= cooldownSec;
  }

  RestrictionViolation _createViolation({
    required RestrictionType type,
    required DetectedObject detection,
    required DateTime timestamp,
    required Rect violationArea,
    required String description,
    Duration? loiteringDuration,
    int? occupancyCount,
  }) {
    final violation = RestrictionViolation(
      type: type,
      personId: detection.id,
      personLabel: detection.label,
      confidence: detection.confidence,
      timestamp: timestamp,
      violationArea: violationArea,
      description: description,
      loiteringDuration: loiteringDuration,
      occupancyCount: occupancyCount,
    );
    _recentViolations.add(violation);
    return violation;
  }

  void _cleanupOldViolations(DateTime now) {
    const maxAge = Duration(hours: 1);
    _recentViolations.removeWhere((v) => now.difference(v.timestamp) > maxAge);
    while (_recentViolations.length > 100) {
      _recentViolations.removeFirst();
    }
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
      _personEntryTime.remove(personId);
      _lastSeenTime.remove(personId);
      _lastViolationTime.remove(personId);
    }
  }

  /// IDs of people currently inside restricted area (Immediate state)
  Set<int> getRestrictedIds() {
    return _personInsideRestricted.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
  }

  /// Alias for compatibility: returns immediate inside state
  Set<int> getRawInsideIds() => getRestrictedIds();

  /// Get recent violations for debugging/alerting
  List<RestrictionViolation> getRecentViolations() {
    return _recentViolations.toList();
  }

  Map<String, dynamic> getStatistics() {
    return {
      'totalViolations': _totalViolations,
      'currentOccupancy': getRestrictedIds().length,
      'recentViolations': _recentViolations.length,
      'violationCounts': _violationCounts,
    };
  }

  int get totalViolations => _totalViolations;
}
