import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_config.dart';
import '../models/firestore_camera_config.dart';
import '../models/roi_config.dart';
import '../models/alert_schedule.dart' as alert_schedule;
import '../adapters/alert_schedule_adapter.dart';
import '../../core/logging/logger_service.dart';
import '../../core/utils/device_id_coordinator.dart';

/// ===========================================================
/// HIVE-BASED LOCAL STORAGE SERVICE
/// Industry-standard, scalable, type-safe local storage
/// ===========================================================
class HiveStorageService {
  static HiveStorageService? _instance;
  static HiveStorageService get instance => _instance ??= HiveStorageService._();
  
  HiveStorageService._();

  // Box references
  late Box<Map<String, dynamic>> _cameraConfigsBox;
  late Box<Map<String, dynamic>> _firestoreConfigsBox;
  late Box<Map<String, dynamic>> _installerTestsBox;
  late Box<Map<String, dynamic>> _syncMetadataBox;
  late Box<Map<String, dynamic>> _whatsappConfigBox;
  late Box<Map<String, dynamic>> _pendingChangesBox;
  
  // Device ID
  late Box<String> _deviceBox;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> init() async {
    try {
      // Initialize Hive
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(AlertScheduleAdapter());
      }
      
      // Open boxes
      await _openBoxes();
      
      // Initialize device ID
      await _initializeDeviceId();
      
      // Initialize storage structure
      await _initializeStorageStructure();
      
      LoggerService.i('✅ HiveStorageService initialized successfully');
    } catch (e) {
      LoggerService.e('❌ Failed to initialize HiveStorageService', e);
      rethrow;
    }
  }

  Future<void> _openBoxes() async {
    final appDir = await getApplicationDocumentsDirectory();
    final hivePath = '${appDir.path}/hive';
    
    // Ensure directory exists
    await Directory(hivePath).create(recursive: true);
    
    _cameraConfigsBox = await Hive.openBox<Map<String, dynamic>>('camera_configs');
    _firestoreConfigsBox = await Hive.openBox<Map<String, dynamic>>('firestore_configs');
    _installerTestsBox = await Hive.openBox<Map<String, dynamic>>('installer_tests');
    _syncMetadataBox = await Hive.openBox<Map<String, dynamic>>('sync_metadata');
    _whatsappConfigBox = await Hive.openBox<Map<String, dynamic>>('whatsapp_config');
    _pendingChangesBox = await Hive.openBox<Map<String, dynamic>>('pending_changes');
    _deviceBox = await Hive.openBox<String>('device');
  }

  Future<void> _initializeDeviceId() async {
    if (!_deviceBox.containsKey('device_id')) {
      final deviceId = await DeviceIdCoordinator.getDeviceId();
      await _deviceBox.put('device_id', deviceId);
    } else {
      // Check if we have an old UUID format that needs migration
      final storageDeviceId = _deviceBox.get('device_id');
      
      // Detect old UUID format (contains hyphens and is longer than 20 chars)
      if (storageDeviceId.toString().contains('-') && storageDeviceId.toString().length > 20) {
        LoggerService.w('⚠️ HiveStorage: Detected old UUID format: $storageDeviceId');
        
        // Get proper device ID from DeviceIdCoordinator
        final properDeviceId = await DeviceIdCoordinator.getDeviceId();
        
        // Update storage with proper device ID
        await _deviceBox.put('device_id', properDeviceId);
        LoggerService.i('🔄 HiveStorage: Migrated old UUID to proper device ID: $properDeviceId');
      }
    }
  }

  Future<void> _initializeStorageStructure() async {
    // Initialize sync metadata if not exists
    if (!_syncMetadataBox.containsKey('metadata')) {
      await _syncMetadataBox.put('metadata', {
        'lastSyncTime': null,
        'syncVersion': 1,
        'deviceId': deviceId,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
    
    // Initialize WhatsApp config if not exists
    if (!_whatsappConfigBox.containsKey('config')) {
      await _whatsappConfigBox.put('config', {
        'alertEnable': false,
        'phoneNumbers': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
    
    // Initialize pending changes if not exists
    if (!_pendingChangesBox.containsKey('changes')) {
      await _pendingChangesBox.put('changes', <String, String>{});
    }
  }

  /// ===========================================================
  /// DEVICE MANAGEMENT
  /// ===========================================================
  String get deviceId => _deviceBox.get('device_id') ?? '';

  /// ===========================================================
  /// CAMERA CONFIG MANAGEMENT
  /// ===========================================================
  
  /// Get all camera configs with optional filtering
  Future<List<CameraConfig>> getCameraConfigs({
    String? nameFilter,
    bool? enabledFilter,
    int? limit,
    int? offset,
  }) async {
    try {
      final configs = <CameraConfig>[];
      final keys = _cameraConfigsBox.keys;
      
      // Apply offset and limit
      final startIndex = offset ?? 0;
      final endIndex = limit != null ? startIndex + limit : keys.length;
      final relevantKeys = keys.skip(startIndex).take(endIndex - startIndex);
      
      for (final key in relevantKeys) {
        final configJson = _cameraConfigsBox.get(key);
        if (configJson == null) continue;
        
        // Apply filters
        if (nameFilter != null && !key.toString().toLowerCase().contains(nameFilter.toLowerCase())) {
          continue;
        }
        
        try {
          final config = CameraConfig.fromJson(configJson);
          if (enabledFilter != null && config.enabled != enabledFilter) {
            continue;
          }
          configs.add(config);
        } catch (e) {
          LoggerService.w('⚠️ Error parsing camera config for key $key: $e');
        }
      }
      
      return configs;
    } catch (e) {
      LoggerService.e('❌ Error getting camera configs', e);
      return [];
    }
  }

  /// Save camera config with validation
  Future<bool> saveCameraConfig(CameraConfig config) async {
    try {
      if (!_validateCameraConfig(config)) {
        LoggerService.w('⚠️ Invalid camera config: ${config.name}');
        return false;
      }
      
      await _cameraConfigsBox.put(config.name, config.toJson());
      await _markPendingChange('camera_config_${config.name}', 'update');
      
      LoggerService.i('✅ Saved camera config: ${config.name}');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving camera config ${config.name}', e);
      return false;
    }
  }

  /// Delete camera config
  Future<bool> deleteCameraConfig(String cameraName) async {
    try {
      await _cameraConfigsBox.delete(cameraName);
      await _markPendingChange('camera_config_$cameraName', 'delete');
      
      LoggerService.i('✅ Deleted camera config: $cameraName');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error deleting camera config $cameraName', e);
      return false;
    }
  }

  /// Get camera config by name
  Future<CameraConfig?> getCameraConfig(String name) async {
    try {
      final configJson = _cameraConfigsBox.get(name);
      if (configJson == null) return null;
      
      return CameraConfig.fromJson(configJson);
    } catch (e) {
      LoggerService.e('❌ Error getting camera config $name', e);
      return null;
    }
  }

  /// Search camera configs by text
  Future<List<CameraConfig>> searchCameraConfigs(String query) async {
    try {
      final allConfigs = await getCameraConfigs();
      final queryLower = query.toLowerCase();
      
      return allConfigs.where((config) {
        return config.name.toLowerCase().contains(queryLower) ||
               config.url.toLowerCase().contains(queryLower);
      }).toList();
    } catch (e) {
      LoggerService.e('❌ Error searching camera configs', e);
      return [];
    }
  }

  /// ===========================================================
  /// FIRESTORE CONFIG MANAGEMENT
  /// ===========================================================
  
  Future<List<FirestoreCameraConfig>> getFirestoreCameraConfigs() async {
    try {
      final configs = <FirestoreCameraConfig>[];
      
      for (final key in _firestoreConfigsBox.keys) {
        final configJson = _firestoreConfigsBox.get(key);
        if (configJson == null) continue;
        
        try {
          final config = _firestoreConfigFromJson(configJson);
          configs.add(config);
        } catch (e) {
          LoggerService.w('⚠️ Error parsing Firestore config for key $key: $e');
        }
      }
      
      return configs;
    } catch (e) {
      LoggerService.e('❌ Error getting Firestore camera configs', e);
      return [];
    }
  }

  Future<bool> saveFirestoreCameraConfig(FirestoreCameraConfig config) async {
    try {
      await _firestoreConfigsBox.put(config.id, _firestoreConfigToJson(config));
      LoggerService.i('✅ Saved Firestore camera config: ${config.id}');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving Firestore camera config ${config.id}', e);
      return false;
    }
  }

  Future<bool> deleteFirestoreCameraConfig(String configId) async {
    try {
      await _firestoreConfigsBox.delete(configId);
      LoggerService.i('✅ Deleted Firestore camera config: $configId');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error deleting Firestore camera config $configId', e);
      return false;
    }
  }

  /// ===========================================================
  /// INSTALLER TEST MANAGEMENT
  /// ===========================================================
  
  Future<bool> saveInstallerTest({
    required String cameraId,
    required String algorithmType,
    required bool pass,
  }) async {
    try {
      final tests = Map<String, dynamic>.from(_installerTestsBox.get('tests', defaultValue: <String, dynamic>{}));
      
      // Ensure camera exists
      if (!tests.containsKey(cameraId)) {
        tests[cameraId] = <String, dynamic>{};
      }
      
      // Save test result
      tests[cameraId][algorithmType] = {
        'algorithmType': algorithmType,
        'pass': pass,
        'testedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await _installerTestsBox.put('tests', tests);
      LoggerService.i('✅ Saved installer test: $cameraId/$algorithmType = $pass');
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to save installer test', e);
      return false;
    }
  }
  
  Map<String, dynamic>? getInstallerTests(String cameraId) {
    try {
      final tests = Map<String, dynamic>.from(_installerTestsBox.get('tests', defaultValue: <String, dynamic>{}));
      final cameraTests = tests[cameraId] as Map<String, dynamic>?;
      return cameraTests != null ? Map<String, dynamic>.from(cameraTests) : null;
    } catch (e) {
      LoggerService.e('❌ Failed to get installer tests for camera: $cameraId', e);
      return null;
    }
  }
  
  Map<String, dynamic> getAllInstallerTests() {
    try {
      final tests = Map<String, dynamic>.from(_installerTestsBox.get('tests', defaultValue: <String, dynamic>{}));
      return tests;
    } catch (e) {
      LoggerService.e('❌ Failed to get all installer tests', e);
      return {};
    }
  }
  
  Future<bool> clearInstallerTests() async {
    try {
      await _installerTestsBox.clear();
      LoggerService.i('✅ Cleared all installer tests');
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to clear installer tests', e);
      return false;
    }
  }

  /// ===========================================================
  /// SYNC METADATA MANAGEMENT
  /// ===========================================================
  
  DateTime? get lastSyncTime {
    final metadata = _syncMetadataBox.get('metadata', defaultValue: <String, dynamic>{});
    if (metadata.isEmpty) return null;
    final timestamp = metadata['lastSyncTime'];
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  Future<bool> updateLastSyncTime() async {
    try {
      final metadata = _syncMetadataBox.get('metadata', defaultValue: <String, dynamic>{});
      final updatedMetadata = Map<String, dynamic>.from(metadata);
      updatedMetadata['lastSyncTime'] = DateTime.now().toIso8601String();
      await _syncMetadataBox.put('metadata', updatedMetadata);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error updating last sync time', e);
      return false;
    }
  }

  Map<String, dynamic> get syncMetadata {
    final metadata = _syncMetadataBox.get('metadata', defaultValue: <String, dynamic>{});
    return Map<String, dynamic>.from(metadata);
  }

  Future<bool> updateSyncMetadata(Map<String, dynamic> metadata) async {
    try {
      final current = syncMetadata;
      current.addAll(metadata);
      await _syncMetadataBox.put('metadata', current);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error updating sync metadata', e);
      return false;
    }
  }

  /// ===========================================================
  /// PENDING CHANGES MANAGEMENT
  /// ===========================================================
  
  Map<String, String> get pendingChanges {
    try {
      final pending = _pendingChangesBox.get('changes', defaultValue: <String, String>{});
      return Map<String, String>.from(pending);
    } catch (e) {
      LoggerService.e('❌ Error getting pending changes', e);
      return {};
    }
  }

  Future<bool> _markPendingChange(String key, String operation) async {
    try {
      final pending = pendingChanges;
      pending[key] = operation;
      await _pendingChangesBox.put('changes', pending);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error in _markPendingChange', e);
      return false;
    }
  }

  Future<bool> clearPendingChange(String key) async {
    try {
      final pending = pendingChanges;
      pending.remove(key);
      await _pendingChangesBox.put('changes', pending);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing pending change', e);
      return false;
    }
  }

  Future<bool> clearAllPendingChanges() async {
    try {
      await _pendingChangesBox.put('changes', <String, String>{});
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing all pending changes', e);
      return false;
    }
  }

  /// ===========================================================
  /// WHATSAPP CONFIG MANAGEMENT
  /// ===========================================================
  
  Map<String, dynamic> getWhatsAppConfig() {
    try {
      final config = _whatsappConfigBox.get('config', defaultValue: {
        'alertEnable': false,
        'phoneNumbers': <String>[],
      });
      return Map<String, dynamic>.from(config);
    } catch (e) {
      LoggerService.e('❌ Error getting WhatsApp config', e);
      return {
        'alertEnable': false,
        'phoneNumbers': <String>[],
      };
    }
  }
  
  Future<bool> saveWhatsAppConfig({
    bool? alertEnable,
    List<String>? phoneNumbers,
  }) async {
    try {
      final currentConfig = getWhatsAppConfig();
      
      List<String> currentPhoneNumbers = [];
      if (currentConfig['phoneNumbers'] != null && currentConfig['phoneNumbers'] is List) {
        currentPhoneNumbers = List<String>.from(currentConfig['phoneNumbers']);
      }
      
      final updatedConfig = <String, dynamic>{
        'alertEnable': alertEnable ?? currentConfig['alertEnable'] ?? false,
        'phoneNumbers': phoneNumbers ?? currentPhoneNumbers,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await _whatsappConfigBox.put('config', updatedConfig);
      await _markPendingChange('whatsapp_config', 'update');
      
      LoggerService.i('✅ Saved WhatsApp config');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving WhatsApp config', e);
      return false;
    }
  }

  /// ===========================================================
  /// STORAGE UTILITIES
  /// ===========================================================
  
  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      return {
        'cameraConfigs': _cameraConfigsBox.length,
        'firestoreConfigs': _firestoreConfigsBox.length,
        'installerTests': _installerTestsBox.length,
        'pendingChanges': _pendingChangesBox.get('changes', defaultValue: <String, String>{}).length,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'deviceId': deviceId,
      };
    } catch (e) {
      LoggerService.e('❌ Error getting storage stats', e);
      return {};
    }
  }

  /// Clear all data
  Future<bool> clearAllData() async {
    try {
      await _cameraConfigsBox.clear();
      await _firestoreConfigsBox.clear();
      await _installerTestsBox.clear();
      await _syncMetadataBox.clear();
      await _whatsappConfigBox.clear();
      await _pendingChangesBox.clear();
      await _deviceBox.clear();
      
      // Reinitialize
      await _initializeDeviceId();
      await _initializeStorageStructure();
      
      LoggerService.i('✅ Cleared all data and reinitialized storage');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing all data', e);
      return false;
    }
  }

  /// Compact storage (optimize file size)
  Future<bool> compactStorage() async {
    try {
      await Future.wait([
        _cameraConfigsBox.compact(),
        _firestoreConfigsBox.compact(),
        _installerTestsBox.compact(),
        _syncMetadataBox.compact(),
        _whatsappConfigBox.compact(),
        _pendingChangesBox.compact(),
        _deviceBox.compact(),
      ]);
      
      LoggerService.i('✅ Compacted storage');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error compacting storage', e);
      return false;
    }
  }

  /// ===========================================================
  /// VALIDATION
  /// ===========================================================
  
  bool _validateCameraConfig(CameraConfig config) {
    // Basic validation
    if (config.name.isEmpty || config.url.isEmpty) {
      return false;
    }

    // URL validation
    if (!config.url.startsWith('rtsp://') && 
        !config.url.startsWith('http://') && 
        !config.url.startsWith('https://')) {
      return false;
    }

    // ROI validation
    if (config.footfallEnabled) {
      final roi = config.footfallConfig.roi;
      if (roi.left < 0 || roi.top < 0 || roi.right > 1 || roi.bottom > 1) {
        return false;
      }
    }

    if (config.restrictedAreaEnabled) {
      final roi = config.restrictedAreaConfig.roi;
      if (roi.left < 0 || roi.top < 0 || roi.right > 1 || roi.bottom > 1) {
        return false;
      }
    }

    // Confidence threshold validation
    if (config.confidenceThreshold < 0 || config.confidenceThreshold > 1) {
      return false;
    }

    return true;
  }

  /// ===========================================================
  /// PRIVATE HELPERS
  /// ===========================================================
  
  FirestoreCameraConfig _firestoreConfigFromJson(Map<String, dynamic> json) {
    return FirestoreCameraConfig(
      id: json['id'],
      deviceId: json['deviceId'],
      name: json['name'],
      url: json['url'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      version: json['version'],

      // Features
      peopleCountEnabled: json['peopleCountEnabled'] ?? true,

      // Footfall
      footfallEnabled: json['footfallEnabled'] ?? false,
      footfallConfig: _roiFromJson(json['footfallConfig']),
      footfallSchedule: json['footfallSchedule'] != null
          ? alert_schedule.AlertSchedule.fromJson(json['footfallSchedule'])
          : null,
      footfallIntervalMinutes: json['footfallIntervalMinutes'] ?? 60,

      // Max people
      maxPeopleEnabled: json['maxPeopleEnabled'] ?? false,
      maxPeople: json['maxPeople'] ?? 5,
      maxPeopleCooldownSeconds: json['maxPeopleCooldownSeconds'] ?? 300,
      maxPeopleSchedule: json['maxPeopleSchedule'] != null
          ? alert_schedule.AlertSchedule.fromJson(json['maxPeopleSchedule'])
          : null,

      // Absent
      absentAlertEnabled: json['absentAlertEnabled'] ?? false,
      absentSeconds: json['absentSeconds'] ?? 60,
      absentCooldownSeconds: json['absentCooldownSeconds'] ?? 600,
      absentSchedule: json['absentSchedule'] != null
          ? alert_schedule.AlertSchedule.fromJson(json['absentSchedule'])
          : null,

      // Theft
      theftAlertEnabled: json['theftAlertEnabled'] ?? false,
      theftCooldownSeconds: json['theftCooldownSeconds'] ?? 300,
      theftSchedule: json['theftSchedule'] != null
          ? alert_schedule.AlertSchedule.fromJson(json['theftSchedule'])
          : null,

      // Restricted Area
      restrictedAreaEnabled: json['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig: _roiFromJson(json['restrictedAreaConfig']),
      restrictedAreaCooldownSeconds: json['restrictedAreaCooldownSeconds'] ?? 300,
      restrictedAreaSchedule: json['restrictedAreaSchedule'] != null
          ? alert_schedule.AlertSchedule.fromJson(json['restrictedAreaSchedule'])
          : null,

      // YOLO
      confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.15,
    );
  }

  Map<String, dynamic> _firestoreConfigToJson(FirestoreCameraConfig config) {
    return {
      'id': config.id,
      'deviceId': config.deviceId,
      'name': config.name,
      'url': config.url,
      'createdAt': config.createdAt.toIso8601String(),
      'updatedAt': config.updatedAt.toIso8601String(),
      'version': config.version,

      // Features
      'peopleCountEnabled': config.peopleCountEnabled,

      // Footfall
      'footfallEnabled': config.footfallEnabled,
      'footfallConfig': _roiToJson(config.footfallConfig),
      if (config.footfallSchedule != null)
        'footfallSchedule': config.footfallSchedule!.toJson(),

      // Max people
      'maxPeopleEnabled': config.maxPeopleEnabled,
      'maxPeople': config.maxPeople,
      'maxPeopleCooldownSeconds': config.maxPeopleCooldownSeconds,
      if (config.maxPeopleSchedule != null)
        'maxPeopleSchedule': config.maxPeopleSchedule!.toJson(),

      // Absent
      'absentAlertEnabled': config.absentAlertEnabled,
      'absentSeconds': config.absentSeconds,
      'absentCooldownSeconds': config.absentCooldownSeconds,
      if (config.absentSchedule != null)
        'absentSchedule': config.absentSchedule!.toJson(),

      // Theft
      'theftAlertEnabled': config.theftAlertEnabled,
      'theftCooldownSeconds': config.theftCooldownSeconds,
      if (config.theftSchedule != null)
        'theftSchedule': config.theftSchedule!.toJson(),

      // Restricted Area
      'restrictedAreaEnabled': config.restrictedAreaEnabled,
      'restrictedAreaConfig': _roiToJson(config.restrictedAreaConfig),
      'restrictedAreaCooldownSeconds': config.restrictedAreaCooldownSeconds,
      if (config.restrictedAreaSchedule != null)
        'restrictedAreaSchedule': config.restrictedAreaSchedule!.toJson(),

      // YOLO
      'confidenceThreshold': config.confidenceThreshold,
    };
  }

  RoiAlertConfig _roiFromJson(Map<String, dynamic> json) {
    return RoiAlertConfig(
      roi: Rect.fromLTRB(
        (json['roi']['l'] as num).toDouble(),
        (json['roi']['t'] as num).toDouble(),
        (json['roi']['r'] as num).toDouble(),
        (json['roi']['b'] as num).toDouble(),
      ),
      lineStart: Offset(
        (json['lineStart']['x'] as num).toDouble(),
        (json['lineStart']['y'] as num).toDouble(),
      ),
      lineEnd: Offset(
        (json['lineEnd']['x'] as num).toDouble(),
        (json['lineEnd']['y'] as num).toDouble(),
      ),
      direction: Offset(
        (json['direction']['x'] as num).toDouble(),
        (json['direction']['y'] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> _roiToJson(RoiAlertConfig c) {
    return {
      'roi': {
        'l': c.roi.left,
        't': c.roi.top,
        'r': c.roi.right,
        'b': c.roi.bottom,
      },
      'lineStart': {'x': c.lineStart.dx, 'y': c.lineStart.dy},
      'lineEnd': {'x': c.lineEnd.dx, 'y': c.lineEnd.dy},
      'direction': {
        'x': c.direction.dx,
        'y': c.direction.dy,
      },
    };
  }
}
