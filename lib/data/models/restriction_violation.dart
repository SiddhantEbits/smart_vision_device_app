import 'dart:ui';

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
