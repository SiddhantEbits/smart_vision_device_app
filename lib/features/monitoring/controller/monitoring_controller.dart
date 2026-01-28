import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models/alert_config_model.dart';
import '../../../data/models/camera_config.dart';
import '../../../data/models/roi_config.dart';
import '../../../data/models/detected_object.dart';
import '../../../data/services/yolo_service.dart';
import '../../../data/services/ffmpeg_service.dart';
import '../../../data/services/detection/restricted_area_detector.dart';
import '../../../data/services/detection/footfall_tracker.dart';
import '../../../data/services/alert_manager.dart';
import '../../../core/utils/detection_processor.dart';
import '../../../core/logging/logger_service.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';

class MonitoringController extends GetxController {
  // Services
  final YoloService _yolo = Get.find<YoloService>();
  final FFmpegService _ffmpeg = Get.find<FFmpegService>();
  final AlertManager _alerts = Get.find<AlertManager>();
  final DetectionProcessor _processor = DetectionProcessor();
  final CameraSetupController cameraSetupController = Get.find<CameraSetupController>();
  
  // Detectors
  final RestrictedAreaDetector _restrictedDetector = RestrictedAreaDetector();
  final FootfallTracker _footfallTracker = FootfallTracker();

  // MediaKit for Background Stream (Visual)
  Player player = Player();
  VideoController? videoController;
  bool _isPlayerInitialized = false;

  // State
  final RxList<DetectedObject> currentDetections = <DetectedObject>[].obs;
  final RxSet<int> restrictedIds = <int>{}.obs;
  final RxInt footfallTotal = 0.obs;
  final RxBool isStreaming = false.obs;
  
  // Configuration
  List<AlertConfig> _configs = [];
  String _rtspUrl = '';

  /// Set alert configurations for monitoring
  void setConfigs(List<AlertConfig> configs) {
    _configs = configs;
    LoggerService.i('Set ${configs.length} alert configurations for monitoring');
  }

  @override
  void onInit() {
    super.onInit();
    _initializePlayer();
  }

  void _initializePlayer() {
    try {
      player = Player();
      videoController = VideoController(player!);
      _isPlayerInitialized = true;
    } catch (e) {
      LoggerService.e('Failed to initialize MediaKit player: $e');
      _isPlayerInitialized = false;
    }
  }

  Future<void> startMonitoring() async {
    if (isStreaming.value) return;
    
    final rtspUrl = cameraSetupController.rtspUrl.value;
    if (rtspUrl.isEmpty) {
      LoggerService.e('RTSP URL is empty');
      Get.snackbar('Error', 'RTSP URL is required');
      return;
    }

    LoggerService.i('Starting Monitoring: $rtspUrl');

    // 1. Check YOLO model
    if (!_yolo.isModelLoaded.value) {
      LoggerService.e('YOLO model not loaded');
      Get.snackbar('Error', 'YOLO model not loaded');
      return;
    }

    // 2. Start MediaKit Preview (independent of FFmpeg)
    try {
      if (!_isPlayerInitialized) {
        videoController = VideoController(player);
        _isPlayerInitialized = true;
      }
      
      await player.open(
        Media(
          rtspUrl,
          extras: {
            "rtsp_transport": "tcp",
            "rtsp_flags": "prefer_tcp",
            "analyzeduration": "1000000", // 1 second
            "probesize": "128",
            "buffer_size": "65536", // 64KB buffer
            "max_delay": "500000", // 0.5 second
            "framedrop": "1", // Frame dropping for stability
          },
        ),
        play: true,
      );
      
      LoggerService.i('MediaKit preview started successfully');
    } catch (e) {
      LoggerService.e('Failed to start MediaKit preview: $e');
      // Don't return - continue with FFmpeg even if preview fails
    }
    
    // 3. Start FFmpeg Extraction (independent of MediaKit)
    // Use retry logic like smart-camera-yolo
    await _startFFmpegWithRetry(rtspUrl);
    
    isStreaming.value = true;
  }

  Future<void> _startFFmpegWithRetry(String rtspUrl) async {
    int attempts = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 3);
    
