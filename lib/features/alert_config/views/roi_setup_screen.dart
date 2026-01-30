import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/roi_config_model.dart' as roi_model;
import '../../../data/models/roi_config.dart' as camera_config;
import '../../../data/models/camera_config.dart';
import '../../../data/repositories/simple_storage_service.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/logging/logger_service.dart';
import 'widgets/roi/footfall_canvas.dart';
import '../../../features/camera_setup/controller/camera_setup_controller.dart';

class RoiSetupScreen extends StatefulWidget {
  const RoiSetupScreen({super.key});

  @override
  State<RoiSetupScreen> createState() => _RoiSetupScreenState();
}

class _RoiSetupScreenState extends State<RoiSetupScreen> {
  late DetectionType detectionType;
  late Function(List<Offset>, String) onComplete;
  
  roi_model.RoiAlertConfig roiConfig = roi_model.RoiAlertConfig.forFootfall();
  
  // Media Kit player for RTSP stream
  late Player player;
  late VideoController videoController;
  final CameraSetupController cameraSetupController = Get.find<CameraSetupController>();
  
  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>;
    detectionType = arguments['detectionType'] as DetectionType;
    onComplete = arguments['onComplete'] as Function(List<Offset>, String);
    
    // Initialize ROI config based on detection type
    if (detectionType == DetectionType.footfallDetection) {
      roiConfig = roi_model.RoiAlertConfig.forFootfall();
    } else if (detectionType == DetectionType.restrictedArea) {
      roiConfig = roi_model.RoiAlertConfig.forRestrictedArea();
    }
    
