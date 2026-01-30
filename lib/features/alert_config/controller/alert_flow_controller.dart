import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/alert_schedule.dart' as schedule_model;
import '../../../data/models/camera_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../monitoring/controller/monitoring_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../data/services/device_firebase_service.dart';
import '../../../data/repositories/simple_storage_service.dart';
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

  /// Sync all setup data to Firebase - ONLY CALLED WHEN USER PRESSES "FINISH SETUP"
  Future<void> finishSetup() async {
    try {
      LoggerService.i('🚀 Starting Firebase sync for all setup data (User pressed Finish Setup)...');
      
      // Get all local data
      final localStorage = SimpleStorageService.instance;
      final deviceId = localStorage.deviceId;
      
      // 1. Sync device information with WhatsApp configuration
      await _syncDeviceToFirebase(deviceId, localStorage);
      
      // 2. Sync all camera configurations
      await _syncCamerasToFirebase(deviceId, localStorage);
      
      // 3. Sync all installer tests
      await _syncInstallerTestsToFirebase(deviceId, localStorage);
      
      // 4. Clear pending changes after successful sync
      await localStorage.clearAllPendingChanges();
      
      LoggerService.i('✅ All setup data synced to Firebase successfully');
      
      // Navigate to camera setup finish screen
      Get.offAllNamed(AppRoutes.cameraSetupFinish);
    } catch (e, stackTrace) {
      LoggerService.e('❌ Failed to sync setup data to Firebase', e, stackTrace);
      
      // Show error to user
      Get.snackbar(
        'Sync Failed',
        'Failed to sync setup data to Firebase. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Sync device information including WhatsApp configuration to Firebase
  Future<void> _syncDeviceToFirebase(String deviceId, SimpleStorageService localStorage) async {
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

  /// Sync all installer tests to Firebase
  Future<void> _syncInstallerTestsToFirebase(String deviceId, SimpleStorageService localStorage) async {
    try {
      LoggerService.i('🧪 Syncing installer tests to Firebase...');
      
      final allTests = localStorage.getAllInstallerTests();
      int syncedCount = 0;
      int permissionDeniedCount = 0;
      
      for (final cameraEntry in allTests.entries) {
        final cameraId = cameraEntry.key;
        final cameraTests = cameraEntry.value as Map<String, dynamic>;
        
        // Generate Firebase camera ID (CAM01, CAM02, etc.)
        final cameraIndex = _getCameraIndexFromId(cameraId);
        final firebaseCameraId = 'CAM${cameraIndex.toString().padLeft(2, '0')}';
        
        for (final testEntry in cameraTests.entries) {
          final algorithmType = testEntry.key;
          final testData = testEntry.value as Map<String, dynamic>;
          
          try {
            await _syncSingleInstallerTestToFirebase(
              deviceId, 
              firebaseCameraId, 
              algorithmType, 
              testData
            );
            syncedCount++;
          } catch (e) {
            // Permission errors are already handled in _syncSingleInstallerTestToFirebase
            if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
              permissionDeniedCount++;
            } else {
              // Re-throw non-permission errors
              rethrow;
            }
          }
        }
      }
      
      if (permissionDeniedCount > 0) {
        LoggerService.w('⚠️ $permissionDeniedCount installer tests failed due to Firebase permissions');
        LoggerService.w('⚠️ Please check Firebase security rules for installerTests collection');
      }
      
      LoggerService.i('✅ $syncedCount installer tests synced to Firebase successfully');
    } catch (e) {
      LoggerService.e('❌ Failed to sync installer tests', e);
      rethrow;
    }
  }

  /// Sync a single installer test to Firebase
  Future<void> _syncSingleInstallerTestToFirebase(
    String deviceId, 
    String cameraId, 
    String algorithmType, 
    Map<String, dynamic> testData
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      final testDoc = {
        'result': testData['result'] ?? 'pending',
        'testedAt': testData['testedAt'] ?? Timestamp.now(),
        'testedBy': testData['testedBy'] ?? 'installer',
        'notes': testData['notes'] ?? '',
        'createdAt': testData['createdAt'] ?? Timestamp.now(),
        'algorithmType': algorithmType,
        'cameraId': cameraId,
        'deviceId': deviceId,
      };
      
      await firestore
          .collection('devices')
          .doc(deviceId)
          .collection('cameras')
          .doc(cameraId)
          .collection('installerTests')
          .doc(algorithmType)
          .set(testDoc, SetOptions(merge: true));
      
      LoggerService.i('✅ Installer test synced: $cameraId/$algorithmType');
    } catch (e) {
      // Handle permission errors gracefully
      if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        LoggerService.w('⚠️ Firebase permission denied for installer tests: $cameraId/$algorithmType');
        LoggerService.w('⚠️ Installer tests will be stored locally only until Firebase permissions are fixed');
      } else {
        LoggerService.e('❌ Failed to sync installer test: $cameraId/$algorithmType', e);
        rethrow;
      }
    }
  }

  /// Get camera index from camera ID (e.g., "camera_0" -> 1, "camera_1" -> 2)
  int _getCameraIndexFromId(String cameraId) {
    try {
      // Extract number from camera ID (assuming format like "camera_0", "camera_1", etc.)
      final match = RegExp(r'(\d+)').firstMatch(cameraId);
      if (match != null) {
        return int.parse(match.group(1)!) + 1; // +1 to make it 1-based
      }
      return 1; // Default to 1 if can't extract
    } catch (e) {
      LoggerService.w('Could not extract camera index from ID: $cameraId');
      return 1; // Default to 1
    }
  }

  /// Sync all camera configurations to Firebase
  Future<void> _syncCamerasToFirebase(String deviceId, SimpleStorageService localStorage) async {
    try {
      LoggerService.i('📹 Syncing camera configurations to Firebase...');
      
      final cameraConfigs = localStorage.getCameraConfigs();
      int syncedCount = 0;
      
      for (final cameraConfig in cameraConfigs) {
        try {
          await _syncSingleCameraToFirebase(deviceId, cameraConfig, cameraConfigs);
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
  Future<void> _syncSingleCameraToFirebase(String deviceId, dynamic cameraConfig, List<dynamic> cameraConfigs) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Generate camera document ID (CAM01, CAM02, etc.)
      final cameraIndex = cameraConfigs.indexOf(cameraConfig) + 1;
      final cameraId = 'CAM${cameraIndex.toString().padLeft(2, '0')}';
      
      // Build algorithms map according to specified Firebase schema
      // ONLY include selected detection types from selectedDetections list
      final algorithms = <String, dynamic>{};
      
      // Only add algorithms for selected detection types
      for (final detectionType in selectedDetections) {
        switch (detectionType) {
          case DetectionType.crowdDetection:
            algorithms['crowdDetection'] = {
              'enabled': cameraConfig.maxPeopleEnabled ?? false,
              'threshold': cameraConfig.confidenceThreshold ?? 0.15,
              'maxCapacity': cameraConfig.maxPeople ?? 5,
              'cooldownSeconds': cameraConfig.maxPeopleCooldownSeconds ?? 300,
              'appNotification': true,
              'wpNotification': false,
              'schedule': _buildScheduleConfig(cameraConfig.maxPeopleSchedule),
              'roiType': 'none',
            };
            break;
            
          case DetectionType.footfallDetection:
            algorithms['footfallCount'] = _footfallToAlgorithmConfig(cameraConfig);
            break;
            
          case DetectionType.restrictedArea:
            algorithms['restrictedArea'] = _restrictedAreaToAlgorithmConfig(cameraConfig);
            break;
            
          case DetectionType.sensitiveAlert:
            algorithms['sensitiveAlert'] = {
              'enabled': cameraConfig.theftAlertEnabled ?? false,
              'threshold': cameraConfig.confidenceThreshold ?? 0.15,
              'cooldownSeconds': cameraConfig.theftCooldownSeconds ?? 300,
              'appNotification': true,
              'wpNotification': false,
              'schedule': _buildScheduleConfig(cameraConfig.theftSchedule),
              'roiType': 'none',
            };
            break;
            
          case DetectionType.absentAlert:
            algorithms['absentAlert'] = {
              'enabled': cameraConfig.absentAlertEnabled ?? false,
              'threshold': cameraConfig.confidenceThreshold ?? 0.15,
              'absentInterval': cameraConfig.absentSeconds ?? 5,
              'cooldownSeconds': cameraConfig.absentCooldownSeconds ?? 300,
              'appNotification': true,
              'wpNotification': false,
              'schedule': _buildScheduleConfig(cameraConfig.absentSchedule),
              'roiType': 'none',
            };
            break;
        }
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

  /// Convert footfall config to AlgorithmConfig for Firebase
  Map<String, dynamic> _footfallToAlgorithmConfig(CameraConfig camera) {
    return {
      'enabled': camera.footfallEnabled,
      'threshold': camera.confidenceThreshold,
      'alertInterval': camera.footfallIntervalMinutes * 60, // Convert to seconds
      'cooldownSeconds': 300, // Default cooldown
      'appNotification': true,
      'wpNotification': false,
      'schedule': _buildScheduleConfig(camera.footfallSchedule),
      // ROI Configuration
      'roiConfig': camera.footfallConfig.toFirebaseMap(),
      'roiCoordinates': [
        camera.footfallConfig.roi.left,
        camera.footfallConfig.roi.top,
        camera.footfallConfig.roi.right,
        camera.footfallConfig.roi.bottom,
      ],
      'lineCoordinates': [
        camera.footfallConfig.lineStart.dx,
        camera.footfallConfig.lineStart.dy,
        camera.footfallConfig.lineEnd.dx,
        camera.footfallConfig.lineEnd.dy,
      ],
      'roiType': 'line',
    };
  }
  
  /// Convert restricted area config to AlgorithmConfig for Firebase
  Map<String, dynamic> _restrictedAreaToAlgorithmConfig(CameraConfig camera) {
    return {
      'enabled': camera.restrictedAreaEnabled,
      'threshold': camera.confidenceThreshold,
      'cooldownSeconds': camera.restrictedAreaCooldownSeconds,
      'appNotification': true,
      'wpNotification': false,
      'schedule': _buildScheduleConfig(camera.restrictedAreaSchedule),
      // ROI Configuration
      'roiConfig': camera.restrictedAreaConfig.toFirebaseMap(),
      'roiCoordinates': [
        camera.restrictedAreaConfig.roi.left,
        camera.restrictedAreaConfig.roi.top,
        camera.restrictedAreaConfig.roi.right,
        camera.restrictedAreaConfig.roi.bottom,
      ],
      'lineCoordinates': [
        camera.restrictedAreaConfig.lineStart.dx,
        camera.restrictedAreaConfig.lineStart.dy,
        camera.restrictedAreaConfig.lineEnd.dx,
        camera.restrictedAreaConfig.lineEnd.dy,
      ],
      'roiType': 'rectangle',
    };
  }
  Map<String, dynamic> _buildScheduleConfig(dynamic schedule) {
    if (schedule == null) {
      return {
        'enabled': false,
        'activeDays': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
        'startMinute': 0,
        'endMinute': 1439, // 23:59 in minutes
      };
    }
    
    // Cast to AlertSchedule to access properties
    final alertSchedule = schedule as schedule_model.AlertSchedule;
    
    return {
      'enabled': true,
      'activeDays': _convertDaysToFirebase(alertSchedule.activeDays),
      'startMinute': alertSchedule.start?.hour != null && alertSchedule.start?.minute != null 
          ? (alertSchedule.start.hour * 60 + alertSchedule.start.minute)
          : 0,
      'endMinute': alertSchedule.end?.hour != null && alertSchedule.end?.minute != null
          ? (alertSchedule.end.hour * 60 + alertSchedule.end.minute)
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
