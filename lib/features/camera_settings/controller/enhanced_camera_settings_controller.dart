import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/camera_config.dart';
import '../../data/repositories/local_storage_service.dart';
import '../../data/repositories/firebase_sync_service.dart';
import '../../data/repositories/data_validation_service.dart';

/// ===========================================================
/// ENHANCED CAMERA SETTINGS CONTROLLER
/// Integrates with Firebase sync system for real-time
/// synchronization and data validation
/// ===========================================================
class EnhancedCameraSettingsController extends GetxController {
  // ===========================================================
  // SERVICES
  // ===========================================================
  late final LocalStorageService _localStorage;
  late final FirebaseSyncService _firebaseSync;
  late final DataValidationService _validator;

  // ===========================================================
  // STATE VARIABLES
  // ===========================================================
  final RxList<CameraConfig> cameras = <CameraConfig>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Ready'.obs;
  final RxString lastSyncTime = 'Never'.obs;
  final RxList<String> syncErrors = <String>[].obs;
  final RxList<String> validationWarnings = <String>[].obs;

  // Form state
  final RxString cameraName = ''.obs;
  final RxString cameraUrl = ''.obs;
  final RxDouble confidenceThreshold = 0.15.obs;

  // Feature toggles
  final RxBool peopleCountEnabled = true.obs;
  final RxBool footfallEnabled = false.obs;
  final RxBool maxPeopleEnabled = false.obs;
  final RxBool absentAlertEnabled = false.obs;
  final RxBool theftAlertEnabled = false.obs;
  final RxBool restrictedAreaEnabled = true.obs;

  // Current editing camera
  final Rx<CameraConfig?> currentCamera = Rx<CameraConfig?>(null);
  final RxBool isEditing = false.obs;

