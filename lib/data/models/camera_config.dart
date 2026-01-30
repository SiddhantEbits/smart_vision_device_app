import 'dart:ui';
import 'package:flutter/material.dart';
import 'alert_config_model.dart';
import 'roi_config.dart';

/// ===========================================================
/// CAMERA CONFIG
/// ===========================================================
class CameraConfig {
  final String name;
  final String url;

  /// ================= FEATURES =================
  final bool peopleCountEnabled;

  /// ================= FOOTFALL =================
  final bool footfallEnabled;
  final RoiAlertConfig footfallConfig;
  final AlertSchedule? footfallSchedule;
  final int footfallIntervalMinutes;

  /// ================= MAX PEOPLE ALERT =================
  final bool maxPeopleEnabled;
  final int maxPeople;
  final int maxPeopleCooldownSeconds;
  final AlertSchedule? maxPeopleSchedule;

  /// ================= ABSENT ALERT =================
  final bool absentAlertEnabled;
  final int absentSeconds;
  final int absentCooldownSeconds;
  final AlertSchedule? absentSchedule;

  /// ================= THEFT ALERT =================
  final bool theftAlertEnabled;
  final int theftCooldownSeconds;
  final AlertSchedule? theftSchedule;

  /// ================= RESTRICTED AREA =================
  final bool restrictedAreaEnabled;
  final RoiAlertConfig restrictedAreaConfig;
  final int restrictedAreaCooldownSeconds;
  final AlertSchedule? restrictedAreaSchedule;

  /// ================= YOLO =================
  final double confidenceThreshold;

  CameraConfig({
    required this.name,
    required this.url,

    // Independent features
    this.peopleCountEnabled = true,

    // Footfall
    this.footfallEnabled = false,
    RoiAlertConfig? footfallConfig,
    this.footfallSchedule,
    this.footfallIntervalMinutes = 60,

    // Max people
    this.maxPeopleEnabled = false,
    this.maxPeople = 5,
    this.maxPeopleCooldownSeconds = 300,
    this.maxPeopleSchedule,

    // Absent
    this.absentAlertEnabled = false,
    this.absentSeconds = 60,
    this.absentCooldownSeconds = 600,
    this.absentSchedule,

    // Theft
    this.theftAlertEnabled = false,
    this.theftCooldownSeconds = 300,
    this.theftSchedule,

    // Restricted Area
    this.restrictedAreaEnabled = true,
    RoiAlertConfig? restrictedAreaConfig,
    this.restrictedAreaCooldownSeconds = 300,
    this.restrictedAreaSchedule,

    // YOLO
    this.confidenceThreshold = 0.15,
  })  : footfallConfig =
      footfallConfig ?? RoiAlertConfig.defaultConfig(),
        restrictedAreaConfig =
            restrictedAreaConfig ??
                RoiAlertConfig.forRestrictedArea(
                  roi: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
                );

  // ============================================================
  // SOURCE OF TRUTH
  // ============================================================
  bool get isDetectionEnabled =>
      peopleCountEnabled ||
          footfallEnabled ||
          maxPeopleEnabled ||
          absentAlertEnabled ||
          theftAlertEnabled ||
          restrictedAreaEnabled;

