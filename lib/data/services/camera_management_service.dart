import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/firestore_models.dart';
import '../repositories/local_storage_service.dart';
import '../models/camera_config.dart';
import '../models/roi_config.dart';
import '../models/alert_schedule.dart';
import '../services/device_management_service.dart';
import '../services/rtsp_url_encryption_service.dart';
import '../services/alert_logging_service.dart';
import '../services/error_logging_service.dart';

/// ===========================================================
/// CAMERA MANAGEMENT SERVICE
/// Handles camera configuration management with Firebase synchronization
/// ===========================================================
class CameraManagementService {
  static CameraManagementService? _instance;
  static CameraManagementService get instance => _instance ??= CameraManagementService._();
  
  CameraManagementService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final DeviceManagementService _deviceService;
  late final RTSPURLEncryptionService _encryptionService;
  late final AlertLoggingService _alertService;
  late final ErrorLoggingService _errorService;
  
  // Firebase references
  late final CollectionReference<FirestoreCamera> _camerasCollection;
  
  // Local state
  final List<FirestoreCamera> _cameras = [];
  final StreamController<CameraEvent> _eventController = StreamController<CameraEvent>.broadcast();
  final StreamController<List<FirestoreCamera>> _camerasController = StreamController<List<FirestoreCamera>>.broadcast();
  
  // State
  bool _isInitialized = false;
  bool _isOnline = false;
  StreamSubscription<QuerySnapshot<FirestoreCamera>>? _camerasSubscription;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  List<FirestoreCamera> get cameras => List.unmodifiable(_cameras);
  Stream<CameraEvent> get events => _eventController.stream;
  Stream<List<FirestoreCamera>> get cameraStream => _camerasController.stream;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      _localStorage = LocalStorageService.instance;
      _deviceService = DeviceManagementService.instance;
      _encryptionService = RTSPURLEncryptionService.instance;
      _alertService = AlertLoggingService.instance;
      _errorService = ErrorLoggingService.instance;
      
      // Initialize services
      await _encryptionService.initialize();
      
      // Setup collection reference
      final deviceId = _deviceService.deviceId;
      _camerasCollection = _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('cameras')
          .withConverter<FirestoreCamera>(
            fromFirestore: FirestoreCamera.fromFirestore,
            toFirestore: (camera, options) => camera.toFirestore(),
          );

      // Load cameras
      await _loadCameras();
      
      // Setup real-time listener
      _setupCamerasListener();
      
      // Setup device status listener
      _setupDeviceStatusListener();
      
      _isInitialized = true;
      _isOnline = _deviceService.isOnline;
      
