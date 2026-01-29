import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../data/models/alert_config_model.dart' as model;
import '../../alert_config/controller/alert_flow_controller.dart';
import '../models/detection_item.dart';

class DetectionSelectionController extends GetxController {
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

  final selectedDetections = <model.DetectionType>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _ensureAlertFlowController();
  }

  void _ensureAlertFlowController() {
    if (!Get.isRegistered<AlertFlowController>()) {
      Get.put(AlertFlowController());
    }
  }

  bool isSelected(model.DetectionType type) {
    return selectedDetections.contains(type);
  }

  void toggleDetection(model.DetectionType type) {
    debugPrint('[DETECTION] Toggle called for type: $type');
    debugPrint('[DETECTION] Current selections: ${selectedDetections.toList()}');
    
    if (selectedDetections.contains(type)) {
      selectedDetections.remove(type);
      debugPrint('[DETECTION] Removed: $type');
    } else {
      selectedDetections.add(type);
      debugPrint('[DETECTION] Added: $type');
    }
    
    debugPrint('[DETECTION] New selections: ${selectedDetections.toList()}');
  }

  void proceedToConfiguration() {
    debugPrint('[DETECTION] Proceed to configuration called');
    debugPrint('[DETECTION] Selected detections: ${selectedDetections.toList()}');
    
    if (selectedDetections.isEmpty) {
      debugPrint('[DETECTION] No detections selected');
      Get.snackbar(
        'No Selection',
        'Please select at least one detection feature',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: Icon(Icons.warning, color: Colors.white),
      );
      return;
    }

    debugPrint('[DETECTION] Getting AlertFlowController...');
    try {
      final flowController = Get.find<AlertFlowController>();
      debugPrint('[DETECTION] AlertFlowController found');
      flowController.selectDetections(selectedDetections.toList());
      debugPrint('[DETECTION] Detections selected, navigating to alert config');
      Get.toNamed(AppRoutes.alertConfigQueue);
    } catch (e) {
      debugPrint('[DETECTION] Error with AlertFlowController: $e');
      Get.snackbar(
        'Error',
        'Could not proceed to configuration',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void navigateBack() {
    Get.back();
  }
}
