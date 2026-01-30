import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'camera_config.dart';
import 'alert_config_model.dart' hide AlertSchedule;
import 'alert_config_model.dart' as alert_model show AlertSchedule;
import 'roi_config.dart';
import 'firestore_models.dart';

/// ===========================================================
/// FIRESTORE-SYNCHRONIZED CAMERA CONFIG
/// ===========================================================
class FirestoreCameraConfig {
  final String id;
  final String deviceId;
  final String name;
  final String url;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  /// ================= FEATURES =================
  final bool peopleCountEnabled;

  /// ================= FOOTFALL =================
  final bool footfallEnabled;
  final RoiAlertConfig footfallConfig;
  final alert_model.AlertSchedule? footfallSchedule;
  final int footfallIntervalMinutes;

  /// ================= MAX PEOPLE ALERT =================
  final bool maxPeopleEnabled;
  final int maxPeople;
  final int maxPeopleCooldownSeconds;
  final alert_model.AlertSchedule? maxPeopleSchedule;

  /// ================= ABSENT ALERT =================
  final bool absentAlertEnabled;
  final int absentSeconds;
  final int absentCooldownSeconds;
  final alert_model.AlertSchedule? absentSchedule;

  /// ================= THEFT ALERT =================
  final bool theftAlertEnabled;
  final int theftCooldownSeconds;
  final alert_model.AlertSchedule? theftSchedule;

  /// ================= RESTRICTED AREA =================
  final bool restrictedAreaEnabled;
  final RoiAlertConfig restrictedAreaConfig;
  final int restrictedAreaCooldownSeconds;
  final alert_model.AlertSchedule? restrictedAreaSchedule;

  /// ================= YOLO =================
  final double confidenceThreshold;

  const FirestoreCameraConfig({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
    required this.version,

    // Features
    this.peopleCountEnabled = true,

    // Footfall
    this.footfallEnabled = false,
    required this.footfallConfig,
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
    required this.restrictedAreaConfig,
    this.restrictedAreaCooldownSeconds = 300,
    this.restrictedAreaSchedule,

    // YOLO
    this.confidenceThreshold = 0.15,
  });

  /// ===========================================================
  /// FROM CAMERA CONFIG (for local to Firestore conversion)
  /// ===========================================================
  factory FirestoreCameraConfig.fromCameraConfig(
    CameraConfig config, {
    required String deviceId,
    String? id,
  }) {
    final now = DateTime.now();
    return FirestoreCameraConfig(
      id: id ?? _generateId(),
      deviceId: deviceId,
      name: config.name,
      url: config.url,
      createdAt: now,
      updatedAt: now,
      version: 1,

      // Features
      peopleCountEnabled: config.peopleCountEnabled,

      // Footfall
      footfallEnabled: config.footfallEnabled,
      footfallConfig: config.footfallConfig,
      footfallSchedule: config.footfallSchedule,
      footfallIntervalMinutes: config.footfallIntervalMinutes,

      // Max people
      maxPeopleEnabled: config.maxPeopleEnabled,
      maxPeople: config.maxPeople,
      maxPeopleCooldownSeconds: config.maxPeopleCooldownSeconds,
      maxPeopleSchedule: config.maxPeopleSchedule,

      // Absent
      absentAlertEnabled: config.absentAlertEnabled,
      absentSeconds: config.absentSeconds,
      absentCooldownSeconds: config.absentCooldownSeconds,
      absentSchedule: config.absentSchedule,

      // Theft
      theftAlertEnabled: config.theftAlertEnabled,
      theftCooldownSeconds: config.theftCooldownSeconds,
      theftSchedule: config.theftSchedule,

      // Restricted Area
      restrictedAreaEnabled: config.restrictedAreaEnabled,
      restrictedAreaConfig: config.restrictedAreaConfig,
      restrictedAreaCooldownSeconds: config.restrictedAreaCooldownSeconds,
      restrictedAreaSchedule: config.restrictedAreaSchedule,

      // YOLO
      confidenceThreshold: config.confidenceThreshold,
    );
  }

  /// ===========================================================
  /// TO CAMERA CONFIG (for Firestore to local conversion)
  /// ===========================================================
  CameraConfig toCameraConfig() {
    return CameraConfig(
      name: name,
      url: url,

      // Features
      peopleCountEnabled: peopleCountEnabled,

      // Footfall
      footfallEnabled: footfallEnabled,
      footfallConfig: footfallConfig,
      footfallSchedule: footfallSchedule,
      footfallIntervalMinutes: footfallIntervalMinutes,

      // Max people
      maxPeopleEnabled: maxPeopleEnabled,
      maxPeople: maxPeople,
      maxPeopleCooldownSeconds: maxPeopleCooldownSeconds,
      maxPeopleSchedule: maxPeopleSchedule,

      // Absent
      absentAlertEnabled: absentAlertEnabled,
      absentSeconds: absentSeconds,
      absentCooldownSeconds: absentCooldownSeconds,
      absentSchedule: absentSchedule,

      // Theft
      theftAlertEnabled: theftAlertEnabled,
      theftCooldownSeconds: theftCooldownSeconds,
      theftSchedule: theftSchedule,

      // Restricted Area
      restrictedAreaEnabled: restrictedAreaEnabled,
      restrictedAreaConfig: restrictedAreaConfig,
      restrictedAreaCooldownSeconds: restrictedAreaCooldownSeconds,
      restrictedAreaSchedule: restrictedAreaSchedule,

      // YOLO
      confidenceThreshold: confidenceThreshold,
    );
  }