  // ============================================================
  // JSON
  // ============================================================
  factory CameraConfig.fromJson(Map<String, dynamic> json) {
    return CameraConfig(
      name: json['name'] ?? "Camera",
      url: json['url'],

      peopleCountEnabled: json['peopleCountEnabled'] ?? true,

      // Footfall
      footfallEnabled: json['footfallEnabled'] ?? false,
      footfallConfig: json['footfallConfig'] != null
          ? _roiFromJson(json['footfallConfig'])
          : RoiAlertConfig.defaultConfig(),
      footfallSchedule: json['footfallSchedule'] != null
          ? AlertSchedule.fromMap(json['footfallSchedule'])
          : null,
      footfallIntervalMinutes:
      (json['footfallIntervalMinutes'] as num?)?.toInt() ?? 60,

      // Max people
      maxPeopleEnabled: json['maxPeopleEnabled'] ?? false,
      maxPeople: (json['maxPeople'] as num?)?.toInt() ?? 5,
      maxPeopleCooldownSeconds:
      (json['maxPeopleCooldownSeconds'] as num?)?.toInt() ?? 300,
      maxPeopleSchedule: json['maxPeopleSchedule'] != null
          ? AlertSchedule.fromMap(json['maxPeopleSchedule'])
          : null,

      // Absent
      absentAlertEnabled: json['absentAlertEnabled'] ?? false,
      absentSeconds:
      (json['absentSeconds'] as num?)?.toInt() ?? 60,
      absentCooldownSeconds:
      (json['absentCooldownSeconds'] as num?)?.toInt() ?? 600,
      absentSchedule: json['absentSchedule'] != null
          ? AlertSchedule.fromMap(json['absentSchedule'])
          : null,

      // Theft
      theftAlertEnabled: json['theftAlertEnabled'] ?? false,
      theftCooldownSeconds:
      (json['theftCooldownSeconds'] as num?)?.toInt() ?? 300,
      theftSchedule: json['theftSchedule'] != null
          ? AlertSchedule.fromMap(json['theftSchedule'])
          : null,

      // Restricted Area
      restrictedAreaEnabled:
      json['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig:
      json['restrictedAreaConfig'] != null
          ? _roiFromJson(json['restrictedAreaConfig'])
          : RoiAlertConfig.forRestrictedArea(
        roi: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
      ),
      restrictedAreaCooldownSeconds:
      (json['restrictedAreaCooldownSeconds'] as num?)?.toInt() ?? 300,
      restrictedAreaSchedule:
      json['restrictedAreaSchedule'] != null
          ? AlertSchedule.fromMap(
        json['restrictedAreaSchedule'],
      )
          : null,

      // YOLO
      confidenceThreshold:
      (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.15,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'peopleCountEnabled': peopleCountEnabled,

    // Footfall
    'footfallEnabled': footfallEnabled,
    'footfallConfig': _roiToJson(footfallConfig),
    if (footfallSchedule != null)
      'footfallSchedule': footfallSchedule!.toJson(),
    'footfallIntervalMinutes': footfallIntervalMinutes,

    // Max people
    'maxPeopleEnabled': maxPeopleEnabled,
    'maxPeople': maxPeople,
    'maxPeopleCooldownSeconds': maxPeopleCooldownSeconds,
    if (maxPeopleSchedule != null)
      'maxPeopleSchedule': maxPeopleSchedule!.toJson(),

    // Absent
    'absentAlertEnabled': absentAlertEnabled,
    'absentSeconds': absentSeconds,
    'absentCooldownSeconds': absentCooldownSeconds,
    if (absentSchedule != null)
      'absentSchedule': absentSchedule!.toJson(),

    // Theft
    'theftAlertEnabled': theftAlertEnabled,
    'theftCooldownSeconds': theftCooldownSeconds,
    if (theftSchedule != null)
      'theftSchedule': theftSchedule!.toJson(),

    // Restricted Area
    'restrictedAreaEnabled': restrictedAreaEnabled,
    'restrictedAreaConfig': _roiToJson(restrictedAreaConfig),
    'restrictedAreaCooldownSeconds':
    restrictedAreaCooldownSeconds,
    if (restrictedAreaSchedule != null)
      'restrictedAreaSchedule':
      restrictedAreaSchedule!.toJson(),

    // YOLO
    'confidenceThreshold': confidenceThreshold,
  };

  // ============================================================
  // COPY WITH
  // ============================================================
  CameraConfig copyWith({
    String? name,
    String? url,
    bool? peopleCountEnabled,

    bool? footfallEnabled,
    RoiAlertConfig? footfallConfig,
    AlertSchedule? footfallSchedule,
    int? footfallIntervalMinutes,

    bool? maxPeopleEnabled,
    int? maxPeople,
    int? maxPeopleCooldownSeconds,
    AlertSchedule? maxPeopleSchedule,

    bool? absentAlertEnabled,
    int? absentSeconds,
    int? absentCooldownSeconds,
    AlertSchedule? absentSchedule,

    bool? theftAlertEnabled,
    int? theftCooldownSeconds,
    AlertSchedule? theftSchedule,

    bool? restrictedAreaEnabled,
    RoiAlertConfig? restrictedAreaConfig,
    int? restrictedAreaCooldownSeconds,
    AlertSchedule? restrictedAreaSchedule,

    double? confidenceThreshold,
  }) {
    return CameraConfig(
      name: name ?? this.name,
      url: url ?? this.url,

      peopleCountEnabled:
      peopleCountEnabled ?? this.peopleCountEnabled,

      footfallEnabled: footfallEnabled ?? this.footfallEnabled,
      footfallConfig: footfallConfig ?? this.footfallConfig,
      footfallSchedule:
      footfallSchedule ?? this.footfallSchedule,
      footfallIntervalMinutes:
      footfallIntervalMinutes ??
          this.footfallIntervalMinutes,

      maxPeopleEnabled:
      maxPeopleEnabled ?? this.maxPeopleEnabled,
      maxPeople: maxPeople ?? this.maxPeople,
      maxPeopleCooldownSeconds:
      maxPeopleCooldownSeconds ??
          this.maxPeopleCooldownSeconds,
      maxPeopleSchedule:
      maxPeopleSchedule ?? this.maxPeopleSchedule,

      absentAlertEnabled:
      absentAlertEnabled ?? this.absentAlertEnabled,
      absentSeconds: absentSeconds ?? this.absentSeconds,
      absentCooldownSeconds:
      absentCooldownSeconds ??
          this.absentCooldownSeconds,
      absentSchedule: absentSchedule ?? this.absentSchedule,

      theftAlertEnabled:
      theftAlertEnabled ?? this.theftAlertEnabled,
      theftCooldownSeconds:
      theftCooldownSeconds ?? this.theftCooldownSeconds,
      theftSchedule: theftSchedule ?? this.theftSchedule,

      restrictedAreaEnabled:
      restrictedAreaEnabled ?? this.restrictedAreaEnabled,
      restrictedAreaConfig:
      restrictedAreaConfig ??
          this.restrictedAreaConfig,
      restrictedAreaCooldownSeconds:
      restrictedAreaCooldownSeconds ??
          this.restrictedAreaCooldownSeconds,
      restrictedAreaSchedule:
      restrictedAreaSchedule ??
          this.restrictedAreaSchedule,

      confidenceThreshold:
      confidenceThreshold ?? this.confidenceThreshold,
    );
  }

  // ============================================================
  // ROI JSON HELPERS
  // ============================================================
  static RoiAlertConfig _roiFromJson(
      Map<String, dynamic> json) {
    return RoiAlertConfig(
      roi: Rect.fromLTRB(
        (json['roi']['l'] as num).toDouble(),
        (json['roi']['t'] as num).toDouble(),
        (json['roi']['r'] as num).toDouble(),
        (json['roi']['b'] as num).toDouble(),
      ),
      lineStart: Offset(
        (json['lineStart']['x'] as num).toDouble(),
        (json['lineStart']['y'] as num).toDouble(),
      ),
      lineEnd: Offset(
        (json['lineEnd']['x'] as num).toDouble(),
        (json['lineEnd']['y'] as num).toDouble(),
      ),
      direction: Offset(
        (json['direction']['x'] as num).toDouble(),
        (json['direction']['y'] as num).toDouble(),
      ),
    );
  }

  static Map<String, dynamic> _roiToJson(RoiAlertConfig c) {
    return {
      // Local storage format (backward compatibility)
      'roi': {
        'l': c.roi.left,
        't': c.roi.top,
        'r': c.roi.right,
        'b': c.roi.bottom,
      },
      'lineStart': {'x': c.lineStart.dx, 'y': c.lineStart.dy},
      'lineEnd': {'x': c.lineEnd.dx, 'y': c.lineEnd.dy},
      'direction': {
        'x': c.direction.dx,
        'y': c.direction.dy,
      },
      // Firebase format
      'firebaseFormat': c.toFirebaseMap(),
    };
  }

  // ============================================================
  // FIRESTORE CONVERSION HELPERS
  // ============================================================
  
  /// Convert footfall config to AlgorithmConfig for Firebase
  static Map<String, dynamic> footfallToAlgorithmConfig(CameraConfig camera) {
    return {
      'enabled': camera.footfallEnabled,
      'threshold': camera.confidenceThreshold,
      'alertInterval': camera.footfallIntervalMinutes * 60, // Convert to seconds
      'cooldownSeconds': 300, // Default cooldown
      'appNotification': true,
      'wpNotification': false,
      'schedule': _alertScheduleToMap(camera.footfallSchedule),
      // ROI Configuration
      'roiConfig': camera.footfallConfig.toFirebaseMap(),
      'roiCoordinates': [
        camera.footfallConfig.roi.left,
        camera.footfallConfig.roi.top,
        camera.footfallConfig.roi.right,
        camera.footfallConfig.roi.bottom,
      ],
      'lineCoordinates': [
        camera.footfallConfig.lineStart.dx,
        camera.footfallConfig.lineStart.dy,
        camera.footfallConfig.lineEnd.dx,
        camera.footfallConfig.lineEnd.dy,
      ],
      'roiType': 'line',
    };
  }
  
  /// Convert restricted area config to AlgorithmConfig for Firebase
  static Map<String, dynamic> restrictedAreaToAlgorithmConfig(CameraConfig camera) {
    return {
      'enabled': camera.restrictedAreaEnabled,
      'threshold': camera.confidenceThreshold,
      'cooldownSeconds': camera.restrictedAreaCooldownSeconds,
      'appNotification': true,
      'wpNotification': false,
      'schedule': _alertScheduleToMap(camera.restrictedAreaSchedule),
      // ROI Configuration
      'roiConfig': camera.restrictedAreaConfig.toFirebaseMap(),
      'roiCoordinates': [
        camera.restrictedAreaConfig.roi.left,
        camera.restrictedAreaConfig.roi.top,
        camera.restrictedAreaConfig.roi.right,
        camera.restrictedAreaConfig.roi.bottom,
      ],
      'lineCoordinates': [
        camera.restrictedAreaConfig.lineStart.dx,
        camera.restrictedAreaConfig.lineStart.dy,
        camera.restrictedAreaConfig.lineEnd.dx,
        camera.restrictedAreaConfig.lineEnd.dy,
      ],
      'roiType': 'rectangle',
    };
  }
  
  /// Convert AlertSchedule to Firebase format
  static Map<String, dynamic> _alertScheduleToMap(AlertSchedule? schedule) {
    if (schedule == null) {
      return {
        'enabled': false,
        'activeDays': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
        'startMinute': 0,
        'endMinute': 1439,
      };
    }
    
    // Parse time strings to get minutes since midnight
    final startParts = schedule.startTime.split(':');
    final endParts = schedule.endTime.split(':');
    final startMinute = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinute = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    
    return {
      'enabled': true,
      'activeDays': schedule.days.map((day) {
        switch (day) {
          case 1: return 'MON';
          case 2: return 'TUE';
          case 3: return 'WED';
          case 4: return 'THU';
          case 5: return 'FRI';
          case 6: return 'SAT';
          case 7: return 'SUN';
          default: return 'MON';
        }
      }).toList(),
      'startMinute': startMinute,
      'endMinute': endMinute,
    };
  }

  @override
  String toString() {
    return 'CameraConfig(name: $name, url: $url, confidenceThreshold: $confidenceThreshold)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraConfig &&
        other.name == name &&
        other.url == url &&
        other.confidenceThreshold == confidenceThreshold;
  }

  @override
  int get hashCode {
    return name.hashCode ^ url.hashCode ^ confidenceThreshold.hashCode;
  }
}
