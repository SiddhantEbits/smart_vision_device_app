import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class RTSPPreviewWidget extends StatefulWidget {
  final String rtspUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color backgroundColor;
  final Widget? placeholder;
  final bool showControls;
  final BoxFit fit;
  final bool autoStart;

  // Static list to track all active instances
  static final List<RTSPPreviewWidgetState> _activeInstances = [];

  const RTSPPreviewWidget({
    super.key,
    required this.rtspUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.border,
    this.backgroundColor = Colors.black,
    this.placeholder,
    this.showControls = false,
    this.fit = BoxFit.contain,
    this.autoStart = true,
  });

  // Static method to kill all RTSP streams
  static Future<void> killAllStreams() async {
    debugPrint('[RTSP] Killing all active streams...');
    
    // Copy list to avoid modification during iteration
    final instances = List.from(_activeInstances);
    
    for (final instance in instances) {
      if (instance.mounted && !instance._isDisposed) {
        await instance._stopStream();
      }
    }
    
    debugPrint('[RTSP] All streams killed');
  }

  // Static method to reinitialize all streams
  static Future<void> reinitializeAllStreams() async {
    debugPrint('[RTSP] Reinitializing all streams...');
    
    // Copy list to avoid modification during iteration
    final instances = List.from(_activeInstances);
    
    for (final instance in instances) {
      if (instance.mounted && !instance._isDisposed) {
        await instance.resetAllStreams();
      }
    }
    
    debugPrint('[RTSP] All streams reinitialized');
  }

  @override
  State<RTSPPreviewWidget> createState() => RTSPPreviewWidgetState();
}

class RTSPPreviewWidgetState extends State<RTSPPreviewWidget> {
  Player? player;
  VideoController? videoController;
  bool isPlayerInitialized = false;
  bool hasError = false;
  String errorMessage = '';
  bool _isDisposed = false;
  bool _isStreamActive = false;

  @override
  void initState() {
    super.initState();
    
    // Add to active instances list
    RTSPPreviewWidget._activeInstances.add(this);
    
    if (widget.autoStart) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    // Remove from active instances list
    RTSPPreviewWidget._activeInstances.remove(this);
    
    // Dispose player synchronously for dispose method
    _isDisposed = true;
    _isStreamActive = false;
    
    // Stop stream before disposing
    if (player != null) {
      try {
        player!.stop();
      } catch (e) {
        print('Error stopping stream during disposal: $e');
      }
    }
    
    // Dispose player
    player?.dispose();
    player = null;
    videoController = null;
    
    super.dispose();
  }

  // Public methods for external control
  void startStream() {
    if (!_isStreamActive && !_isDisposed) {
      _startStream();
    }
  }

  void stopStream() {
    if (_isStreamActive && !_isDisposed) {
      _stopStream();
    }
  }

  // Reset all RTSP streams and reinitialize MediaKit
  Future<void> resetAllStreams() async {
    if (_isDisposed) return;
    
    // Kill all streams globally
    await RTSPPreviewWidget.killAllStreams();
    
    // Wait a moment for cleanup
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Reinitialize all streams globally
    await RTSPPreviewWidget.reinitializeAllStreams();
  }

  // Force complete reset of this specific widget
  Future<void> forceReset() async {
    if (_isDisposed) return;
    
    debugPrint('[RTSP] Force resetting widget...');
    
    // Stop current stream
    await _stopStream();
    
    // Dispose current player completely (synchronous)
    _isDisposed = true;
    _isStreamActive = false;
    
    if (player != null) {
      try {
        await player!.stop();
      } catch (e) {
        print('Error stopping stream during force reset: $e');
      }
      player?.dispose();
      player = null;
      videoController = null;
    }
    
    // Wait for cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reinitialize if not disposed
    if (!_isDisposed && mounted) {
      setState(() {
        hasError = false;
        errorMessage = '';
        isPlayerInitialized = false;
        _isDisposed = false; // Reset disposal flag for reinitialization
      });
      
      await _initializePlayer();
      debugPrint('[RTSP] Force reset complete');
    }
  }

  Future<void> _initializePlayer() async {
    if (_isDisposed) return;
    
    try {
      player = Player();
      videoController = VideoController(player!);
      
      // Configure player for RTSP
      await player!.setVolume(0); // Mute for preview
      
      setState(() {
        isPlayerInitialized = true;
      });
      
      // Start playing RTSP stream
      await _startStream();
      
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          hasError = true;
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _startStream() async {
    if (player == null || _isDisposed || _isStreamActive) return;
    
    try {
      await player!.open(
        Media(widget.rtspUrl),
        play: true,
      );
      _isStreamActive = true;
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          hasError = true;
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _stopStream() async {
    if (player == null || !_isStreamActive || _isDisposed) return;
    
    try {
      await player!.stop();
      _isStreamActive = false;
    } catch (e) {
      // Log error but don't update state if disposed
      if (!_isDisposed) {
        print('Error stopping stream: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: widget.borderRadius,
          border: widget.border,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'RTSP Connection Error',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (!isPlayerInitialized) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: widget.borderRadius,
          border: widget.border,
        ),
        child: widget.placeholder ?? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: widget.borderRadius,
            border: widget.border,
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: Video(
              controller: videoController!,
              controls: widget.showControls ? NoVideoControls : null,
              fit: widget.fit,
              wakelock: false,
            ),
          ),
        ),
        // Reset button overlay
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: resetAllStreams,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