      debugPrint('📷 Camera Management Service initialized');
      _eventController.add(CameraEvent(CameraEventType.initialized, 'Camera service initialized'));
      
    } catch (e) {
      debugPrint('❌ Error initializing Camera Management Service: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Initialization failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// CAMERA MANAGEMENT
  /// ===========================================================
  Future<String> addCamera({
    required String cameraName,
    required String rtspUrl,
    Map<String, AlgorithmConfig>? algorithms,
  }) async {
    if (!_isInitialized) throw Exception('Service not initialized');

    try {
      // Validate RTSP URL
      final validationError = RTSPURLValidator.validateAndGetError(rtspUrl);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }

      // Encrypt RTSP URL
      final encryptedUrl = _encryptionService.encryptRTSPUrl(rtspUrl);
      
      // Generate camera ID
      final cameraId = _generateCameraId();
      
      // Create algorithms configuration
      final algorithmsConfig = algorithms ?? _getDefaultAlgorithms();
      
      // Create Firestore camera
      final firestoreCamera = FirestoreCamera(
        cameraId: cameraId,
        cameraName: cameraName,
        rtspUrlEncrypted: encryptedUrl,
        createdAt: Timestamp.now(),
        algorithms: algorithmsConfig,
      );

      // Save to Firebase
      await _camerasCollection.doc(cameraId).set(firestoreCamera);
      
      // Add to local cache
      _cameras.add(firestoreCamera);
      _camerasController.add(List.unmodifiable(_cameras));
      
      // Save to local storage
      await _saveCameraToLocal(firestoreCamera);
      
      debugPrint('📷 Camera added: $cameraName');
      _eventController.add(CameraEvent(CameraEventType.added, 'Camera added: $cameraName'));
      
      return cameraId;
      
    } catch (e) {
      debugPrint('❌ Error adding camera: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Add failed: $e'));
      rethrow;
    }
  }

  Future<void> updateCamera({
    required String cameraId,
    String? cameraName,
    String? rtspUrl,
    Map<String, AlgorithmConfig>? algorithms,
  }) async {
    if (!_isInitialized) return;

    try {
      final cameraIndex = _cameras.indexWhere((c) => c.cameraId == cameraId);
      if (cameraIndex == -1) {
        throw Exception('Camera not found: $cameraId');
      }

      final existingCamera = _cameras[cameraIndex];
      
      // Prepare updates
      String? encryptedUrl;
      if (rtspUrl != null) {
        final validationError = RTSPURLValidator.validateAndGetError(rtspUrl);
        if (validationError != null) {
          throw ArgumentError(validationError);
        }
        encryptedUrl = _encryptionService.encryptRTSPUrl(rtspUrl);
      }

      // Create updated camera
      final updatedCamera = existingCamera.copyWith(
        cameraName: cameraName,
        rtspUrlEncrypted: encryptedUrl,
        algorithms: algorithms ?? existingCamera.algorithms,
      );

      // Update Firebase
      await _camerasCollection.doc(cameraId).update(updatedCamera.toFirestore());
      
      // Update local cache
      _cameras[cameraIndex] = updatedCamera;
      _camerasController.add(List.unmodifiable(_cameras));
      
      // Update local storage
      await _saveCameraToLocal(updatedCamera);
      
      debugPrint('📷 Camera updated: $cameraId');
      _eventController.add(CameraEvent(CameraEventType.updated, 'Camera updated: $cameraId'));
      
    } catch (e) {
      debugPrint('❌ Error updating camera: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Update failed: $e'));
      rethrow;
    }
  }

  Future<void> deleteCamera(String cameraId) async {
    if (!_isInitialized) return;

    try {
      final cameraIndex = _cameras.indexWhere((c) => c.cameraId == cameraId);
      if (cameraIndex == -1) {
        throw Exception('Camera not found: $cameraId');
      }

      final camera = _cameras[cameraIndex];
      
      // Delete from Firebase
      await _camerasCollection.doc(cameraId).delete();
      
      // Remove from local cache
      _cameras.removeAt(cameraIndex);
      _camerasController.add(List.unmodifiable(_cameras));
      
      // Remove from local storage
      await _localStorage.storage.write('camera_$cameraId', null);
      
      debugPrint('📷 Camera deleted: $cameraId');
      _eventController.add(CameraEvent(CameraEventType.deleted, 'Camera deleted: $cameraId'));
      
    } catch (e) {
      debugPrint('❌ Error deleting camera: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Delete failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// ALGORITHM MANAGEMENT
  /// ===========================================================
  Future<void> updateAlgorithmConfig({
    required String cameraId,
    required String algorithmType,
    required AlgorithmConfig config,
  }) async {
    if (!_isInitialized) return;

    try {
      final cameraIndex = _cameras.indexWhere((c) => c.cameraId == cameraId);
      if (cameraIndex == -1) {
        throw Exception('Camera not found: $cameraId');
      }

      final camera = _cameras[cameraIndex];
      final updatedAlgorithms = Map<String, AlgorithmConfig>.from(camera.algorithms);
      updatedAlgorithms[algorithmType] = config;

      await updateCamera(
        cameraId: cameraId,
        algorithms: updatedAlgorithms,
      );
      
      debugPrint('⚙️ Algorithm config updated: $algorithmType for $cameraId');
      _eventController.add(CameraEvent(CameraEventType.configUpdated, 'Algorithm updated: $algorithmType'));
      
    } catch (e) {
      debugPrint('❌ Error updating algorithm config: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Config update failed: $e'));
      rethrow;
    }
  }

  Future<void> enableAlgorithm({
    required String cameraId,
    required String algorithmType,
    bool enabled = true,
  }) async {
    final camera = _getCameraById(cameraId);
    if (camera == null) return;

    final config = camera.algorithms[algorithmType];
    if (config == null) return;

    final updatedConfig = config.copyWith(enabled: enabled);
    await updateAlgorithmConfig(
      cameraId: cameraId,
      algorithmType: algorithmType,
      config: updatedConfig,
    );
  }

  /// ===========================================================
  /// CAMERA CONFIGURATION CONVERSION
  /// ===========================================================
  CameraConfig convertToCameraConfig(FirestoreCamera firestoreCamera) {
    // Decrypt RTSP URL
    final rtspUrl = _encryptionService.decryptRTSPUrl(firestoreCamera.rtspUrlEncrypted);
    
    // Convert algorithms to feature flags and configurations
    final algorithms = firestoreCamera.algorithms;
    
    // Extract footfall configuration
    final footfallAlgorithm = algorithms['FOOTFALL'];
    final footfallConfig = footfallAlgorithm != null 
        ? _convertToRoiAlertConfig(footfallAlgorithm, isFootfall: true)
        : RoiAlertConfig.defaultConfig();
    
    // Extract restricted area configuration
    final restrictedAlgorithm = algorithms['RESTRICTED_AREA'];
    final restrictedConfig = restrictedAlgorithm != null
        ? _convertToRoiAlertConfig(restrictedAlgorithm, isFootfall: false)
        : RoiAlertConfig.forRestrictedArea(roi: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4));
    
    return CameraConfig(
      name: firestoreCamera.cameraName,
      url: rtspUrl,
      confidenceThreshold: algorithms['PERSON_DETECTION']?.threshold ?? 0.15,
      
      // Feature flags
      peopleCountEnabled: algorithms['PERSON_DETECTION']?.enabled ?? false,
      footfallEnabled: footfallAlgorithm?.enabled ?? false,
      maxPeopleEnabled: algorithms['MAX_PEOPLE']?.enabled ?? false,
      absentAlertEnabled: algorithms['ABSENT_DETECTION']?.enabled ?? false,
      theftAlertEnabled: algorithms['THEFT_DETECTION']?.enabled ?? false,
      restrictedAreaEnabled: restrictedAlgorithm?.enabled ?? false,
      
      // ROI configurations
      footfallConfig: footfallConfig,
      restrictedAreaConfig: restrictedConfig,
      
      // Timing configurations
      footfallIntervalMinutes: footfallAlgorithm?.alertInterval ?? 60,
      maxPeople: algorithms['MAX_PEOPLE']?.maxCapacity ?? 5,
      maxPeopleCooldownSeconds: algorithms['MAX_PEOPLE']?.cooldownSeconds ?? 300,
      absentSeconds: algorithms['ABSENT_DETECTION']?.absentInterval ?? 60,
      absentCooldownSeconds: algorithms['ABSENT_DETECTION']?.cooldownSeconds ?? 600,
      theftCooldownSeconds: algorithms['THEFT_DETECTION']?.cooldownSeconds ?? 300,
      restrictedAreaCooldownSeconds: restrictedAlgorithm?.cooldownSeconds ?? 300,
      
      // Schedules
      footfallSchedule: _convertToAlertSchedule(footfallAlgorithm?.schedule),
      maxPeopleSchedule: _convertToAlertSchedule(algorithms['MAX_PEOPLE']?.schedule),
      absentSchedule: _convertToAlertSchedule(algorithms['ABSENT_DETECTION']?.schedule),
      theftSchedule: _convertToAlertSchedule(algorithms['THEFT_DETECTION']?.schedule),
      restrictedAreaSchedule: _convertToAlertSchedule(restrictedAlgorithm?.schedule),
    );
  }

  FirestoreCamera convertToFirestoreCamera(CameraConfig cameraConfig) {
    // Encrypt RTSP URL
    final encryptedUrl = _encryptionService.encryptRTSPUrl(cameraConfig.url);
    
    // Convert feature configurations to algorithms
    final algorithms = <String, AlgorithmConfig>{};
    
    // Person detection algorithm
    algorithms['PERSON_DETECTION'] = AlgorithmConfig(
      enabled: cameraConfig.peopleCountEnabled,
      threshold: cameraConfig.confidenceThreshold,
      appNotification: true,
      schedule: const ScheduleConfig(enabled: false, activeDays: [], startMinute: 0, endMinute: 1439),
    );
    
    // Footfall algorithm
    if (cameraConfig.footfallEnabled) {
      algorithms['FOOTFALL'] = AlgorithmConfig(
        enabled: cameraConfig.footfallEnabled,
        threshold: cameraConfig.confidenceThreshold,
        alertInterval: cameraConfig.footfallIntervalMinutes,
        cooldownSeconds: 300, // Default cooldown
        appNotification: true,
        schedule: _convertFromAlertSchedule(cameraConfig.footfallSchedule),
      );
    }
    
    // Max people algorithm
    if (cameraConfig.maxPeopleEnabled) {
      algorithms['MAX_PEOPLE'] = AlgorithmConfig(
        enabled: cameraConfig.maxPeopleEnabled,
        threshold: cameraConfig.confidenceThreshold,
        maxCapacity: cameraConfig.maxPeople,
        cooldownSeconds: cameraConfig.maxPeopleCooldownSeconds,
        appNotification: true,
        schedule: _convertFromAlertSchedule(cameraConfig.maxPeopleSchedule),
      );
    }
    
    // Absent detection algorithm
    if (cameraConfig.absentAlertEnabled) {
      algorithms['ABSENT_DETECTION'] = AlgorithmConfig(
        enabled: cameraConfig.absentAlertEnabled,
        threshold: cameraConfig.confidenceThreshold,
        absentInterval: cameraConfig.absentSeconds,
        cooldownSeconds: cameraConfig.absentCooldownSeconds,
        appNotification: true,
        schedule: _convertFromAlertSchedule(cameraConfig.absentSchedule),
      );
    }
    
    // Theft detection algorithm
    if (cameraConfig.theftAlertEnabled) {
      algorithms['THEFT_DETECTION'] = AlgorithmConfig(
        enabled: cameraConfig.theftAlertEnabled,
        threshold: cameraConfig.confidenceThreshold,
        cooldownSeconds: cameraConfig.theftCooldownSeconds,
        appNotification: true,
        schedule: _convertFromAlertSchedule(cameraConfig.theftSchedule),
      );
    }
    
    // Restricted area algorithm
    if (cameraConfig.restrictedAreaEnabled) {
      algorithms['RESTRICTED_AREA'] = AlgorithmConfig(
        enabled: cameraConfig.restrictedAreaEnabled,
        threshold: cameraConfig.confidenceThreshold,
        cooldownSeconds: cameraConfig.restrictedAreaCooldownSeconds,
        appNotification: true,
        schedule: _convertFromAlertSchedule(cameraConfig.restrictedAreaSchedule),
      );
    }

    return FirestoreCamera(
      cameraId: _generateCameraId(),
      cameraName: cameraConfig.name,
      rtspUrlEncrypted: encryptedUrl,
      createdAt: Timestamp.now(),
      algorithms: algorithms,
    );
  }

  /// ===========================================================
  /// INSTALLER TEST MANAGEMENT
  /// ===========================================================
  Future<void> saveInstallerTest({
    required String cameraId,
    required String algorithmType,
    required TestResult result,
    required String testedBy,
    String? notes,
  }) async {
    if (!_isInitialized) return;

    try {
      final deviceId = _deviceService.deviceId;
      final testCollection = _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('cameras')
          .doc(cameraId)
          .collection('installerTests')
          .withConverter<InstallerTest>(
            fromFirestore: InstallerTest.fromFirestore,
            toFirestore: (test, options) => test.toFirestore(),
          );

      final test = InstallerTest(
        algorithmType: algorithmType,
        result: result,
        testedAt: Timestamp.now(),
        testedBy: testedBy,
        notes: notes,
        createdAt: Timestamp.now(),
      );

      await testCollection.doc(algorithmType).set(test);
      
      debugPrint('🧪 Installer test saved: $algorithmType - $result');
      _eventController.add(CameraEvent(CameraEventType.testCompleted, 'Test completed: $algorithmType'));
      
    } catch (e) {
      debugPrint('❌ Error saving installer test: $e');
      _eventController.add(CameraEvent(CameraEventType.error, 'Test save failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// UTILITY METHODS
  /// ===========================================================
  FirestoreCamera? _getCameraById(String cameraId) {
    try {
      return _cameras.firstWhere((camera) => camera.cameraId == cameraId);
    } catch (e) {
      return null;
    }
  }

  String _generateCameraId() {
    return 'cam_${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, AlgorithmConfig> _getDefaultAlgorithms() {
    return {
      'PERSON_DETECTION': AlgorithmConfig(
        enabled: true,
        threshold: 0.15,
        appNotification: true,
        schedule: const ScheduleConfig(enabled: false, activeDays: [], startMinute: 0, endMinute: 1439),
      ),
    };
  }

  /// ===========================================================
  /// LISTENERS
  /// ===========================================================
  void _setupCamerasListener() {
    _camerasSubscription = _camerasCollection
        .snapshots()
        .listen(
          (snapshot) => _handleCamerasUpdate(snapshot),
          onError: (error) {
            debugPrint('❌ Cameras listener error: $error');
            _eventController.add(CameraEvent(CameraEventType.error, 'Listener error: $error'));
          },
        );
  }

  void _handleCamerasUpdate(QuerySnapshot<FirestoreCamera> snapshot) {
    final updatedCameras = snapshot.docs.map((doc) => doc.data()).toList();
    
    // Update local cache
    _cameras.clear();
    _cameras.addAll(updatedCameras);
    _camerasController.add(List.unmodifiable(_cameras));
    
    debugPrint('📷 Cameras updated: ${updatedCameras.length} cameras');
    _eventController.add(CameraEvent(CameraEventType.synced, 'Cameras synced from Firebase'));
  }

  void _setupDeviceStatusListener() {
    _deviceService.events.listen((event) {
      if (event.type == DeviceEventType.statusChanged) {
        _isOnline = _deviceService.isOnline;
      }
    });
  }

  /// ===========================================================
  /// LOCAL STORAGE
  /// ===========================================================
  Future<void> _loadCameras() async {
    try {
      // Load from Firebase first if online
      if (_isOnline) {
        final snapshot = await _camerasCollection.get();
        _cameras.addAll(snapshot.docs.map((doc) => doc.data()));
      } else {
        // Load from local storage
        final cameraKeys = _localStorage.storage.getKeys().where((key) => key.startsWith('camera_'));
        
        for (final key in cameraKeys) {
          try {
            final cameraData = _localStorage.storage.read(key);
            if (cameraData != null) {
              // Convert local storage format to FirestoreCamera
              // This would need implementation based on your local storage format
            }
          } catch (e) {
            debugPrint('⚠️ Failed to load camera from local storage: $e');
          }
        }
      }
      
      debugPrint('📷 Loaded ${_cameras.length} cameras');
      
    } catch (e) {
      debugPrint('❌ Error loading cameras: $e');
    }
  }

  Future<void> _saveCameraToLocal(FirestoreCamera camera) async {
    try {
      // Save camera data to local storage
      final cameraData = {
        'cameraId': camera.cameraId,
        'cameraName': camera.cameraName,
        'rtspUrlEncrypted': camera.rtspUrlEncrypted,
        'createdAt': camera.createdAt.millisecondsSinceEpoch,
        'algorithms': camera.algorithms.map((key, config) => MapEntry(key, config.toMap())),
      };
      
      await _localStorage.storage.write('camera_${camera.cameraId}', cameraData);
    } catch (e) {
      debugPrint('⚠️ Failed to save camera to local storage: $e');
    }
  }

  /// ===========================================================
  /// CONVERSION HELPERS
  /// ===========================================================
  RoiAlertConfig _convertToRoiAlertConfig(AlgorithmConfig config, {required bool isFootfall}) {
    if (isFootfall) {
      return RoiAlertConfig.forFootfall();
    } else {
      return RoiAlertConfig.forRestrictedArea(
        roi: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
      );
    }
  }

  AlertSchedule? _convertToAlertSchedule(ScheduleConfig? scheduleConfig) {
    if (scheduleConfig == null || !scheduleConfig.enabled) return null;
    
    return AlertSchedule(
      start: TimeOfDay(hour: scheduleConfig.startMinute ~/ 60, minute: scheduleConfig.startMinute % 60),
      end: TimeOfDay(hour: scheduleConfig.endMinute ~/ 60, minute: scheduleConfig.endMinute % 60),
      activeDays: scheduleConfig.activeDays.map(_dayStringToInt).toList(),
    );
  }

  ScheduleConfig _convertFromAlertSchedule(AlertSchedule? alertSchedule) {
    if (alertSchedule == null) {
      return const ScheduleConfig(enabled: false, activeDays: [], startMinute: 0, endMinute: 1439);
    }
    
    return ScheduleConfig(
      enabled: true,
      activeDays: alertSchedule.activeDays.map(_dayIntToString).toList(),
      startMinute: alertSchedule.start.hour * 60 + alertSchedule.start.minute,
      endMinute: alertSchedule.end.hour * 60 + alertSchedule.end.minute,
    );
  }

  String _dayIntToString(int day) {
    switch (day) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return 'MON';
    }
  }

  int _dayStringToInt(String day) {
    switch (day) {
      case 'MON': return 1;
      case 'TUE': return 2;
      case 'WED': return 3;
      case 'THU': return 4;
      case 'FRI': return 5;
      case 'SAT': return 6;
      case 'SUN': return 7;
      default: return 1;
    }
  }

  /// ===========================================================
  /// DISPOSAL
  /// ===========================================================
  Future<void> dispose() async {
    await _camerasSubscription?.cancel();
    await _eventController.close();
    await _camerasController.close();
    
    _isInitialized = false;
    
    debugPrint('📷 Camera Management Service disposed');
  }
}

/// ===========================================================
/// CAMERA EVENT MODEL
/// ===========================================================
class CameraEvent {
  final CameraEventType type;
  final String message;
  final DateTime timestamp;

  CameraEvent(this.type, this.message) : timestamp = DateTime.now();

  @override
  String toString() => 'CameraEvent($type, $message, $timestamp)';
}

enum CameraEventType {
  initialized,
  added,
  updated,
  deleted,
  synced,
  configUpdated,
  testCompleted,
  error,
}
