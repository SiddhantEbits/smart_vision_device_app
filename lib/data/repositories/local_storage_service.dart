import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../models/camera_config.dart';
import '../models/firestore_camera_config.dart';
import '../models/alert_schedule.dart';
import '../models/roi_config.dart';

/// ===========================================================
/// LOCAL STORAGE SERVICE
/// Handles persistent storage with GetStorage and provides
/// structured data access for Firebase synchronization
/// ===========================================================
class LocalStorageService {
  static LocalStorageService? _instance;
  static LocalStorageService get instance => _instance ??= LocalStorageService._();
  
  LocalStorageService._();

  late final GetStorage _storage;
  static const String _cameraConfigsKey = 'camera_configs';
  static const String _deviceIdKey = 'device_id';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _pendingChangesKey = 'pending_changes';
  static const String _syncMetadataKey = 'sync_metadata';
  static const String _whatsappConfigKey = 'whatsapp_config';

  // Public getter for storage access
  GetStorage get storage => _storage;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> init() async {
    await GetStorage.init();
    _storage = GetStorage();
    
    // Initialize device ID if not exists
    if (!_storage.hasData(_deviceIdKey)) {
      _storage.write(_deviceIdKey, const Uuid().v4());
    }
    
    // Initialize storage structure if needed
    await _initializeStorageStructure();
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
          print('Error parsing camera config for key ${entry.key}: $e');
        }
      }
      
      return configs;
    } catch (e) {
      print('Error getting camera configs: $e');
      return [];
    }
  }

  /// Save camera config to local storage
  Future<void> saveCameraConfig(CameraConfig config) async {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      configsData[config.name] = config.toJson();
      await _storage.write(_cameraConfigsKey, configsData);
      
      // Mark as pending change for sync
      await _markPendingChange('camera_config_${config.name}', 'update');
    } catch (e) {
      print('Error saving camera config ${config.name}: $e');
      rethrow;
    }
  }

  /// Delete camera config from local storage
  Future<void> deleteCameraConfig(String cameraName) async {
    try {
      final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      configsData.remove(cameraName);
      await _storage.write(_cameraConfigsKey, configsData);
      
      // Mark as pending change for sync
      await _markPendingChange('camera_config_$cameraName', 'delete');
    } catch (e) {
      print('Error deleting camera config $cameraName: $e');
      rethrow;
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
      print('Error getting camera config $name: $e');
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
          print('Error parsing Firestore camera config for key ${entry.key}: $e');
        }
      }
      
      return configs;
    } catch (e) {
      print('Error getting Firestore camera configs: $e');
      return [];
    }
  }

  /// Save Firestore camera config to local storage
  Future<void> saveFirestoreCameraConfig(FirestoreCameraConfig config) async {
    try {
      final configsData = _storage.read('firestore_camera_configs') as Map<String, dynamic>? ?? {};
      configsData[config.id] = _firestoreConfigToJson(config);
      await _storage.write('firestore_camera_configs', configsData);
    } catch (e) {
      print('Error saving Firestore camera config ${config.id}: $e');
      rethrow;
    }
  }

  /// Delete Firestore camera config from local storage
  Future<void> deleteFirestoreCameraConfig(String configId) async {
    try {
      final configsData = _storage.read('firestore_camera_configs') as Map<String, dynamic>? ?? {};
      configsData.remove(configId);
      await _storage.write('firestore_camera_configs', configsData);
    } catch (e) {
      print('Error deleting Firestore camera config $configId: $e');
      rethrow;
    }
  }

  /// ===========================================================
  /// SYNC METADATA MANAGEMENT
  /// ===========================================================
  
  DateTime? get lastSyncTime {
    final timestamp = _storage.read(_lastSyncTimeKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> updateLastSyncTime() async {
    await _storage.write(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Map<String, dynamic> get syncMetadata {
    return _storage.read(_syncMetadataKey) as Map<String, dynamic>? ?? {};
  }

  Future<void> updateSyncMetadata(Map<String, dynamic> metadata) async {
    final current = syncMetadata;
    current.addAll(metadata);
    await _storage.write(_syncMetadataKey, current);
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
      print('Error getting pending changes: $e');
      return {};
    }
  }

  Future<void> _markPendingChange(String key, String operation) async {
    try {
      final pending = pendingChanges;
      pending[key] = operation;
      await _storage.write(_pendingChangesKey, pending);
    } catch (e) {
      print('Error in _markPendingChange: $e');
      rethrow;
    }
  }

  Future<void> clearPendingChange(String key) async {
    final pending = pendingChanges;
    pending.remove(key);
    await _storage.write(_pendingChangesKey, pending);
  }

  Future<void> clearAllPendingChanges() async {
    await _storage.write(_pendingChangesKey, <String, dynamic>{});
  }

  /// ===========================================================
  /// DATA VALIDATION
  /// ===========================================================
  
  /// Validate camera config before saving
  bool validateCameraConfig(CameraConfig config) {
    // Basic validation
    if (config.name.isEmpty || config.url.isEmpty) {
      return false;
    }

    // URL validation (basic RTSP check)
    if (!config.url.startsWith('rtsp://') && !config.url.startsWith('http://') && !config.url.startsWith('https://')) {
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
  /// IMPORT/EXPORT UTILITIES
  /// ===========================================================
  
  /// Export all data as JSON string
  String exportData() {
    final exportData = {
      'deviceId': deviceId,
      'cameraConfigs': getCameraConfigs().map((c) => c.toJson()).toList(),
      'firestoreConfigs': getFirestoreCameraConfigs().map((c) => _firestoreConfigToJson(c)).toList(),
      'syncMetadata': syncMetadata,
      'pendingChanges': pendingChanges,
      'exportTime': DateTime.now().toIso8601String(),
    };
    
    return jsonEncode(exportData);
  }

  /// Import data from JSON string
  Future<bool> importData(String jsonData) async {
    try {
      final importData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Import camera configs
      final cameraConfigsData = importData['cameraConfigs'] as List?;
      if (cameraConfigsData != null) {
        final configsData = _storage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
        for (final configJson in cameraConfigsData) {
          final config = CameraConfig.fromJson(configJson as Map<String, dynamic>);
          if (validateCameraConfig(config)) {
            configsData[config.name] = config.toJson();
          }
        }
        await _storage.write(_cameraConfigsKey, configsData);
      }
      
      // Import Firestore configs
      final firestoreConfigsData = importData['firestoreConfigs'] as List?;
      if (firestoreConfigsData != null) {
        final configsData = <String, dynamic>{};
        for (final configJson in firestoreConfigsData) {
          final config = _firestoreConfigFromJson(configJson as Map<String, dynamic>);
          configsData[config.id] = _firestoreConfigToJson(config);
        }
        await _storage.write('firestore_camera_configs', configsData);
      }
      
      // Import sync metadata
      final syncMetadata = importData['syncMetadata'] as Map<String, dynamic>?;
      if (syncMetadata != null) {
        await updateSyncMetadata(syncMetadata);
      }
      
      return true;
    } catch (e) {
      print('Error importing data: $e');
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
      print('Error getting WhatsApp config: $e');
      return {
        'alertEnable': false,
        'phoneNumbers': <String>[],
      };
    }
  }
  
  /// Save WhatsApp configuration to local storage
  Future<void> saveWhatsAppConfig({
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
    } catch (e) {
      print('Error saving WhatsApp config: $e');
      rethrow;
    }
  }
  
  /// Add phone number to WhatsApp configuration
  Future<void> addWhatsAppPhoneNumber(String phoneNumber) async {
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
      
      await saveWhatsAppConfig(phoneNumbers: phoneNumbers);
    } catch (e) {
      print('Error adding WhatsApp phone number: $e');
      rethrow;
    }
  }
  
  /// Remove phone number from WhatsApp configuration
  Future<void> removeWhatsAppPhoneNumber(String phoneNumber) async {
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
      
      await saveWhatsAppConfig(phoneNumbers: phoneNumbers);
    } catch (e) {
      print('Error removing WhatsApp phone number: $e');
      rethrow;
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
      print('Error getting WhatsApp phone numbers: $e');
      return [];
    }
  }
  
  /// Enable/disable WhatsApp alerts
  Future<void> setWhatsAppAlertsEnabled(bool enabled) async {
    try {
      await saveWhatsAppConfig(alertEnable: enabled);
    } catch (e) {
      print('Error setting WhatsApp alerts enabled: $e');
      rethrow;
    }
  }
  
  /// Check if WhatsApp alerts are enabled
  bool getWhatsAppAlertsEnabled() {
    try {
      final config = getWhatsAppConfig();
      return config['alertEnable'] ?? false;
    } catch (e) {
      print('Error getting WhatsApp alerts enabled: $e');
      return false;
    }
  }

  /// ===========================================================
  /// STORAGE UTILITIES
  /// ===========================================================
  
  /// Clear all local data
  Future<void> clearAllData() async {
    await _storage.erase();
    await init();
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
      print('Error calculating storage size: $e');
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

      // Footfall
      footfallEnabled: json['footfallEnabled'] ?? false,
      footfallConfig: _roiFromJson(json['footfallConfig']),
      footfallSchedule: json['footfallSchedule'] != null
          ? _scheduleFromJson(json['footfallSchedule'])
          : null,
      footfallIntervalMinutes: json['footfallIntervalMinutes'] ?? 60,

      // Max people
      maxPeopleEnabled: json['maxPeopleEnabled'] ?? false,
      maxPeople: json['maxPeople'] ?? 5,
      maxPeopleCooldownSeconds: json['maxPeopleCooldownSeconds'] ?? 300,
      maxPeopleSchedule: json['maxPeopleSchedule'] != null
          ? _scheduleFromJson(json['maxPeopleSchedule'])
          : null,

      // Absent
      absentAlertEnabled: json['absentAlertEnabled'] ?? false,
      absentSeconds: json['absentSeconds'] ?? 60,
      absentCooldownSeconds: json['absentCooldownSeconds'] ?? 600,
      absentSchedule: json['absentSchedule'] != null
          ? _scheduleFromJson(json['absentSchedule'])
          : null,

      // Theft
      theftAlertEnabled: json['theftAlertEnabled'] ?? false,
      theftCooldownSeconds: json['theftCooldownSeconds'] ?? 300,
      theftSchedule: json['theftSchedule'] != null
          ? _scheduleFromJson(json['theftSchedule'])
          : null,

      // Restricted Area
      restrictedAreaEnabled: json['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig: _roiFromJson(json['restrictedAreaConfig']),
      restrictedAreaCooldownSeconds: json['restrictedAreaCooldownSeconds'] ?? 300,
      restrictedAreaSchedule: json['restrictedAreaSchedule'] != null
          ? _scheduleFromJson(json['restrictedAreaSchedule'])
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
        'footfallSchedule': _scheduleToJson(config.footfallSchedule!),
      'footfallIntervalMinutes': config.footfallIntervalMinutes,

      // Max people
      'maxPeopleEnabled': config.maxPeopleEnabled,
      'maxPeople': config.maxPeople,
      'maxPeopleCooldownSeconds': config.maxPeopleCooldownSeconds,
      if (config.maxPeopleSchedule != null)
        'maxPeopleSchedule': _scheduleToJson(config.maxPeopleSchedule!),

      // Absent
      'absentAlertEnabled': config.absentAlertEnabled,
      'absentSeconds': config.absentSeconds,
      'absentCooldownSeconds': config.absentCooldownSeconds,
      if (config.absentSchedule != null)
        'absentSchedule': _scheduleToJson(config.absentSchedule!),

      // Theft
      'theftAlertEnabled': config.theftAlertEnabled,
      'theftCooldownSeconds': config.theftCooldownSeconds,
      if (config.theftSchedule != null)
        'theftSchedule': _scheduleToJson(config.theftSchedule!),

      // Restricted Area
      'restrictedAreaEnabled': config.restrictedAreaEnabled,
      'restrictedAreaConfig': _roiToJson(config.restrictedAreaConfig),
      'restrictedAreaCooldownSeconds': config.restrictedAreaCooldownSeconds,
      if (config.restrictedAreaSchedule != null)
        'restrictedAreaSchedule': _scheduleToJson(config.restrictedAreaSchedule!),

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

  AlertSchedule _scheduleFromJson(Map<String, dynamic> json) {
    return AlertSchedule(
      start: TimeOfDay(
        hour: json['startHour'],
        minute: json['startMinute'],
      ),
      end: TimeOfDay(
        hour: json['endHour'],
        minute: json['endMinute'],
      ),
      activeDays: List<int>.from(json['activeDays'] ?? []),
    );
  }

  Map<String, dynamic> _scheduleToJson(AlertSchedule schedule) {
    return {
      'startHour': schedule.start.hour,
      'startMinute': schedule.start.minute,
      'endHour': schedule.end.hour,
      'endMinute': schedule.end.minute,
      'activeDays': schedule.activeDays,
    };
  }
}
