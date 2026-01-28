import 'dart:typed_data';

/// Abstract interface for video services
/// Allows different implementations (MediaKit, Optimized, etc.)
abstract class VideoServiceInterface {
  /// Open RTSP stream
  Future<void> open(String url);
  
  /// Stop streaming
  Future<void> stop();
  
  /// Dispose resources
  Future<void> dispose();
  
  /// Current stream URL
  String? get currentUrl;
  
  /// Whether video is ready
  bool get isVideoReady;
  
  /// Whether service is disposed
  bool get isDisposed;
}
