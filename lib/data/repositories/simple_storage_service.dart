import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/camera_config.dart';
import '../models/firestore_camera_config.dart';
import '../models/roi_config.dart';
import '../models/alert_schedule.dart';
import '../../core/logging/logger_service.dart';
import '../../core/utils/device_id_coordinator.dart';

/// ===========================================================
/// SIMPLE STORAGE SERVICE (GetStorage - Fixed)
/// Uses GetStorage with proper type handling and no conflicts
/// ===========================================================
class SimpleStorageService {
  static SimpleStorageService? _instance;
  static SimpleStorageService get instance => _instance ??= SimpleStorageService._();
  
  SimpleStorageService._();

  late final GetStorage _storage;
  bool _isInitialized = false;
  static const String _cameraConfigsKey = 'camera_configs';
  static const String _deviceIdKey = 'device_id';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _pendingChangesKey = 'pending_changes';
  static const String _syncMetadataKey = 'sync_metadata';
  static const String _whatsappConfigKey = 'whatsapp_config';
  static const String _installerTestsKey = 'installer_tests';

  // Public getter for storage access
  GetStorage get storage => _storage;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> init() async {
    if (_isInitialized) {
      LoggerService.w('⚠️ SimpleStorageService already initialized, skipping...');
      return;
    }

    try {
      // Initialize GetStorage
      await GetStorage.init();
      _storage = GetStorage();
      _isInitialized = true;
      
      // Initialize device ID using DeviceIdCoordinator if not exists or migrate old UUID
      if (!_storage.hasData(_deviceIdKey)) {
        final deviceId = await DeviceIdCoordinator.getDeviceId();
        _storage.write(_deviceIdKey, deviceId);
        LoggerService.i('🆔 Device ID set from DeviceIdCoordinator: $deviceId');
      } else {
        // Check if we have an old UUID format that needs migration
        final storageDeviceId = _storage.read(_deviceIdKey);
        
        // Detect old UUID format (contains hyphens and is longer than 20 chars)
        if (storageDeviceId.toString().contains('-') && storageDeviceId.toString().length > 20) {
          LoggerService.w('⚠️ Detected old UUID format: $storageDeviceId');
          
          // Get proper device ID from DeviceIdCoordinator
          final properDeviceId = await DeviceIdCoordinator.getDeviceId();
          
          // Update storage with proper device ID
          _storage.write(_deviceIdKey, properDeviceId);
          LoggerService.i('🔄 Migrated old UUID to proper device ID: $properDeviceId');
        } else {
          // Ensure storage is synchronized with DeviceIdCoordinator
          final coordinatorDeviceId = await DeviceIdCoordinator.getDeviceId();
          
          if (coordinatorDeviceId != storageDeviceId) {
            // Sync storage with DeviceIdCoordinator
            _storage.write(_deviceIdKey, coordinatorDeviceId);
            LoggerService.i('🔄 Synced storage with DeviceIdCoordinator: $coordinatorDeviceId');
          }
        }
      }
      
      // Initialize storage structure if needed
      await _initializeStorageStructure();
      
      LoggerService.i('✅ SimpleStorageService initialized successfully');
    } catch (e) {
      LoggerService.e('❌ Failed to initialize SimpleStorageService', e);
      rethrow;
    }
  }

  Future<void> _initializeStorageStructure() async {
    if (!_storage.hasData(_cameraConfigsKey)) {
      _storage.write(_cameraConfigsKey, <String, dynamic>{});
    }
    
    if (!_storage.hasData(_pendingChangesKey)) {
      _storage.write(_pendingChangesKey, <String, dynamic>{});
    }
    
    if (!_storage.hasData(_syncMetadataKey)) {
      _storage.write(_syncMetadataKey, {
        'lastSyncTime': null,
        'syncVersion': 1,
        'deviceId': deviceId,
      });
    }
    
    if (!_storage.hasData(_whatsappConfigKey)) {
      _storage.write(_whatsappConfigKey, {
        'alertEnable': false,
        'phoneNumbers': <String>[],
      });
    }
  }

  /// ===========================================================
  /// DEVICE MANAGEMENT
  /// ===========================================================
  String get deviceId => _storage.read(_deviceIdKey) ?? '';

  /// ===========================================================
  /// CAMERA CONFIG MANAGEMENT
  /// ===========================================================
  
