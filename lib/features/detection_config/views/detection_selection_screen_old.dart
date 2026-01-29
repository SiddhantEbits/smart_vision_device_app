import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../alert_config/controller/alert_flow_controller.dart';
import '../../../data/models/alert_config_model.dart' as model;

class DetectionSelectionScreen extends StatefulWidget {
  const DetectionSelectionScreen({super.key});

  @override
  State<DetectionSelectionScreen> createState() => _DetectionSelectionScreenState();
}

class _DetectionSelectionScreenState extends State<DetectionSelectionScreen> {
  final List<DetectionItem> detections = [
    DetectionItem(
      type: model.DetectionType.crowdDetection,
      title: 'Crowd Detection',
      description: 'Alert when person count exceeds threshold.',
      icon: Icons.groups_rounded,
    ),
    DetectionItem(
      type: model.DetectionType.absentAlert,
      title: 'Absent Alert',
      description: 'Alert when no one is present for a duration.',
      icon: Icons.person_off_rounded,
    ),
    DetectionItem(
      type: model.DetectionType.footfallDetection,
      title: 'Footfall Detection',
      description: 'Count people crossing a specific line.',
      icon: Icons.directions_walk_rounded,
    ),
    DetectionItem(
      type: model.DetectionType.restrictedArea,
      title: 'Restricted Area',
      description: 'Alert if someone enters a forbidden zone.',
      icon: Icons.block_flipped,
    ),
    DetectionItem(
      type: model.DetectionType.sensitiveAlert,
      title: 'Sensitive Alert',
      description: 'Immediate alert on any person detection.',
      icon: Icons.security_rounded,
    ),
  ];

  final Set<model.DetectionType> selected = {};

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AlertFlowController>()) {
      Get.put(AlertFlowController());
    }
    
    final flowController = Get.find<AlertFlowController>();

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
                  child: ElevatedButton(
                    onPressed: selected.isEmpty 
                        ? null 
                        : () {
                          flowController.selectDetections(selected.toList());
                          Get.toNamed(AppRoutes.alertConfigQueue);
                        },
                    child: const Text('CONFIGURE ALERTS'),
                  ),
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
                  itemCount: detections.length,
                  itemBuilder: (context, index) {
                    final item = detections[index];
                    final isSelected = selected.contains(item.type);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selected.remove(item.type);
                          } else {
                            selected.add(item.type);
                          }
                        });
                      },
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

class DetectionItem {
  final model.DetectionType type;
  final String title;
  final String description;
  final IconData icon;

  DetectionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}
