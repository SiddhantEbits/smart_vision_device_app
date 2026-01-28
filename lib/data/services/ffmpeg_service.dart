import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:get/get.dart';
import '../../core/logging/logger_service.dart';
import '../../core/error/crash_logger.dart';

typedef OnFrameCallback = void Function(Uint8List jpegBytes);

class FFmpegService extends GetxService {
  bool _isRunning = false;
  bool _disposed = false;
  bool _isExtracting = false;

  String? _currentUrl;
  String? _framePath;
  int? _sessionId;
  OnFrameCallback? _onFrame;
  String? _successfulStrategy; // Track which strategy worked

  DateTime? _lastFrameModified;
  Timer? _readingTimer;

  bool get isRunning => _isRunning;

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  Future<void> start(String rtspUrl, {required OnFrameCallback onFrame}) async {
    if (_disposed || _isRunning) return;

    // Validate URL before starting
    if (rtspUrl.isEmpty) {
      LoggerService.e('RTSP URL is empty, cannot start FFmpeg service');
      return;
    }
    
    if (!rtspUrl.startsWith('rtsp://') && !rtspUrl.startsWith('rtsps://')) {
      LoggerService.e('Invalid RTSP URL format: $rtspUrl');
      return;
    }

    _currentUrl = rtspUrl;
    _onFrame = onFrame;
    _isRunning = true;

    final tempDir = await Directory.systemTemp.createTemp('yolo_');
    _framePath = '${tempDir.path}/frame.jpg';

    LoggerService.i('Starting FFmpeg extractor for: $rtspUrl');

    await _testRTSPConnection();
    _startFFmpeg();
    _startReadingLoop();
  }

  Future<void> _testRTSPConnection() async {
    // Validate URL before testing
    if (_currentUrl == null || _currentUrl!.isEmpty) {
      LoggerService.e('RTSP URL is empty or null, skipping connection test');
      return;
    }
    
    // Basic URL validation
    if (!_currentUrl!.startsWith('rtsp://') && !_currentUrl!.startsWith('rtsps://')) {
      LoggerService.e('Invalid RTSP URL format: $_currentUrl');
      return;
    }
    
    // Use the same simple test as smart-camera-yolo
    final command = [
      '-rtsp_transport', 'tcp',
      '-rtsp_flags', 'prefer_tcp',
      '-i', _currentUrl!,
      '-t', '3',
      '-f', 'null',
      '-'
    ];

    try {
      LoggerService.i('Testing RTSP connection');
      final session = await FFmpegKit.execute(command.join(' '));
      final rc = await session.getReturnCode();
      
      if (rc != null && rc.isValueSuccess()) {
        LoggerService.i('RTSP Connection Test: Success');
        _successfulStrategy = 'TCP Low Bandwidth'; // Default strategy
      } else {
        LoggerService.w('RTSP Connection Test: Failed with return code: ${rc?.getValue()}');
        CrashLogger().logRTSPError(
          error: 'RTSP test failed',
          rtspUrl: _currentUrl!,
          operation: 'rtsp_test',
          returnCode: rc?.getValue(),
          ffmpegCommand: command.join(' '),
        );
      }
    } catch (e, s) {
      LoggerService.e('RTSP test exception: $e');
      CrashLogger().logRTSPError(
        error: e.toString(),
        rtspUrl: _currentUrl!,
        operation: 'rtsp_test_exception',
        stackTrace: s,
      );
    }
  }