  /// ===========================================================
  /// COPY WITH VERSION INCREMENT
  /// ===========================================================
  FirestoreCameraConfig copyWithVersionIncrement({
    String? name,
    String? url,
    bool? peopleCountEnabled,

    bool? footfallEnabled,
    RoiAlertConfig? footfallConfig,
    alert_model.AlertSchedule? footfallSchedule,
    int? footfallIntervalMinutes,

    bool? maxPeopleEnabled,
    int? maxPeople,
    int? maxPeopleCooldownSeconds,
    alert_model.AlertSchedule? maxPeopleSchedule,

    bool? absentAlertEnabled,
    int? absentSeconds,
    int? absentCooldownSeconds,
    alert_model.AlertSchedule? absentSchedule,

    bool? theftAlertEnabled,
    int? theftCooldownSeconds,
    alert_model.AlertSchedule? theftSchedule,

    bool? restrictedAreaEnabled,
    RoiAlertConfig? restrictedAreaConfig,
    int? restrictedAreaCooldownSeconds,
    alert_model.AlertSchedule? restrictedAreaSchedule,

    double? confidenceThreshold,
  }) {
    return FirestoreCameraConfig(
      id: id,
      deviceId: deviceId,
      name: name ?? this.name,
      url: url ?? this.url,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      version: version + 1,

      // Features
      peopleCountEnabled: peopleCountEnabled ?? this.peopleCountEnabled,

      // Footfall
      footfallEnabled: footfallEnabled ?? this.footfallEnabled,
      footfallConfig: footfallConfig ?? this.footfallConfig,
      footfallSchedule: footfallSchedule ?? this.footfallSchedule,
      footfallIntervalMinutes: footfallIntervalMinutes ?? this.footfallIntervalMinutes,

      // Max people
      maxPeopleEnabled: maxPeopleEnabled ?? this.maxPeopleEnabled,
      maxPeople: maxPeople ?? this.maxPeople,
      maxPeopleCooldownSeconds: maxPeopleCooldownSeconds ?? this.maxPeopleCooldownSeconds,
      maxPeopleSchedule: maxPeopleSchedule ?? this.maxPeopleSchedule,

      // Absent
      absentAlertEnabled: absentAlertEnabled ?? this.absentAlertEnabled,
      absentSeconds: absentSeconds ?? this.absentSeconds,
      absentCooldownSeconds: absentCooldownSeconds ?? this.absentCooldownSeconds,
      absentSchedule: absentSchedule ?? this.absentSchedule,

      // Theft
      theftAlertEnabled: theftAlertEnabled ?? this.theftAlertEnabled,
      theftCooldownSeconds: theftCooldownSeconds ?? this.theftCooldownSeconds,
      theftSchedule: theftSchedule ?? this.theftSchedule,

      // Restricted Area
      restrictedAreaEnabled: restrictedAreaEnabled ?? this.restrictedAreaEnabled,
      restrictedAreaConfig: restrictedAreaConfig ?? this.restrictedAreaConfig,
      restrictedAreaCooldownSeconds: restrictedAreaCooldownSeconds ?? this.restrictedAreaCooldownSeconds,
      restrictedAreaSchedule: restrictedAreaSchedule ?? this.restrictedAreaSchedule,

      // YOLO
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
    );
  }

