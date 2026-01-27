import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models/alert_config_model.dart';
import '../../../data/models/detected_object.dart';
import '../../../data/services/yolo_service.dart';
import '../../../data/services/ffmpeg_service.dart';
import '../../../data/services/detection/restricted_area_detector.dart';
import '../../../data/services/detection/footfall_tracker.dart';
import '../../../data/services/alert_manager.dart';
import '../../../core/utils/detection_processor.dart';
import '../../../core/logging/logger_service.dart';

class MonitoringController extends GetxController {
  // Services
  final YoloService _yolo = Get.find<YoloService>();
  final FFmpegService _ffmpeg = Get.find<FFmpegService>();
  final AlertManager _alerts = Get.find<AlertManager>();
  final DetectionProcessor _processor = DetectionProcessor();
  
  // Detectors
  final RestrictedAreaDetector _restrictedDetector = RestrictedAreaDetector();
  final FootfallTracker _footfallTracker = FootfallTracker();

  // MediaKit for Background Stream (Visual)
  late final Player player;
  late final VideoController videoController;

  // State
  final RxList<DetectedObject> currentDetections = <DetectedObject>[].obs;
  final RxSet<int> restrictedIds = <int>{}.obs;
  final RxInt footfallTotal = 0.obs;
  final RxBool isStreaming = false.obs;
  
  // Configuration
  List<AlertConfig> _configs = [];
  String _rtspUrl = '';

  @override
  void onInit() {
    super.onInit();
    player = Player();
    videoController = VideoController(player);
  }

  @override
  void onClose() {
    stopMonitoring();
    player.dispose();
    super.onClose();
  }

  Future<void> startMonitoring({
    required String rtspUrl,
    required List<AlertConfig> configs,
  }) async {
    _rtspUrl = rtspUrl;
    _configs = configs;
    
    LoggerService.i('Starting Monitoring: $rtspUrl');
    
    // 1. Initialize YOLO
    if (!_yolo.isModelLoaded.value) {
      await _yolo.initModel();
    }

    // 2. Start Visual Stream (MediaKit)
    await player.open(Media(rtspUrl));
    
    // 3. Start Extraction Stream (FFmpeg)
    await _ffmpeg.start(rtspUrl, _onFrameReceived);
    
    isStreaming.value = true;
  }

  Future<void> stopMonitoring() async {
    await _ffmpeg.stop();
    await player.stop();
    isStreaming.value = false;
    _restrictedDetector.reset();
    _footfallTracker.reset();
    currentDetections.clear();
    restrictedIds.clear();
  }

  void _onFrameReceived(Uint8List bytes) async {
    if (!isStreaming.value) return;

    final now = DateTime.now();
    
    // 1. Run YOLO Inference
    final result = await _yolo.predict(bytes);
    if (result == null) return;

    // 2. Normalize Detections
    final rawBoxes = result['boxes'] as List? ?? [];
    final detections = _processor.process(
      boxes: rawBoxes, 
      confidenceThreshold: 0.5,
    );

    // 3. Process Domain Specific Logic
    int footfallIncrement = 0;
    bool restrictedTriggered = false;

    for (var config in _configs) {
      if (!config.isEnabled) continue;

      if (config.type == DetectionType.footfallDetection) {
        if (config.roiPoints != null && config.roiPoints!.length >= 2) {
          footfallIncrement += _footfallTracker.processDetections(
            detections: detections,
            lineStart: config.roiPoints![0],
            lineEnd: config.roiPoints![1],
            direction: const Offset(0, 1),
            now: now,
          );
        }
      }

      if (config.type == DetectionType.restrictedArea) {
        if (config.roiPoints != null && config.roiPoints!.length >= 2) {
          final roiRect = Rect.fromPoints(config.roiPoints![0], config.roiPoints![1]);
          final entries = _restrictedDetector.processDetections(
            detections: detections,
            restrictedRoi: roiRect,
          );
          if (entries.isNotEmpty) restrictedTriggered = true;
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
