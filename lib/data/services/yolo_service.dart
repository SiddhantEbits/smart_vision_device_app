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
    status.value = 'Loading Detection Model...';
    LoggerService.i(status.value);

    try {
      final path = await _getModelPath();
      if (path == null) {
        status.value = 'Model file not found';
        return false;
      }

      _yolo = YOLO(
        modelPath: path,
        task: YOLOTask.detect,
        useGpu: AppConstants.useGpu,
      );

      final success = await _yolo!.loadModel();
      isModelLoaded.value = success;
      status.value = success ? 'Detection ready' : 'Detection failed';
      
      if (!success) {
        CrashLogger().logDetectionError(
          error: 'Failed to load TFLite model',
          operation: 'initModel',
        );
      }
      
      LoggerService.i('YOLO Init: ${status.value}');
      return success;
    } catch (e, stackTrace) {
      status.value = 'Initialization Error';
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'initModel',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> predict(Uint8List imageBytes, {double confidence = 0.5}) async {
    if (_yolo == null || isProcessing.value) return null;

    isProcessing.value = true;
    try {
      final result = await _yolo!.predict(
        imageBytes,
        confidenceThreshold: confidence,
        iouThreshold: AppConstants.iouThreshold,
      );
      
      return result;
    } catch (e, stackTrace) {
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'predict',
        stackTrace: stackTrace,
        confidence: confidence,
      );
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  Future<String?> _getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/${AppConstants.yoloModelName}.tflite");

    if (await file.exists()) return file.path;

    // Try to load from assets first (Production standard)
    final assetPath = await _loadFromAssets(file);
    if (assetPath != null) return assetPath;

    // Fallback to download if specified
    return await _downloadModel(file);
  }

  Future<String?> _loadFromAssets(File target) async {
    try {
      LoggerService.i('Loading model from assets...');
      final data = await rootBundle.load("assets/models/${AppConstants.yoloModelName}.tflite");
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return target.path;
    } catch (e) {
      LoggerService.w('Model not found in assets, trying download...');
      return null;
    }
  }

  Future<String?> _downloadModel(File target) async {
    final url = Uri.parse("${AppConstants.yoloDownloadBase}/${AppConstants.yoloModelName}.tflite");

    try {
      final res = await http.Client().send(http.Request("GET", url));
      if (res.statusCode != 200) return null;

      final bytes = <int>[];
      int read = 0;
      final total = res.contentLength ?? 0;

      await for (final chunk in res.stream) {
        bytes.addAll(chunk);
        read += chunk.length;
        if (total > 0) {
          downloadProgress.value = read / total;
        }
      }

      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (e) {
      LoggerService.e('Model download failed', e);
      return null;
    }
  }

  void reset() {
    isProcessing.value = false;
  }
}
