import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

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
  
  /// Generate a new unique device ID
  static Future<String> _generateNewDeviceId() async {
    try {
      // Try to use hardware info first
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final uuid = const Uuid().v4();
        return 'SV-${androidInfo.brand}-${androidInfo.model}-$uuid';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final uuid = const Uuid().v4();
        return 'SV-${iosInfo.model}-$uuid';
      }
    } catch (e) {
      // Fallback to UUID only
      print('Error getting device info: $e');
    }
    
    // Fallback: UUID with prefix
    final uuid = const Uuid().v4();
    return 'SV-DEVICE-$uuid';
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
  
  /// Generate a simple random device ID (alternative method)
  static String generateSimpleDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    final hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'SV-$hexString';
  }
  
  /// Generate timestamp-based device ID (alternative method)
  static String generateTimestampDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'SV-$timestamp-$random';
  }
}
