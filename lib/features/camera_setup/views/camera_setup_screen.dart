import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controller/camera_setup_controller.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../widgets/common/rtsp_preview_widget.dart';

class CameraSetupScreen extends GetView<CameraSetupController> {
   CameraSetupScreen({super.key});
  
  final RxBool _urlFormatValid = false.obs;
  
  void _validateUrlFormat(String url) {
    if (url.isEmpty || url == 'rtsp://') {
      _urlFormatValid.value = false;
      return;
    }
    
    // Basic RTSP URL validation - check if it has more than just rtsp://
    final rtspPattern = RegExp(r'^rtsp://.+\..+');
    _urlFormatValid.value = rtspPattern.hasMatch(url);
  }
  
  Widget _buildQuickTemplate(String url, TextEditingController controller, String label) {
    return GestureDetector(
      onTap: () {
        controller.text = url;
        _validateUrlFormat(url);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.adaptSize, vertical: 8.adaptSize),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8.adaptSize),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.adaptSize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2.adaptSize),
            Text(
              url,
              style: TextStyle(
                fontSize: 9.adaptSize,
                color: Colors.white54,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CameraSetupController>()) {
      Get.put(CameraSetupController());
    }

    final TextEditingController urlController = TextEditingController(text: 'rtsp://');

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
                            'Camera Setup',
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
                    
                    Obx(() {
                      if (!controller.isStreamValid.value) {
                        // Initial state: Show templates and action buttons
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Templates Section
                            Container(
                              padding: EdgeInsets.all(20.adaptSize),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16.adaptSize),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick Templates',
                                    style: TextStyle(
                                      fontSize: 16.adaptSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 16.adaptSize),
                                  Wrap(
                                    spacing: 8.adaptSize,
                                    runSpacing: 8.adaptSize,
                                    children: [
                                      _buildQuickTemplate('rtsp://admin:admin@192.168.1.100:554/live', urlController, 'Hikvision'),
                                      _buildQuickTemplate('rtsp://admin:admin123@192.168.1.100:554/Streaming/Channels/101', urlController, 'Dahua'),
                                      _buildQuickTemplate('rtsp://admin:admin@192.168.1.100:554/profile2', urlController, 'Profile 2'),
                                      _buildQuickTemplate('rtsp://admin:admin123@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0', urlController, 'RealMonitor'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 32.adaptSize),
                            
                            // Connection Status Card
                            Container(
                              padding: EdgeInsets.all(20.adaptSize),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16.adaptSize),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
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
                                          color: Colors.orange,
                                        ),
                                      ),
                                      SizedBox(width: 12.adaptSize),
                                      Text(
                                        'No Stream',
                                        style: TextStyle(
                                          fontSize: 14.adaptSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.adaptSize),
                                  Text(
                                    'Configure RTSP URL to begin streaming',
                                    style: TextStyle(
                                      fontSize: 11.adaptSize,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 32.adaptSize),
                            
                            // Action Buttons (Always visible)
                            Column(
                              children: [
                                // Validate Stream Button
                                SizedBox(
                                  width: double.infinity,
                                  child: Obx(() => ElevatedButton.icon(
                                    onPressed: controller.isConnecting.value 
                                        ? null 
                                        : () => controller.validateStream(urlController.text),
                                    icon: controller.isConnecting.value 
                                        ? SizedBox(
                                            width: 16.adaptSize, 
                                            height: 16.adaptSize, 
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.adaptSize,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(Icons.check, size: 18.adaptSize),
                                    label: Text(
                                      controller.isConnecting.value ? 'Validating...' : 'Validate Stream',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.adaptSize,
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
                                  )),
                                ),
                                
                                SizedBox(height: 16.adaptSize),
                                
                                // Next Button (disabled until stream is valid)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: controller.isStreamValid.value ? () {
                                      controller.stopStream();
                                      Get.toNamed(AppRoutes.detectionSelection);
                                    } : null,
                                    icon: Icon(Icons.arrow_forward, size: 18.adaptSize),
                                    label: Text(
                                      'Next',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.adaptSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: controller.isStreamValid.value ? AppTheme.successColor : Colors.grey,
                                      padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.adaptSize),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Validated state: Show URL and action buttons
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Connection Status Card
                            Container(
                              padding: EdgeInsets.all(20.adaptSize),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16.adaptSize),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.4),
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
                                          color: Colors.green,
                                        ),
                                      ),
                                      SizedBox(width: 12.adaptSize),
                                      Text(
                                        'Stream Connected',
                                        style: TextStyle(
                                          fontSize: 14.adaptSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 16.adaptSize),
                                  
                                  Text(
                                    'RTSP URL:',
                                    style: TextStyle(
                                      fontSize: 12.adaptSize,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8.adaptSize),
                                  Text(
                                    controller.rtspUrl.value,
                                    style: TextStyle(
                                      fontSize: 11.adaptSize,
                                      color: Colors.green,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 32.adaptSize),
                            
                            // Action Buttons
                            Column(
                              children: [
                                // Edit URL Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => controller.enterEditMode(),
                                    icon: Icon(Icons.edit, size: 18.adaptSize),
                                    label: Text(
                                      'Edit URL',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.adaptSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.adaptSize),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: 16.adaptSize),
                                
                                // Next Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      controller.stopStream();
                                      Get.toNamed(AppRoutes.detectionSelection);
                                    },
                                    icon: Icon(Icons.arrow_forward, size: 18.adaptSize),
                                    label: Text(
                                      'Next',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.adaptSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successColor,
                                      padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.adaptSize),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    }),
                    
                    SizedBox(height: 32.adaptSize),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Side - Content (65%)
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
                child: Obx(() {
                  if (!controller.isStreamValid.value) {
                    // Initial state: Show RTSP input field only
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(24.adaptSize),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 20.adaptSize),
                          Icon(
                            Icons.link,
                            size: 60.adaptSize,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 24.adaptSize),
                          Text(
                            'Configure RTSP Stream',
                            style: TextStyle(
                              fontSize: 20.adaptSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.adaptSize),
                          Text(
                            'Enter your camera\'s RTSP URL below',
                            style: TextStyle(
                              fontSize: 13.adaptSize,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 30.adaptSize),
                          
                          // RTSP URL Input
                          TextField(
                            controller: urlController,
                            onChanged: (value) {
                              _validateUrlFormat(value);
                            },
                            decoration: InputDecoration(
                              labelText: 'RTSP URL',
                              hintText: 'admin:password@192.168.1.100:554/live',
                              hintStyle: TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.adaptSize),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.adaptSize),
                                borderSide: BorderSide(
                                  color: _urlFormatValid.value ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.adaptSize),
                                borderSide: BorderSide(
                                  color: _urlFormatValid.value ? Colors.green.withOpacity(0.5) : AppTheme.primaryColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.link,
                                color: _urlFormatValid.value ? Colors.green : Colors.white54,
                              ),
                              contentPadding: EdgeInsets.symmetric(vertical: 12.adaptSize, horizontal: 16.adaptSize),
                            ),
                            style: TextStyle(
                              fontSize: 14.adaptSize,
                              fontFamily: 'monospace',
                            ),
                          ),
                          
                          SizedBox(height: 12.adaptSize),
                          
                          Obx(() => Text(
                            controller.statusMessage.value,
                            style: TextStyle(
                              color: controller.isStreamValid.value 
                                  ? AppTheme.successColor 
                                  : Colors.white70,
                              fontSize: 11.adaptSize,
                            ),
                          )),
                          
                          SizedBox(height: 20.adaptSize),
                          
                          // Note: No validate button here - it's on the left side only
                        ],
                      ),
                    );
                  } else {
                    // Validated state: Show video preview
                    return AspectRatio(
                      aspectRatio: 16/9,
                      child: RTSPPreviewWidget(
                        rtspUrl: controller.rtspUrl.value,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(16.adaptSize),
                        backgroundColor: Colors.black,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
