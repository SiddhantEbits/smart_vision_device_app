import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../core/constants/app_routes.dart';
import '../../monitoring/controller/monitoring_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../data/services/device_firebase_service.dart';
import '../../../data/repositories/local_storage_service.dart';
import '../../../core/logging/logger_service.dart';

class AlertFlowController extends GetxController {
  final RxList<DetectionType> selectedDetections = <DetectionType>[].obs;
  final RxInt currentConfigIndex = 0.obs;
  
  // Store the actual configurations being built
  final Map<DetectionType, AlertConfig> configs = {};

  void selectDetections(List<DetectionType> types) {
    selectedDetections.assignAll(types);
    currentConfigIndex.value = 0;
    configs.clear();
  }

  DetectionType? get currentAlert => 
      currentConfigIndex.value < selectedDetections.length 
          ? selectedDetections[currentConfigIndex.value] 
          : null;

  void saveConfig(AlertConfig config) {
    configs[config.type] = config;
  }

  Future<void> finishSetup() async {
    try {
      LoggerService.i('🚀 Starting Firebase sync for all setup data...');
      
      // Get all local data
      final localStorage = LocalStorageService.instance;
      final deviceId = localStorage.deviceId;
      
      // 1. Sync device information with WhatsApp configuration
      await _syncDeviceToFirebase(deviceId, localStorage);
      
      // 2. Sync all camera configurations
      await _syncCamerasToFirebase(deviceId, localStorage);
      
      // 3. Clear pending changes after successful sync
      await localStorage.clearAllPendingChanges();
      
      LoggerService.i('✅ All setup data synced to Firebase successfully');
      
      // Navigate to camera setup finish screen
      Get.offAllNamed(AppRoutes.cameraSetupFinish);
    } catch (e, stackTrace) {
      LoggerService.e('❌ Failed to sync setup data to Firebase', e, stackTrace);
      
      // Show error to user
      Get.snackbar(
        'Sync Failed',
        'Failed to save setup data. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Sync device information including WhatsApp configuration to Firebase
  Future<void> _syncDeviceToFirebase(String deviceId, LocalStorageService localStorage) async {
    try {
      LoggerService.i('📱 Syncing device configuration to Firebase...');
      
      // Get WhatsApp configuration
      final whatsappConfig = localStorage.getWhatsAppConfig();
      final phoneNumbers = whatsappConfig['phoneNumbers'] as List<String>? ?? [];
      final whatsappAlertsEnabled = whatsappConfig['alertEnable'] as bool? ?? false;
      
      // Get device name from camera setup or use default
      final cameraSetupController = Get.find<CameraSetupController>();
      final deviceName = cameraSetupController.cameraName.isNotEmpty 
          ? cameraSetupController.cameraName.value 
          : 'Smart Vision Device';
      
      await DeviceFirebaseService.saveDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        linked: true, // Device is now paired and configured
      );
      
      // Update WhatsApp configuration separately
      await _updateWhatsAppConfig(deviceId, phoneNumbers, whatsappAlertsEnabled);
      
      LoggerService.i('✅ Device configuration synced to Firebase');
    } catch (e) {
      LoggerService.e('❌ Failed to sync device configuration', e);
      rethrow;
    }
  }

  /// Update WhatsApp configuration for the device
  Future<void> _updateWhatsAppConfig(String deviceId, List<String> phoneNumbers, bool alertEnable) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('devices').doc(deviceId).update({
        'whatsapp.alertEnable': alertEnable,
        'whatsapp.phoneNumbers': phoneNumbers,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      LoggerService.i('✅ WhatsApp configuration updated: ${phoneNumbers.length} numbers, alerts: $alertEnable');
    } catch (e) {
      LoggerService.e('❌ Failed to update WhatsApp configuration', e);
      rethrow;
    }
  }

  /// Sync all camera configurations to Firebase
  Future<void> _syncCamerasToFirebase(String deviceId, LocalStorageService localStorage) async {
    try {
      LoggerService.i('📹 Syncing camera configurations to Firebase...');
      
      final cameraConfigs = localStorage.getCameraConfigs();
      int syncedCount = 0;
      
      for (final cameraConfig in cameraConfigs) {
        try {
          await _syncSingleCameraToFirebase(deviceId, cameraConfig);
          syncedCount++;
        } catch (e) {
          LoggerService.e('❌ Failed to sync camera: ${cameraConfig.name}', e);
          // Continue with other cameras
        }
      }
      
      LoggerService.i('✅ $syncedCount camera configurations synced to Firebase');
    } catch (e) {
      LoggerService.e('❌ Failed to sync camera configurations', e);
      rethrow;
    }
  }

  /// Sync a single camera configuration to Firebase
  Future<void> _syncSingleCameraToFirebase(String deviceId, dynamic cameraConfig) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Generate camera document ID
      final cameraId = '${deviceId}_${cameraConfig.name.replaceAll(' ', '_').toLowerCase()}';
      
      // Build algorithms map according to firebase.md schema
      final algorithms = <String, dynamic>{};
      
      // People Count Algorithm
      algorithms['peopleCount'] = {
        'enabled': cameraConfig.peopleCountEnabled ?? true,
        'threshold': cameraConfig.confidenceThreshold ?? 0.15,
        'appNotification': true,
        'wpNotification': cameraConfig.peopleCountEnabled ?? true,
        'schedule': _buildScheduleConfig(null), // No schedule for basic people count
      };
      
      // Footfall Algorithm
      if (cameraConfig.footfallEnabled == true) {
        algorithms['footfall'] = {
          'enabled': true,
          'threshold': cameraConfig.confidenceThreshold ?? 0.15,
          'alertInterval': (cameraConfig.footfallIntervalMinutes ?? 60) * 60, // Convert to seconds
          'appNotification': true,
          'wpNotification': true,
          'schedule': _buildScheduleConfig(cameraConfig.footfallSchedule),
        };
      }
      
      // Max People Algorithm
      if (cameraConfig.maxPeopleEnabled == true) {
        algorithms['maxPeople'] = {
          'enabled': true,
          'threshold': cameraConfig.confidenceThreshold ?? 0.15,
          'maxCapacity': cameraConfig.maxPeople ?? 5,
          'cooldownSeconds': cameraConfig.maxPeopleCooldownSeconds ?? 300,
          'appNotification': true,
          'wpNotification': true,
          'schedule': _buildScheduleConfig(cameraConfig.maxPeopleSchedule),
        };
      }
      
      // Absent Alert Algorithm
      if (cameraConfig.absentAlertEnabled == true) {
        algorithms['absentAlert'] = {
          'enabled': true,
          'threshold': cameraConfig.confidenceThreshold ?? 0.15,
          'absentInterval': cameraConfig.absentSeconds ?? 60,
          'cooldownSeconds': cameraConfig.absentCooldownSeconds ?? 600,
          'appNotification': true,
          'wpNotification': true,
          'schedule': _buildScheduleConfig(cameraConfig.absentSchedule),
        };
      }
      
      // Theft Alert Algorithm
      if (cameraConfig.theftAlertEnabled == true) {
        algorithms['theftAlert'] = {
          'enabled': true,
          'threshold': cameraConfig.confidenceThreshold ?? 0.15,
          'cooldownSeconds': cameraConfig.theftCooldownSeconds ?? 300,
          'appNotification': true,
          'wpNotification': true,
          'schedule': _buildScheduleConfig(cameraConfig.theftSchedule),
        };
      }
      
      // Restricted Area Algorithm
      if (cameraConfig.restrictedAreaEnabled == true) {
        algorithms['restrictedArea'] = {
          'enabled': true,
          'threshold': cameraConfig.confidenceThreshold ?? 0.15,
          'cooldownSeconds': cameraConfig.restrictedAreaCooldownSeconds ?? 300,
          'appNotification': true,
          'wpNotification': true,
          'schedule': _buildScheduleConfig(cameraConfig.restrictedAreaSchedule),
        };
      }
      
      // Prepare camera document
      final cameraData = {
        'cameraName': cameraConfig.name,
        'rtspUrlEncrypted': _encryptRtspUrl(cameraConfig.url), // Encrypt RTSP URL as per firebase.md
        'createdAt': FieldValue.serverTimestamp(),
        'algorithms': algorithms,
      };
      
      // Save to Firebase
      await firestore
          .collection('devices')
          .doc(deviceId)
          .collection('cameras')
          .doc(cameraId)
          .set(cameraData, SetOptions(merge: true));
      
      LoggerService.i('✅ Camera synced: ${cameraConfig.name} with ${algorithms.length} algorithms');
    } catch (e) {
      LoggerService.e('❌ Failed to sync camera: ${cameraConfig.name}', e);
      rethrow;
    }
  }

