import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controller/monitoring_controller.dart';
import 'widgets/detection_overlay.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/camera_config.dart';
import '../../../data/models/detected_object.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../data/repositories/simple_storage_service.dart';
import '../../../core/logging/logger_service.dart';

class MonitoringScreen extends GetView<MonitoringController> {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MonitoringController>()) {
      Get.put(MonitoringController());
    }
    
    // Set alert configurations for the monitoring controller
    _setupAlertConfigs();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Video Stream
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Obx(() {
                  if (controller.videoController != null) {
                    return Video(
                      controller: controller.videoController!,
                      controls: NoVideoControls,
                    );
                  } else {
                    return Icon(
                      Icons.videocam_off,
                      size: 60.adaptSize,
                      color: Colors.white54,
                    );
                  }
                }),
              ),
            ),
          ),

          // 2. Detection Overlay (Boxes)
          Positioned.fill(
            child: Obx(() => DetectionOverlay(
              detections: controller.currentDetections,
              restrictedIds: controller.restrictedIds,
            )),
          ),

          // 3. UI Dashboard (Glass)
          Positioned(
            left: 32.adaptSize,
            top: 32.adaptSize,
            child: _buildStatusDashboard(context),
          ),

          // 4. Side Toolbar
          Positioned(
            right: 32.adaptSize,
            bottom: 32.adaptSize,
            child: _buildToolbar(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDashboard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.adaptSize),
      decoration: AppTheme.glassDecoration.copyWith(
        borderRadius: BorderRadius.circular(24.adaptSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 12.adaptSize,
                height: 12.adaptSize,
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.adaptSize),
              const Text(
                'SYSTEM ACTIVE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
          SizedBox(height: 24.adaptSize),
          _buildStat('Active People', controller.currentDetections.length.toString(), Icons.people),
          SizedBox(height: 16.adaptSize),
          _buildStat('Footfall Total', controller.footfallTotal.value.toString(), Icons.directions_walk),
          SizedBox(height: 16.adaptSize),
          _buildStat('People in Restricted Area', controller.restrictedIds.length.toString(), Icons.security),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.adaptSize, color: AppTheme.mutedTextColor),
        SizedBox(width: 12.adaptSize),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.mutedTextColor,
                fontSize: 12.adaptSize,
              ),
            ),
            Obx(() => Text(
              value, 
              style: TextStyle(
                fontSize: 18.adaptSize,
                fontWeight: FontWeight.bold,
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      children: [
        FloatingActionButton.small(
          onPressed: () => Get.back(),
          backgroundColor: AppTheme.surfaceColor,
          child: Icon(Icons.settings, size: 20.adaptSize),
        ),
        SizedBox(height: 16.adaptSize),
        FloatingActionButton.small(
          onPressed: () => _verifyAlgorithms(),
          backgroundColor: AppTheme.primaryColor,
          child: Icon(Icons.verified, size: 20.adaptSize),
        ),
        SizedBox(height: 16.adaptSize),
        FloatingActionButton(
          onPressed: () {
            if (controller.isStreaming.value) {
              controller.stopMonitoring();
            } else {
              // This would need proper params passed back from setup
            }
          },
          backgroundColor: AppTheme.errorColor,
          child: Obx(() => Icon(
            controller.isStreaming.value ? Icons.stop : Icons.play_arrow,
            size: 24.adaptSize,
          )),
        ),
        SizedBox(height: 16.adaptSize),
        FloatingActionButton(
          onPressed: () async {
            // Stop the stream, YOLO, and FFmpeg before navigating
            await controller.stopMonitoring();
            // Navigate to next configuration screen
            Get.toNamed('/detection-selection');
          },
          backgroundColor: AppTheme.successColor,
          child: Icon(Icons.arrow_forward, size: 24.adaptSize),
        ),
      ],
    );
  }
  
  void _setupAlertConfigs() {
    try {
      final cameraSetupController = Get.find<CameraSetupController>();
      final cameras = cameraSetupController.cameras;
      
      if (cameras.isNotEmpty) {
        final currentCamera = cameras[cameraSetupController.currentCameraIndex.value]; // Use current camera index
        final configs = <AlertConfig>[];
        
        // Add restricted area config if enabled
        if (currentCamera.restrictedAreaEnabled) {
          final roiPoints = <Offset>[];
          final roi = currentCamera.restrictedAreaConfig.roi;
          roiPoints.add(roi.topLeft);
          roiPoints.add(roi.bottomRight);
          
          configs.add(AlertConfig(
            type: DetectionType.restrictedArea,
            isEnabled: true,
            cooldown: 30,
            schedule: AlertSchedule(
              startTime: '00:00',
              endTime: '23:59',
              days: [1, 2, 3, 4, 5, 6, 7],
            ),
            roiPoints: roiPoints,
          ));
        }
        
        // Add other alert configs as needed
        if (currentCamera.maxPeopleEnabled) {
          configs.add(AlertConfig(
            type: DetectionType.crowdDetection,
            isEnabled: true,
            maxCapacity: currentCamera.maxPeople,
            cooldown: 60,
            schedule: AlertSchedule(
              startTime: '00:00',
              endTime: '23:59',
              days: [1, 2, 3, 4, 5, 6, 7],
            ),
          ));
        }
        
        if (currentCamera.footfallEnabled) {
          final roiPoints = <Offset>[];
          roiPoints.add(currentCamera.footfallConfig.lineStart);
          roiPoints.add(currentCamera.footfallConfig.lineEnd);
          
          configs.add(AlertConfig(
            type: DetectionType.footfallDetection,
            isEnabled: true,
            interval: currentCamera.footfallIntervalMinutes,
            cooldown: 60,
            schedule: AlertSchedule(
              startTime: '00:00',
              endTime: '23:59',
              days: [1, 2, 3, 4, 5, 6, 7],
            ),
            roiPoints: roiPoints,
          ));
        }
        
        if (currentCamera.theftAlertEnabled) {
          configs.add(AlertConfig(
            type: DetectionType.sensitiveAlert,
            isEnabled: true,
            cooldown: 60,
            schedule: AlertSchedule(
              startTime: '00:00',
              endTime: '23:59',
              days: [1, 2, 3, 4, 5, 6, 7],
            ),
          ));
        }
        
        // Set the configs on the monitoring controller
        controller.setConfigs(configs);
        print('✅ MonitoringScreen: Set ${configs.length} alert configurations');
      } else {
        print('⚠️ MonitoringScreen: No cameras found');
      }
    } catch (e) {
      print('❌ MonitoringScreen: Error setting up alert configs: $e');
    }
  }

  /// Verify algorithms and save installer test results locally
  Future<void> _verifyAlgorithms() async {
    try {
      LoggerService.i('🧪 Starting algorithm verification...');
      
      final cameraSetupController = Get.find<CameraSetupController>();
      final currentCamera = cameraSetupController.cameras[cameraSetupController.currentCameraIndex.value];
      final localStorage = SimpleStorageService.instance;
      
      // Generate camera ID for local storage
      final cameraId = 'camera_${cameraSetupController.currentCameraIndex.value}';
      
      // Check each algorithm and save test results
      bool allTestsPassed = true;
      
      // Test Crowd Detection (maxPeopleEnabled)
      if (currentCamera.maxPeopleEnabled) {
        final hasDetections = controller.currentDetections.isNotEmpty;
        await localStorage.saveInstallerTest(
          cameraId: cameraId,
          algorithmType: 'crowdDetection',
          pass: hasDetections,
        );
        if (!hasDetections) allTestsPassed = false;
        LoggerService.i('🧪 crowdDetection test: ${hasDetections ? "PASS" : "FAIL"}');
      }
      
      // Test Footfall Detection (footfallEnabled)
      if (currentCamera.footfallEnabled) {
        final hasFootfall = controller.footfallTotal.value > 0;
        await localStorage.saveInstallerTest(
          cameraId: cameraId,
          algorithmType: 'footfallCount',
          pass: hasFootfall,
        );
        if (!hasFootfall) allTestsPassed = false;
        LoggerService.i('🧪 footfallCount test: ${hasFootfall ? "PASS" : "FAIL"}');
      }
      
      // Test Restricted Area (restrictedAreaEnabled)
      if (currentCamera.restrictedAreaEnabled) {
        final hasRestrictedDetections = controller.restrictedIds.isNotEmpty;
        await localStorage.saveInstallerTest(
          cameraId: cameraId,
          algorithmType: 'restrictedArea',
          pass: hasRestrictedDetections,
        );
        if (!hasRestrictedDetections) allTestsPassed = false;
        LoggerService.i('🧪 restrictedArea test: ${hasRestrictedDetections ? "PASS" : "FAIL"}');
      }
      
      // Test Sensitive Alert (theftAlertEnabled)
      if (currentCamera.theftAlertEnabled) {
        final hasDetections = controller.currentDetections.isNotEmpty;
        await localStorage.saveInstallerTest(
          cameraId: cameraId,
          algorithmType: 'sensitiveAlert',
          pass: hasDetections,
        );
        if (!hasDetections) allTestsPassed = false;
        LoggerService.i('🧪 sensitiveAlert test: ${hasDetections ? "PASS" : "FAIL"}');
      }
      
      // Test Absent Alert (absentAlertEnabled)
      if (currentCamera.absentAlertEnabled) {
        // For absent alert, we consider it passing if there are no people (absence detected)
        final hasNoPeople = controller.currentDetections.isEmpty;
        await localStorage.saveInstallerTest(
          cameraId: cameraId,
          algorithmType: 'absentAlert',
          pass: hasNoPeople,
        );
        if (!hasNoPeople) allTestsPassed = false;
        LoggerService.i('🧪 absentAlert test: ${hasNoPeople ? "PASS" : "FAIL"}');
      }
      
      // Show result to user
      Get.snackbar(
        'Verification Complete',
        allTestsPassed ? 'All algorithms verified successfully!' : 'Some algorithms need attention',
        backgroundColor: allTestsPassed ? Colors.green : Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
      LoggerService.i('✅ Algorithm verification completed: ${allTestsPassed ? "ALL PASS" : "SOME FAIL"}');
    } catch (e, stackTrace) {
      LoggerService.e('❌ Algorithm verification failed', e, stackTrace);
      Get.snackbar(
        'Verification Failed',
        'Failed to verify algorithms. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
