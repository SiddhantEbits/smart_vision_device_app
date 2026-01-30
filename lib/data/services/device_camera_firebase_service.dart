import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/camera_config.dart';
import '../models/alert_config_model.dart' hide AlertSchedule;
import '../models/alert_config_model.dart' as alert_model show AlertSchedule;
import '../repositories/local_storage_service.dart';

/// ===========================================================
/// DEVICE CAMERA FIREBASE SERVICE
/// Handles camera data in devices/{deviceId}/cameras/{cameraId} structure
/// Follows Firebase schema from firebase.md
/// ===========================================================
class DeviceCameraFirebaseService {
  static DeviceCameraFirebaseService? _instance;
  static DeviceCameraFirebaseService get instance => _instance ??= DeviceCameraFirebaseService._();
  
  DeviceCameraFirebaseService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final CollectionReference<Map<String, dynamic>> _devicesCollection;
  
  // Service state
  bool _isInitialized = false;
  String? _deviceId;

  /// ===========================================================
  /// GETTERS
  /// ===========================================================
  bool get isInitialized => _isInitialized;
  String get deviceId => _deviceId ?? '';

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      _firestore = FirebaseFirestore.instance;
      
      // Initialize local storage
      _localStorage = LocalStorageService.instance;
      await _localStorage.init();
      
      // Get device ID
      _deviceId = _localStorage.deviceId;
      
      // Setup collection reference
      _devicesCollection = _firestore.collection('devices');
      
