import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// ===========================================================
/// FIRESTORE DEVICE MODEL
/// Represents device document in Firestore
/// ===========================================================
class FirestoreDevice {
  final String deviceId;
  final String? pairedUserId;
  final String? hardwareName;
  final DeviceStatus status;
  final Timestamp lastSeen;
  final String? appVersion;
  final bool maintenanceMode;
  final bool hardRestart;
  final Timestamp createdAt;
  final bool isPaired;
  final Timestamp? pairedAt;
  final String? pairedBy;
  final bool alertEnable;
  final bool notificationEnabled;
  final String? fcmToken;
  final Timestamp? fcmTokenUpdatedAt;
  final WhatsAppConfig whatsapp;

  const FirestoreDevice({
    required this.deviceId,
    this.pairedUserId,
    this.hardwareName,
    required this.status,
    required this.lastSeen,
    this.appVersion,
    this.maintenanceMode = false,
    this.hardRestart = false,
    required this.createdAt,
    this.isPaired = false,
    this.pairedAt,
    this.pairedBy,
    this.alertEnable = true,
    this.notificationEnabled = true,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.whatsapp = const WhatsAppConfig(),
  });

  factory FirestoreDevice.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreDevice(
      deviceId: doc.id,
      pairedUserId: data['pairedUserId'],
      hardwareName: data['hardwareName'],
      status: DeviceStatus.fromString(data['status'] ?? 'offline'),
      lastSeen: data['lastSeen'] as Timestamp,
      appVersion: data['appVersion'],
      maintenanceMode: data['maintenanceMode'] ?? false,
      hardRestart: data['hardRestart'] ?? false,
      createdAt: data['createdAt'] as Timestamp,
      isPaired: data['isPaired'] ?? false,
      pairedAt: data['pairedAt'],
      pairedBy: data['pairedBy'],
      alertEnable: data['alertEnable'] ?? true,
      notificationEnabled: data['notificationEnabled'] ?? true,
      fcmToken: data['fcmToken'],
      fcmTokenUpdatedAt: data['fcmTokenUpdatedAt'],
      whatsapp: WhatsAppConfig.fromMap(data['whatsapp'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pairedUserId': pairedUserId,
      'hardwareName': hardwareName,
      'status': status.value,
      'lastSeen': lastSeen,
      'appVersion': appVersion,
      'maintenanceMode': maintenanceMode,
      'hardRestart': hardRestart,
      'createdAt': createdAt,
      'isPaired': isPaired,
      'pairedAt': pairedAt,
      'pairedBy': pairedBy,
      'alertEnable': alertEnable,
      'notificationEnabled': notificationEnabled,
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt,
      'whatsapp': whatsapp.toMap(),
    };
  }

  FirestoreDevice copyWith({
    String? pairedUserId,
    String? hardwareName,
    DeviceStatus? status,
    Timestamp? lastSeen,
    String? appVersion,
    bool? maintenanceMode,
    bool? hardRestart,
    bool? isPaired,
    Timestamp? pairedAt,
    String? pairedBy,
    bool? alertEnable,
    bool? notificationEnabled,
    String? fcmToken,
    Timestamp? fcmTokenUpdatedAt,
    WhatsAppConfig? whatsapp,
  }) {
    return FirestoreDevice(
      deviceId: deviceId,
      pairedUserId: pairedUserId ?? this.pairedUserId,
      hardwareName: hardwareName ?? this.hardwareName,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      appVersion: appVersion ?? this.appVersion,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      hardRestart: hardRestart ?? this.hardRestart,
      createdAt: createdAt,
      isPaired: isPaired ?? this.isPaired,
      pairedAt: pairedAt ?? this.pairedAt,
      pairedBy: pairedBy ?? this.pairedBy,
      alertEnable: alertEnable ?? this.alertEnable,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }

  /// Update heartbeat (called every hour minimum)
  FirestoreDevice updateHeartbeat() {
    return copyWith(
      lastSeen: Timestamp.now(),
      status: DeviceStatus.online,
    );
  }

  @override
  String toString() => 'FirestoreDevice(id: $deviceId, status: $status, lastSeen: $lastSeen)';
}

/// ===========================================================
/// FIRESTORE CAMERA MODEL
/// Represents camera document in devices/{deviceId}/cameras subcollection
/// ===========================================================
class FirestoreCamera {
  final String cameraId;
  final String cameraName;
  final String rtspUrlEncrypted;
  final Timestamp createdAt;
  final Map<String, AlgorithmConfig> algorithms;

  const FirestoreCamera({
    required this.cameraId,
    required this.cameraName,
    required this.rtspUrlEncrypted,
    required this.createdAt,
    required this.algorithms,
  });

  factory FirestoreCamera.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final algorithmsMap = <String, AlgorithmConfig>{};
    
    final algorithmsData = data['algorithms'] as Map<String, dynamic>? ?? {};
    algorithmsData.forEach((key, value) {
      algorithmsMap[key] = AlgorithmConfig.fromMap(value);
    });

    return FirestoreCamera(
      cameraId: doc.id,
      cameraName: data['cameraName'] ?? '',
      rtspUrlEncrypted: data['rtspUrlEncrypted'] ?? '',
      createdAt: data['createdAt'] as Timestamp,
      algorithms: algorithmsMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    final algorithmsMap = <String, dynamic>{};
    algorithms.forEach((key, config) {
      algorithmsMap[key] = config.toMap();
    });

    return {
      'cameraName': cameraName,
      'rtspUrlEncrypted': rtspUrlEncrypted,
      'createdAt': createdAt,
      'algorithms': algorithmsMap,
    };
  }

  FirestoreCamera copyWith({
    String? cameraName,
    String? rtspUrlEncrypted,
    Map<String, AlgorithmConfig>? algorithms,
  }) {
    return FirestoreCamera(
      cameraId: cameraId,
      cameraName: cameraName ?? this.cameraName,
      rtspUrlEncrypted: rtspUrlEncrypted ?? this.rtspUrlEncrypted,
      createdAt: createdAt,
      algorithms: algorithms ?? this.algorithms,
    );
  }

  @override
  String toString() => 'FirestoreCamera(id: $cameraId, name: $cameraName, algorithms: ${algorithms.keys})';
}

/// ===========================================================
/// ALGORITHM CONFIG MODEL
/// Embedded map in camera document for algorithm configuration
/// ===========================================================
class AlgorithmConfig {
  final bool enabled;
  final double threshold;
  final int? maxCapacity;
  final int? absentInterval;
  final int? alertInterval;
  final int? cooldownSeconds;
  final bool appNotification;
  final bool wpNotification;
  final ScheduleConfig schedule;

  const AlgorithmConfig({
    required this.enabled,
    required this.threshold,
    this.maxCapacity,
    this.absentInterval,
    this.alertInterval,
    this.cooldownSeconds,
    this.appNotification = true,
    this.wpNotification = false,
    required this.schedule,
  });

  factory AlgorithmConfig.fromMap(Map<String, dynamic> map) {
    return AlgorithmConfig(
      enabled: map['enabled'] ?? false,
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0.15,
      maxCapacity: map['maxCapacity'],
      absentInterval: map['absentInterval'],
      alertInterval: map['alertInterval'],
      cooldownSeconds: map['cooldownSeconds'],
      appNotification: map['appNotification'] ?? true,
      wpNotification: map['wpNotification'] ?? false,
      schedule: ScheduleConfig.fromMap(map['schedule'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'threshold': threshold,
      if (maxCapacity != null) 'maxCapacity': maxCapacity,
      if (absentInterval != null) 'absentInterval': absentInterval,
      if (alertInterval != null) 'alertInterval': alertInterval,
      if (cooldownSeconds != null) 'cooldownSeconds': cooldownSeconds,
      'appNotification': appNotification,
      'wpNotification': wpNotification,
      'schedule': schedule.toMap(),
    };
  }

  /// Check if algorithm should run based on schedule
  bool shouldRunNow() {
    if (!enabled) return false;
    if (!schedule.enabled) return true;

    final now = DateTime.now();
    final currentDay = _getDayString(now.weekday);
    
    if (!schedule.activeDays.contains(currentDay)) {
      return false;
    }

    final currentMinute = now.hour * 60 + now.minute;
    final startMinute = schedule.startMinute;
    final endMinute = schedule.endMinute;

    if (startMinute <= endMinute) {
      return currentMinute >= startMinute && currentMinute <= endMinute;
    } else {
      // Overnight schedule
      return currentMinute >= startMinute || currentMinute <= endMinute;
    }
  }

  AlgorithmConfig copyWith({
    bool? enabled,
    double? threshold,
    int? maxCapacity,
    int? absentInterval,
    int? alertInterval,
    int? cooldownSeconds,
    bool? appNotification,
    bool? wpNotification,
    ScheduleConfig? schedule,
  }) {
    return AlgorithmConfig(
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      absentInterval: absentInterval ?? this.absentInterval,
      alertInterval: alertInterval ?? this.alertInterval,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      appNotification: appNotification ?? this.appNotification,
      wpNotification: wpNotification ?? this.wpNotification,
      schedule: schedule ?? this.schedule,
    );
  }

  static String _getDayString(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return 'MON';
    }
  }

  @override
  String toString() => 'AlgorithmConfig(enabled: $enabled, threshold: $threshold)';
}

/// ===========================================================
/// SCHEDULE CONFIG MODEL
/// Embedded schedule configuration for algorithms
/// ===========================================================
class ScheduleConfig {
  final bool enabled;
  final List<String> activeDays;
  final int startMinute;
  final int endMinute;

  const ScheduleConfig({
    required this.enabled,
    required this.activeDays,
    required this.startMinute,
    required this.endMinute,
  });

  factory ScheduleConfig.fromMap(Map<String, dynamic> map) {
    return ScheduleConfig(
      enabled: map['enabled'] ?? false,
      activeDays: List<String>.from(map['activeDays'] ?? []),
      startMinute: map['startMinute'] ?? 0,
      endMinute: map['endMinute'] ?? 1439,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'activeDays': activeDays,
      'startMinute': startMinute,
      'endMinute': endMinute,
    };
  }

  @override
  String toString() => 'ScheduleConfig(enabled: $enabled, days: $activeDays, $startMinute-$endMinute)';
}

/// ===========================================================
/// WHATSAPP CONFIG MODEL
/// Embedded WhatsApp configuration
/// ===========================================================
class WhatsAppConfig {
  final bool alertEnable;
  final List<String> phoneNumbers;

  const WhatsAppConfig({
    this.alertEnable = false,
    this.phoneNumbers = const [],
  });

  factory WhatsAppConfig.fromMap(Map<String, dynamic> map) {
    return WhatsAppConfig(
      alertEnable: map['alertEnable'] ?? false,
      phoneNumbers: List<String>.from(map['phoneNumbers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertEnable': alertEnable,
      'phoneNumbers': phoneNumbers,
    };
  }

  @override
  String toString() => 'WhatsAppConfig(enabled: $alertEnable, numbers: ${phoneNumbers.length})';
}

/// ===========================================================
/// DEVICE STATUS ENUM
/// ===========================================================
enum DeviceStatus {
  online('online'),
  offline('offline'),
  error('error');

  const DeviceStatus(this.value);
  final String value;

  static DeviceStatus fromString(String value) {
    return DeviceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DeviceStatus.offline,
    );
  }
}

/// ===========================================================
/// ALERT LOG MODEL
/// High-volume alert logs collection
/// ===========================================================
class AlertLog {
  final String deviceId;
  final String deviceName;
  final String cameraId;
  final String camName;
  final String algorithmType;
  final Timestamp alertTime;
  final Timestamp createdAt;
  final String message;
  final int? currentCount;
  final String? imgUrl;
  final bool isRead;
  final List<String> sentTo;

  const AlertLog({
    required this.deviceId,
    required this.deviceName,
    required this.cameraId,
    required this.camName,
    required this.algorithmType,
    required this.alertTime,
    required this.createdAt,
    required this.message,
    this.currentCount,
    this.imgUrl,
    this.isRead = false,
    this.sentTo = const [],
  });

  factory AlertLog.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertLog(
      deviceId: data['deviceId'] ?? '',
      deviceName: data['deviceName'] ?? '',
      cameraId: data['cameraId'] ?? '',
      camName: data['camName'] ?? '',
      algorithmType: data['algorithmType'] ?? '',
      alertTime: data['alertTime'] as Timestamp,
      createdAt: data['createdAt'] as Timestamp,
      message: data['message'] ?? '',
      currentCount: data['currentCount'],
      imgUrl: data['imgUrl'],
      isRead: data['isRead'] ?? false,
      sentTo: List<String>.from(data['sentTo'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'cameraId': cameraId,
      'camName': camName,
      'algorithmType': algorithmType,
      'alertTime': alertTime,
      'createdAt': createdAt,
      'message': message,
      if (currentCount != null) 'currentCount': currentCount,
      if (imgUrl != null) 'imgUrl': imgUrl,
      'isRead': isRead,
      'sentTo': sentTo,
    };
  }

  /// Generate composite document ID: {device_camera_algorithm_timestamp}
  static String generateDocumentId({
    required String deviceId,
    required String cameraId,
    required String algorithmType,
    required Timestamp timestamp,
  }) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return '${deviceId}_${cameraId}_${algorithmType}_$timestampMs';
  }

  AlertLog copyWith({
    String? deviceId,
    String? deviceName,
    String? cameraId,
    String? camName,
    String? algorithmType,
    Timestamp? alertTime,
    Timestamp? createdAt,
    String? message,
    int? currentCount,
    String? imgUrl,
    bool? isRead,
    List<String>? sentTo,
  }) {
    return AlertLog(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      cameraId: cameraId ?? this.cameraId,
      camName: camName ?? this.camName,
      algorithmType: algorithmType ?? this.algorithmType,
      alertTime: alertTime ?? this.alertTime,
      createdAt: createdAt ?? this.createdAt,
      message: message ?? this.message,
      currentCount: currentCount ?? this.currentCount,
      imgUrl: imgUrl ?? this.imgUrl,
      isRead: isRead ?? this.isRead,
      sentTo: sentTo ?? this.sentTo,
    );
  }

  @override
  String toString() => 'AlertLog($algorithmType: $message)';
}

/// ===========================================================
/// ERROR LOG MODEL
/// Error and crash logs collection
/// ===========================================================
class ErrorLog {
  final String deviceId;
  final String cameraId;
  final String errorType;
  final ErrorSeverity severity;
  final String message;
  final Timestamp timestamp;
  final Timestamp createdAt;

  const ErrorLog({
    required this.deviceId,
    required this.cameraId,
    required this.errorType,
    required this.severity,
    required this.message,
    required this.timestamp,
    required this.createdAt,
  });

  factory ErrorLog.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return ErrorLog(
      deviceId: data['deviceId'] ?? '',
      cameraId: data['cameraId'] ?? '',
      errorType: data['errorType'] ?? '',
      severity: ErrorSeverity.fromString(data['severity'] ?? 'INFO'),
      message: data['message'] ?? '',
      timestamp: data['timestamp'] as Timestamp,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'cameraId': cameraId,
      'errorType': errorType,
      'severity': severity.value,
      'message': message,
      'timestamp': timestamp,
      'createdAt': createdAt,
    };
  }

  /// Generate composite document ID: {device_camera_timestamp}
  static String generateDocumentId({
    required String deviceId,
    required String cameraId,
    required Timestamp timestamp,
  }) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return '${deviceId}_${cameraId}_$timestampMs';
  }

  ErrorLog copyWith({
    String? deviceId,
    String? cameraId,
    String? errorType,
    ErrorSeverity? severity,
    String? message,
    Timestamp? timestamp,
    Timestamp? createdAt,
  }) {
    return ErrorLog(
      deviceId: deviceId ?? this.deviceId,
      cameraId: cameraId ?? this.cameraId,
      errorType: errorType ?? this.errorType,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ErrorLog($errorType: $message)';
}

/// ===========================================================
/// ERROR SEVERITY ENUM
/// ===========================================================
enum ErrorSeverity {
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  const ErrorSeverity(this.value);
  final String value;

  static ErrorSeverity fromString(String value) {
    return ErrorSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => ErrorSeverity.info,
    );
  }
}

/// ===========================================================
/// INSTALLER TEST MODEL
/// Installer validation tests subcollection
/// ===========================================================
class InstallerTest {
  final String algorithmType;
  final TestResult result;
  final Timestamp testedAt;
  final String testedBy;
  final String? notes;
  final Timestamp createdAt;

  const InstallerTest({
    required this.algorithmType,
    required this.result,
    required this.testedAt,
    required this.testedBy,
    this.notes,
    required this.createdAt,
  });

  factory InstallerTest.fromFirestore(
    DocumentSnapshot doc,
    SnapshotOptions? options,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return InstallerTest(
      algorithmType: data['algorithmType'] ?? '',
      result: TestResult.fromString(data['result'] ?? 'FAIL'),
      testedAt: data['testedAt'] as Timestamp,
      testedBy: data['testedBy'] ?? '',
      notes: data['notes'],
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'algorithmType': algorithmType,
      'result': result.value,
      'testedAt': testedAt,
      'testedBy': testedBy,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt,
    };
  }

  InstallerTest copyWith({
    String? algorithmType,
    TestResult? result,
    Timestamp? testedAt,
    String? testedBy,
    String? notes,
    Timestamp? createdAt,
  }) {
    return InstallerTest(
      algorithmType: algorithmType ?? this.algorithmType,
      result: result ?? this.result,
      testedAt: testedAt ?? this.testedAt,
      testedBy: testedBy ?? this.testedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'InstallerTest($algorithmType: $result)';
}

/// ===========================================================
/// TEST RESULT ENUM
/// ===========================================================
enum TestResult {
  pass('PASS'),
  fail('FAIL');

  const TestResult(this.value);
  final String value;

  static TestResult fromString(String value) {
    return TestResult.values.firstWhere(
      (result) => result.value == value,
      orElse: () => TestResult.fail,
    );
  }
}
