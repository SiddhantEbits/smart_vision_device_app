import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'devices';

  /// Save device information to Firebase (matches firebase.md schema)
  static Future<void> saveDevice({
    required String deviceId,
    String? deviceName,
    String platform = 'android',
    String appVersion = '1.0.0',
    bool linked = false,
  }) async {
    try {
      print('🔥 Firebase: Saving device $deviceId');
      
      final deviceData = {
        'pairedUserId': '', // Will be updated when paired
        'deviceName': deviceName ?? 'Smart Vision Device',
        'status': 'online', // Always online when saving
        'lastSeen': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
        
        'maintenanceMode': false,
        'hardRestart': false,
        
        'createdAt': FieldValue.serverTimestamp(),
        
        'isPaired': linked,
        'pairedAt': linked ? FieldValue.serverTimestamp() : null,
        'pairedBy': '', // Will be updated when paired
        
        'alertEnable': true,
        'notificationEnabled': true,
        
        'fcmToken': '', // Will be updated when FCM is set up
        'fcmTokenUpdatedAt': linked ? FieldValue.serverTimestamp() : null,
        
        'whatsapp': {
          'alertEnable': true,
          'phoneNumbers': [], // Will be updated when configured
        }
      };
      
      // Check if document exists first
      final docSnapshot = await _firestore.collection(_collection).doc(deviceId).get();
      
      if (docSnapshot.exists) {
        print('📝 Firebase: Document exists, updating...');
        // Preserve existing createdAt if it exists
        final existingData = docSnapshot.data() as Map<String, dynamic>?;
        if (existingData != null && existingData['createdAt'] != null) {
          deviceData['createdAt'] = existingData['createdAt'];
        }
        // Preserve existing deviceName if it exists and we're not providing a new one
        if (deviceName == null && existingData != null && existingData['deviceName'] != null) {
          deviceData['deviceName'] = existingData['deviceName'];
        }
      } else {
        print('🆕 Firebase: Creating new document...');
      }
      
      await _firestore.collection(_collection).doc(deviceId).set(
        deviceData,
        SetOptions(merge: true),
      );
      
      print('✅ Firebase: Device saved successfully: $deviceId');
    } catch (e) {
      print('❌ Firebase: Error saving device: $e');
      rethrow;
    }
  }

  /// Save only device ID to Firebase (for initial QR generation)
  static Future<void> saveDeviceIdOnly({
    required String deviceId,
    String platform = 'android',
    String appVersion = '1.0.0',
  }) async {
    try {
      print('🔥 Firebase: Saving device ID only $deviceId');
      
      final deviceData = {
        'pairedUserId': '', // Will be updated when paired
        'deviceName': '', // Will be updated on continue button
        'status': 'online', // Always online when saving
        'lastSeen': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
        
        'maintenanceMode': false,
        'hardRestart': false,
        
        'createdAt': FieldValue.serverTimestamp(),
        
        'isPaired': false, // Default to false
        'pairedAt': null,
        'pairedBy': '',
        
        'alertEnable': true,
        'notificationEnabled': true,
        
        'fcmToken': '', // Will be updated when FCM is set up
        'fcmTokenUpdatedAt': null,
        
        'whatsapp': {
          'alertEnable': true,
          'phoneNumbers': [], // Will be updated when configured
        }
      };
      
      // Check if document already exists
      final docSnapshot = await _firestore.collection(_collection).doc(deviceId).get();
      final isUpdate = docSnapshot.exists;
      
      print('🔥 Firebase: ${isUpdate ? "Updating existing" : "Creating new"} device document: $deviceId');
      
      await _firestore.collection(_collection).doc(deviceId).set(
        deviceData,
        SetOptions(merge: true),
      );
      
      print('✅ Firebase: Device ID ${isUpdate ? "updated" : "created"} successfully: $deviceId');
    } catch (e) {
      print('❌ Firebase: Error saving device ID: $e');
      rethrow;
    }
  }

  /// Update device last seen timestamp
  static Future<void> updateLastSeen(String deviceId) async {
    try {
      await _firestore.collection(_collection).doc(deviceId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  /// Mark device as linked
  static Future<void> markAsLinked(String deviceId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(deviceId).update({
        'linked': true,
        'linkedAt': FieldValue.serverTimestamp(),
        'linkedBy': userId,
        'status': 'linked',
      });
    } catch (e) {
      print('Error marking device as linked: $e');
    }
  }

  /// Get device information
  static Future<DocumentSnapshot?> getDevice(String deviceId) async {
    try {
      return await _firestore.collection(_collection).doc(deviceId).get();
    } catch (e) {
      print('Error getting device: $e');
      return null;
    }
  }

  /// Check if device exists
  static Future<bool> deviceExists(String deviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(deviceId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking device existence: $e');
      return false;
    }
  }

  /// Delete device from Firebase
  static Future<void> deleteDevice(String deviceId) async {
    try {
      await _firestore.collection(_collection).doc(deviceId).delete();
      print('Device deleted from Firebase: $deviceId');
    } catch (e) {
      print('Error deleting device: $e');
      rethrow;
    }
  }
}
