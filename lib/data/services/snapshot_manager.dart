import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';
import 'rtsp_snapshot_service.dart';

class SnapshotManager extends GetxService {
  final RTSPSnapshotService _rtspService = Get.find<RTSPSnapshotService>();

  // Cache snapshots for 2 seconds to avoid RTSP spam for rapid alerts
  final Map<String, ({File file, DateTime timestamp})> _snapshotCache = {};
  
  // Persistent snapshot reference for logs
  final Map<String, File> _persistentSnapshots = {};

  Future<SnapshotResult> captureSnapshot({
    required String rtspUrl,
    required String cameraName,
  }) async {
    try {
      File? highResFile;
      String? lowResPath;

      // 1. Check Cache
      final cached = _snapshotCache[cameraName];
      if (cached != null) {
        final age = DateTime.now().difference(cached.timestamp);
        if (age.inSeconds < 2 && await cached.file.exists()) {
          LoggerService.d("♻️ Reusing recent snapshot for $cameraName");
          highResFile = cached.file;
        } else {
          _snapshotCache.remove(cameraName);
        }
      }

      // 2. Capture New if needed
      if (highResFile == null) {
        highResFile = await _rtspService.captureSnapshot(rtspUrl, cameraName: cameraName);
        if (highResFile != null) {
          _snapshotCache[cameraName] = (file: highResFile, timestamp: DateTime.now());
        }
      }
      
      if (highResFile == null) {
        final existing = _persistentSnapshots[cameraName];
        if (existing != null && await existing.exists()) {
          return SnapshotResult(highResFile: existing, lowResPath: existing.path);
        }
        return SnapshotResult(highResFile: null, lowResPath: null);
      }

      // 3. Save for long-term logs (7-day retention)
      if (AppConstants.testMode) {
        lowResPath = await _saveForLogs(highResFile, cameraName);
        if (lowResPath != null) {
          _persistentSnapshots[cameraName] = File(lowResPath);
        }
      }

      return SnapshotResult(
        highResFile: highResFile,
        lowResPath: lowResPath,
      );
    } catch (e) {
      LoggerService.e("Error in SnapshotManager", e);
      return SnapshotResult(highResFile: null, lowResPath: null);
    }
  }

  Future<String?> _saveForLogs(File sourceFile, String cameraName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeCamName = cameraName.replaceAll(RegExp(r'[^\w\-]'), '_');
      
      final snapshotDir = Directory('${appDir.path}/testlogs/$safeCamName/snapshot');
      if (!await snapshotDir.exists()) {
        await snapshotDir.create(recursive: true);
      }

      final now = DateTime.now();
      final formatter = DateFormat('dd-MM-yyyy_HH-mm-ss');
      final filename = "${safeCamName}_${formatter.format(now)}.jpg";
      
      final targetPath = '${snapshotDir.path}/$filename';
      await sourceFile.copy(targetPath);
      
      LoggerService.d("Log snapshot saved (7-day retention): $filename");
      return targetPath;
    } catch (e) {
      LoggerService.e("Failed to save log snapshot", e);
      return null;
    }
  }
}

class SnapshotResult {
  final File? highResFile;
  final String? lowResPath;

  SnapshotResult({required this.highResFile, required this.lowResPath});
}