  /// Get all camera configs from local storage
  List<CameraConfig> getCameraConfigs() {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      final configs = <CameraConfig>[];
      
      for (final entry in configsData.entries) {
        try {
          final configJson = entry.value as Map<String, dynamic>;
          final config = CameraConfig.fromJson(configJson);
          configs.add(config);
        } catch (e) {
          LoggerService.w('⚠️ Error parsing camera config for key ${entry.key}: $e');
        }
      }
      
      return configs;
    } catch (e) {
      LoggerService.e('❌ Error getting camera configs', e);
      return [];
    }
  }

  /// Save camera config to local storage
  Future<bool> saveCameraConfig(CameraConfig config) async {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      configsData[config.name] = config.toJson();
      await _storage.write(_cameraConfigsKey, configsData);
      
      // Mark as pending change for sync
      await _markPendingChange('camera_config_${config.name}', 'update');
      
      LoggerService.i('✅ Saved camera config: ${config.name}');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving camera config ${config.name}', e);
      return false;
    }
  }

  /// Delete camera config from local storage
  Future<bool> deleteCameraConfig(String cameraName) async {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      configsData.remove(cameraName);
      await _storage.write(_cameraConfigsKey, configsData);
      
      // Mark as pending change for sync
      await _markPendingChange('camera_config_$cameraName', 'delete');
      
      LoggerService.i('✅ Deleted camera config: $cameraName');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error deleting camera config $cameraName', e);
      return false;
    }
  }

  /// Get camera config by name
  CameraConfig? getCameraConfig(String name) {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      final configJson = configsData[name] as Map<String, dynamic>?;
      
      if (configJson != null) {
        return CameraConfig.fromJson(configJson);
      }
      return null;
    } catch (e) {
      LoggerService.e('❌ Error getting camera config $name', e);
      return null;
    }
  }

  /// ===========================================================
  /// FIRESTORE CONFIG MANAGEMENT
  /// ===========================================================
  
  /// Get all Firestore camera configs from local storage
  List<FirestoreCameraConfig> getFirestoreCameraConfigs() {
    try {
      final configsData = _storage.read('firestore_camera_configs') as Map<String, dynamic>? ?? {};
      final configs = <FirestoreCameraConfig>[];
      
      for (final entry in configsData.entries) {
        try {
          final configJson = entry.value as Map<String, dynamic>;
          final config = _firestoreConfigFromJson(configJson);
          configs.add(config);
        } catch (e) {
          LoggerService.w('⚠️ Error parsing Firestore camera config for key ${entry.key}: $e');
        }
      }
      
      return configs;
    } catch (e) {
      LoggerService.e('❌ Error getting Firestore camera configs', e);
      return [];
    }
  }

  /// Save Firestore camera config to local storage
  Future<bool> saveFirestoreCameraConfig(FirestoreCameraConfig config) async {
    try {
      final configsData = _storage.read('firestore_camera_configs') as Map<String, dynamic>? ?? {};
      configsData[config.id] = _firestoreConfigToJson(config);
      await _storage.write('firestore_camera_configs', configsData);
      
      LoggerService.i('✅ Saved Firestore camera config: ${config.id}');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving Firestore camera config ${config.id}', e);
      return false;
    }
  }

  /// Delete Firestore camera config from local storage
  Future<bool> deleteFirestoreCameraConfig(String configId) async {
    try {
      final configsData = _storage.read('firestore_camera_configs') as Map<String, dynamic>? ?? {};
      configsData.remove(configId);
      await _storage.write('firestore_camera_configs', configsData);
      
      LoggerService.i('✅ Deleted Firestore camera config: $configId');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error deleting Firestore camera config $configId', e);
      return false;
    }
  }

  /// ===========================================================
  /// SYNC METADATA MANAGEMENT
  /// ===========================================================
  
  DateTime? get lastSyncTime {
    final timestamp = _storage.read(_lastSyncTimeKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<bool> updateLastSyncTime() async {
    try {
      await _storage.write(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error updating last sync time', e);
      return false;
    }
  }

  Map<String, dynamic> get syncMetadata {
    return _storage.read(_syncMetadataKey) as Map<String, dynamic>? ?? {};
  }

  Future<bool> updateSyncMetadata(Map<String, dynamic> metadata) async {
    try {
      final current = syncMetadata;
      current.addAll(metadata);
      await _storage.write(_syncMetadataKey, current);
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
      final pending = _storage.read(_pendingChangesKey);
      
      if (pending is Map<String, String>) {
        return pending;
      } else if (pending is Map) {
        // Convert to Map<String, String> if needed
        return Map<String, String>.from(pending.cast<String, dynamic>());
      } else {
        return {};
      }
    } catch (e) {
      LoggerService.e('❌ Error getting pending changes', e);
      return {};
    }
  }

  Future<bool> _markPendingChange(String key, String operation) async {
    try {
      final pending = pendingChanges;
      pending[key] = operation;
      await _storage.write(_pendingChangesKey, pending);
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
      await _storage.write(_pendingChangesKey, pending);
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing pending change', e);
      return false;
    }
  }

  Future<bool> clearAllPendingChanges() async {
    try {
      await _storage.write(_pendingChangesKey, <String, dynamic>{});
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing all pending changes', e);
      return false;
    }
  }

  /// ===========================================================
  /// INSTALLER TEST MANAGEMENT
  /// ===========================================================
  
  /// Save installer test result locally
  Future<bool> saveInstallerTest({
    required String cameraId,
    required String algorithmType,
    required bool pass,
  }) async {
    try {
      final tests = _storage.read(_installerTestsKey) as Map<String, dynamic>? ?? {};
      
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
      
      await _storage.write(_installerTestsKey, tests);
      LoggerService.i('✅ Saved installer test: $cameraId/$algorithmType = $pass');
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to save installer test', e);
      return false;
    }
  }
  
  /// Get all installer tests for a camera
  Map<String, dynamic>? getInstallerTests(String cameraId) {
    try {
      final tests = _storage.read(_installerTestsKey) as Map<String, dynamic>? ?? {};
      return tests[cameraId] as Map<String, dynamic>?;
    } catch (e) {
      LoggerService.e('❌ Failed to get installer tests for camera: $cameraId', e);
      return null;
    }
  }
  
  /// Get all installer tests for all cameras
  Map<String, dynamic> getAllInstallerTests() {
    try {
      return _storage.read(_installerTestsKey) as Map<String, dynamic>? ?? {};
    } catch (e) {
      LoggerService.e('❌ Failed to get all installer tests', e);
      return {};
    }
  }
  
  /// Clear all installer tests (after successful sync to Firebase)
  Future<bool> clearInstallerTests() async {
    try {
      await _storage.remove(_installerTestsKey);
      LoggerService.i('✅ Cleared all installer tests after Firebase sync');
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to clear installer tests', e);
      return false;
    }
  }

  /// ===========================================================
  /// WHATSAPP CONFIG MANAGEMENT
  /// ===========================================================
  
  /// Get WhatsApp configuration from local storage
  Map<String, dynamic> getWhatsAppConfig() {
    try {
      final config = _storage.read(_whatsappConfigKey);
      
      if (config is Map<String, dynamic>) {
        return config;
      } else if (config is Map) {
        // Convert to Map<String, dynamic> if needed
        return Map<String, dynamic>.from(config);
      } else {
        return {
          'alertEnable': false,
          'phoneNumbers': <String>[],
        };
      }
    } catch (e) {
      LoggerService.e('❌ Error getting WhatsApp config', e);
      return {
        'alertEnable': false,
        'phoneNumbers': <String>[],
      };
    }
  }
  
  /// Save WhatsApp configuration to local storage
  Future<bool> saveWhatsAppConfig({
    bool? alertEnable,
    List<String>? phoneNumbers,
  }) async {
    try {
      final currentConfig = getWhatsAppConfig();
      
      // Safely extract phone numbers list
      List<String> currentPhoneNumbers = [];
      if (currentConfig['phoneNumbers'] != null) {
        if (currentConfig['phoneNumbers'] is List) {
          currentPhoneNumbers = List<String>.from(currentConfig['phoneNumbers']);
        }
      }
      
      final updatedConfig = <String, dynamic>{
        'alertEnable': alertEnable ?? currentConfig['alertEnable'] ?? false,
        'phoneNumbers': phoneNumbers ?? currentPhoneNumbers,
      };
      
      await _storage.write(_whatsappConfigKey, updatedConfig);
      
      // Mark as pending change for sync
      await _markPendingChange('whatsapp_config', 'update');
      
      LoggerService.i('✅ Saved WhatsApp config');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error saving WhatsApp config', e);
      return false;
    }
  }

  /// Enable/disable WhatsApp alerts
  Future<bool> setWhatsAppAlertsEnabled(bool enabled) async {
    try {
      return await saveWhatsAppConfig(alertEnable: enabled);
    } catch (e) {
      LoggerService.e('❌ Error setting WhatsApp alerts enabled', e);
      return false;
    }
  }

  /// Check if WhatsApp alerts are enabled
  bool getWhatsAppAlertsEnabled() {
    try {
      final config = getWhatsAppConfig();
      return config['alertEnable'] ?? false;
    } catch (e) {
      LoggerService.e('❌ Error getting WhatsApp alerts enabled', e);
      return false;
    }
  }

  /// Add phone number to WhatsApp configuration
  Future<bool> addWhatsAppPhoneNumber(String phoneNumber) async {
    try {
      final config = getWhatsAppConfig();
      
      // Safely extract phone numbers list
      List<String> phoneNumbers = [];
      if (config['phoneNumbers'] != null) {
        if (config['phoneNumbers'] is List) {
          phoneNumbers = List<String>.from(config['phoneNumbers']);
        }
      }
      
      // Remove duplicates and add new number
      phoneNumbers.removeWhere((number) => number == phoneNumber);
      phoneNumbers.add(phoneNumber);
      
      return await saveWhatsAppConfig(phoneNumbers: phoneNumbers);
    } catch (e) {
      LoggerService.e('❌ Error adding WhatsApp phone number', e);
      return false;
    }
  }
  
  /// Remove phone number from WhatsApp configuration
  Future<bool> removeWhatsAppPhoneNumber(String phoneNumber) async {
    try {
      final config = getWhatsAppConfig();
      
      // Safely extract phone numbers list
      List<String> phoneNumbers = [];
      if (config['phoneNumbers'] != null) {
        if (config['phoneNumbers'] is List) {
          phoneNumbers = List<String>.from(config['phoneNumbers']);
        }
      }
      
      phoneNumbers.removeWhere((number) => number == phoneNumber);
      
      return await saveWhatsAppConfig(phoneNumbers: phoneNumbers);
    } catch (e) {
      LoggerService.e('❌ Error removing WhatsApp phone number', e);
      return false;
    }
  }
  
  /// Get all WhatsApp phone numbers
  List<String> getWhatsAppPhoneNumbers() {
    try {
      final config = getWhatsAppConfig();
      
      // Safely extract phone numbers list
      if (config['phoneNumbers'] != null) {
        if (config['phoneNumbers'] is List) {
          return List<String>.from(config['phoneNumbers']);
        }
      }
      
      return [];
    } catch (e) {
      LoggerService.e('❌ Error getting WhatsApp phone numbers', e);
      return [];
    }
  }

  /// ===========================================================
  /// STORAGE UTILITIES
  /// ===========================================================
  
  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      return {
        'cameraConfigs': getCameraConfigs().length,
        'firestoreConfigs': getFirestoreCameraConfigs().length,
        'installerTests': getAllInstallerTests().length,
        'pendingChanges': pendingChanges.length,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'deviceId': deviceId,
      };
    } catch (e) {
      LoggerService.e('❌ Error getting storage stats', e);
      return {};
    }
  }

  /// Clear all local data
  Future<bool> clearAllData() async {
    try {
      await _storage.erase();
      await init();
      LoggerService.i('✅ Cleared all data and reinitialized storage');
      return true;
    } catch (e) {
      LoggerService.e('❌ Error clearing all data', e);
      return false;
    }
  }

  /// Get storage size estimate
  int getStorageSize() {
    try {
      final data = _storage.getKeys();
      int totalSize = 0;
      
      for (final key in data) {
        final value = _storage.read(key);
        if (value != null) {
          totalSize += jsonEncode(value).length;
        }
      }
      
      return totalSize;
    } catch (e) {
      LoggerService.e('❌ Error calculating storage size', e);
      return 0;
    }
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

      // Footfall - Use simple JSON to avoid type conflicts
      footfallEnabled: json['footfallEnabled'] ?? false,
      footfallConfig: _roiFromJson(json['footfallConfig']),
      footfallIntervalMinutes: json['footfallIntervalMinutes'] ?? 60,

      // Max people
      maxPeopleEnabled: json['maxPeopleEnabled'] ?? false,
      maxPeople: json['maxPeople'] ?? 5,
      maxPeopleCooldownSeconds: json['maxPeopleCooldownSeconds'] ?? 300,

      // Absent
      absentAlertEnabled: json['absentAlertEnabled'] ?? false,
      absentSeconds: json['absentSeconds'] ?? 60,
      absentCooldownSeconds: json['absentCooldownSeconds'] ?? 600,

      // Theft
      theftAlertEnabled: json['theftAlertEnabled'] ?? false,
      theftCooldownSeconds: json['theftCooldownSeconds'] ?? 300,

      // Restricted Area
      restrictedAreaEnabled: json['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig: _roiFromJson(json['restrictedAreaConfig']),
      restrictedAreaCooldownSeconds: json['restrictedAreaCooldownSeconds'] ?? 300,

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

      // Footfall - Store as simple JSON to avoid type conflicts
      'footfallEnabled': config.footfallEnabled,
      'footfallConfig': _roiToJson(config.footfallConfig),

      // Max people
      'maxPeopleEnabled': config.maxPeopleEnabled,
      'maxPeople': config.maxPeople,
      'maxPeopleCooldownSeconds': config.maxPeopleCooldownSeconds,

      // Absent
      'absentAlertEnabled': config.absentAlertEnabled,
      'absentSeconds': config.absentSeconds,
      'absentCooldownSeconds': config.absentCooldownSeconds,

      // Theft
      'theftAlertEnabled': config.theftAlertEnabled,
      'theftCooldownSeconds': config.theftCooldownSeconds,

      // Restricted Area
      'restrictedAreaEnabled': config.restrictedAreaEnabled,
      'restrictedAreaConfig': _roiToJson(config.restrictedAreaConfig),
      'restrictedAreaCooldownSeconds': config.restrictedAreaCooldownSeconds,

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
