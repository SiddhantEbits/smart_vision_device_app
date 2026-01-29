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

  @override
  State<RTSPPreviewWidget> createState() => _RTSPPreviewWidgetState();
}

class _RTSPPreviewWidgetState extends State<RTSPPreviewWidget> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground, start stream if autoStart is enabled
        if (widget.autoStart && !_isStreamActive) {
          _startStream();
        }
        break;
      case AppLifecycleState.paused:
        // App is in background, stop stream to save resources
        _stopStream();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Stop stream when app is not visible
        _stopStream();
        break;
    }
  }

  // Public methods for lifecycle control
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

  void _disposePlayer() {
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

    return Container(
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
    );
  }
}
