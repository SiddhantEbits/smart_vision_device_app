import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/device_id_manager.dart';
import '../../../../data/services/device_firebase_service.dart';

class QRScanController extends GetxController {
  final deviceId = ''.obs;
  final deviceName = ''.obs;
  final isLoading = true.obs;
  final isPaired = false.obs;
  final deviceNameController = TextEditingController();
  StreamSubscription<DocumentSnapshot>? _deviceSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadDeviceInfo();
  }

  @override
  void onClose() {
    deviceNameController.dispose();
    _deviceSubscription?.cancel();
    super.onClose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      print('🔄 Loading device info...');
      isLoading.value = true;
      
      // First check if device ID already exists in local storage
      final existingDeviceId = await DeviceIdManager.getExistingDeviceId();
      print('📱 Existing device ID from local storage: $existingDeviceId');
      
      if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
        print('📋 Using existing device ID from local storage...');
        // Use existing device ID from local storage
        deviceId.value = existingDeviceId;
        print('✅ Existing device ID: $existingDeviceId');
        
        // Get device name
        print('📝 Loading device name...');
        final name = await DeviceIdManager.getDeviceName();
        deviceName.value = name;
        deviceNameController.text = name;
        print('✅ Device name loaded: $name');
        
        // Ensure Firebase document exists (will update existing if it exists)
        print('💾 Ensuring Firebase document exists...');
        await _saveDeviceIdToFirebase(existingDeviceId);
      } else {
        // No local device ID found - check if we should create a new one
        print('🔍 No local device ID found, checking Firebase for any existing device...');
        
        // For now, generate a new device ID since we don't have any existing one
        // In the future, you might want to implement logic to recover a device ID
        print('🆕 No existing device ID found, generating new device ID...');
        final id = await DeviceIdManager.regenerateDeviceId();
        deviceId.value = id;
        print('✅ Device ID generated: $id');
        
        // Get device name first
        print('📝 Loading device name...');
        final name = await DeviceIdManager.getDeviceName();
        deviceName.value = name;
        deviceNameController.text = name;
        print('✅ Device name loaded: $name');
        
        // Save ONLY device ID to Firebase (no device name)
        print('💾 Saving device ID to Firebase...');
        await _saveDeviceIdToFirebase(id);
      }
      
      // Start listening to Firebase for pairing status
      print('👂 Starting Firebase listener...');
      _startListeningToPairingStatus();
      
      isLoading.value = false;
      print('✅ Device info loading complete');
    } catch (e) {
      print('❌ Error loading device info: $e');
      deviceId.value = 'SV-ERROR-LOADING';
      deviceName.value = 'Unknown Device';
      isLoading.value = false;
    }
  }

  /// Start listening to Firebase for pairing status changes
  void _startListeningToPairingStatus() {
    if (deviceId.value.isEmpty) return;
    
    _deviceSubscription = FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId.value)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          // Check if device is paired using isPaired field from firebase.md
          final paired = data['isPaired'] as bool? ?? false;
          isPaired.value = paired;
          
          // Update device name from deviceName field if available
          final deviceNameFromFirebase = data['deviceName'] as String?;
          if (deviceNameFromFirebase != null && deviceNameFromFirebase.isNotEmpty) {
            deviceName.value = deviceNameFromFirebase;
            deviceNameController.text = deviceNameFromFirebase;
            // Save to local storage
            DeviceIdManager.saveDeviceName(deviceNameFromFirebase);
          }
          
          print('👂 Firebase: Device pairing status updated: isPaired=$paired, deviceName=$deviceNameFromFirebase');
        }
      }
    }, onError: (error) {
      print('❌ Error listening to device updates: $error');
    });
  }

  /// Update device name
  Future<void> updateDeviceName() async {
    if (deviceNameController.text.trim().isNotEmpty) {
      try {
        // Update local storage
        await DeviceIdManager.saveDeviceName(deviceNameController.text.trim());
        deviceName.value = deviceNameController.text.trim();
        
        // Update Firebase with device name ONLY (preserve isPaired status)
        await _updateDeviceNameInFirebase(deviceNameController.text.trim());
        
        print('✅ Device name updated: ${deviceNameController.text.trim()}');
      } catch (e) {
        print('❌ Error updating device name: $e');
      }
    }
  }

  /// Update only device name in Firebase without affecting other fields
  Future<void> _updateDeviceNameInFirebase(String deviceName) async {
    try {
      print('🔥 Firebase: Updating device name only: $deviceName');
      
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId.value)
          .update({
        'deviceName': deviceName,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      print('✅ Firebase: Device name updated successfully: $deviceName');
    } catch (e) {
      print('❌ Firebase: Error updating device name: $e');
      rethrow;
    }
  }

  /// Save only device ID to Firebase (for initial QR generation)
  Future<void> _saveDeviceIdToFirebase(String deviceId) async {
    try {
      print('💾 Saving device ID to Firebase: $deviceId');
      await DeviceFirebaseService.saveDeviceIdOnly(
        deviceId: deviceId,
        platform: 'android',
        appVersion: '1.0.0',
      );
      print('✅ Device ID saved to Firebase: $deviceId');
    } catch (e) {
      print('❌ Error saving device ID to Firebase: $e');
      // Don't throw error - device ID generation should still work even if Firebase fails
    }
  }

  /// Check if next button should be enabled
  bool get canNavigateToNext => isPaired.value && deviceName.value.isNotEmpty;

  /// Save device information to Firebase devices collection
  Future<void> _saveDeviceToFirebase(String deviceId) async {
    try {
      print('Saving to Firebase - Device ID: $deviceId, Device Name: ${deviceName.value}');
      
      await DeviceFirebaseService.saveDevice(
        deviceId: deviceId,
        deviceName: deviceName.value,
        platform: 'android',
        appVersion: '1.0.0',
        linked: false,
      );
      
      print('✅ Device successfully saved to Firebase: $deviceId');
    } catch (e) {
      print('❌ Error saving device to Firebase: $e');
      print('Stack trace: ${StackTrace.current}');
      // Don't throw error - device ID generation should still work even if Firebase fails
    }
  }
}
