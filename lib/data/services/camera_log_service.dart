import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';

class CameraLogService extends GetxService {
  final Map<String, Completer<void>?> _writeLocks = {};

  Future<void> logAlert({
    required String cameraName,
    required String alertType,
    required String? snapshotPath,
    String startCpuUsage = "0.0%",
  }) async {
    if (!AppConstants.testMode) return;

    // Use specific lock per camera to avoid blocking everything
    while (_writeLocks[cameraName]?.isCompleted == false) {
      await _writeLocks[cameraName]!.future;
    }
    
    final completer = Completer<void>();
    _writeLocks[cameraName] = completer;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeCamName = cameraName.replaceAll(RegExp(r'[^\w\-]'), '_');
      
      final workspaceDir = Directory('${appDir.path}/testlogs/$safeCamName');
      if (!await workspaceDir.exists()) {
        await workspaceDir.create(recursive: true);
      }

      final logFile = File('${workspaceDir.path}/${safeCamName}_log.txt');
      
      final now = DateTime.now();
      final timestamp = DateFormat('dd-MM-yyyy HH:mm:ss.SSS').format(now);
      final snapshotName = (snapshotPath != null) ? snapshotPath.split('/').last : "NO_SNAPSHOT";
      
      final logLine = "$timestamp | $alertType | $snapshotName | $startCpuUsage";
      await logFile.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
      
      LoggerService.d("Log entry written for $cameraName: $alertType");
    } catch (e) {
      LoggerService.e("CameraLogService: Failed to write log", e);
    } finally {
      completer.complete();
      _writeLocks.remove(cameraName);
    }
  }
}
