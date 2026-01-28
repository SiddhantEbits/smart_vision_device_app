import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import 'ffmpeg_service.dart';
import 'video_service_interface.dart';
import 'rtsp_snapshot_service.dart';
import '../../core/logging/logger_service.dart';
import '../../core/error/crash_logger.dart';

typedef OnFrameCallback = void Function(Uint8List jpegBytes);

class VideoService implements VideoServiceInterface {
  late final Player player;
  late final VideoController videoController;
  late final FFmpegService ffmpegExtractor;
  late final RTSPSnapshotService snapshotService;

  final OnFrameCallback onFrame;
  final GlobalKey _videoKey = GlobalKey();

  bool _videoReady = false;
  bool _disposed = false;
  String? _currentUrl;
  String? get currentUrl => _currentUrl;

  ui.Image? _lastFrame;

  VideoService({required this.onFrame}) {
    // Initialize FFmpeg extractor for YOLO inference
    ffmpegExtractor = FFmpegService();

    // Initialize RTSP snapshot service
    snapshotService = RTSPSnapshotService();

    // Initialize Media Kit for stable preview with buffering
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 256 * 1024, // 256KB buffer for stability
        title: 'STABLE-PREVIEW',
      ),
    );

    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false, // Disable for stability on H616
      ),
    );

    _applySafeLatency();
    _listenPlayback();
  }

  // ==================================================
  // CAMERA CONTROL
  // ==================================================
  Future<void> open(String url) async {
    if (_disposed) return;

    _videoReady = false;
    _currentUrl = url;

    LoggerService.i('🎥 [VIDEO_SERVICE] Opening stream: $url');

    // Start FFmpeg persistent frame extraction for YOLO
    try {
      await ffmpegExtractor.start(url, onFrame: onFrame);
      LoggerService.i('🎥 [VIDEO_SERVICE] FFmpeg extractor started');
    } catch (e, stack) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Failed to start FFmpeg extractor: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'ffmpeg_start',
        stackTrace: stack,
      );
      // Don't return - continue with Media Kit even if FFmpeg fails
    }

    // Start Media Kit for preview
    try {
      await player.stop();
      
      await player.open(
        Media(
          url,
          extras: {
            "rtsp_transport": "tcp",
            "rtsp_flags": "prefer_tcp",
            "analyzeduration": "1000000", // 1 second
            "probesize": "128",
            "buffer_size": "65536", // 64KB buffer
            "max_delay": "500000", // 0.5 second
            "framedrop": "1", // Frame dropping for stability
          },
        ),
        play: true,
      );
      
      LoggerService.i('🎥 [VIDEO_SERVICE] MediaKit preview started successfully');
    } catch (e, stack) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Failed to start MediaKit preview: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'mediakit_start',
        stackTrace: stack,
      );
      // Don't return - FFmpeg extraction can work independently
    }
  }

  Future<void> stop() async {
    LoggerService.i('🎥 [VIDEO_SERVICE] Stopping video service...');

    try {
      await player.stop();
    } catch (e) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Error stopping MediaKit player: $e');
    }

    try {
      await ffmpegExtractor.stop();
    } catch (e) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Error stopping FFmpeg extractor: $e');
    }

    _videoReady = false;
    _currentUrl = null;
    _lastFrame = null;

    LoggerService.i('🎥 [VIDEO_SERVICE] Video service stopped');
  }

  // ==================================================
  // FRAME CAPTURE (Manual - for snapshots)
  // ==================================================
  Future<ui.Image?> captureFrame() async {
    if (!_videoReady || _videoKey.currentContext == null) {
      LoggerService.w('🎥 [VIDEO_SERVICE] Cannot capture frame - video not ready');
      return null;
    }

    try {
      final boundary = _videoKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: AppConstants.snapshotPixelRatio);
      _lastFrame = image;
      return image;
    } catch (e, stack) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Frame capture failed: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'captureFrame',
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<Uint8List?> captureFrameAsJpeg() async {
    final image = await captureFrame();
    if (image == null) return null;

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // Convert PNG to JPEG for better compression
      final pngBytes = byteData.buffer.asUint8List();
      final pngImage = img.decodePng(pngBytes);
      if (pngImage == null) return null;

      final jpegBytes = img.encodeJpg(pngImage, quality: AppConstants.snapshotJpegQuality);
      return Uint8List.fromList(jpegBytes);
    } catch (e, stack) {
      LoggerService.e('🎥 [VIDEO_SERVICE] JPEG conversion failed: $e');
      CrashLogger().logDetectionError(
        error: e.toString(),
        operation: 'captureFrameAsJpeg',
        stackTrace: stack,
      );
      return null;
    }
  }

  // ==================================================
  // SNAPSHOT SERVICE
  // ==================================================
  Future<String?> takeSnapshot(String cameraName) async {
    final snapshotFile = await snapshotService.captureSnapshot(
      _currentUrl ?? '',
      cameraName: cameraName,
    );
    return snapshotFile?.path;
  }

  // ==================================================
  // STATE HELPERS
  // ==================================================
  bool get isVideoReady => _videoReady;
  bool get isDisposed => _disposed;
  GlobalKey get videoKey => _videoKey;

  // ==================================================
  // MEDIA KIT CONFIGURATION
  // ==================================================
  void _applySafeLatency() {
    try {
      player.setVolume(0.0); // Mute for surveillance
      LoggerService.d('🎥 [VIDEO_SERVICE] Applied safe latency settings');
    } catch (e) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Failed to apply safe latency: $e');
    }
  }

  void _listenPlayback() {
    player.streams.error.listen((error) {
      LoggerService.e('🎥 [VIDEO_SERVICE] MediaKit playback error: $error');
      CrashLogger().logDetectionError(
        error: error.toString(),
        operation: 'mediakit_playback',
      );
    });

    player.streams.buffering.listen((buffering) {
      if (buffering) {
        LoggerService.d('🎥 [VIDEO_SERVICE] MediaKit buffering...');
      } else {
        LoggerService.d('🎥 [VIDEO_SERVICE] MediaKit buffer ready');
        _videoReady = true;
      }
    });

    player.streams.completed.listen((_) {
      LoggerService.w('🎥 [VIDEO_SERVICE] MediaKit playback completed');
      _videoReady = false;
    });
  }

  // ==================================================
  // DISPOSE
  // ==================================================
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    LoggerService.i('🎥 [VIDEO_SERVICE] Disposing video service...');

    await stop();

    try {
      await player.dispose();
    } catch (e) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Error disposing MediaKit player: $e');
    }

    try {
      await ffmpegExtractor.dispose();
    } catch (e) {
      LoggerService.e('🎥 [VIDEO_SERVICE] Error disposing FFmpeg extractor: $e');
    }

    LoggerService.i('🎥 [VIDEO_SERVICE] Video service disposed');
  }
}
