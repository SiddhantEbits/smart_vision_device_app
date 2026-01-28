import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../controller/alert_flow_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/models/alert_config_model.dart';

class CameraSetupFinishScreen extends StatelessWidget {
  const CameraSetupFinishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AlertFlowController flowController = Get.put(AlertFlowController());
    final CameraSetupController cameraSetupController = Get.find<CameraSetupController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(24.adaptSize),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                  SizedBox(width: 12.adaptSize),
                  Expanded(
                    child: Text(
                      'Setup Complete',
                      style: TextStyle(
                        fontSize: 24.adaptSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.adaptSize),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 24.adaptSize),
                      
                      // Success Icon
                      Container(
                        width: 120.adaptSize,
                        height: 120.adaptSize,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 60.adaptSize,
                          color: Colors.green,
                        ),
                      ),
                      
                      SizedBox(height: 32.adaptSize),
                      
                      // Success Message
                      Text(
                        'Camera Setup Complete!',
                        style: TextStyle(
                          fontSize: 28.adaptSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 16.adaptSize),
                      
                      Text(
                        'Camera: ${cameraSetupController.cameraName}',
                        style: TextStyle(
                          fontSize: 16.adaptSize,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 8.adaptSize),
                      
                      Text(
                        '${flowController.selectedDetections.length} Detection Types Configured',
                        style: TextStyle(
                          fontSize: 16.adaptSize,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 48.adaptSize),
                      
                      // Configured Detections Summary
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20.adaptSize),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16.adaptSize),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configured Detections:',
                              style: TextStyle(
                                fontSize: 16.adaptSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 12.adaptSize),
                            ...flowController.selectedDetections.map((detection) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8.adaptSize),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16.adaptSize,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8.adaptSize),
                                    Text(
                                      _getDetectionTitle(detection),
                                      style: TextStyle(
                                        fontSize: 14.adaptSize,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 48.adaptSize),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Padding(
              padding: EdgeInsets.all(24.adaptSize),
              child: Column(
                children: [
                  // Finish Setup Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Save all configurations and go to dashboard
                        flowController.finishSetup();
                      },
                      icon: Icon(Icons.done_all, size: 18.adaptSize),
                      label: Text(
                        'Finish Setup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.adaptSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.adaptSize),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12.adaptSize),
                  
                  // Add Another Camera Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Reset flow and go back to camera setup for new camera
                        flowController.selectDetections([]);
                        cameraSetupController.resetCamera();
                        Get.offAllNamed(AppRoutes.cameraSetup);
                      },
                      icon: Icon(Icons.add, size: 18.adaptSize),
                      label: Text(
                        'Add Another Camera',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16.adaptSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.4),
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.adaptSize),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDetectionTitle(DetectionType type) {
    switch (type) {
      case DetectionType.crowdDetection:
        return 'Crowd Detection';
      case DetectionType.absentAlert:
        return 'Absent Alert';
      case DetectionType.footfallDetection:
        return 'Footfall Detection';
      case DetectionType.restrictedArea:
        return 'Restricted Area';
      case DetectionType.sensitiveAlert:
        return 'Sensitive Area Alert';
    }
  }
}
