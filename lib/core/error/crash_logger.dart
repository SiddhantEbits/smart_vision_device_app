import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../logging/logger_service.dart';

class CrashLogger {
  static final CrashLogger _instance = CrashLogger._internal();
  factory CrashLogger() => _instance;
  CrashLogger._internal();

  Future<void> logDetectionError({
    required String error,
    required String operation,
    StackTrace? stackTrace,
    double? confidence,
  }) async {
    final message = '[DETECTION ERROR] Op: $operation | Error: $error | Conf: $confidence';
    LoggerService.e(message, error, stackTrace);

    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Detection Failure during $operation',
        information: [
          'operation: $operation',
          if (confidence != null) 'confidence: $confidence',
        ],
      );
    }
  }

  Future<void> logGeneralError(dynamic error, StackTrace stackTrace, {String? reason}) async {
    LoggerService.e('General Error: $reason', error, stackTrace);
    
    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
      );
    }
  }

  Future<void> logRTSPError({
    required String error,
    required String rtspUrl,
    required String operation,
    int? returnCode,
    String? ffmpegCommand,
    StackTrace? stackTrace,
  }) async {
    final message = '[RTSP ERROR] Op: $operation | RC: $returnCode | URL: $rtspUrl';
    LoggerService.e(message, error, stackTrace);

    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'RTSP Failure: $operation',
        information: [
          'rtspUrl: $rtspUrl',
          'operation: $operation',
          if (returnCode != null) 'returnCode: $returnCode',
          if (ffmpegCommand != null) 'ffmpegCommand: $ffmpegCommand',
        ],
      );
    }
  }

  void logEvent(String message) {
    LoggerService.i(message);
    FirebaseCrashlytics.instance.log(message);
  }
}
