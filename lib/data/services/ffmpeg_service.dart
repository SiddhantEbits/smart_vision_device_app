import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import '../../core/error/crash_logger.dart';
import '../../core/logging/logger_service.dart';

typedef OnRawFrameCallback = void Function(Uint8List jpegBytes);

class FFmpegService extends GetxService {
  OnRawFrameCallback? _onFrame;
  bool _isRunning = false;
  bool _isExtracting = false;
  String? _currentUrl;
  String? _framePath;
  int? _sessionId;
  DateTime? _lastFrameModified;
  Timer? _readingTimer;

  bool get isRunning => _isRunning;

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  Future<void> start(String rtspUrl, OnRawFrameCallback onFrame) async {
    if (_isRunning) await stop();

    _onFrame = onFrame;
    _currentUrl = rtspUrl;
    _isRunning = true;

    try {
      final tempDir = await Directory.systemTemp.createTemp('smart_vision_');
      _framePath = '${tempDir.path}/frame.jpg';
      
      LoggerService.i('Starting FFmpeg extractor for: $rtspUrl');
      
      await _testRTSPConnection();
      _startFFmpegLoop();
      _startReadingLoop();
    } catch (e, s) {
      LoggerService.e('Failed to initialize FFmpeg extractor', e, s);
      _isRunning = false;
    }
  }

  Future<void> _testRTSPConnection() async {
    if (_currentUrl == null) return;
    
    final command = [
      '-rtsp_transport', 'tcp',
      '-rtsp_flags', 'prefer_tcp',
      '-i', _currentUrl!,
      '-t', '3',
      '-f', 'null',
      '-'
    ];

    try {
      final session = await FFmpegKit.execute(command.join(' '));
      final rc = await session.getReturnCode();

      if (rc == null || !rc.isValueSuccess()) {
        CrashLogger().logRTSPError(
          error: 'RTSP connection test failed',
          rtspUrl: _currentUrl!,
          operation: 'test_connection',
          returnCode: rc?.getValue(),
          ffmpegCommand: command.join(' '),
        );
      } else {
        LoggerService.i('RTSP Connection Test: Success');
      }
    } catch (e, s) {
      CrashLogger().logRTSPError(
        error: e.toString(),
        rtspUrl: _currentUrl!,
        operation: 'test_connection_exception',
        stackTrace: s,
      );
    }
  }

  void _startFFmpegLoop() async {
    while (_isRunning) {
      if (_currentUrl == null || _framePath == null) break;

      final command = [
        '-rtsp_transport', 'tcp',
        '-rtsp_flags', 'prefer_tcp',
        '-i', _currentUrl!,
        '-vf', 'fps=2,scale=640:640', // Balanced resolution for YOLO
        '-update', '1',
        '-y',
        '-timeout', '15000000',
        '-analyzeduration', '1500000',
        '-probesize', '256',
        '-threads', '1',
        _framePath!
      ];

      try {
        final session = await FFmpegKit.execute(command.join(' '));
        _sessionId = session.getSessionId();
        final rc = await session.getReturnCode();
        
        if (rc != null && !rc.isValueSuccess() && _isRunning) {
          LoggerService.w('FFmpeg session ended with error code: ${rc.getValue()}');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e, s) {
        CrashLogger().logRTSPError(
          error: e.toString(),
          rtspUrl: _currentUrl!,
          operation: 'ffmpeg_runtime',
          stackTrace: s,
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _startReadingLoop() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isRunning || _isExtracting || _framePath == null || _onFrame == null) return;

      _isExtracting = true;
      try {
        final file = File(_framePath!);
        if (!await file.exists()) return;

        final stat = await file.stat();
        if (_lastFrameModified == stat.modified) return;
        _lastFrameModified = stat.modified;

        final bytes = await file.readAsBytes();

        // Basic JPEG validation
        if (bytes.length > 4 && 
            bytes[0] == 0xFF && bytes[1] == 0xD8 && 
            bytes[bytes.length - 2] == 0xFF && bytes[bytes.length - 1] == 0xD9) {
          _onFrame!(bytes);
        }
      } catch (e) {
        // Safe to ignore minor IO races
      } finally {
        _isExtracting = false;
      }
    });
  }

  Future<void> stop() async {
    LoggerService.i('Stopping FFmpeg service...');
    _isRunning = false;
    _readingTimer?.cancel();
    
    if (_sessionId != null) {
      await FFmpegKit.cancel(_sessionId!);
      _sessionId = null;
    }

    if (_framePath != null) {
      try {
        final file = File(_framePath!);
        if (await file.exists()) {
          await file.parent.delete(recursive: true);
        }
      } catch (_) {}
      _framePath = null;
    }
    
    _currentUrl = null;
    _onFrame = null;
  }
}
