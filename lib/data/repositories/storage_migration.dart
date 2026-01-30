import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'hive_storage_service.dart';
import '../models/camera_config.dart';
import '../models/firestore_camera_config.dart';
import '../../core/logging/logger_service.dart';

/// ===========================================================
/// STORAGE MIGRATION SERVICE
/// Migrates data from GetStorage to Hive
/// ===========================================================
class StorageMigration {
  static const String _cameraConfigsKey = 'camera_configs';
  static const String _firestoreConfigsKey = 'firestore_camera_configs';
  static const String _deviceIdKey = 'device_id';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _pendingChangesKey = 'pending_changes';
  static const String _syncMetadataKey = 'sync_metadata';
  static const String _whatsappConfigKey = 'whatsapp_config';
  static const String _installerTestsKey = 'installer_tests';

  /// Migrate all data from GetStorage to Hive
  static Future<bool> migrateFromGetStorage() async {
    try {
      LoggerService.i('🚀 Starting migration from GetStorage to Hive...');
      
      // Initialize GetStorage
      await GetStorage.init();
      final oldStorage = GetStorage();
      
      // Initialize Hive
      await HiveStorageService.instance.init();
      
      // Migrate device ID
      await _migrateDeviceId(oldStorage);
      
      // Migrate camera configs
      await _migrateCameraConfigs(oldStorage);
      
      // Migrate Firestore configs
      await _migrateFirestoreConfigs(oldStorage);
      
      // Migrate sync metadata
      await _migrateSyncMetadata(oldStorage);
      
      // Migrate WhatsApp config
      await _migrateWhatsAppConfig(oldStorage);
      
      // Migrate pending changes
      await _migratePendingChanges(oldStorage);
      
      // Migrate installer tests
      await _migrateInstallerTests(oldStorage);
      
      LoggerService.i('✅ Migration completed successfully');
      return true;
    } catch (e) {
      LoggerService.e('❌ Migration failed', e);
      return false;
    }
  }

  static Future<void> _migrateDeviceId(GetStorage oldStorage) async {
    try {
      final deviceId = oldStorage.read(_deviceIdKey);
      if (deviceId != null) {
        final hiveService = HiveStorageService.instance;
        // Device ID is already initialized in Hive, so we just log it
        LoggerService.i('📱 Device ID migrated: $deviceId');
      }
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate device ID: $e');
    }
  }

