import 'package:flutter/material.dart';

enum DetectionType {
  crowdDetection,
  absentAlert,
  footfallDetection,
  restrictedArea,
  sensitiveAlert
}

class AlertSchedule {
  final String startTime;
  final String endTime;
  final List<int> days; // 1-7 (Monday-Sunday)

  AlertSchedule({
    required this.startTime,
    required this.endTime,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
    'days': days,
  };
}

class AlertConfig {
  final DetectionType type;
  bool isEnabled;
  double threshold;
  int cooldown; // in seconds
  AlertSchedule schedule;
  
  // Specific configs
  int? maxCapacity; // Crowd
  int? interval; // Absent / Footfall
  List<Offset>? roiPoints; // Restricted / Footfall
  String? roiType; // 'box' or 'line'

  AlertConfig({
    required this.type,
    this.isEnabled = true,
    this.threshold = 0.5,
    this.cooldown = 30,
    required this.schedule,
    this.maxCapacity,
    this.interval,
    this.roiPoints,
    this.roiType,
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'isEnabled': isEnabled,
    'threshold': threshold,
    'cooldown': cooldown,
    'schedule': schedule.toJson(),
    'maxCapacity': maxCapacity,
    'interval': interval,
    'roiType': roiType,
    // ROI points would need proper serialization
  };
}