  Future<void> _startFFmpeg() async {
    int retryCount = 0;
    const maxRetries = 3; // Limit retries to prevent infinite loop
    
    while (_isRunning && !_disposed && retryCount < maxRetries) {
      String rtspUrl = _currentUrl!;
      
      // Use the successful strategy if available
      if (_successfulStrategy == 'Alternative Path') {
        rtspUrl = _currentUrl!.replaceAll('/profile2', '/profile1');
        LoggerService.i('Using alternative path for main extraction');
      } else if (_successfulStrategy == 'Ultra Low Bandwidth') {
        LoggerService.i('Using ultra-low bandwidth settings for main extraction');
      }
      
      // Use the same working command as smart-camera-yolo
      final command = [
        '-rtsp_transport', 'tcp',
        '-rtsp_flags', 'prefer_tcp',
        '-i', rtspUrl,

        // BALANCED SETTINGS (same as smart-camera-yolo)
        '-vf', 'fps=2,scale=256:256',
        '-update', '1',
        '-y',

        // STABILITY (same as smart-camera-yolo)
        '-timeout', '15000000',
        '-analyzeduration', '1500000',
        '-probesize', '256',
        '-threads', '1',

        _framePath!
      ];

      try {
        LoggerService.i('Starting FFmpeg with balanced settings (strategy: $_successfulStrategy)');
        final session = await FFmpegKit.execute(command.join(' '));
        _sessionId = session.getSessionId();
        final returnCode = await session.getReturnCode();
        
        // Check if FFmpeg succeeded
        if (returnCode != null && returnCode.isValueSuccess()) {
          LoggerService.i('FFmpeg started successfully');
          return; // Success, exit the loop
        } else {
          LoggerService.w('FFmpeg failed with return code: ${returnCode?.getValue()}');
          retryCount++;
          if (retryCount < maxRetries) {
            LoggerService.i('Retrying FFmpeg (${retryCount}/$maxRetries)...');
            await Future.delayed(Duration(seconds: 2 * retryCount)); // Exponential backoff
          }
        }
      } catch (e, s) {
        LoggerService.e('FFmpeg exception: $e');
        CrashLogger().logRTSPError(
          error: e.toString(),
          rtspUrl: _currentUrl!,
          operation: 'ffmpeg_runtime',
          stackTrace: s,
          ffmpegCommand: command.join(' '),
        );
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount)); // Exponential backoff
        }
      }
    }
    
    if (retryCount >= maxRetries) {
      LoggerService.e('FFmpeg failed after $maxRetries attempts. Stopping retries.');
      CrashLogger().logRTSPError(
        error: 'FFmpeg failed after $maxRetries attempts',
        rtspUrl: _currentUrl!,
        operation: 'ffmpeg_max_retries',
      );
      // Stop the service to prevent infinite loops
      _isRunning = false;
    }
  }

  void _startReadingLoop() {
    Timer.periodic(
      const Duration(milliseconds: 500), // Match 2 FPS extraction rate (same as smart-camera-yolo)
      (timer) async {
        if (!_isRunning || _disposed || _isExtracting) return;

        _isExtracting = true;

        try {
          final file = File(_framePath!);
          if (!await file.exists()) return;

          final stat = await file.stat();

          // Skip duplicate frames
          if (_lastFrameModified == stat.modified) return;
          _lastFrameModified = stat.modified;

          final bytes = await file.readAsBytes();

          // JPEG integrity check
          if (bytes.length < 4 ||
              bytes[0] != 0xFF ||
              bytes[1] != 0xD8 ||
              bytes[bytes.length - 2] != 0xFF ||
              bytes[bytes.length - 1] != 0xD9) {
            return;
          }

          _onFrame!(bytes);
        } catch (_) {
          // Ignore mid-write or IO race safely
        } finally {
          _isExtracting = false;
        }
      },
    );
  }

  Future<void> stop() async {
    LoggerService.i('Stopping FFmpeg service...');
    _isRunning = false;

    if (_sessionId != null) {
      await FFmpegKit.cancel(_sessionId!);
      _sessionId = null;
    }

    _currentUrl = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();

    if (_framePath != null) {
      try {
        final file = File(_framePath!);
        if (await file.exists()) {
          await file.parent.delete(recursive: true);
        }
      } catch (e) {
        LoggerService.e('Failed to cleanup temp files: $e');
      }
    }
  }
}