    // Initialize Media Kit player
    _initializePlayer();
  }
  
  void _initializePlayer() {
    player = Player();
    videoController = VideoController(player);
    
    // Start RTSP stream if URL is available
    if (cameraSetupController.rtspUrl.value.isNotEmpty) {
      player.open(Media(cameraSetupController.rtspUrl.value));
      player.play();
    }
  }
  
  void _stopRTSPStream() {
    try {
      player.stop();
      debugPrint('RTSP stream stopped in ROI setup');
    } catch (e) {
      debugPrint('Error stopping RTSP stream: $e');
    }
  }
  
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Left Side - Controls (35%)
          Expanded(
            flex: 35,
            child: Container(
              padding: EdgeInsets.all(24.adaptSize),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
              ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Get.back();
                        },
                      ),
                      SizedBox(width: 12.adaptSize),
                      Expanded(
                        child: Text(
                          'ROI Setup - ${_getTitle(detectionType)}',
                          style: TextStyle(
                            fontSize: 18.adaptSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32.adaptSize),
                  
                  // Status Card
                  Container(
                    padding: EdgeInsets.all(20.adaptSize),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16.adaptSize),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12.adaptSize,
                              height: 12.adaptSize,
                              decoration: BoxDecoration(
                                color: detectionType == DetectionType.restrictedArea ? Colors.red : Colors.green,
                              ),
                            ),
                            SizedBox(width: 12.adaptSize),
                            Text(
                              detectionType == DetectionType.footfallDetection 
                                  ? 'ROI + Line Active'
                                  : 'ROI Active',
                              style: TextStyle(
                                fontSize: 14.adaptSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 12.adaptSize),
                        
                        // Detection Type Status
                        Text(
                          detectionType == DetectionType.footfallDetection 
                              ? 'ROI + Line Active'
                              : 'ROI Active',
                          style: TextStyle(
                            fontSize: 14.adaptSize,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24.adaptSize),
                  
                  // Stream Status
                  if (cameraSetupController.rtspUrl.value.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16.adaptSize),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12.adaptSize),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8.adaptSize,
                            height: 8.adaptSize,
                            decoration: BoxDecoration(
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(width: 12.adaptSize),
                          Text(
                            'LIVE STREAM',
                            style: TextStyle(
                              fontSize: 12.adaptSize,
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(16.adaptSize),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12.adaptSize),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, size: 18.adaptSize, color: Colors.orange),
                          SizedBox(width: 12.adaptSize),
                          Expanded(
                            child: Text(
                              'No RTSP Stream',
                              style: TextStyle(
                                fontSize: 11.adaptSize,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 32.adaptSize),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // Clear Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              if (detectionType == DetectionType.footfallDetection) {
                                roiConfig = roi_model.RoiAlertConfig.forFootfall();
                              } else {
                                roiConfig = roi_model.RoiAlertConfig.forRestrictedArea();
                              }
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14.adaptSize),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.adaptSize),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          child: Text(
                            'Clear ROI',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14.adaptSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16.adaptSize),
                      
                      // Save & Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.adaptSize),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 20.adaptSize),
                              SizedBox(width: 12.adaptSize),
                              Text(
                                'Save & Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.adaptSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24.adaptSize),
                ],
              ),
            ),
          ),
          
          // Right Side - Preview (65%)
          Expanded(
            flex: 65,
            child: Container(
              margin: EdgeInsets.all(16.adaptSize),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16.adaptSize),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.adaptSize),
                child: Stack(
                  children: [
                    // RTSP Stream
                    if (cameraSetupController.rtspUrl.value.isNotEmpty)
                      Video(
                        controller: videoController,
                        controls: NoVideoControls,
                        fit: BoxFit.contain,
                        wakelock: false,
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              size: 80.adaptSize,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16.adaptSize),
                            Text(
                              'No RTSP Stream Available',
                              style: TextStyle(
                                fontSize: 18.adaptSize,
                                color: Colors.white54,
                              ),
                            ),
                            SizedBox(height: 8.adaptSize),
                            Text(
                              'Please configure camera settings first',
                              style: TextStyle(
                                fontSize: 14.adaptSize,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // ROI Canvas Overlay
                    Positioned.fill(
                      child: FootfallCanvas(
                        config: roiConfig,
                        onChanged: (newConfig) {
                          setState(() => roiConfig = newConfig);
                        },
                        showLine: detectionType == DetectionType.footfallDetection,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(DetectionType type) {
    switch (type) {
      case DetectionType.crowdDetection: return 'Crowd Detection';
      case DetectionType.absentAlert: return 'Absent Alert';
      case DetectionType.footfallDetection: return 'Footfall Detection';
      case DetectionType.restrictedArea: return 'Restricted Area';
      case DetectionType.sensitiveAlert: return 'Sensitive Alert';
    }
  }

  void _saveAndContinue() {
    // Stop RTSP stream before continuing
    _stopRTSPStream();
    
    // Collect ROI points based on detection type
    List<Offset> roiPoints;
    
    if (detectionType == DetectionType.restrictedArea) {
      // For restricted area, use rectangle corners (top-left, bottom-right)
      roiPoints = [
        roiConfig.roi.topLeft,
        roiConfig.roi.bottomRight,
      ];
    } else {
      // For footfall, use line points
      roiPoints = [
        roiConfig.lineStart,
        roiConfig.lineEnd,
      ];
    }
    
    final roiType = detectionType == DetectionType.footfallDetection ? 'line' : 'box';
    
    // Debug logging
    LoggerService.i('ROI Setup - Detection Type: $detectionType');
    LoggerService.i('ROI Setup - ROI Type: $roiType');
    if (detectionType == DetectionType.restrictedArea) {
      LoggerService.i('ROI Setup - ROI Rectangle: ${roiConfig.roi}');
      LoggerService.i('ROI Setup - Top Left: ${roiConfig.roi.topLeft}');
      LoggerService.i('ROI Setup - Bottom Right: ${roiConfig.roi.bottomRight}');
    } else {
      LoggerService.i('ROI Setup - Line Start: ${roiConfig.lineStart}');
      LoggerService.i('ROI Setup - Line End: ${roiConfig.lineEnd}');
    }
    LoggerService.i('ROI Setup - ROI Points: $roiPoints');
    
    // Save ROI configuration to current camera in local storage
    _saveRoiConfigToCurrentCamera();
    
    // Call the onComplete callback with proper type casting
    onComplete(roiPoints.cast<Offset>(), roiType);
    
    // Don't call Get.back() here - the callback will handle navigation
    // This allows the flow to continue to the next detection configuration
  }

  void _saveRoiConfigToCurrentCamera() {
    try {
      // Get the current camera from CameraSetupController
      final currentCamera = cameraSetupController.currentCamera;
      
      if (currentCamera == null) {
        LoggerService.w('❌ No current camera found to save ROI configuration');
        Get.snackbar(
          'Error',
          'No camera selected. Please select a camera first.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Create a copy of the current camera with updated ROI configuration
      final updatedCamera = _applyRoiConfigToCamera(currentCamera);
      
      // Update the camera in the list
      final cameraIndex = cameraSetupController.cameras.indexWhere((c) => c.name == currentCamera.name);
      if (cameraIndex != -1) {
        cameraSetupController.updateCamera(cameraIndex, updatedCamera);
        
        LoggerService.i('✅ ROI configuration saved to camera: ${currentCamera.name} for detection: $detectionType');
        
        Get.snackbar(
          'ROI Saved',
          'ROI configuration saved to ${currentCamera.name}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        LoggerService.e('❌ Camera not found in list: ${currentCamera.name}');
      }
    } catch (e) {
      LoggerService.e('❌ Failed to save ROI configuration to camera', e);
      Get.snackbar(
        'Save Failed',
        'Failed to save ROI configuration: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  CameraConfig _applyRoiConfigToCamera(CameraConfig camera) {
    // Create a copy of the camera with updated ROI configuration
    final updatedCamera = CameraConfig(
      name: camera.name,
      url: camera.url,
      confidenceThreshold: camera.confidenceThreshold,
      
      // Preserve all existing detection settings
      peopleCountEnabled: camera.peopleCountEnabled,
      maxPeople: camera.maxPeople,
      maxPeopleCooldownSeconds: camera.maxPeopleCooldownSeconds,
      maxPeopleSchedule: camera.maxPeopleSchedule,
      
      footfallEnabled: camera.footfallEnabled,
      footfallIntervalMinutes: camera.footfallIntervalMinutes,
      footfallSchedule: camera.footfallSchedule,
      
      restrictedAreaEnabled: camera.restrictedAreaEnabled,
      restrictedAreaCooldownSeconds: camera.restrictedAreaCooldownSeconds,
      restrictedAreaSchedule: camera.restrictedAreaSchedule,
      
      theftAlertEnabled: camera.theftAlertEnabled,
      theftCooldownSeconds: camera.theftCooldownSeconds,
      theftSchedule: camera.theftSchedule,
      
      absentAlertEnabled: camera.absentAlertEnabled,
      absentSeconds: camera.absentSeconds,
      absentCooldownSeconds: camera.absentCooldownSeconds,
      absentSchedule: camera.absentSchedule,
      
      // Apply ROI configuration based on detection type
      footfallConfig: detectionType == DetectionType.footfallDetection ? _convertRoiConfig(roiConfig) : camera.footfallConfig,
      restrictedAreaConfig: detectionType == DetectionType.restrictedArea ? _convertRoiConfig(roiConfig) : camera.restrictedAreaConfig,
    );
    
    return updatedCamera;
  }

  /// Convert RoiAlertConfig from roi_config_model.dart to roi_config.dart
  camera_config.RoiAlertConfig _convertRoiConfig(roi_model.RoiAlertConfig sourceConfig) {
    return camera_config.RoiAlertConfig(
      roi: sourceConfig.roi,
      lineStart: sourceConfig.lineStart,
      lineEnd: sourceConfig.lineEnd,
      direction: sourceConfig.direction,
    );
  }
}
