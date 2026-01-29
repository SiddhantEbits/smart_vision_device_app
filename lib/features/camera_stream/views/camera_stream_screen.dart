import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controller/camera_stream_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../data/models/detected_object.dart';
import '../widgets/detection_overlay.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/logging/logger_service.dart';

class CameraStreamScreen extends StatefulWidget {
  const CameraStreamScreen({super.key});

  @override
  State<CameraStreamScreen> createState() => _CameraStreamScreenState();
}

class _CameraStreamScreenState extends State<CameraStreamScreen> {
  late CameraStreamController controller;

  @override
  void initState() {
    super.initState();
    // Register controller if not already registered
    if (!Get.isRegistered<CameraStreamController>()) {
      Get.put(CameraStreamController());
    }
    controller = Get.find<CameraStreamController>();
    
    // Start camera when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.startCamera();
      }
    });
  }

  @override
  void dispose() {
    // Stop camera when widget is disposed
    if (Get.isRegistered<CameraStreamController>()) {
      controller.stopCamera();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Stop camera stream when navigating away
          controller.stopCamera();
        }
      },
      child: Scaffold(
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                        SizedBox(width: 12.adaptSize),
                        Expanded(
                          child: Text(
                            'Camera Stream',
                            style: TextStyle(
                              fontSize: 24.adaptSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Status Dashboard
                    _buildStatusDashboard(context),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Stream Status Card
                    Obx(() => Container(
                      padding: EdgeInsets.all(20.adaptSize),
                      decoration: BoxDecoration(
                        color: controller.videoReady.value 
                            ? Colors.green.withOpacity(0.15)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16.adaptSize),
                        border: Border.all(
                          color: controller.videoReady.value 
                              ? Colors.green.withOpacity(0.4)
                              : Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12.adaptSize,
                                height: 12.adaptSize,
                                decoration: BoxDecoration(
                                  color: controller.videoReady.value ? Colors.green : Colors.orange,
                                ),
                              ),
                              SizedBox(width: 12.adaptSize),
                              Text(
                                controller.videoReady.value ? 'Stream Active' : 'Stream Inactive',
                                style: TextStyle(
                                  fontSize: 14.adaptSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          
                          if (!controller.videoReady.value) ...[
                            SizedBox(height: 12.adaptSize),
                            Text(
                              controller.loadingMessage.value,
                              style: TextStyle(
                                fontSize: 11.adaptSize,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Detection Status
                    Obx(() => Container(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detection Status',
                            style: TextStyle(
                              fontSize: 14.adaptSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 16.adaptSize),
                          
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: AppTheme.primaryColor,
                                size: 18.adaptSize,
                              ),
                              SizedBox(width: 12.adaptSize),
                              Text(
                                '${controller.detections.length} People Detected',
                                style: TextStyle(
                                  fontSize: 13.adaptSize,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 12.adaptSize),
                          
                          Row(
                            children: [
                              Icon(
                                controller.modelLoaded.value ? Icons.check_circle : Icons.hourglass_empty,
                                color: controller.modelLoaded.value ? Colors.green : Colors.orange,
                                size: 18.adaptSize,
                              ),
                              SizedBox(width: 12.adaptSize),
                              Text(
                                controller.modelLoaded.value ? 'YOLO Model Ready' : 'Loading YOLO Model...',
                                style: TextStyle(
                                  fontSize: 13.adaptSize,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Camera Switcher
                    _buildCameraSwitcher(),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Control Toolbar
                    _buildControlToolbar(),
                    
                    SizedBox(height: 32.adaptSize),
                  ],
                ),
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.adaptSize),
                child: Stack(
                  children: [
                    // Video Stream
                    Positioned.fill(
                      child: Obx(() {
                        if (controller.videoReady.value) {
                          return Video(
                            controller: controller.videoService.videoController,
                            controls: NoVideoControls,
                          );
                        } else {
                          return Center(
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
                                  controller.loadingMessage.value,
                                  style: TextStyle(
                                    fontSize: 18.adaptSize,
                                    color: Colors.white54,
                                  ),
                                ),
                                if (!controller.modelLoaded.value)
                                  Padding(
                                    padding: EdgeInsets.only(top: 16.adaptSize),
                                    child: SizedBox(
                                      width: 40.adaptSize,
                                      height: 40.adaptSize,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3.adaptSize,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                      }),
                    ),
                    
                    // Detection Overlay
                    Positioned.fill(
                      child: Obx(() => DetectionOverlay(
                        detections: controller.detections,
                        restrictedIds: controller.restrictedIds,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatusDashboard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.adaptSize),
      decoration: AppTheme.glassDecoration.copyWith(
        borderRadius: BorderRadius.circular(20.adaptSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status Indicator
          Row(
            children: [
              Container(
                width: 12.adaptSize,
                height: 12.adaptSize,
                decoration: BoxDecoration(
                  color: controller.streamRunning.value 
                      ? AppTheme.successColor 
                      : AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.adaptSize),
              Text(
                controller.streamRunning.value ? 'STREAMING' : 'STOPPED',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.5,
                  fontSize: 12.adaptSize,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.adaptSize),
          
          // Camera Name
          Obx(() => Text(
            controller.currentCam.name,
            style: TextStyle(
              fontSize: 18.adaptSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          )),
          SizedBox(height: 16.adaptSize),
          
          // Detection Stats
          _buildStat('People', controller.peopleCount.value.toString(), Icons.people),
          SizedBox(height: 12.adaptSize),
          _buildStat('Footfall', controller.footfallCount.value.toString(), Icons.directions_walk),
          SizedBox(height: 12.adaptSize),
          _buildStat('Violations', controller.restrictedIds.length.toString(), Icons.security),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.adaptSize, color: AppTheme.mutedTextColor),
        SizedBox(width: 12.adaptSize),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.mutedTextColor,
                fontSize: 11.adaptSize,
              ),
            ),
            Text(
              value, 
              style: TextStyle(
                fontSize: 16.adaptSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCameraSwitcher() {
    final cameraSetup = Get.find<CameraSetupController>();
    
    return Container(
      padding: EdgeInsets.all(16.adaptSize),
      decoration: AppTheme.glassDecoration.copyWith(
        borderRadius: BorderRadius.circular(16.adaptSize),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt, size: 20.adaptSize, color: AppTheme.primaryColor),
          SizedBox(height: 8.adaptSize),
          Obx(() => DropdownButton<int>(
            value: controller.currentCameraIndex.value,
            dropdownColor: AppTheme.surfaceColor,
            icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
            items: cameraSetup.cameras.asMap().entries.map((entry) {
              final index = entry.key;
              final camera = entry.value;
              return DropdownMenuItem<int>(
                value: index,
                child: Text(
                  camera.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.adaptSize,
                  ),
                ),
              );
            }).toList(),
            onChanged: (index) {
              if (index != null) {
                controller.switchCamera(index);
              }
            },
          )),
        ],
      ),
    );
  }

  Widget _buildControlToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Mode Buttons
        Obx(() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.currentCam.footfallEnabled)
              FloatingActionButton.small(
                onPressed: () => controller.isFootfallEditMode.toggle(),
                backgroundColor: controller.isFootfallEditMode.value 
                    ? AppTheme.primaryColor 
                    : AppTheme.surfaceColor,
                child: Icon(Icons.show_chart, size: 16.adaptSize),
              ),
            if (controller.currentCam.footfallEnabled && controller.currentCam.restrictedAreaEnabled)
              SizedBox(width: 8.adaptSize),
            if (controller.currentCam.restrictedAreaEnabled)
              FloatingActionButton.small(
                onPressed: () => controller.isRestrictedEditMode.toggle(),
                backgroundColor: controller.isRestrictedEditMode.value 
                    ? Colors.redAccent 
                    : AppTheme.surfaceColor,
                child: Icon(Icons.block, size: 16.adaptSize),
              ),
          ],
        )),
        SizedBox(height: 16.adaptSize),
        
        // Main Control Button
        Obx(() => FloatingActionButton(
          onPressed: () {
            if (controller.streamRunning.value) {
              controller.stopCamera();
            } else {
              controller.startCamera();
            }
          },
          backgroundColor: controller.streamRunning.value 
              ? AppTheme.errorColor 
              : AppTheme.successColor,
          child: Icon(
            controller.streamRunning.value ? Icons.stop : Icons.play_arrow,
            size: 24.adaptSize,
          ),
        )),
      ],
    );
  }

  Widget _buildEditModeOverlays() {
    return Stack(
      children: [
        // Footfall Line Edit Mode
        if (controller.isFootfallEditMode.value && controller.currentCam.footfallEnabled)
          _buildFootfallLine(),
          
        // Restricted Area Edit Mode
        if (controller.isRestrictedEditMode.value && controller.currentCam.restrictedAreaEnabled)
          _buildRestrictedArea(),
      ],
    );
  }

  Widget _buildFootfallLine() {
    // This would be implemented with custom painter for footfall line editing
    // For now, showing a placeholder
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _FootfallLinePainter(
            start: controller.currentCam.footfallConfig.lineStart,
            end: controller.currentCam.footfallConfig.lineEnd,
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictedArea() {
    // This would be implemented with custom painter for restricted area editing
    // For now, showing a placeholder
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _RestrictedAreaPainter(
            rect: controller.currentCam.restrictedAreaConfig.roi,
          ),
        ),
      ),
    );
  }
}

// Custom painters for edit mode overlays
class _FootfallLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _FootfallLinePainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final startScaled = Offset(start.dx * size.width, start.dy * size.height);
    final endScaled = Offset(end.dx * size.width, end.dy * size.height);

    canvas.drawLine(startScaled, endScaled, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RestrictedAreaPainter extends CustomPainter {
  final Rect rect;

  _RestrictedAreaPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final scaledRect = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );

    canvas.drawRect(scaledRect, paint);
    canvas.drawRect(scaledRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
