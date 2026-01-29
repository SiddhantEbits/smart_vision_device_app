import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/qr_scan_controller.dart';

class QRScanScreen extends StatelessWidget {
  const QRScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QRScanController>();
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 300.adaptSize,
            padding: EdgeInsets.all(48.adaptSize),
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
                SizedBox(height: 20.adaptSize),
                Text(
                  'Link\nDevice',
                  style: TextStyle(
                    fontSize: 24.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.adaptSize),
                const Text(
                  'Scan this QR code with your Smart Vision Mobile App to link this device to your account.',
                  style: TextStyle(color: AppTheme.mutedTextColor),
                ),
                SizedBox(height: 24.adaptSize),
                
                // Pairing Status moved to left panel
                Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14.adaptSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 6.adaptSize),
                    Row(
                      children: [
                        Icon(
                          controller.isPaired.value ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: controller.isPaired.value ? Colors.green : Colors.orange,
                          size: 14.adaptSize,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            controller.isPaired.value ? 'Device Paired' : 'Waiting for Pairing...',
                            style: TextStyle(
                              fontSize: 12.adaptSize,
                              color: controller.isPaired.value ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.adaptSize),
                    
                    // Continue Button moved to left panel
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.canNavigateToNext 
                            ? () async {
                                // Update device name to Firebase before navigating
                                await controller.updateDeviceName();
                                Get.toNamed('/whatsapp-setup');
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: controller.canNavigateToNext 
                              ? AppTheme.primaryColor 
                              : Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10.adaptSize),
                        ),
                        child: Text(
                          controller.canNavigateToNext 
                              ? 'CONTINUE' 
                              : 'WAITING FOR PAIRING',
                          style: TextStyle(fontSize: 12.adaptSize),
                        ),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
          
          // Right Content - Responsive to keyboard
          Expanded(
            child: Container(
              height: availableHeight,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.adaptSize),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.adaptSize),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 40.adaptSize,
                              spreadRadius: 10.adaptSize,
                            ),
                          ],
                        ),
                        child: Obx(() => controller.isLoading.value
                            ? Container(
                                width: 160.adaptSize,
                                height: 160.adaptSize,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : QrImageView(
                                data: controller.deviceId.value,
                                version: QrVersions.auto,
                                size: 160.adaptSize,
                              )),
                      ),
                      SizedBox(height: 16.adaptSize),
                      
                      Obx(() => !controller.isLoading.value && controller.deviceId.value.isNotEmpty
                          ? Column(
                              children: [
                                // Device Name Field
                                Container(
                                  width: 260.adaptSize,
                                  child: TextField(
                                    controller: controller.deviceNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Device Name',
                                      labelStyle: TextStyle(color: Colors.white70, fontSize: 12.adaptSize),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.white24),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primaryColor),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12.adaptSize, vertical: 8.adaptSize),
                                    ),
                                    style: TextStyle(color: Colors.white, fontSize: 12.adaptSize),
                                  ),
                                ),
                                SizedBox(height: 8.adaptSize),
                                Text(
                                  'DEVICE ID: ${controller.deviceId.value}',
                                  style: TextStyle(
                                    fontSize: 12.adaptSize,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
