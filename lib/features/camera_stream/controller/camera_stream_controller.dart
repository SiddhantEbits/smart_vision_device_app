import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../data/models/camera_config.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/detected_object.dart';
import '../../../data/services/video_service.dart';
import '../../../data/services/yolo_service.dart';
import '../../../data/services/alert_manager.dart';
import '../../../data/services/detection/footfall_tracker.dart';
import '../../../data/services/detection/restricted_area_detector.dart';
import '../../../core/utils/detection_processor.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/logging/logger_service.dart';
import '../../../core/error/crash_logger.dart';

final _storage = GetStorage();
String _getFootfallKey(String cameraName) => 'footfall_count_$cameraName';

class CameraStreamController extends GetxController {
  // ==================================================
  // STREAM ID
  // ==================================================
  int _streamId = 0;
  int get streamId => _streamId;
  void setStreamId(int id) => _streamId = id;

  // ==================================================
  // DEPENDENCIES
  // ==================================================
  late final YoloService yolo;
  late final VideoService videoService;
  late final AlertManager alertManager;
  late final CameraSetupController cameraSetup;

  // ==================================================
  // READY FLAGS
  // ==================================================
  final modelLoaded = false.obs;
  final videoReady = false.obs;
  final surfaceReady = false.obs;
  final streamRunning = false.obs;

  // ==================================================
  // COMPONENTS
  // ==================================================
  late final DetectionProcessor detector;
  late final FootfallTracker footfallTracker;
  late final RestrictedAreaDetector restrictedAreaDetector;

  // ==================================================
  // UI STATE
  // ==================================================
  final peopleCount = 0.obs;
  final footfallCount = 0.obs;

  final isFootfallEditMode = false.obs;
  final isRestrictedEditMode = false.obs;

  final loadingMessage = "Initializing...".obs;

  // ==================================================
  // SCHEDULE STATE
  // ==================================================
  final peopleDetectionActive = false.obs;
  final footfallDetectionActive = false.obs;
  final theftDetectionActive = false.obs;
  final restrictedDetectionActive = false.obs;
  final anyDetectionActive = false.obs;

  // ==================================================
  // CAMERA STATE
  // ==================================================
  final currentCameraIndex = 0.obs;
  List<CameraConfig> get cameraConfigs => cameraSetup.cameras;
  CameraConfig get currentCam {
    if (cameraConfigs.isEmpty) {
      return CameraConfig(name: "No Camera", url: "");
    }
    return cameraConfigs[currentCameraIndex.value];
  }

  // ==================================================
  // DETECTIONS
  // ==================================================
  final detections = <DetectedObject>[].obs;

  /// 🔴 IDs currently inside restricted ROI (for UI)
  final restrictedIds = <int>{}.obs;

  // ==================================================
  // INTERNAL FLAGS
  // ==================================================
  bool _isPredicting = false;
  bool _closing = false;
  bool _surfaceListenerAttached = false;
  bool _previousFootfallEnabled = false;
  
  /// If true, the camera will start even if surfaceReady is false.
  /// Useful for background detection.
  bool _headlessMode = false;
  
  /// Track the previous URL to detect URL changes
  String? _previousUrl;

  Timer? _scheduleCheckTimer;
  Timer? _firstFrameRetryTimer;

  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minInferenceGapMs = 800;

