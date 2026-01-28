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
  });

  @override
  State<RTSPPreviewWidget> createState() => _RTSPPreviewWidgetState();
}

class _RTSPPreviewWidgetState extends State<RTSPPreviewWidget> {
  Player? player;
  VideoController? videoController;
  bool isPlayerInitialized = false;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      player = Player();
      videoController = VideoController(player!);
      
      // Configure player for RTSP
      await player!.setVolume(0); // Mute for preview
      
      setState(() {
        isPlayerInitialized = true;
      });
      
      // Start playing RTSP stream
      await player!.open(
        Media(widget.rtspUrl),
        play: true,
      );
      
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
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
