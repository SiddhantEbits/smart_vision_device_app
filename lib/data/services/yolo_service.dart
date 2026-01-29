import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/crash_logger.dart';
import '../../core/logging/logger_service.dart';

class YoloService extends GetxService {
  YOLO? _yolo;
  bool _busy = false;
  final RxBool isModelLoaded = false.obs;
  final RxBool isProcessing = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxString status = 'Idle'.obs;

  @override
  void onClose() {
    _yolo?.dispose();
    super.onClose();
  }

  Future<bool> initModel() async {
    _status("Loading Detection Model...");
    LoggerService.i(status.value);

    try {
      debugPrint('🤖 YOLO: Starting model initialization...');
      debugPrint('🤖 YOLO: Model name: ${AppConstants.yoloModelName}');
      
      final path = await _getModelFile();
      if (path == null) {
        _status("Model file not found");
        debugPrint('❌ YOLO: Model file not found');
        return false;
      }

      debugPrint('✅ YOLO: Model file found at: $path');

      _yolo = YOLO(
        modelPath: path,
        task: YOLOTask.detect,
        useGpu: AppConstants.useGpu,
      );

      debugPrint('🤖 YOLO: Loading model with GPU=${AppConstants.useGpu}...');
      final ok = await _yolo!.loadModel();
      
      if (ok) {
        isModelLoaded.value = ok;
        _status("Detection ready");
        debugPrint('✅ YOLO: Model loaded successfully');
      } else {
        _status("Detection failed");
        debugPrint('❌ YOLO: Model loading failed');
      }
      
      if (!ok) {
        CrashLogger().logDetectionError(
          error: 'Failed to load TFLite model',
          operation: 'loadModel',
        );
      }
      
      return ok;
    } catch (e, stackTrace) {
      debugPrint("❌ YOLO: Detection error: $e\n$stackTrace");
      
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'loadModel',
        stackTrace: stackTrace,
      );
      
      return false;
    }
  }

  // ==================================================
  // PREDICT
  // ==================================================
  Future<Map<String, dynamic>?> predict(
      Uint8List imageBytes, {
        required double confidence,
      }) async {
    if (_yolo == null || _busy) return null;

    _busy = true;
    try {
      final result = await _yolo!.predict(
        imageBytes,
        confidenceThreshold: confidence,
        iouThreshold: AppConstants.iouThreshold,
      );
      
      // Log successful prediction for debugging
      if (kDebugMode && result != null) {
        final detections = result['detections'] as List? ?? [];
        debugPrint('[DETECTION] Prediction successful: ${detections.length} detections');
      }
      
      return result;
    } catch (e, stackTrace) {
      debugPrint("Detection prediction failed: $e");
      
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'predict',
        stackTrace: stackTrace,
        confidence: confidence,
      );
      
      return null;
    } finally {
      _busy = false;
    }
  }

  // ==================================================
  // RESET
  // ==================================================
  void reset() {
    _busy = false;
  }

  // ==================================================
  // MODEL FILE HANDLING
  // ==================================================
  Future<String?> _getModelFile() async {
    debugPrint('🤖 YOLO: Looking for model file...');
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/${AppConstants.yoloModelName}.tflite");

    debugPrint('🤖 YOLO: Checking local file: ${file.path}');

    if (await file.exists()) {
      debugPrint('✅ YOLO: Local model file exists');
      return file.path;
    }

    debugPrint('🤖 YOLO: Local file not found, trying download...');
    final downloaded = await _downloadModel(file);
    if (downloaded != null) {
      debugPrint('✅ YOLO: Model downloaded successfully');
      return downloaded;
    }

    debugPrint('🤖 YOLO: Download failed, trying assets...');
    final assetsPath = await _loadFromAssets(file);
    if (assetsPath != null) {
      debugPrint('✅ YOLO: Model loaded from assets');
      return assetsPath;
    }

    debugPrint('❌ YOLO: Could not find model file anywhere');
    return null;
  }

  Future<String?> _downloadModel(File target) async {
    final url = Uri.parse(
      "${AppConstants.yoloDownloadBase}/${AppConstants.yoloModelName}.tflite",
    );

    try {
      final res = await http.Client().send(
        http.Request("GET", url),
      );

      if (res.statusCode != 200) return null;

      final bytes = <int>[];
      int read = 0;
      final total = res.contentLength ?? 0;

      await for (final c in res.stream) {
        bytes.addAll(c);
        read += c.length;
        if (total > 0) {
          downloadProgress.value = read / total;
        }
      }

      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadFromAssets(File target) async {
    try {
      debugPrint('🤖 YOLO: Loading from assets: assets/models/${AppConstants.yoloModelName}.tflite');
      
      final data = await rootBundle.load(
        "assets/models/${AppConstants.yoloModelName}.tflite",
      );

      await target.writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
      
      debugPrint('✅ YOLO: Assets model written to: ${target.path}');
      return target.path;
    } catch (e) {
      debugPrint('❌ YOLO: Failed to load from assets: $e');
      return null;
    }
  }

  // ==================================================
  // STATUS
  // ==================================================
  void _status(String msg) {
    debugPrint("Detection: $msg");
    status.value = msg;
  }
}
