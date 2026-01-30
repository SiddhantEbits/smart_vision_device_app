import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../logging/logger_service.dart';

class DeviceIdManager {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';
  
  static String? _cachedDeviceId;
  
  /// Get or generate a unique device ID
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      deviceId = await _generateNewDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    _cachedDeviceId = deviceId;
    return deviceId;
  }
  
  /// Check if device ID is already generated
  static Future<bool> hasDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_deviceIdKey);
  }
  
  /// Get device ID without generating new one (returns null if not exists)
  static Future<String?> getExistingDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }
  
  /// Get device name for display
  static Future<String> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceName = prefs.getString(_deviceNameKey);
    
    if (deviceName == null) {
      deviceName = await _generateDeviceName();
      await prefs.setString(_deviceNameKey, deviceName);
    }
    
    return deviceName;
  }
  
  /// Save device name
  static Future<void> saveDeviceName(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, deviceName);
  }
  
  /// Update device name and save to Firebase
  static Future<void> updateDeviceName(String deviceName) async {
    await saveDeviceName(deviceName);
    // Note: Firebase update should be called from controller to avoid circular dependency
  }
  
  /// Clear device ID and force regeneration
  static Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    _cachedDeviceId = null;
    LoggerService.i('🗑️ Device ID cleared, will regenerate on next access');
  }
  
  /// Force regenerate device ID (useful for migration)
  static Future<String> forceRegenerateDeviceId() async {
    await clearDeviceId();
    return await getDeviceId();
  }
  
  /// Generate a new unique device ID
  static Future<String> _generateNewDeviceId() async {
    try {
      // Try to use hardware info for device name
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand}-${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.model;
      }
      
      // Generate device ID in format: SV-SDDMMYY@HHMMSS
      final now = DateTime.now();
      
      // SDDMMYY format (S is fixed letter)
      final day = now.day.toString().padLeft(2, '0');       // DD
      final month = now.month.toString().padLeft(2, '0');   // MM
      final year = (now.year % 100).toString().padLeft(2, '0'); // YY
      
      final datePart = "S$day$month$year";
      
      // HHMMSS format
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      final second = now.second.toString().padLeft(2, '0');
      
      final timePart = "$hour$minute$second";
      
      return "SV-$datePart@$timePart";
      
    } catch (e) {
      // Fallback to timestamp-based format
      print('Error generating device ID: $e');
      final now = DateTime.now();
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = (now.year % 100).toString().padLeft(2, '0');
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      final second = now.second.toString().padLeft(2, '0');
      
      return "SV-S$day$month$year@$hour$minute$second";
    }
  }
  
  /// Generate a human-readable device name
  static Future<String> _generateDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Smart Vision ${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'Smart Vision ${iosInfo.model}';
      }
    } catch (e) {
      print('Error getting device info for name: $e');
    }
    
    // Fallback
    return 'Smart Vision Device';
  }
  
  /// Reset device ID (for testing or re-setup)
  static Future<String> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final newDeviceId = await _generateNewDeviceId();
    await prefs.setString(_deviceIdKey, newDeviceId);
    _cachedDeviceId = newDeviceId;
    return newDeviceId;
  }
  
  /// Force regenerate device ID with new format (call this after format change)
  static Future<String> regenerateDeviceId() async {
    _cachedDeviceId = null; // Clear cache
    return await resetDeviceId();
  }
  
  /// Get device info as map
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Generate a simple device ID using the new format
  static String generateSimpleDeviceId() {
    final now = DateTime.now();
    
    // SDDMMYY format (S is fixed letter)
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0');
    
    final datePart = "S$day$month$year";
    
    // HHMMSS format
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    final timePart = "$hour$minute$second";
    
    return "SV-$datePart@$timePart";
  }
  
  /// Generate timestamp-based device ID using the new format
  static String generateTimestampDeviceId() {
    return generateSimpleDeviceId(); // Same format now
  }
}