  /// ===========================================================
  /// FIRESTORE SERIALIZATION
  /// ===========================================================
  factory FirestoreCameraConfig.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreCameraConfig(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      version: data['version'] ?? 1,

      // Features
      peopleCountEnabled: data['peopleCountEnabled'] ?? true,

      // Footfall
      footfallEnabled: data['footfallEnabled'] ?? false,
      footfallConfig: _roiFromFirestore(data['footfallConfig']),
      footfallSchedule: data['footfallSchedule'] != null
          ? _scheduleFromFirestore(data['footfallSchedule'])
          : null,
      footfallIntervalMinutes: data['footfallIntervalMinutes'] ?? 60,

      // Max people
      maxPeopleEnabled: data['maxPeopleEnabled'] ?? false,
      maxPeople: data['maxPeople'] ?? 5,
      maxPeopleCooldownSeconds: data['maxPeopleCooldownSeconds'] ?? 300,
      maxPeopleSchedule: data['maxPeopleSchedule'] != null
          ? _scheduleFromFirestore(data['maxPeopleSchedule'])
          : null,

      // Absent
      absentAlertEnabled: data['absentAlertEnabled'] ?? false,
      absentSeconds: data['absentSeconds'] ?? 60,
      absentCooldownSeconds: data['absentCooldownSeconds'] ?? 600,
      absentSchedule: data['absentSchedule'] != null
          ? _scheduleFromFirestore(data['absentSchedule'])
          : null,

      // Theft
      theftAlertEnabled: data['theftAlertEnabled'] ?? false,
      theftCooldownSeconds: data['theftCooldownSeconds'] ?? 300,
      theftSchedule: data['theftSchedule'] != null
          ? _scheduleFromFirestore(data['theftSchedule'])
          : null,

      // Restricted Area
      restrictedAreaEnabled: data['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig: _roiFromFirestore(data['restrictedAreaConfig']),
      restrictedAreaCooldownSeconds: data['restrictedAreaCooldownSeconds'] ?? 300,
      restrictedAreaSchedule: data['restrictedAreaSchedule'] != null
          ? _scheduleFromFirestore(data['restrictedAreaSchedule'])
          : null,

      // YOLO
      confidenceThreshold: (data['confidenceThreshold'] as num?)?.toDouble() ?? 0.15,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'name': name,
      'url': url,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'version': version,

      // Features
      'peopleCountEnabled': peopleCountEnabled,

      // Footfall
      'footfallEnabled': footfallEnabled,
      'footfallConfig': _roiToFirestore(footfallConfig),
      if (footfallSchedule != null)
        'footfallSchedule': _scheduleToFirestore(footfallSchedule!),
      'footfallIntervalMinutes': footfallIntervalMinutes,

      // Max people
      'maxPeopleEnabled': maxPeopleEnabled,
      'maxPeople': maxPeople,
      'maxPeopleCooldownSeconds': maxPeopleCooldownSeconds,
      if (maxPeopleSchedule != null)
        'maxPeopleSchedule': _scheduleToFirestore(maxPeopleSchedule!),

      // Absent
      'absentAlertEnabled': absentAlertEnabled,
      'absentSeconds': absentSeconds,
      'absentCooldownSeconds': absentCooldownSeconds,
      if (absentSchedule != null)
        'absentSchedule': _scheduleToFirestore(absentSchedule!),

      // Theft
      'theftAlertEnabled': theftAlertEnabled,
      'theftCooldownSeconds': theftCooldownSeconds,
      if (theftSchedule != null)
        'theftSchedule': _scheduleToFirestore(theftSchedule!),

      // Restricted Area
      'restrictedAreaEnabled': restrictedAreaEnabled,
      'restrictedAreaConfig': _roiToFirestore(restrictedAreaConfig),
      'restrictedAreaCooldownSeconds': restrictedAreaCooldownSeconds,
      if (restrictedAreaSchedule != null)
        'restrictedAreaSchedule': _scheduleToFirestore(restrictedAreaSchedule!),

      // YOLO
      'confidenceThreshold': confidenceThreshold,
    };
  }

  /// ===========================================================
  /// FIRESTORE HELPERS
  /// ===========================================================
  static RoiAlertConfig _roiFromFirestore(Map<String, dynamic> json) {
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

  static Map<String, dynamic> _roiToFirestore(RoiAlertConfig c) {
    return {
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
    };
  }

  static alert_model.AlertSchedule _scheduleFromFirestore(Map<String, dynamic> json) {
    return alert_model.AlertSchedule(
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '23:59',
      days: List<int>.from(json['days'] ?? [1, 2, 3, 4, 5, 6, 7]),
    );
  }

  static Map<String, dynamic> _scheduleToFirestore(alert_model.AlertSchedule schedule) {
    return {
      'startTime': schedule.startTime,
      'endTime': schedule.endTime,
      'days': schedule.days,
    };
  }

  /// ===========================================================
  /// UTILITY METHODS
  /// ===========================================================
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  bool get isDetectionEnabled =>
      peopleCountEnabled ||
          footfallEnabled ||
          maxPeopleEnabled ||
          absentAlertEnabled ||
          theftAlertEnabled ||
          restrictedAreaEnabled;

  @override
  String toString() {
    return 'FirestoreCameraConfig(id: $id, deviceId: $deviceId, name: $name, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirestoreCameraConfig &&
        other.id == id &&
        other.deviceId == deviceId &&
        other.version == version;
  }

  @override
  int get hashCode {
    return id.hashCode ^ deviceId.hashCode ^ version.hashCode;
  }
}

/// ===========================================================
/// FIRESTORE SERIALIZATION OPTIONS
/// ===========================================================
class FirestoreCameraConfigSerializer {
  static const String collectionName = 'camera_configs';
  
  static Map<String, dynamic> serialize(FirestoreCameraConfig config) {
    return config.toFirestore();
  }

  static FirestoreCameraConfig deserialize(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    return FirestoreCameraConfig.fromFirestore(doc, options);
  }
}
