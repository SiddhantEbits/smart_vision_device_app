import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controller/camera_setup_controller.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';

class CameraSetupScreen extends GetView<CameraSetupController> {
  const CameraSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CameraSetupController>()) {
      Get.put(CameraSetupController());
    }

    final TextEditingController urlController = TextEditingController();

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          SingleChildScrollView(
            child: Container(
              width: 350.adaptSize,
              padding: EdgeInsets.all(40.adaptSize),
              color: AppTheme.surfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                  ),
                ),
                SizedBox(height: 32.adaptSize),
                Text(
                  'Camera\nSetup',
                  style: TextStyle(
                    fontSize: 32.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 32.adaptSize),
                
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'RTSP URL',
                    hintText: 'rtsp://admin:pass@192.168.1.100:554/ch1',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.adaptSize),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 16.adaptSize),
                
                Obx(() => Text(
                  controller.statusMessage.value,
                  style: TextStyle(
                    color: controller.isStreamValid.value 
                        ? AppTheme.successColor 
                        : Colors.white70,
                    fontSize: 13.adaptSize,
                  ),
                )),
                
                SizedBox(height: 32.adaptSize),
                
                Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isConnecting.value 
                        ? null 
                        : () => controller.validateStream(urlController.text),
                    child: controller.isConnecting.value 
                        ? SizedBox(
                            width: 20.adaptSize, 
                            height: 20.adaptSize, 
                            child: CircularProgressIndicator(
                              strokeWidth: 2.adaptSize,
                              color: Colors.white,
                            ),
                          )
                        : const Text('VALIDATE STREAM'),
                  ),
                )),
                
                SizedBox(height: 48.adaptSize),
                
                Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isStreamValid.value 
                        ? () => Get.toNamed(AppRoutes.detectionSelection) 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                    child: const Text('CONTINUE'),
                  ),
                )),
              ],
            ),
            ),
          ),
          
          // Right Content: Live Preview
          Flexible(
            child: Container(
              margin: EdgeInsets.all(24.adaptSize),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24.adaptSize),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.adaptSize),
                child: Obx(() {
                  if (controller.rtspUrl.value.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_camera_back_outlined,
                            size: 64.adaptSize,
                            color: Colors.white24,
                          ),
                          SizedBox(height: 16.adaptSize),
                          Text(
                            'Enter RTSP URL to see preview',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 14.adaptSize,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Video(
                    controller: controller.videoController,
                    controls: NoVideoControls,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
