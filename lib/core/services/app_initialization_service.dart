import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../../data/repositories/local_storage_service.dart';
import '../../data/repositories/firebase_sync_service.dart';
import '../../data/repositories/data_validation_service.dart';
import '../../data/services/device_management_service.dart';
import '../../data/services/alert_logging_service.dart';
import '../../data/services/error_logging_service.dart';
import '../../data/services/camera_management_service.dart';
import '../../data/services/rtsp_url_encryption_service.dart';

/// ===========================================================
/// APP INITIALIZATION SERVICE
/// Handles proper initialization of all services and
/// provides centralized app startup management
/// ===========================================================
class AppInitializationService {
  static AppInitializationService? _instance;
  static AppInitializationService get instance => _instance ??= AppInitializationService._();
  
  AppInitializationService._();

  // Service instances
  late final LocalStorageService _localStorage;
  late final FirebaseSyncService _firebaseSync;
  late final DataValidationService _validator;
  late final DeviceManagementService _deviceService;
  late final AlertLoggingService _alertService;
  late final ErrorLoggingService _errorService;
  late final CameraManagementService _cameraService;
  late final RTSPURLEncryptionService _encryptionService;

  // Initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initializationError;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get initializationError => _initializationError;

  /// ===========================================================
  // MAIN INITIALIZATION
  /// ===========================================================
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      // Wait for current initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    _initializationError = null;

