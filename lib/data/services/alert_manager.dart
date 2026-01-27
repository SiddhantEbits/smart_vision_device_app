import 'package:get/get.dart';
import '../models/alert_config_model.dart';
import '../../core/utils/cooldown_manager.dart';
import '../../core/logging/logger_service.dart';
import 'whatsapp_service.dart';
import 'snapshot_manager.dart';
import 'camera_log_service.dart';
import '../../../core/constants/app_constants.dart';

class AlertManager extends GetxService {
  final CooldownManager _cooldownManager = Get.find<CooldownManager>();
  final WhatsAppAlertService _whatsapp = Get.find<WhatsAppAlertService>();
  final SnapshotManager _snapshotManager = Get.find<SnapshotManager>();
  final CameraLogService _logService = Get.find<CameraLogService>();
  
  // Track last seen for Absent Alerts
  final Map<DetectionType, DateTime> _lastAlertTimes = {};
  DateTime? _lastPersonSeen;

  void processDetections({
    required List<AlertConfig> configs,
    required int personCount,
    required bool restrictedTriggered,
    required int footfallIncrement,
    required String rtspUrl,
    required String cameraName,
  }) {
    final now = DateTime.now();

    if (personCount > 0) {
      _lastPersonSeen = now;
    }

    for (var config in configs) {
      if (!config.isEnabled) continue;

      switch (config.type) {
        case DetectionType.crowdDetection:
          _checkCrowd(config, personCount, rtspUrl, cameraName);
          break;
        case DetectionType.absentAlert:
          _checkAbsent(config, now, rtspUrl, cameraName);
          break;
        case DetectionType.restrictedArea:
          if (restrictedTriggered) _checkRestricted(config, rtspUrl, cameraName);
          break;
        case DetectionType.sensitiveAlert:
          if (personCount > 0) _checkSensitive(config, rtspUrl, cameraName);
          break;
        case DetectionType.footfallDetection:
          if (footfallIncrement > 0) _checkFootfall(config, footfallIncrement, rtspUrl, cameraName);
          break;
      }
    }
  }

  void _checkCrowd(AlertConfig config, int count, String rtspUrl, String camName) {
    if (count >= (config.maxCapacity ?? 2)) {
      if (_cooldownManager.checkCooldown(
        cameraId: camName,
        feature: 'crowd',
        cooldownSeconds: config.cooldown,
      )) {
        _dispatchAlert(DetectionType.crowdDetection, 'Crowd Alert: $count people detected.', 
            rtspUrl: rtspUrl, cameraName: camName);
      }
    }
  }

  void _checkAbsent(AlertConfig config, DateTime now, String rtspUrl, String camName) {
    if (_lastPersonSeen == null) return;
    
    final absentDuration = now.difference(_lastPersonSeen!).inSeconds;
    if (absentDuration >= (config.interval ?? 60)) {
      if (_cooldownManager.checkCooldown(
        cameraId: camName,
        feature: 'absent',
        cooldownSeconds: config.cooldown,
      )) {
        _dispatchAlert(DetectionType.absentAlert, 'Absent Alert: No person seen for $absentDuration seconds.', 
            rtspUrl: rtspUrl, cameraName: camName);
      }
    }
  }

  void _checkRestricted(AlertConfig config, String rtspUrl, String camName) {
    if (_cooldownManager.checkCooldown(
      cameraId: camName,
      feature: 'restricted',
      cooldownSeconds: config.cooldown,
    )) {
      _dispatchAlert(DetectionType.restrictedArea, 'Security Breach: Person in Restricted Area.', 
          rtspUrl: rtspUrl, cameraName: camName);
    }
  }

  void _checkSensitive(AlertConfig config, String rtspUrl, String camName) {
    if (_cooldownManager.checkCooldown(
      cameraId: camName,
      feature: 'sensitive',
      cooldownSeconds: config.cooldown,
    )) {
      _dispatchAlert(DetectionType.sensitiveAlert, 'Sensitive Zone Alert: Person detected.', 
          rtspUrl: rtspUrl, cameraName: camName);
    }
  }

  void _checkFootfall(AlertConfig config, int increment, String rtspUrl, String camName) {
    _dispatchAlert(DetectionType.footfallDetection, 'Footfall: $increment person(s) crossed.', 
        detectionCount: increment, rtspUrl: rtspUrl, cameraName: camName);
  }

  Future<void> _dispatchAlert(DetectionType type, String message, {
    int? detectionCount,
    required String rtspUrl,
    required String cameraName,
  }) async {
    LoggerService.i('ALERT PIPELINE: [$type] $message');
    
    // 1. Capture Snapshots (High-res for WhatsApp, Low-res for logs)
    final snapshot = await _snapshotManager.captureSnapshot(
      rtspUrl: rtspUrl, 
      cameraName: cameraName,
    );

    // 2. Write to persistent Log File
    await _logService.logAlert(
      cameraName: cameraName, 
      alertType: type.toString().split('.').last, 
      snapshotPath: snapshot.lowResPath,
    );
    
    // 3. Send WhatsApp Alert
    String whatsAppType = "detection";
    switch (type) {
      case DetectionType.crowdDetection: whatsAppType = AppConstants.alertMaxPeople; break;
      case DetectionType.absentAlert: whatsAppType = AppConstants.alertAbsent; break;
      case DetectionType.restrictedArea: whatsAppType = AppConstants.alertRestrictedZone; break;
      case DetectionType.sensitiveAlert: whatsAppType = AppConstants.alertTheft; break;
      case DetectionType.footfallDetection: whatsAppType = "footFall"; break;
    }

    await _whatsapp.sendAlert(
      mediaFile: snapshot.highResFile,
      alertType: whatsAppType,
      cameraNo: cameraName,
      detectionCount: detectionCount,
    );
  }

  void reset() {
    _lastPersonSeen = null;
    _lastAlertTimes.clear();
  }
}