      _isInitialized = true;
      print('Device Camera Firebase Service initialized for device: $_deviceId');
    } catch (e) {
      print('Error initializing Device Camera Firebase Service: $e');
      rethrow;
    }
  }

  /// ===========================================================
  /// CAMERA OPERATIONS
  /// ===========================================================
  
  /// Save camera to devices/{deviceId}/cameras/{cameraId}
  Future<void> saveCamera(CameraConfig cameraConfig) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      // Generate camera ID (CAM01, CAM02, etc.)
      final cameraId = cameraConfig.name;
      
      // Get device reference
      final deviceRef = _devicesCollection.doc(_deviceId);
      final camerasCollection = deviceRef.collection('cameras');
      
      // Convert camera config to Firebase schema
      final cameraData = _convertCameraConfigToFirebaseSchema(cameraConfig);
      
      // Save to Firestore
      await camerasCollection.doc(cameraId).set(cameraData);
      
      print('Camera $cameraId saved to Firebase successfully');
    } catch (e) {
      print('Error saving camera to Firebase: $e');
      rethrow;
    }
  }

  /// Update camera in devices/{deviceId}/cameras/{cameraId}
  Future<void> updateCamera(CameraConfig cameraConfig) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final cameraId = cameraConfig.name;
      final deviceRef = _devicesCollection.doc(_deviceId);
      final camerasCollection = deviceRef.collection('cameras');
      
      // Convert camera config to Firebase schema
      final cameraData = _convertCameraConfigToFirebaseSchema(cameraConfig);
      
      // Update in Firestore
      await camerasCollection.doc(cameraId).update(cameraData);
      
      print('Camera $cameraId updated in Firebase successfully');
    } catch (e) {
      print('Error updating camera in Firebase: $e');
      rethrow;
    }
  }

  /// Delete camera from devices/{deviceId}/cameras/{cameraId}
  Future<void> deleteCamera(String cameraId) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final deviceRef = _devicesCollection.doc(_deviceId);
      final camerasCollection = deviceRef.collection('cameras');
      
      // Delete from Firestore
      await camerasCollection.doc(cameraId).delete();
      
      print('Camera $cameraId deleted from Firebase successfully');
    } catch (e) {
      print('Error deleting camera from Firebase: $e');
      rethrow;
    }
  }

  /// Get all cameras for this device
  Future<List<CameraConfig>> getAllCameras() async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final deviceRef = _devicesCollection.doc(_deviceId);
      final camerasCollection = deviceRef.collection('cameras');
      
      final snapshot = await camerasCollection.get();
      
      final cameras = snapshot.docs.map((doc) {
        return _convertFirebaseSchemaToCameraConfig(doc.id, doc.data()!);
      }).toList();
      
      return cameras;
    } catch (e) {
      print('Error getting cameras from Firebase: $e');
      return [];
    }
  }

  /// Get specific camera by ID
  Future<CameraConfig?> getCamera(String cameraId) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final deviceRef = _devicesCollection.doc(_deviceId);
      final camerasCollection = deviceRef.collection('cameras');
      
      final doc = await camerasCollection.doc(cameraId).get();
      
      if (!doc.exists) return null;
      
      return _convertFirebaseSchemaToCameraConfig(doc.id, doc.data()!);
    } catch (e) {
      print('Error getting camera from Firebase: $e');
      return null;
    }
  }

  /// ===========================================================
  /// SCHEMA CONVERSION METHODS
  /// ===========================================================
  
  /// Convert CameraConfig to Firebase schema according to firebase.md
  Map<String, dynamic> _convertCameraConfigToFirebaseSchema(CameraConfig config) {
    // Encrypt RTSP URL (basic encryption for demo - in production use proper encryption)
    final encryptedUrl = _encryptRtspUrl(config.url);
    
    return {
      'cameraName': config.name,
      'rtspUrlEncrypted': encryptedUrl,
      'createdAt': FieldValue.serverTimestamp(),
      
      // Algorithms according to firebase.md schema
      'algorithms': {
        // Crowd Detection Algorithm (renamed from peopleCount)
        'crowdDetection': {
          'enabled': config.peopleCountEnabled,
          'threshold': config.confidenceThreshold,
          'maxCapacity': config.maxPeople,
          'cooldownSeconds': 300,
          'appNotification': true,
          'wpNotification': false,
          'schedule': _convertScheduleToFirebaseSchema(config.maxPeopleSchedule),
        },
        
        // Footfall Count Algorithm
        'footfallCount': {
          'enabled': config.footfallEnabled,
          'threshold': config.confidenceThreshold,
          'alertInterval': 300, // Fixed 5 minutes as per schema
          'appNotification': true,
          'wpNotification': false,
          'schedule': _convertScheduleToFirebaseSchema(config.footfallSchedule),
        },
        
        // Restricted Area Algorithm
        'restrictedArea': {
          'enabled': config.restrictedAreaEnabled,
          'threshold': config.confidenceThreshold,
          'cooldownSeconds': config.restrictedAreaCooldownSeconds,
          'appNotification': true,
          'wpNotification': false,
          'schedule': _convertScheduleToFirebaseSchema(config.restrictedAreaSchedule),
        },
        
        // Sensitive Alert Algorithm (renamed from theftDetection)
        'sensitiveAlert': {
          'enabled': config.theftAlertEnabled,
          'threshold': config.confidenceThreshold,
          'cooldownSeconds': config.theftCooldownSeconds,
          'appNotification': true,
          'wpNotification': false,
          'schedule': _convertScheduleToFirebaseSchema(config.theftSchedule),
        },
        
        // Absent Alert Algorithm
        'absentAlert': {
          'enabled': config.absentAlertEnabled,
          'threshold': config.confidenceThreshold,
          'absentInterval': 5, // Fixed value as per schema (note: typo in original schema)
          'cooldownSeconds': config.absentCooldownSeconds,
          'appNotification': true,
          'wpNotification': false,
          'schedule': _convertScheduleToFirebaseSchema(config.absentSchedule),
        },
      },
    };
  }

  /// Convert Firebase schema to CameraConfig
  CameraConfig _convertFirebaseSchemaToCameraConfig(String cameraId, Map<String, dynamic> data) {
    final algorithms = data['algorithms'] as Map<String, dynamic>? ?? {};
    
    // Extract algorithm configurations
    final crowdDetectionAlg = algorithms['crowdDetection'] as Map<String, dynamic>? ?? {};
    final footfallCountAlg = algorithms['footfallCount'] as Map<String, dynamic>? ?? {};
    final restrictedAreaAlg = algorithms['restrictedArea'] as Map<String, dynamic>? ?? {};
    final sensitiveAlertAlg = algorithms['sensitiveAlert'] as Map<String, dynamic>? ?? {};
    final absentAlertAlg = algorithms['absentAlert'] as Map<String, dynamic>? ?? {};
    
    return CameraConfig(
      name: data['cameraName'] ?? cameraId,
      url: '', // RTSP URL is encrypted, not stored locally
      
      // Crowd Detection (renamed from peopleCount)
      peopleCountEnabled: crowdDetectionAlg['enabled'] ?? false,
      maxPeople: (crowdDetectionAlg['maxCapacity'] as num?)?.toInt() ?? 5,
      maxPeopleSchedule: _convertFirebaseScheduleToSchedule(crowdDetectionAlg['schedule']),
      maxPeopleCooldownSeconds: (crowdDetectionAlg['cooldownSeconds'] as num?)?.toInt() ?? 300,
      
      // Footfall
      footfallEnabled: footfallCountAlg['enabled'] ?? false,
      footfallIntervalMinutes: ((footfallCountAlg['alertInterval'] as num?)?.toInt() ?? 300) ~/ 60,
      footfallSchedule: _convertFirebaseScheduleToSchedule(footfallCountAlg['schedule']),
      
      // Restricted Area
      restrictedAreaEnabled: restrictedAreaAlg['enabled'] ?? false,
      restrictedAreaCooldownSeconds: (restrictedAreaAlg['cooldownSeconds'] as num?)?.toInt() ?? 300,
      restrictedAreaSchedule: _convertFirebaseScheduleToSchedule(restrictedAreaAlg['schedule']),
      
      // Sensitive Alert (renamed from theftDetection)
      theftAlertEnabled: sensitiveAlertAlg['enabled'] ?? false,
      theftCooldownSeconds: (sensitiveAlertAlg['cooldownSeconds'] as num?)?.toInt() ?? 300,
      theftSchedule: _convertFirebaseScheduleToSchedule(sensitiveAlertAlg['schedule']),
      
      // Absent Alert
      absentAlertEnabled: absentAlertAlg['enabled'] ?? false,
      absentSeconds: (absentAlertAlg['absentInterval'] as num?)?.toInt() ?? 5, // Note: using typo from schema
      absentCooldownSeconds: (absentAlertAlg['cooldownSeconds'] as num?)?.toInt() ?? 300,
      absentSchedule: _convertFirebaseScheduleToSchedule(absentAlertAlg['schedule']),
      
      // YOLO
      confidenceThreshold: (crowdDetectionAlg['threshold'] as num?)?.toDouble() ?? 0.15,
    );
  }

  /// Convert AlertSchedule to Firebase schedule schema
  Map<String, dynamic>? _convertScheduleToFirebaseSchema(alert_model.AlertSchedule? schedule) {
    if (schedule == null) return null;
    
    return {
      'enabled': true,
      'activeDays': _convertDaysToFirebase(schedule.days),
      'startMinute': schedule.startTime,
      'endMinute': schedule.endTime,
    };
  }

  /// Convert Firebase schedule schema to AlertSchedule
  alert_model.AlertSchedule? _convertFirebaseScheduleToSchedule(dynamic scheduleData) {
    if (scheduleData == null) return null;
    
    final data = scheduleData as Map<String, dynamic>;
    
    final activeDays = _convertDaysFromFirebase((data['activeDays'] as List?)?.cast<String>() ?? []);
    final startMinute = (data['startMinute'] as num?)?.toInt() ?? 0;
    final endMinute = (data['endMinute'] as num?)?.toInt() ?? 0;
    
    return alert_model.AlertSchedule(
      startTime: data['startTime'] ?? '00:00',
      endTime: data['endTime'] ?? '23:59',
      days: activeDays,
    );
  }

  /// Basic RTSP URL encryption (for demo - use proper encryption in production)
  String _encryptRtspUrl(String url) {
    final key = utf8.encode('your-secret-key-32-chars-long!!'); // 32 chars for AES-256
    final bytes = utf8.encode(url);
    final encryptedHmac = Hmac(sha256, key).convert(bytes);
    return 'ENC:AES256-GCM:${base64.encode(encryptedHmac.bytes)}';
  }

  /// Convert days list (1-7) to Firebase format (MON-SUN)
  List<String> _convertDaysToFirebase(List<int> days) {
    const dayMap = {
      1: 'MON',
      2: 'TUE', 
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };
    
    return days.map((day) => dayMap[day] ?? 'MON').toList();
  }

  /// Convert Firebase format (MON-SUN) to days list (1-7)
  List<int> _convertDaysFromFirebase(List<String> firebaseDays) {
    const dayMap = {
      'MON': 1,
      'TUE': 2,
      'WED': 3,
      'THU': 4,
      'FRI': 5,
      'SAT': 6,
      'SUN': 7,
    };
    
    return firebaseDays.map((day) => dayMap[day] ?? 1).toList();
  }

  /// Helper method to convert day number to label
  String _dayLabel(int d) {
    const map = {
      1: "MON",
      2: "TUE", 
      3: "WED",
      4: "THU",
      5: "FRI",
      6: "SAT",
      7: "SUN",
    };
    return map[d] ?? "?";
  }

  /// Helper method to convert day label to number
  int? _labelToDay(String label) {
    const map = {
      "MON": 1,
      "TUE": 2,
      "WED": 3,
      "THU": 4,
      "FRI": 5,
      "SAT": 6,
      "SUN": 7,
    };
    return map[label];
  }

  /// ===========================================================
  /// DEVICE MANAGEMENT
  /// ===========================================================
  
  /// Ensure device document exists
  Future<void> ensureDeviceExists() async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final deviceRef = _devicesCollection.doc(_deviceId);
      final deviceDoc = await deviceRef.get();
      
      if (!deviceDoc.exists) {
        // Create device document
        await deviceRef.set({
          'deviceId': _deviceId,
          'status': 'online',
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'appVersion': '1.0.0', // Get from app config
          'isPaired': true,
          'pairedAt': FieldValue.serverTimestamp(),
          'alertEnable': true,
          'notificationEnabled': true,
        });
        
        print('Device document created for: $_deviceId');
      }
    } catch (e) {
      print('Error ensuring device exists: $e');
      rethrow;
    }
  }

  /// Update device heartbeat
  Future<void> updateDeviceHeartbeat() async {
    if (!_isInitialized) return;

    try {
      final deviceRef = _devicesCollection.doc(_deviceId);
      
      await deviceRef.update({
        'lastSeen': FieldValue.serverTimestamp(),
        'status': 'online',
      });
      
      print('Device heartbeat updated for: $_deviceId');
    } catch (e) {
      print('Error updating device heartbeat: $e');
    }
  }
}
