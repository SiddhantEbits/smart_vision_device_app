import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';

class RTSPSnapshotService extends GetxService {
  static const Duration _cleanupDelay = AppConstants.shortTermRetention;
  
  final Map<String, Timer> _cleanupTimers = {};
  bool _disposed = false;

  Future<File?> captureSnapshot(String rtspUrl, {String? cameraName}) async {
    if (_disposed) return null;

    LoggerService.i('📸 Capturing RTSP snapshot for ${cameraName ?? 'camera'}');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cameraTag = cameraName?.replaceAll(RegExp(r'[^\w\-]'), '_') ?? 'camera';
      final snapshotFile = File('${tempDir.path}/snapshot_${cameraTag}_$timestamp.jpg');
      
      final command = [
        '-y',
        '-rtsp_transport', 'tcp',
        '-i', rtspUrl,
        '-frames:v', '1',
        '-q:v', '2',
        '-timeout', '5000000',
        snapshotFile.path,
      ];

      final session = await FFmpegKit.execute(command.join(' '));
      final returnCode = await session.getReturnCode();
      
      if (returnCode != null && returnCode.isValueSuccess()) {
        if (await snapshotFile.exists() && await snapshotFile.length() > 0) {
          _scheduleCleanup(snapshotFile.path);
          return snapshotFile;
        }
      }
      throw Exception('FFmpeg failed or returned empty file');
    } catch (e, s) {
      LoggerService.e('RTSP Snapshot failed', e, s);
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
        LoggerService.d('Auto-deleted temporary snapshot: ${filePath.split('/').last}');
      }
    } catch (e) {
      LoggerService.e('Failed to cleanup snapshot $filePath', e);
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
