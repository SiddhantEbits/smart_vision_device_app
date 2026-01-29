import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controller/monitoring_controller.dart';
import 'widgets/detection_overlay.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';

class MonitoringScreen extends GetView<MonitoringController> {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MonitoringController>()) {
      Get.put(MonitoringController());
    }

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
}
