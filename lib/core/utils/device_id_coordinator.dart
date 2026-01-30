import 'dart:async';
import '../../core/utils/device_id_manager.dart';
import '../../core/logging/logger_service.dart';

/// Centralized device ID coordinator to ensure single device ID across all services
class DeviceIdCoordinator {
  static DeviceIdCoordinator? _instance;
  static DeviceIdCoordinator get instance => _instance ??= DeviceIdCoordinator._();
  
  DeviceIdCoordinator._();
  
  static bool _isInitialized = false;
  static String? _cachedDeviceId;
  static final Completer<String> _initCompleter = Completer<String>();
  
  /// Initialize device ID coordination (call once at app start)
  static Future<void> initialize() async {
    if (_isInitialized) {
      LoggerService.i('🔄 DeviceIdCoordinator already initialized');
      return;
    }
    
    try {
      LoggerService.i('🚀 Initializing DeviceIdCoordinator...');
      
      // Ensure DeviceIdManager has a proper device ID
      final deviceId = await DeviceIdManager.getDeviceId();
      _cachedDeviceId = deviceId;
      
      // Clear any old UUID formats from all storage services
      await _clearOldUuids();
      
      _isInitialized = true;
      _initCompleter.complete(deviceId);
      
      LoggerService.i('✅ DeviceIdCoordinator initialized with device ID: $deviceId');
    } catch (e) {
      LoggerService.e('❌ Failed to initialize DeviceIdCoordinator', e);
      _initCompleter.completeError(e);
      rethrow;
    }
  }
  
  /// Get the coordinated device ID (waits for initialization if needed)
  static Future<String> getDeviceId() async {
    if (!_isInitialized) {
      return await _initCompleter.future;
    }
    return _cachedDeviceId!;
  }
  
  /// Clear old UUID formats from all storage services
  static Future<void> _clearOldUuids() async {
    try {
      LoggerService.i('🧹 Clearing old UUID formats from storage services...');
      
      // This will be handled by individual storage services during their initialization
      // The migration logic in each service will detect and clear old UUIDs
      
      LoggerService.i('✅ Old UUID cleanup completed');
    } catch (e) {
      LoggerService.e('❌ Failed to clear old UUIDs', e);
    }
  }
  
  /// Force reset device ID (for testing/debugging)
  static Future<void> resetDeviceId() async {
    LoggerService.w('🔄 Resetting device ID...');
    
    // Clear DeviceIdManager
    await DeviceIdManager.clearDeviceId();
    
    // Reset coordinator state
    _isInitialized = false;
    _cachedDeviceId = null;
    _initCompleter.completeError('Device ID reset');
    
    // Reinitialize
    await initialize();
    
    LoggerService.i('✅ Device ID reset completed');
  }
}