  // ==================================================
  // INIT
  // ==================================================
  @override
  void onInit() {
    super.onInit();

    cameraSetup = Get.find<CameraSetupController>();
    yolo = Get.find<YoloService>();
    alertManager = Get.find<AlertManager>();

    detector = DetectionProcessor();
    footfallTracker = FootfallTracker();
    restrictedAreaDetector = RestrictedAreaDetector();

    // Initialize video service
    videoService = VideoService(onFrame: _onFrameForCamera);

    // ============================================================
    // EDIT MODE MANAGEMENT
    // ============================================================
    ever(isFootfallEditMode, (on) {
      _updateScheduleStatus();
    });

    ever(isRestrictedEditMode, (on) {
      _updateScheduleStatus();
    });

    ever(cameraSetup.cameras, (List<CameraConfig> newCameras) {
      if (newCameras.isEmpty) {
        stopCamera();
        _resetState();
        _previousUrl = null;
        return;
      }

      // Check if we have a valid current index
      if (currentCameraIndex.value >= newCameras.length) {
        // Index out of bounds - camera was deleted
        LoggerService.d('[CAMERA_STREAM] Camera deleted, switching to last available');
        currentCameraIndex.value = newCameras.length - 1;
        _previousUrl = newCameras[currentCameraIndex.value].url;
        startCamera(index: currentCameraIndex.value, forceRestart: true);
        return;
      }

      final newCam = newCameras[currentCameraIndex.value];
      
      // Check if URL changed at the current index
      if (_previousUrl != null && _previousUrl != newCam.url && streamRunning.value) {
        LoggerService.d('[CAMERA_STREAM] URL changed from $_previousUrl to ${newCam.url}. Restarting...');
        _previousUrl = newCam.url;
        startCamera(index: currentCameraIndex.value, forceRestart: true);
        return;
      }
      
      // Just settings changed or first load
      _previousUrl = newCam.url;
      _updateScheduleStatus();
    });

    ever(currentCameraIndex, (int newIndex) {
      _updateScheduleStatus();
      
      // Reset footfall count if switching to camera with footfall disabled
      if (cameraConfigs.isNotEmpty && newIndex < cameraConfigs.length) {
        final cam = cameraConfigs[newIndex];
        if (!cam.footfallEnabled) {
          final footfallKey = _getFootfallKey(cam.name);
          final currentCount = _storage.read<int>(footfallKey) ?? 0;
          if (currentCount > 0) {
            footfallCount.value = 0;
            _storage.write(footfallKey, 0);
            LoggerService.d('[FOOTFALL] Feature disabled - reset count to 0 for camera: ${cam.name}');
          }
        }
        _previousFootfallEnabled = cam.footfallEnabled;
      }
    });

    // Start schedule checker
    _scheduleCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateScheduleStatus());
  }

  // ==================================================
  // CAMERA CONTROL
  // ==================================================
  Future<void> startCamera({
    int? index,
    bool forceRestart = false,
    bool headlessMode = false,
  }) async {
    if (_closing) return;

    _headlessMode = headlessMode;

    final targetIndex = index ?? currentCameraIndex.value;
    if (targetIndex >= cameraConfigs.length) {
      LoggerService.e('[CAMERA_STREAM] Invalid camera index: $targetIndex');
      return;
    }

    final cam = cameraConfigs[targetIndex];
    if (cam.url.isEmpty) {
      LoggerService.e('[CAMERA_STREAM] Empty RTSP URL for camera: ${cam.name}');
      return;
    }

    // Stop current camera if running
    if (streamRunning.value && !forceRestart) {
      LoggerService.d('[CAMERA_STREAM] Camera already running: ${cam.name}');
      return;
    }

    if (streamRunning.value) {
      await stopCamera();
    }

    currentCameraIndex.value = targetIndex;
    _previousUrl = cam.url;

    LoggerService.i('[CAMERA_STREAM] Starting camera: ${cam.name} (${cam.url})');

    // Load footfall count
    if (cam.footfallEnabled) {
      final footfallKey = _getFootfallKey(cam.name);
      footfallCount.value = _storage.read<int>(footfallKey) ?? 0;
      _previousFootfallEnabled = true;
    } else {
      footfallCount.value = 0;
      _previousFootfallEnabled = false;
    }

    // Start video service
    try {
      await videoService.open(cam.url);
      videoReady.value = true;
      LoggerService.i('[CAMERA_STREAM] Video service started for: ${cam.name}');
    } catch (e, stack) {
      LoggerService.e('[CAMERA_STREAM] Failed to start video service: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'startCamera',
        stackTrace: stack,
      );
      return;
    }

    streamRunning.value = true;
    _updateScheduleStatus();

    LoggerService.i('[CAMERA_STREAM] Camera started successfully: ${cam.name}');
  }

  Future<void> stopCamera() async {
    if (!streamRunning.value) return;

    LoggerService.i('[CAMERA_STREAM] Stopping camera...');

    streamRunning.value = false;
    videoReady.value = false;

    try {
      await videoService.stop();
    } catch (e) {
      LoggerService.e('[CAMERA_STREAM] Error stopping video service: $e');
    }

    _resetState();
    _updateScheduleStatus();

    LoggerService.i('[CAMERA_STREAM] Camera stopped');
  }

  Future<void> switchCamera(int index) async {
    if (index == currentCameraIndex.value) return;
    
    // Properly wait for current camera to stop
    await stopCamera();
    currentCameraIndex.value = index;
    await startCamera(index: index);
  }

  // ==================================================
  // SCHEDULE MANAGEMENT
  // ==================================================
  void _updateScheduleStatus() {
    if (cameraConfigs.isEmpty) return;

    final cam = currentCam;
    final now = DateTime.now();

    // People detection
    peopleDetectionActive.value = cam.peopleCountEnabled;

    // Footfall detection
    final wasFootfallActive = footfallDetectionActive.value;
    footfallDetectionActive.value = cam.footfallEnabled;
    
    // Check if footfall was just disabled (was enabled, now disabled)
    if (_previousFootfallEnabled && !cam.footfallEnabled) {
      final footfallKey = _getFootfallKey(cam.name);
      final currentCount = _storage.read<int>(footfallKey) ?? 0;
      if (currentCount > 0) {
        footfallCount.value = 0;
        _storage.write(footfallKey, 0);
        LoggerService.d('[FOOTFALL] Feature disabled - reset count to 0 for camera: ${cam.name}');
      }
    }
    // Update previous state
    _previousFootfallEnabled = cam.footfallEnabled;

    // Theft detection
    theftDetectionActive.value = cam.theftAlertEnabled;

    // Restricted area detection
    restrictedDetectionActive.value = cam.restrictedAreaEnabled;

    // Any detection active
    anyDetectionActive.value = peopleDetectionActive.value ||
        footfallDetectionActive.value ||
        theftDetectionActive.value ||
        restrictedDetectionActive.value;

    LoggerService.d('[SCHEDULE] People: ${peopleDetectionActive.value}, Footfall: ${footfallDetectionActive.value}, Theft: ${theftDetectionActive.value}, Restricted: ${restrictedDetectionActive.value}');
  }

  bool _isScheduleActive(Map<String, dynamic>? schedule, DateTime now) {
    if (schedule == null || schedule.isEmpty) return true; // Always active if no schedule

    try {
      final startTime = TimeOfDay(
        hour: schedule['startHour'] ?? 0,
        minute: schedule['startMinute'] ?? 0,
      );
      final endTime = TimeOfDay(
        hour: schedule['endHour'] ?? 23,
        minute: schedule['endMinute'] ?? 59,
      );

      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

      if (startTime.hour <= endTime.hour) {
        // Same day schedule
        if (currentTime.hour > startTime.hour ||
            (currentTime.hour == startTime.hour && currentTime.minute >= startTime.minute)) {
          return currentTime.hour < endTime.hour ||
              (currentTime.hour == endTime.hour && currentTime.minute <= endTime.minute);
        }
      } else {
        // Overnight schedule
        return currentTime.hour > startTime.hour ||
            (currentTime.hour == startTime.hour && currentTime.minute >= startTime.minute) ||
            currentTime.hour < endTime.hour ||
            (currentTime.hour == endTime.hour && currentTime.minute <= endTime.minute);
      }
    } catch (e) {
      LoggerService.e('Error checking schedule: $e');
    }

    return false;
  }

  // ==================================================
  // FRAME PROCESSING
  // ==================================================
  Future<void> _onFrameForCamera(Uint8List bytes) async {
    if (_closing ||
        !yolo.isModelLoaded.value ||
        !streamRunning.value ||
        _isPredicting ||
        !_canInfer()) {
      return;
    }

    _isPredicting = true;
    _lastInference = DateTime.now();

    try {
      final cam = currentCam;
      
      // Only process if any detection is active
      if (!anyDetectionActive.value) {
        LoggerService.d('[DETECTION] No detection features active, skipping inference');
        return;
      }

      LoggerService.d('Starting detection processing - current detections count: ${detections.length}');

      // Only use real YOLO predictions
      try {
        final result = await yolo.predict(
          bytes,
          confidence: cam.confidenceThreshold, // Use dynamic threshold from camera config
        );
        LoggerService.d('YOLO prediction result (REAL): $result');
        if (result != null) {
          final realBoxes = result["boxes"] as List? ?? [];
          LoggerService.d('YOLO detected boxes (REAL): $realBoxes');
          
          final realDetections = detector.process(
            boxes: realBoxes,
            confidenceThreshold: cam.confidenceThreshold,
          );

          // Update UI detections
          detections.assignAll(realDetections);
          peopleCount.value = realDetections.length;

          // Process detection features
          await _processDetectionFeatures(realDetections, cam);
        } else {
          // Clear detections on null result
          detections.clear();
          peopleCount.value = 0;
          LoggerService.d('YOLO returned null result, clearing detections');
        }
      } catch (e) {
        LoggerService.e('Real YOLO prediction failed: $e');
        // Clear detections on error
        detections.clear();
        peopleCount.value = 0;
      }

      // Update alert manager with current state
      alertManager.processDetections(
        configs: _getAlertConfigs(),
        personCount: peopleCount.value,
        restrictedTriggered: restrictedIds.isNotEmpty,
        footfallIncrement: 0, // Will be updated in footfall processing
        rtspUrl: cam.url,
        cameraName: cam.name,
      );

    } catch (e, stack) {
      LoggerService.e('Error in frame processing: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: '_onFrameForCamera',
        stackTrace: stack,
      );
    } finally {
      _isPredicting = false;
    }
  }

  Future<void> _processDetectionFeatures(List<DetectedObject> realDetections, CameraConfig cam) async {
    final now = DateTime.now();

    // Process footfall detection
    if (footfallDetectionActive.value && cam.footfallEnabled) {
      int footfallIncrement = 0;
      footfallTracker.update(
        detections: realDetections,
        cam: cam,
        now: now,
        onCount: () {
          footfallCount.value++;
          final footfallKey = _getFootfallKey(cam.name);
          _storage.write(footfallKey, footfallCount.value);
          footfallIncrement = 1;
          LoggerService.i('[FOOTFALL] Person crossed. Total: ${footfallCount.value}');
        },
      );
      
      if (footfallIncrement > 0) {
        LoggerService.i('[FOOTFALL] $footfallIncrement people crossed. Total: ${footfallCount.value}');
      }
    }

    // Process restricted area detection
    if (restrictedDetectionActive.value && cam.restrictedAreaEnabled) {
      final violations = restrictedAreaDetector.processDetections(
        detections: realDetections,
        restrictedRoi: cam.restrictedAreaConfig.roi,
      );

      if (violations.isNotEmpty) {
        final violationIds = violations.map((v) => v.personId).toList();
        restrictedIds.assignAll(violationIds);
        LoggerService.i('[RESTRICTED] ${violations.length} violations detected');
        for (final violation in violations) {
          LoggerService.i('[RESTRICTED] ${violation.description} - Person ID: ${violation.personId}');
        }
      } else {
        restrictedIds.clear();
      }
    } else {
      restrictedIds.clear();
    }
  }

  List<AlertConfig> _getAlertConfigs() {
    final cam = currentCam;
    final configs = <AlertConfig>[];

    if (cam.maxPeopleEnabled) {
      configs.add(AlertConfig(
        type: DetectionType.crowdDetection,
        isEnabled: true,
        maxCapacity: cam.maxPeople,
        cooldown: 60,
        schedule: AlertSchedule(
          startTime: '00:00',
          endTime: '23:59',
          days: [1, 2, 3, 4, 5, 6, 7],
        ),
      ));
    }

    if (cam.footfallEnabled) {
      final roiPoints = <Offset>[];
      roiPoints.add(cam.footfallConfig.lineStart);
      roiPoints.add(cam.footfallConfig.lineEnd);
      
      configs.add(AlertConfig(
        type: DetectionType.footfallDetection,
        isEnabled: true,
        interval: cam.footfallIntervalMinutes,
        cooldown: 60,
        schedule: AlertSchedule(
          startTime: '00:00',
          endTime: '23:59',
          days: [1, 2, 3, 4, 5, 6, 7],
        ),
        roiPoints: roiPoints,
      ));
    }

    if (cam.restrictedAreaEnabled) {
      final roiPoints = <Offset>[];
      final roi = cam.restrictedAreaConfig.roi;
      roiPoints.add(roi.topLeft);
      roiPoints.add(roi.bottomRight);
      
      configs.add(AlertConfig(
        type: DetectionType.restrictedArea,
        isEnabled: true,
        cooldown: 30,
        schedule: AlertSchedule(
          startTime: '00:00',
          endTime: '23:59',
          days: [1, 2, 3, 4, 5, 6, 7],
        ),
        roiPoints: roiPoints,
      ));
    }

    if (cam.theftAlertEnabled) {
      configs.add(AlertConfig(
        type: DetectionType.sensitiveAlert,
        isEnabled: true,
        cooldown: 120,
        schedule: AlertSchedule(
          startTime: '00:00',
          endTime: '23:59',
          days: [1, 2, 3, 4, 5, 6, 7],
        ),
      ));
    }

    return configs;
  }

  bool _canInfer() {
    final gap = DateTime.now().difference(_lastInference).inMilliseconds;
    return gap >= _minInferenceGapMs;
  }

  // ==================================================
  // STATE MANAGEMENT
  // ==================================================
  void _resetState() {
    detections.clear();
    peopleCount.value = 0;
    restrictedIds.clear();
    _isPredicting = false;
    _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ==================================================
  // DISPOSE
  // ==================================================
  @override
  void onClose() {
    _closing = true;
    _scheduleCheckTimer?.cancel();
    _firstFrameRetryTimer?.cancel();
    stopCamera();
    
    videoService.dispose();
    detector.reset();
    footfallTracker.reset();
    restrictedAreaDetector.reset();
    
    super.onClose();
  }
}