  // ===========================================================
  // STREAM SUBSCRIPTIONS
  // ===========================================================
  StreamSubscription? _syncSubscription;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeServices();
    await _loadCameras();
    _setupSyncListener();
  }

  @override
  void onClose() {
    _syncSubscription?.cancel();
    super.onClose();
  }

  // ===========================================================
  // INITIALIZATION
  // ===========================================================
  Future<void> _initializeServices() async {
    try {
      _localStorage = LocalStorageService.instance;
      await _localStorage.init();

      _firebaseSync = FirebaseSyncService.instance;
      await _firebaseSync.initialize();

      _validator = DataValidationService.instance;

      // Update sync status
      if (_firebaseSync.isInitialized) {
        syncStatus.value = 'Connected';
        _updateLastSyncTime();
      }
    } catch (e) {
      print('Error initializing services: $e');
      syncStatus.value = 'Error: $e';
      syncErrors.add('Initialization failed: $e');
    }
  }

  // ===========================================================
  // CAMERA MANAGEMENT
  // ===========================================================
  Future<void> _loadCameras() async {
    try {
      isLoading.value = true;
      cameras.value = _localStorage.getCameraConfigs();
      
      // Validate loaded cameras
      final validation = _validator.validateBatchConfigs(cameras);
      validationWarnings.assignAll(validation.allWarnings);
      
      if (!validation.isValid) {
        syncErrors.assignAll(validation.allErrors);
      }
    } catch (e) {
      print('Error loading cameras: $e');
      syncErrors.add('Failed to load cameras: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveCamera() async {
    try {
      isLoading.value = true;

      // Create camera config
      final config = CameraConfig(
        name: cameraName.value.trim(),
        url: cameraUrl.value.trim(),
        confidenceThreshold: confidenceThreshold.value,
        peopleCountEnabled: peopleCountEnabled.value,
        footfallEnabled: footfallEnabled.value,
        maxPeopleEnabled: maxPeopleEnabled.value,
        absentAlertEnabled: absentAlertEnabled.value,
        theftAlertEnabled: theftAlertEnabled.value,
        restrictedAreaEnabled: restrictedAreaEnabled.value,
      );

      // Validate configuration
      final validation = _validator.validateCameraConfig(config);
      if (!validation.isValid) {
        syncErrors.assignAll(validation.errors);
        validationWarnings.assignAll(validation.warnings);
        Get.snackbar(
          'Validation Error',
          'Please fix the validation errors',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Show warnings if any
      if (validation.hasWarnings) {
        validationWarnings.assignAll(validation.warnings);
        Get.snackbar(
          'Warning',
          'Configuration has warnings',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      // Save to local storage
      await _localStorage.saveCameraConfig(config);

      // Sync to Firebase if available
      if (_firebaseSync.isInitialized) {
        try {
          await _firebaseSync.saveCameraConfig(config);
          syncStatus.value = 'Synced';
          _updateLastSyncTime();
        } catch (e) {
          print('Error syncing to Firebase: $e');
          syncStatus.value = 'Local only';
          syncErrors.add('Firebase sync failed: $e');
        }
      }

      // Update local list
      if (isEditing.value && currentCamera.value != null) {
        final index = cameras.indexWhere((c) => c.name == currentCamera.value!.name);
        if (index != -1) {
          cameras[index] = config;
        }
        isEditing.value = false;
        currentCamera.value = null;
      } else {
        cameras.add(config);
      }

      // Reset form
      _resetForm();

      Get.snackbar(
        'Success',
        isEditing.value ? 'Camera updated' : 'Camera added',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving camera: $e');
      syncErrors.add('Failed to save camera: $e');
      Get.snackbar(
        'Error',
        'Failed to save camera',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteCamera(CameraConfig camera) async {
    try {
      isLoading.value = true;

      // Delete from local storage
      await _localStorage.deleteCameraConfig(camera.name);

      // Delete from Firebase if available
      if (_firebaseSync.isInitialized) {
        try {
          await _firebaseSync.deleteCameraConfig(camera.name);
        } catch (e) {
          print('Error deleting from Firebase: $e');
          syncErrors.add('Firebase delete failed: $e');
        }
      }

      // Update local list
      cameras.remove(camera);

      Get.snackbar(
        'Success',
        'Camera deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error deleting camera: $e');
      syncErrors.add('Failed to delete camera: $e');
      Get.snackbar(
        'Error',
        'Failed to delete camera',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void editCamera(CameraConfig camera) {
    currentCamera.value = camera;
    isEditing.value = true;

    // Populate form
    cameraName.value = camera.name;
    cameraUrl.value = camera.url;
    confidenceThreshold.value = camera.confidenceThreshold;
    peopleCountEnabled.value = camera.peopleCountEnabled;
    footfallEnabled.value = camera.footfallEnabled;
    maxPeopleEnabled.value = camera.maxPeopleEnabled;
    absentAlertEnabled.value = camera.absentAlertEnabled;
    theftAlertEnabled.value = camera.theftAlertEnabled;
    restrictedAreaEnabled.value = camera.restrictedAreaEnabled;
  }

  void cancelEdit() {
    isEditing.value = false;
    currentCamera.value = null;
    _resetForm();
  }

  // ===========================================================
  // SYNC MANAGEMENT
  // ===========================================================
  void _setupSyncListener() {
    _syncSubscription = _firebaseSync.syncEvents.listen((event) {
      switch (event.type) {
        case SyncEventType.syncStarted:
          isSyncing.value = true;
          syncStatus.value = 'Syncing...';
          break;
        case SyncEventType.syncCompleted:
          isSyncing.value = false;
          syncStatus.value = 'Synced';
          _updateLastSyncTime();
          _loadCameras(); // Reload to get latest data
          break;
        case SyncEventType.error:
          isSyncing.value = false;
          syncStatus.value = 'Error';
          syncErrors.add(event.message);
          break;
        case SyncEventType.added:
        case SyncEventType.updated:
        case SyncEventType.deleted:
          // These will be handled by sync completed event
          break;
        case SyncEventType.initialized:
          syncStatus.value = 'Connected';
          break;
      }
    });
  }

  Future<void> manualSync() async {
    if (!_firebaseSync.isInitialized) {
      Get.snackbar(
        'Error',
        'Firebase sync not initialized',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      syncErrors.clear();
      final result = await _firebaseSync.fullSync();
      
      if (result.success) {
        Get.snackbar(
          'Success',
          result.message,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Sync Error',
          result.message,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error during manual sync: $e');
      Get.snackbar(
        'Error',
        'Manual sync failed',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _updateLastSyncTime() {
    final lastSync = _firebaseSync.lastSyncTime;
    if (lastSync != null) {
      lastSyncTime.value = _formatDateTime(lastSync);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // ===========================================================
  // FORM MANAGEMENT
  // ===========================================================
  void _resetForm() {
    cameraName.value = '';
    cameraUrl.value = '';
    confidenceThreshold.value = 0.15;
    peopleCountEnabled.value = true;
    footfallEnabled.value = false;
    maxPeopleEnabled.value = false;
    absentAlertEnabled.value = false;
    theftAlertEnabled.value = false;
    restrictedAreaEnabled.value = true;
  }

  void clearErrors() {
    syncErrors.clear();
    validationWarnings.clear();
  }

  // ===========================================================
  // UTILITY METHODS
  // ===========================================================
  String get deviceId => _localStorage.deviceId;
  
  bool get hasUnsyncedChanges => _localStorage.pendingChanges.isNotEmpty;
  
  int get pendingChangesCount => _localStorage.pendingChanges.length;

  // Validation helpers
  bool validateForm() {
    return cameraName.value.trim().isNotEmpty && 
           cameraUrl.value.trim().isNotEmpty;
  }

  String? validateCameraName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Camera name is required';
    }
    
    // Check for duplicate names (except when editing the same camera)
    final duplicate = cameras.firstWhereOrNull(
      (c) => c.name.toLowerCase() == value.trim().toLowerCase() && 
             (!isEditing.value || c.name != currentCamera.value?.name),
    );
    
    if (duplicate != null) {
      return 'Camera name already exists';
    }
    
    return null;
  }

  String? validateCameraUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Camera URL is required';
    }
    
    if (!value.startsWith('rtsp://') && 
        !value.startsWith('http://') && 
        !value.startsWith('https://')) {
      return 'URL must start with rtsp://, http://, or https://';
    }
    
    return null;
  }

  String? validateConfidenceThreshold(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confidence threshold is required';
    }
    
    final threshold = double.tryParse(value);
    if (threshold == null) {
      return 'Must be a valid number';
    }
    
    if (threshold < 0.0 || threshold > 1.0) {
      return 'Must be between 0.0 and 1.0';
    }
    
    return null;
  }
}