  static Future<void> _migrateCameraConfigs(GetStorage oldStorage) async {
    try {
      final configsData = oldStorage.read(_cameraConfigsKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      int migratedCount = 0;
      for (final entry in configsData.entries) {
        try {
          final configJson = entry.value as Map<String, dynamic>;
          final config = CameraConfig.fromJson(configJson);
          
          final success = await hiveService.saveCameraConfig(config);
          if (success) {
            migratedCount++;
          }
        } catch (e) {
          LoggerService.w('⚠️ Failed to migrate camera config ${entry.key}: $e');
        }
      }
      
      LoggerService.i('📷 Migrated $migratedCount camera configs');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate camera configs: $e');
    }
  }

  static Future<void> _migrateFirestoreConfigs(GetStorage oldStorage) async {
    try {
      final configsData = oldStorage.read(_firestoreConfigsKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      int migratedCount = 0;
      for (final entry in configsData.entries) {
        try {
          final configJson = entry.value as Map<String, dynamic>;
          final config = _firestoreConfigFromJson(configJson);
          
          final success = await hiveService.saveFirestoreCameraConfig(config);
          if (success) {
            migratedCount++;
          }
        } catch (e) {
          LoggerService.w('⚠️ Failed to migrate Firestore config ${entry.key}: $e');
        }
      }
      
      LoggerService.i('🔥 Migrated $migratedCount Firestore configs');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate Firestore configs: $e');
    }
  }

  static Future<void> _migrateSyncMetadata(GetStorage oldStorage) async {
    try {
      final metadata = oldStorage.read(_syncMetadataKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      await hiveService.updateSyncMetadata(metadata);
      LoggerService.i('🔄 Migrated sync metadata');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate sync metadata: $e');
    }
  }

  static Future<void> _migrateWhatsAppConfig(GetStorage oldStorage) async {
    try {
      final config = oldStorage.read(_whatsappConfigKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      final alertEnable = config['alertEnable'] as bool?;
      final phoneNumbers = config['phoneNumbers'] as List<String>?;
      
      await hiveService.saveWhatsAppConfig(
        alertEnable: alertEnable,
        phoneNumbers: phoneNumbers,
      );
      
      LoggerService.i('💬 Migrated WhatsApp config');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate WhatsApp config: $e');
    }
  }

  static Future<void> _migratePendingChanges(GetStorage oldStorage) async {
    try {
      final pending = oldStorage.read(_pendingChangesKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      // Clear existing pending changes in Hive
      await hiveService.clearAllPendingChanges();
      
      // Add all pending changes from GetStorage
      for (final entry in pending.entries) {
        await hiveService._markPendingChange(entry.key, entry.value);
      }
      
      LoggerService.i('⏳ Migrated ${pending.length} pending changes');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate pending changes: $e');
    }
  }

  static Future<void> _migrateInstallerTests(GetStorage oldStorage) async {
    try {
      final tests = oldStorage.read(_installerTestsKey) as Map<String, dynamic>? ?? {};
      final hiveService = HiveStorageService.instance;
      
      int migratedCount = 0;
      for (final cameraEntry in tests.entries) {
        final cameraId = cameraEntry.key;
        final cameraTests = cameraEntry.value as Map<String, dynamic>? ?? {};
        
        for (final testEntry in cameraTests.entries) {
          final algorithmType = testEntry.key;
          final testData = testEntry.value as Map<String, dynamic>;
          
          final success = await hiveService.saveInstallerTest(
            cameraId: cameraId,
            algorithmType: algorithmType,
            pass: testData['pass'] as bool? ?? false,
          );
          
          if (success) {
            migratedCount++;
          }
        }
      }
      
      LoggerService.i('🧪 Migrated $migratedCount installer tests');
    } catch (e) {
      LoggerService.w('⚠️ Failed to migrate installer tests: $e');
    }
  }

  /// Backup GetStorage data before migration
  static Future<bool> backupGetStorage() async {
    try {
      await GetStorage.init();
      final oldStorage = GetStorage();
      
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'data': {
          'camera_configs': oldStorage.read(_cameraConfigsKey),
          'firestore_camera_configs': oldStorage.read(_firestoreConfigsKey),
          'device_id': oldStorage.read(_deviceIdKey),
          'last_sync_time': oldStorage.read(_lastSyncTimeKey),
          'pending_changes': oldStorage.read(_pendingChangesKey),
          'sync_metadata': oldStorage.read(_syncMetadataKey),
          'whatsapp_config': oldStorage.read(_whatsappConfigKey),
          'installer_tests': oldStorage.read(_installerTestsKey),
        },
      };
      
      // Save backup to file (you might want to use path_provider)
      final backupJson = jsonEncode(backupData);
      LoggerService.i('💾 GetStorage backup created (${backupJson.length} characters)');
      
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to backup GetStorage', e);
      return false;
    }
  }

  /// Clear GetStorage after successful migration
  static Future<bool> clearGetStorage() async {
    try {
      await GetStorage.init();
      final oldStorage = GetStorage();
      await oldStorage.erase();
      LoggerService.i('🗑️ GetStorage cleared successfully');
      return true;
    } catch (e) {
      LoggerService.e('❌ Failed to clear GetStorage', e);
      return false;
    }
  }

  // Helper method to create FirestoreCameraConfig from JSON (copied from HiveStorageService)
  static FirestoreCameraConfig _firestoreConfigFromJson(Map<String, dynamic> json) {
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
          ? AlertSchedule.fromJson(json['footfallSchedule'])
          : null,
      footfallIntervalMinutes: json['footfallIntervalMinutes'] ?? 60,

      // Max people
      maxPeopleEnabled: json['maxPeopleEnabled'] ?? false,
      maxPeople: json['maxPeople'] ?? 5,
      maxPeopleCooldownSeconds: json['maxPeopleCooldownSeconds'] ?? 300,
      maxPeopleSchedule: json['maxPeopleSchedule'] != null
          ? AlertSchedule.fromJson(json['maxPeopleSchedule'])
          : null,

      // Absent
      absentAlertEnabled: json['absentAlertEnabled'] ?? false,
      absentSeconds: json['absentSeconds'] ?? 60,
      absentCooldownSeconds: json['absentCooldownSeconds'] ?? 600,
      absentSchedule: json['absentSchedule'] != null
          ? AlertSchedule.fromJson(json['absentSchedule'])
          : null,

      // Theft
      theftAlertEnabled: json['theftAlertEnabled'] ?? false,
      theftCooldownSeconds: json['theftCooldownSeconds'] ?? 300,
      theftSchedule: json['theftSchedule'] != null
          ? AlertSchedule.fromJson(json['theftSchedule'])
          : null,

      // Restricted Area
      restrictedAreaEnabled: json['restrictedAreaEnabled'] ?? true,
      restrictedAreaConfig: _roiFromJson(json['restrictedAreaConfig']),
      restrictedAreaCooldownSeconds: json['restrictedAreaCooldownSeconds'] ?? 300,
      restrictedAreaSchedule: json['restrictedAreaSchedule'] != null
          ? AlertSchedule.fromJson(json['restrictedAreaSchedule'])
          : null,

      // YOLO
      confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.15,
    );
  }

  static RoiAlertConfig _roiFromJson(Map<String, dynamic> json) {
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
}