  /// Build schedule configuration for Firebase
  Map<String, dynamic> _buildScheduleConfig(dynamic schedule) {
    if (schedule == null) {
      return {
        'enabled': false,
        'activeDays': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
        'startMinute': 0,
        'endMinute': 1439, // 23:59 in minutes
      };
    }
    
    return {
      'enabled': true,
      'activeDays': _convertDaysToFirebase(schedule.activeDays ?? []),
      'startMinute': schedule.start?.hour != null && schedule.start?.minute != null 
          ? (schedule.start.hour * 60 + schedule.start.minute)
          : 0,
      'endMinute': schedule.end?.hour != null && schedule.end?.minute != null 
          ? (schedule.end.hour * 60 + schedule.end.minute)
          : 1439,
    };
  }

  /// Convert days to Firebase format
  List<String> _convertDaysToFirebase(List<int> days) {
    const dayMap = {
      1: 'MON',
      2: 'TUE', 
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };
    
    return days.map((day) => dayMap[day] ?? 'MON').toList();
  }

  /// Encrypt RTSP URL (placeholder - implement actual encryption as per firebase.md)
  String _encryptRtspUrl(String rtspUrl) {
    // TODO: Implement AES-256-GCM encryption as specified in firebase.md
    // For now, return a placeholder encrypted format
    return 'ENC:AES256-GCM:${rtspUrl}';
  }

  void nextAlert() {
    if (currentConfigIndex.value < selectedDetections.length - 1) {
      currentConfigIndex.value++;
    } else {
      finishSetup();
    }
  }

  bool get isLastAlert => currentConfigIndex.value == selectedDetections.length - 1;
}
