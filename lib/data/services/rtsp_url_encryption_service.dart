import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

// Import Key from encrypt package with alias
import 'package:encrypt/encrypt.dart' as encrypt;

/// ===========================================================
/// RTSP URL ENCRYPTION SERVICE
/// Handles AES-256-GCM encryption for RTSP URLs as per Firebase requirements
/// ===========================================================
class RTSPURLEncryptionService {
  static RTSPURLEncryptionService? _instance;
  static RTSPURLEncryptionService get instance => _instance ??= RTSPURLEncryptionService._();
  
  RTSPURLEncryptionService._();

  late final Encrypter _encrypter;
  late final IV _iv;
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // In a production environment, this key should come from Cloud KMS or secure storage
      // For development, we'll use a hardcoded key (THIS SHOULD BE CHANGED IN PRODUCTION)
      const keyString = '32-character-long-encryption-key!'; // 32 chars = 256 bits
      final key = encrypt.Key.fromUtf8(keyString);
      
      _encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      _iv = IV.fromLength(16); // 16 bytes = 128 bits for GCM
      
      _isInitialized = true;
      
      debugPrint('🔐 RTSP URL Encryption Service initialized');
      
    } catch (e) {
      debugPrint('❌ Error initializing RTSP URL Encryption Service: $e');
      rethrow;
    }
  }

  /// ===========================================================
  /// ENCRYPTION METHODS
  /// ===========================================================
  String encryptRTSPUrl(String rtspUrl) {
    if (!_isInitialized) {
      throw Exception('RTSPURLEncryptionService not initialized');
    }

    try {
      // Validate RTSP URL
      if (!_isValidRTSPUrl(rtspUrl)) {
        throw ArgumentError('Invalid RTSP URL format');
      }

      // Encrypt the URL
      final encrypted = _encrypter.encrypt(rtspUrl, iv: _iv);
      
      // Format as required: ENC:AES256-GCM:base64
      final base64Encoded = encrypted.base64;
      final formattedResult = 'ENC:AES256-GCM:$base64Encoded';
      
      debugPrint('🔐 RTSP URL encrypted successfully');
      return formattedResult;
      
    } catch (e) {
      debugPrint('❌ Error encrypting RTSP URL: $e');
      rethrow;
    }
  }

  String decryptRTSPUrl(String encryptedUrl) {
    if (!_isInitialized) {
      throw Exception('RTSPURLEncryptionService not initialized');
    }

    try {
      // Validate encrypted format
      if (!_isValidEncryptedFormat(encryptedUrl)) {
        throw ArgumentError('Invalid encrypted URL format');
      }

      // Extract base64 part
      final parts = encryptedUrl.split(':');
      if (parts.length != 3 || parts[0] != 'ENC' || parts[1] != 'AES256-GCM') {
        throw ArgumentError('Invalid encrypted URL format');
      }
      
      final base64Encoded = parts[2];
      
      // Decrypt
      final encrypted = Encrypted.fromBase64(base64Encoded);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      
      debugPrint('🔓 RTSP URL decrypted successfully');
      return decrypted;
      
    } catch (e) {
      debugPrint('❌ Error decrypting RTSP URL: $e');
      rethrow;
    }
  }

  /// ===========================================================
  /// BATCH OPERATIONS
  /// ===========================================================
  Map<String, String> encryptMultipleUrls(Map<String, String> cameraUrls) {
    final encryptedUrls = <String, String>{};
    
    for (final entry in cameraUrls.entries) {
      try {
        encryptedUrls[entry.key] = encryptRTSPUrl(entry.value);
      } catch (e) {
        debugPrint('❌ Failed to encrypt URL for ${entry.key}: $e');
        // Keep original URL as fallback
        encryptedUrls[entry.key] = entry.value;
      }
    }
    
    return encryptedUrls;
  }

  Map<String, String> decryptMultipleUrls(Map<String, String> encryptedUrls) {
    final decryptedUrls = <String, String>{};
    
    for (final entry in encryptedUrls.entries) {
      try {
        decryptedUrls[entry.key] = decryptRTSPUrl(entry.value);
      } catch (e) {
        debugPrint('❌ Failed to decrypt URL for ${entry.key}: $e');
        // Keep encrypted URL as fallback
        decryptedUrls[entry.key] = entry.value;
      }
    }
    
    return decryptedUrls;
  }

  /// ===========================================================
  /// VALIDATION METHODS
  /// ===========================================================
  bool _isValidRTSPUrl(String url) {
    if (url.isEmpty) return false;
    
    // Check RTSP protocol
    if (!url.startsWith('rtsp://')) return false;
    
    // Basic URL structure validation
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Must have host
    if (uri.host.isEmpty) return false;
    
    // Optional: Check for port
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
    
    return true;
  }

  bool _isValidEncryptedFormat(String encryptedUrl) {
    if (encryptedUrl.isEmpty) return false;
    
    final parts = encryptedUrl.split(':');
    if (parts.length != 3) return false;
    
    if (parts[0] != 'ENC') return false;
    if (parts[1] != 'AES256-GCM') return false;
    
    // Check if base64 part is valid
    try {
      base64.decode(parts[2]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ===========================================================
  /// UTILITY METHODS
  /// ===========================================================
  bool isEncrypted(String url) {
    return _isValidEncryptedFormat(url);
  }

  String extractAlgorithm(String encryptedUrl) {
    if (!_isValidEncryptedFormat(encryptedUrl)) return '';
    
    final parts = encryptedUrl.split(':');
    return parts[1]; // AES256-GCM
  }

  /// ===========================================================
  /// SECURITY METHODS
  /// ===========================================================
  /// Generate a new encryption key (for key rotation)
  String generateNewKey() {
    final keyBytes = Uint8List.fromList(SecureRandom(32).bytes());
    return base64.encode(keyBytes);
  }

  /// Rotate encryption key (would require re-encrypting all URLs)
  Future<void> rotateKey(String newKey) async {
    if (!_isInitialized) return;

    try {
      // In a real implementation, this would:
      // 1. Update the encryption key
      // 2. Re-encrypt all stored RTSP URLs
      // 3. Update Firebase documents
      // 4. Handle any decryption failures gracefully
      
      debugPrint('🔄 Key rotation initiated');
      
      // For now, just log the operation
      // In production, this would be a complex operation requiring careful handling
      
    } catch (e) {
      debugPrint('❌ Error during key rotation: $e');
      rethrow;
    }
  }

  /// ===========================================================
  /// TESTING METHODS
  /// ===========================================================
  /// Test encryption/decryption functionality
  bool testEncryption() {
    if (!_isInitialized) return false;

    try {
      const testUrl = 'rtsp://192.168.1.100:554/stream';
      
      // Encrypt
      final encrypted = encryptRTSPUrl(testUrl);
      
      // Decrypt
      final decrypted = decryptRTSPUrl(encrypted);
      
      // Verify
      return testUrl == decrypted;
      
    } catch (e) {
      debugPrint('❌ Encryption test failed: $e');
      return false;
    }
  }

  /// Get encryption info for debugging
  Map<String, dynamic> getEncryptionInfo() {
    return {
      'initialized': _isInitialized,
      'algorithm': 'AES-256-GCM',
      'keyLength': 256,
      'ivLength': 128,
      'format': 'ENC:AES256-GCM:base64',
    };
  }
}

/// ===========================================================
/// SECURE RANDOM GENERATOR
/// ===========================================================
class SecureRandom {
  final int length;
  
  const SecureRandom(this.length);
  
  Uint8List bytes() {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}

/// ===========================================================
/// RTSP URL VALIDATOR
/// Utility class for RTSP URL validation
/// ===========================================================
class RTSPURLValidator {
  static bool isValidRTSPUrl(String url) {
    if (url.isEmpty) return false;
    
    // Check protocol
    if (!url.startsWith('rtsp://')) return false;
    
    try {
      final uri = Uri.parse(url);
      
      // Required components
      if (uri.host.isEmpty) return false;
      
      // Optional validation
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
      
      // Check for path
      if (uri.path.isEmpty) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static String? validateAndGetError(String url) {
    if (url.isEmpty) return 'URL cannot be empty';
    
    if (!url.startsWith('rtsp://')) {
      return 'URL must start with rtsp://';
    }
    
    try {
      final uri = Uri.parse(url);
      
      if (uri.host.isEmpty) {
        return 'URL must contain a valid host';
      }
      
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
        return 'Port must be between 1 and 65535';
      }
      
      if (uri.path.isEmpty) {
        return 'URL must contain a path';
      }
      
      return null; // Valid
    } catch (e) {
      return 'Invalid URL format: $e';
    }
  }
  
  static List<String> getCommonFormats() {
    return [
      'rtsp://192.168.1.100:554/stream',
      'rtsp://admin:password@192.168.1.100:554/stream',
      'rtsp://camera.local:554/live',
      'rtsp://[fe80::1]:554/stream', // IPv6 example
    ];
  }
}
