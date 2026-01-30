import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';
import '../repositories/simple_storage_service.dart';

class FrameSnapshotService extends GetxService {
  static const Duration _cleanupDelay = AppConstants.shortTermRetention;
  
  final Map<String, Timer> _cleanupTimers = {};
  bool _disposed = false;
  final SimpleStorageService _storage = Get.find<SimpleStorageService>();

  Future<File?> captureSnapshot(Uint8List frameBytes, {String? cameraName}) async {
    if (_disposed || frameBytes.isEmpty) return null;

    LoggerService.i('📸 Capturing frame snapshot for ${cameraName ?? 'camera'}');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cameraTag = cameraName?.replaceAll(RegExp(r'[^\w\-]'), '_') ?? 'camera';
      final snapshotFile = File('${tempDir.path}/frame_snapshot_${cameraTag}_$timestamp.jpg');
      
      // Try to decode as JPEG first (if frame is already JPEG)
      img.Image? image;
      try {
        image = img.decodeImage(frameBytes);
        LoggerService.d('✅ Frame decoded as JPEG');
      } catch (e) {
        LoggerService.w('⚠️ Frame is not JPEG format, trying alternative methods: $e');
        
        // If JPEG decode fails, try other formats
        try {
          image = img.decodePng(frameBytes);
          LoggerService.d('✅ Frame decoded as PNG');
        } catch (e2) {
          LoggerService.w('⚠️ Frame is not PNG format either: $e2');
          
          // If both fail, save raw bytes as JPEG fallback
          // This might not work but it's worth trying
          try {
            // Create a simple RGB image from raw data if possible
            // For now, just save the raw bytes with .jpg extension
            await snapshotFile.writeAsBytes(frameBytes);
            if (await snapshotFile.exists() && await snapshotFile.length() > 0) {
              _scheduleCleanup(snapshotFile.path);
              LoggerService.w('⚠️ Saved raw frame bytes as JPEG (may not be valid image)');
              return snapshotFile;
            }
          } catch (e3) {
            LoggerService.e('❌ Failed to save raw frame bytes: $e3');
            return null;
          }
        }
      }
      
      if (image == null) {
        LoggerService.e('❌ Unable to decode frame image with any method');
        return null;
      }
      
      // Resize if too large (max 1920x1080 for efficiency)
      if (image.width > 1920 || image.height > 1080) {
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (image.width > image.height) {
          newWidth = 1920;
          newHeight = (1920 / aspectRatio).round();
        } else {
          newHeight = 1080;
          newWidth = (1080 * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
        LoggerService.d('📐 Image resized to ${image.width}x${image.height}');
      }
      
      // Encode as JPEG with good quality
      final jpegBytes = img.encodeJpg(image, quality: 85);
      await snapshotFile.writeAsBytes(jpegBytes);
      
      if (await snapshotFile.exists() && await snapshotFile.length() > 0) {
        _scheduleCleanup(snapshotFile.path);
        LoggerService.i('✅ Frame snapshot captured successfully: ${snapshotFile.path}');
        return snapshotFile;
      } else {
        LoggerService.e('❌ Failed to write frame snapshot file');
        return null;
      }
    } catch (e, s) {
      LoggerService.e('❌ Frame snapshot failed', e, s);
      return null;
    }
  }

  void _scheduleCleanup(String filePath) {
    _cleanupTimers[filePath]?.cancel();
    _cleanupTimers[filePath] = Timer(_cleanupDelay, () {
      _cleanupSnapshot(filePath);
    });
  }

  Future<void> _cleanupSnapshot(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        LoggerService.d('Auto-deleted temporary frame snapshot: ${filePath.split('/').last}');
      }
    } catch (e) {
      LoggerService.e('Failed to cleanup frame snapshot $filePath', e);
    } finally {
      _cleanupTimers.remove(filePath);
    }
  }

  @override
  void onClose() {
    _disposed = true;
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    super.onClose();
  }
}