    while (attempts <= maxRetries) {
      try {
        LoggerService.i('Starting FFmpeg extraction attempt ${attempts + 1}');
        await _ffmpeg.start(rtspUrl, onFrame: _onFrameReceived);
        LoggerService.i('FFmpeg extraction started successfully');
        return; // Success
      } catch (e, stack) {
        attempts++;
        if (attempts > maxRetries) {
          LoggerService.e('FFmpeg extraction failed after $attempts attempts: $e');
          LoggerService.e('Stack trace: $stack');
          
          // Show user-friendly message but don't stop monitoring
          Get.snackbar(
            'Detection Limited', 
            'YOLO detection unavailable, but preview is working',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          );
          return;
        }

        LoggerService.w('FFmpeg extraction attempt $attempts failed, retrying in ${retryDelay.inSeconds}s... Error: $e');
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> stopMonitoring() async {
    await _ffmpeg.stop();
    
    // Only stop player if it's initialized
    if (_isPlayerInitialized) {
      try {
        await player.stop();
      } catch (e) {
        LoggerService.e('Failed to stop MediaKit player: $e');
      }
    }
    
    isStreaming.value = false;
    _restrictedDetector.reset();
    _footfallTracker.reset();
    currentDetections.clear();
    restrictedIds.clear();
  }

  @override
  void onClose() {
    stopMonitoring();
    if (_isPlayerInitialized) {
      player.dispose();
      _isPlayerInitialized = false;
    }
    super.onClose();
  }

  void _onFrameReceived(Uint8List bytes) async {
    if (!isStreaming.value) return;

    final now = DateTime.now();
    
    // 1. Run YOLO Inference
    final result = await _yolo.predict(bytes, confidence: 0.15);
    if (result == null) return;

    // 2. Normalize Detections
    final rawBoxes = result['boxes'] as List? ?? [];
    final detections = _processor.process(
      boxes: rawBoxes, 
      confidenceThreshold: 0.15,
    );

    // 3. Process Domain Specific Logic
    int footfallIncrement = 0;
    bool restrictedTriggered = false;

    for (var config in _configs) {
      if (!config.isEnabled) continue;

      if (config.type == DetectionType.footfallDetection) {
        if (config.roiPoints != null && config.roiPoints!.length >= 2) {
          LoggerService.i('Processing footfall detection with ${config.roiPoints!.length} ROI points');
          LoggerService.i('Line start: ${config.roiPoints![0]}, end: ${config.roiPoints![1]}');
          
          // Create a temporary camera config for footfall tracking
          final tempCam = CameraConfig(
            name: 'monitoring',
            url: '', // Empty URL for monitoring
            peopleCountEnabled: false,
            footfallEnabled: true,
            footfallConfig: RoiAlertConfig(
              roi: Rect.zero,
              lineStart: config.roiPoints![0],
              lineEnd: config.roiPoints![1],
              direction: const Offset(0, 1), // Downward direction
            ),
            footfallIntervalMinutes: 5,
            maxPeopleEnabled: false,
            maxPeople: 0,
            maxPeopleCooldownSeconds: 30,
            absentAlertEnabled: false,
            absentSeconds: 0,
            absentCooldownSeconds: 0,
            theftAlertEnabled: false,
            theftCooldownSeconds: 0,
            restrictedAreaEnabled: false,
            restrictedAreaConfig: RoiAlertConfig.forRestrictedArea(
              roi: Rect.zero,
            ),
            restrictedAreaCooldownSeconds: 30,
            confidenceThreshold: 0.15,
          );
          
          _footfallTracker.update(
            detections: detections,
            cam: tempCam,
            now: now,
            onCount: () {
              footfallIncrement++;
              LoggerService.i('Footfall count incremented! Total increment: $footfallIncrement');
            },
          );
        } else {
          LoggerService.w('Footfall detection config missing ROI points or insufficient points: ${config.roiPoints?.length ?? 0}');
        }
      }

      if (config.type == DetectionType.restrictedArea) {
        if (config.roiPoints != null && config.roiPoints!.length >= 2) {
          LoggerService.i('Processing restricted area detection with ${config.roiPoints!.length} ROI points');
          final roiRect = Rect.fromPoints(config.roiPoints![0], config.roiPoints![1]);
          LoggerService.i('Restricted area ROI: $roiRect');
          
          final violations = _restrictedDetector.processDetections(
            detections: detections,
            restrictedRoi: roiRect,
          );
          if (violations.isNotEmpty) {
            restrictedTriggered = true;
            LoggerService.i('Restricted area violations detected: ${violations.length}');
            for (final violation in violations) {
              LoggerService.i('Violation: ${violation.description} - Person ID: ${violation.personId}');
            }
          }
        } else {
          LoggerService.w('Restricted area config missing ROI points or insufficient points: ${config.roiPoints?.length ?? 0}');
        }
      }
    }

    // 4. Update UI State
    currentDetections.assignAll(detections);
    restrictedIds.assignAll(_restrictedDetector.getRestrictedIds());
    if (footfallIncrement > 0) {
      footfallTotal.value += footfallIncrement;
    }

    // 5. Handle Alerts with Full Pipeline
    _alerts.processDetections(
      configs: _configs,
      personCount: detections.length,
      restrictedTriggered: restrictedTriggered,
      footfallIncrement: footfallIncrement,
      rtspUrl: _rtspUrl,
      cameraName: "Main_Camera", // In production this comes from camera config
    );
  }
}