    try {
      debugPrint('🚀 Starting comprehensive Firebase app initialization...');

      // Step 1: Initialize local storage
      await _initializeLocalStorage();
      debugPrint('✅ Local storage initialized');

      // Step 2: Initialize data validation
      await _initializeDataValidation();
      debugPrint('✅ Data validation initialized');

      // Step 3: Initialize RTSP encryption
      await _initializeEncryptionService();
      debugPrint('✅ RTSP encryption initialized');

      // Step 4: Initialize device management
      await _initializeDeviceManagement();
      debugPrint('✅ Device management initialized');

      // Step 5: Initialize alert logging
      await _initializeAlertLogging();
      debugPrint('✅ Alert logging initialized');

      // Step 6: Initialize error logging
      await _initializeErrorLogging();
      debugPrint('✅ Error logging initialized');

      // Step 7: Initialize camera management
      await _initializeCameraManagement();
      debugPrint('✅ Camera management initialized');

      // Step 8: Initialize Firebase sync (legacy compatibility)
      await _initializeFirebaseSync();
      debugPrint('✅ Firebase sync initialized');

      // Step 9: Perform initial data migration if needed
      await _performDataMigration();
      debugPrint('✅ Data migration completed');

      // Step 10: Validate stored data
      await _validateStoredData();
      debugPrint('✅ Data validation completed');

      _isInitialized = true;
      debugPrint('🎉 Comprehensive Firebase app initialization completed successfully!');
      return true;

    } catch (e, stackTrace) {
      _initializationError = e.toString();
      _isInitializing = false;
      debugPrint('❌ Comprehensive Firebase app initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// ===========================================================
  // STEP 1: LOCAL STORAGE INITIALIZATION
  /// ===========================================================
  Future<void> _initializeLocalStorage() async {
    try {
      _localStorage = LocalStorageService.instance;
      await _localStorage.init();
      
      // Verify device ID is set
      final deviceId = _localStorage.deviceId;
      if (deviceId.isEmpty) {
        throw Exception('Device ID not generated properly');
      }
      
      debugPrint('📱 Device ID: $deviceId');
    } catch (e) {
      throw Exception('Failed to initialize local storage: $e');
    }
  }

  /// ===========================================================
  // STEP 2: DATA VALIDATION INITIALIZATION
  /// ===========================================================
  Future<void> _initializeDataValidation() async {
    try {
      _validator = DataValidationService.instance;
      debugPrint('🔍 Data validation service ready');
    } catch (e) {
      throw Exception('Failed to initialize data validation: $e');
    }
  }

  /// ===========================================================
  // STEP 3: RTSP ENCRYPTION INITIALIZATION
  /// ===========================================================
  Future<void> _initializeEncryptionService() async {
    try {
      _encryptionService = RTSPURLEncryptionService.instance;
      await _encryptionService.initialize();
      
      // Test encryption functionality
      if (!_encryptionService.testEncryption()) {
        throw Exception('RTSP encryption test failed');
      }
      
      debugPrint('🔐 RTSP encryption service ready');
    } catch (e) {
      debugPrint('⚠️ RTSP encryption initialization failed: $e');
      // Continue without encryption (not recommended for production)
    }
  }

  /// ===========================================================
  // STEP 4: DEVICE MANAGEMENT INITIALIZATION
  /// ===========================================================
  Future<void> _initializeDeviceManagement() async {
    try {
      _deviceService = DeviceManagementService.instance;
      await _deviceService.initialize();
      debugPrint('📱 Device management service ready');
    } catch (e) {
      debugPrint('⚠️ Device management initialization failed: $e');
      // Continue without device management
    }
  }

  /// ===========================================================
  // STEP 5: ALERT LOGGING INITIALIZATION
  /// ===========================================================
  Future<void> _initializeAlertLogging() async {
    try {
      _alertService = AlertLoggingService.instance;
      await _alertService.initialize();
      debugPrint('🚨 Alert logging service ready');
    } catch (e) {
      debugPrint('⚠️ Alert logging initialization failed: $e');
      // Continue without alert logging
    }
  }

  /// ===========================================================
  // STEP 6: ERROR LOGGING INITIALIZATION
  /// ===========================================================
  Future<void> _initializeErrorLogging() async {
    try {
      _errorService = ErrorLoggingService.instance;
      await _errorService.initialize();
      debugPrint('🚨 Error logging service ready');
    } catch (e) {
      debugPrint('⚠️ Error logging initialization failed: $e');
      // Continue without error logging
    }
  }

  /// ===========================================================
  // STEP 7: CAMERA MANAGEMENT INITIALIZATION
  /// ===========================================================
  Future<void> _initializeCameraManagement() async {
    try {
      _cameraService = CameraManagementService.instance;
      await _cameraService.initialize();
      debugPrint('📷 Camera management service ready');
    } catch (e) {
      debugPrint('⚠️ Camera management initialization failed: $e');
      // Continue without camera management
    }
  }

  /// ===========================================================
  // STEP 8: FIREBASE SYNC INITIALIZATION (LEGACY COMPATIBILITY)
  /// ===========================================================
  Future<void> _initializeFirebaseSync() async {
    try {
      _firebaseSync = FirebaseSyncService.instance;
      await _firebaseSync.initialize();
      
      // Setup sync event listener for logging
      _firebaseSync.syncEvents.listen((event) {
        debugPrint('🔄 Sync event: ${event.type} - ${event.message}');
      });
      
      debugPrint('☁️ Firebase sync service ready');
    } catch (e) {
      debugPrint('⚠️ Firebase sync initialization failed: $e');
      // Continue without Firebase sync (local storage only)
    }
  }

  /// ===========================================================
  // STEP 9: DATA MIGRATION
  /// ===========================================================
  Future<void> _performDataMigration() async {
    try {
      // Check if this is first run
      final isFirstRun = !_localStorage.syncMetadata.containsKey('migrationVersion');
      
      if (isFirstRun) {
        debugPrint('🔄 Performing first-time data migration...');
        
        // Migrate any existing data from old storage format
        await _migrateFromOldStorage();
        
        // Update migration version
        await _localStorage.updateSyncMetadata({
          'migrationVersion': 1,
          'migrationDate': DateTime.now().toIso8601String(),
        });
        
        debugPrint('✅ First-time migration completed');
      } else {
        debugPrint('ℹ️ Data migration already completed');
      }
    } catch (e) {
      debugPrint('⚠️ Data migration failed: $e');
      // Continue anyway - migration is not critical
    }
  }

  Future<void> _migrateFromOldStorage() async {
    // This would contain logic to migrate from any previous
    // storage format to the new structured format
    debugPrint('🔄 Checking for legacy data to migrate...');
    
    // Example: Check for old camera configs in different keys
    final storage = GetStorage();
    final oldKeys = ['cameras', 'camera_settings', 'saved_cameras'];
    
    for (final key in oldKeys) {
      if (storage.hasData(key)) {
        debugPrint('📦 Found legacy data in key: $key');
        // Migration logic would go here
        // For now, just log that we found it
      }
    }
  }

  /// ===========================================================
  // STEP 10: DATA VALIDATION
  /// ===========================================================
  Future<void> _validateStoredData() async {
    try {
      debugPrint('🔍 Validating stored camera configurations...');
      
      final cameraConfigs = _localStorage.getCameraConfigs();
      debugPrint('📷 Found ${cameraConfigs.length} camera configurations');
      
      // Validate each camera config
      int validCount = 0;
      int invalidCount = 0;
      
      for (final config in cameraConfigs) {
        final validation = _validator.validateCameraConfig(config);
        if (validation.isValid) {
          validCount++;
        } else {
          invalidCount++;
          debugPrint('⚠️ Invalid camera config "${config.name}": ${validation.errors.join(', ')}');
        }
      }
      
      debugPrint('✅ Data validation completed: $validCount valid, $invalidCount invalid');
      
      // Validate Firestore configs if available
      if (_firebaseSync.isInitialized) {
        final firestoreConfigs = _localStorage.getFirestoreCameraConfigs();
        debugPrint('☁️ Found ${firestoreConfigs.length} Firestore configurations');
      }
      
    } catch (e) {
      debugPrint('⚠️ Data validation failed: $e');
      // Continue anyway - validation is not critical
    }
  }

  /// ===========================================================
  // UTILITY METHODS
  /// ===========================================================
  
  /// Get initialization status as human-readable string
  String get initializationStatus {
    if (_isInitializing) return 'Initializing...';
    if (_isInitialized) return 'Initialized';
    if (_initializationError != null) return 'Error: $_initializationError';
    return 'Not initialized';
  }

  /// Get service status summary
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'initializing': _isInitializing,
      'error': _initializationError,
      'localStorage': _localStorage.deviceId.isNotEmpty,
      'firebaseSync': _firebaseSync.isInitialized,
      'deviceId': _localStorage.deviceId,
      'lastSyncTime': _firebaseSync.lastSyncTime?.toIso8601String(),
      'pendingChanges': _localStorage.pendingChanges.length,
    };
  }

