import 'package:flutter/material.dart';
import '../widgets/common/rtsp_preview_widget.dart';

/// Global RTSP Stream Manager
/// Provides static methods to control all RTSP streams across the app
class RTSPStreamManager {
  
  /// Kill all running RTSP streams
  /// This will stop all active RTSP preview widgets
  static Future<void> killAllStreams() async {
    debugPrint('[RTSP Manager] Killing all streams...');
    await RTSPPreviewWidget.killAllStreams();
    debugPrint('[RTSP Manager] All streams killed');
  }
  
  /// Reinitialize all RTSP streams
  /// This will restart all RTSP preview widgets with fresh MediaKit instances
  static Future<void> reinitializeAllStreams() async {
    debugPrint('[RTSP Manager] Reinitializing all streams...');
    await RTSPPreviewWidget.reinitializeAllStreams();
    debugPrint('[RTSP Manager] All streams reinitialized');
  }
  
  /// Reset all RTSP streams (kill + reinitialize)
  /// This is the main method to use for complete stream reset
  static Future<void> resetAllStreams() async {
    debugPrint('[RTSP Manager] Starting complete stream reset...');
    
    // Step 1: Kill all streams
    await killAllStreams();
    
    // Wait for cleanup
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Step 2: Reinitialize all streams
    await reinitializeAllStreams();
    
    debugPrint('[RTSP Manager] Complete stream reset finished');
  }
  
  /// Check if any streams are currently active
  static bool hasActiveStreams() {
    return RTSPPreviewWidget._activeInstances.isNotEmpty;
  }
  
  /// Get count of active streams
  static int getActiveStreamCount() {
    return RTSPPreviewWidget._activeInstances.length;
  }
}
