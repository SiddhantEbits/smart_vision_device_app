import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../controllers/detection_selection_controller.dart';
import '../models/detection_item.dart';

class DetectionSelectionScreen extends StatelessWidget {
  const DetectionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DetectionSelectionController>();

    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: Container(
              width: 300.adaptSize,
              padding: EdgeInsets.all(48.adaptSize),
              color: AppTheme.surfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Select\nDetections',
                  style: TextStyle(
                    fontSize: 32.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.adaptSize),
                const Text(
                  'Choose the smart vision features you want to enable for this camera.',
                  style: TextStyle(color: AppTheme.mutedTextColor),
                ),
                SizedBox(height: 32.adaptSize),
                SizedBox(
                  width: double.infinity,
                  child: Obx(() => ElevatedButton(
                    onPressed: controller.selectedDetections.isEmpty 
                        ? null 
                        : controller.proceedToConfiguration,
                    child: const Text('CONFIGURE ALERTS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.selectedDetections.isEmpty 
                          ? AppTheme.mutedTextColor 
                          : AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                    ),
                  )),
                ),
              ],
            ),
            ),
          ),
          
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive crossAxisCount based on screen width
                int crossAxisCount = 3;
                if (constraints.maxWidth < 600) {
                  crossAxisCount = 2; // Small screens
                } else if (constraints.maxWidth < 900) {
                  crossAxisCount = 3; // Medium screens
                } else {
                  crossAxisCount = 4; // Large screens
                }
                
                return GridView.builder(
                  padding: EdgeInsets.all(48.adaptSize),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 24.adaptSize,
                    mainAxisSpacing: 24.adaptSize,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: controller.detections.length,
                  itemBuilder: (context, index) {
                    final item = controller.detections[index];
                    final isSelected = controller.isSelected(item.type);
                    
                    return GestureDetector(
                      onTap: () => controller.toggleDetection(item.type),
                      child: Container(
                        padding: EdgeInsets.all(16.adaptSize),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(24.adaptSize),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : Colors.white10,
                            width: 2.adaptSize,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.icon,
                              size: 28.adaptSize,
                              color: isSelected ? AppTheme.primaryColor : Colors.white70,
                            ),
                            SizedBox(height: 6.adaptSize),
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 16.adaptSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6.adaptSize),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white70 : AppTheme.mutedTextColor,
                                fontSize: 12.adaptSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