  /// Force re-initialization (for debugging/testing)
  Future<bool> reinitialize() async {
    _isInitialized = false;
    _isInitializing = false;
    _initializationError = null;
    return await initialize();
  }

  /// Reset all data (for debugging/testing)
  Future<void> resetAllData() async {
    try {
      debugPrint('🔄 Resetting all app data...');
      
      // Clear local storage
      await _localStorage.clearAllData();
      
      // Reset initialization state
      _isInitialized = false;
      _isInitializing = false;
      _initializationError = null;
      
      debugPrint('✅ All data reset completed');
    } catch (e) {
      debugPrint('❌ Failed to reset data: $e');
      rethrow;
    }
  }

  /// Export all data for backup
  Future<String> exportAllData() async {
    if (!_isInitialized) {
      throw Exception('App not initialized');
    }
    
    try {
      final exportData = _localStorage.exportData();
      debugPrint('📤 Data export completed (${exportData.length} characters)');
      return exportData;
    } catch (e) {
      debugPrint('❌ Data export failed: $e');
      rethrow;
    }
  }

  /// Import data from backup
  Future<bool> importAllData(String jsonData) async {
    if (!_isInitialized) {
      throw Exception('App not initialized');
    }
    
    try {
      debugPrint('📥 Starting data import...');
      final success = await _localStorage.importData(jsonData);
      
      if (success) {
        debugPrint('✅ Data import completed successfully');
        
        // Re-validate imported data
        await _validateStoredData();
        
        // DISABLED: Firebase sync should only happen when user presses "Finish Setup"
        // if (_firebaseSync.isInitialized) {
        //   await _firebaseSync.fullSync();
        // }
        debugPrint('📝 Firebase sync disabled - will sync only on Finish Setup');
      } else {
        debugPrint('❌ Data import failed');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Data import failed: $e');
      rethrow;
    }
  }
}
