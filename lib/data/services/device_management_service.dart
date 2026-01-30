import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/firestore_models.dart';
import '../repositories/local_storage_service.dart';

/// ===========================================================
/// DEVICE MANAGEMENT SERVICE
/// Handles device heartbeat, status management, and device lifecycle
/// ===========================================================
class DeviceManagementService {
  static DeviceManagementService? _instance;
  static DeviceManagementService get instance => _instance ??= DeviceManagementService._();
  
  DeviceManagementService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final CollectionReference<FirestoreDevice> _devicesCollection;
  
  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot<FirestoreDevice>>? _deviceSubscription;
  final StreamController<DeviceEvent> _eventController = StreamController<DeviceEvent>.broadcast();
  
  // Device state
  FirestoreDevice? _currentDevice;
  String? _deviceId;
  bool _isInitialized = false;
  bool _isOnline = false;

  // Getters
  FirestoreDevice? get currentDevice => _currentDevice;
  String get deviceId => _deviceId ?? '';
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  Stream<DeviceEvent> get events => _eventController.stream;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      _localStorage = LocalStorageService.instance;
      
      // Get device ID from local storage
      _deviceId = _localStorage.deviceId;
      
      // Setup collection reference
      _devicesCollection = _firestore
          .collection('devices')
          .withConverter<FirestoreDevice>(
            fromFirestore: FirestoreDevice.fromFirestore,
            toFirestore: (device, options) => device.toFirestore(),
          );

      // Initialize device document
      await _initializeDevice();
      
      // Setup real-time listener
      _setupDeviceListener();
      
      // Start heartbeat timer
      _startHeartbeatTimer();
      
      _isInitialized = true;
      _isOnline = true;
      
      debugPrint('📱 Device Management Service initialized for device: $_deviceId');
      _eventController.add(DeviceEvent(DeviceEventType.initialized, 'Device service initialized'));
      
    } catch (e) {
      debugPrint('❌ Error initializing Device Management Service: $e');
      _eventController.add(DeviceEvent(DeviceEventType.error, 'Initialization failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// DEVICE INITIALIZATION
  /// ===========================================================
  Future<void> _initializeDevice() async {
    try {
      final deviceDoc = await _devicesCollection.doc(_deviceId).get();
      
      if (deviceDoc.exists) {
        _currentDevice = deviceDoc.data();
        debugPrint('📱 Existing device found: ${_currentDevice!.deviceName}');
        
        // Update device status to online
        await _updateDeviceStatus(DeviceStatus.online);
      } else {
        // Create new device document
        _currentDevice = await _createNewDevice();
        debugPrint('📱 New device created: ${_currentDevice!.deviceName}');
      }
      
      // Save device info to local storage
      await _localStorage.updateSyncMetadata({
        'deviceId': _deviceId,
        'deviceName': _currentDevice!.deviceName ?? 'Unknown Device',
        'lastHeartbeat': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      debugPrint('❌ Error initializing device: $e');
      rethrow;
    }
  }

  Future<FirestoreDevice> _createNewDevice() async {
    final now = Timestamp.now();
    final device = FirestoreDevice(
      deviceId: _deviceId!,
      status: DeviceStatus.online,
      lastSeen: now,
      createdAt: now,
      deviceName: _getDeviceName(),
      appVersion: _getAppVersion(),
    );

    await _devicesCollection.doc(_deviceId).set(device);
    return device;
  }

  /// ===========================================================
  /// HEARTBEAT MANAGEMENT
  /// ===========================================================
  void _startHeartbeatTimer() {
    // Send heartbeat every 30 minutes (minimum requirement: every hour)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _sendHeartbeat();
    });
    
    // Send initial heartbeat
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    if (!_isInitialized || _currentDevice == null) return;

    try {
      final updatedDevice = _currentDevice!.updateHeartbeat();
      await _devicesCollection.doc(_deviceId).update(updatedDevice.toFirestore());
      
      _currentDevice = updatedDevice;
      _isOnline = true;
      
      debugPrint('💓 Heartbeat sent for device: $_deviceId');
      _eventController.add(DeviceEvent(DeviceEventType.heartbeat, 'Heartbeat sent'));
      
    } catch (e) {
      debugPrint('❌ Failed to send heartbeat: $e');
      _isOnline = false;
      _eventController.add(DeviceEvent(DeviceEventType.error, 'Heartbeat failed: $e'));
    }
  }

  /// ===========================================================
  /// STATUS MANAGEMENT
  /// ===========================================================
  Future<void> _updateDeviceStatus(DeviceStatus status) async {
    if (_currentDevice == null) return;

    try {
      final updatedDevice = _currentDevice!.copyWith(
        status: status,
        lastSeen: Timestamp.now(),
      );

      await _devicesCollection.doc(_deviceId).update(updatedDevice.toFirestore());
      _currentDevice = updatedDevice;
      
      debugPrint('📱 Device status updated to: ${status.value}');
      _eventController.add(DeviceEvent(DeviceEventType.statusChanged, 'Status: ${status.value}'));
      
    } catch (e) {
      debugPrint('❌ Failed to update device status: $e');
    }
  }

  Future<void> setMaintenanceMode(bool enabled) async {
    if (_currentDevice == null) return;

    try {
      final updatedDevice = _currentDevice!.copyWith(maintenanceMode: enabled);
      await _devicesCollection.doc(_deviceId).update(updatedDevice.toFirestore());
      _currentDevice = updatedDevice;
      
      debugPrint('🔧 Maintenance mode: ${enabled ? 'ON' : 'OFF'}');
      _eventController.add(DeviceEvent(DeviceEventType.maintenanceMode, 'Maintenance mode: ${enabled ? 'ON' : 'OFF'}'));
      
    } catch (e) {
      debugPrint('❌ Failed to set maintenance mode: $e');
    }
  }

  Future<void> triggerHardRestart() async {
    if (_currentDevice == null) return;

    try {
      // Set hard restart flag
      await _devicesCollection.doc(_deviceId).update({'hardRestart': true});
      
      debugPrint('🔄 Hard restart triggered for device: $_deviceId');
      _eventController.add(DeviceEvent(DeviceEventType.hardRestart, 'Hard restart triggered'));
      
      // In a real implementation, this would trigger a device restart
      // For now, we'll just clear the flag after a delay
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          await _devicesCollection.doc(_deviceId).update({'hardRestart': false});
        } catch (e) {
          debugPrint('❌ Failed to clear hard restart flag: $e');
        }
      });
      
    } catch (e) {
      debugPrint('❌ Failed to trigger hard restart: $e');
    }
  }

  /// ===========================================================
  /// PAIRING MANAGEMENT
  /// ===========================================================
  Future<void> pairDevice(String userId, String pairedBy) async {
    if (_currentDevice == null) return;

    try {
      final now = Timestamp.now();
      final updatedDevice = _currentDevice!.copyWith(
        pairedUserId: userId,
        isPaired: true,
        pairedAt: now,
        pairedBy: pairedBy,
      );

      await _devicesCollection.doc(_deviceId).update(updatedDevice.toFirestore());
      _currentDevice = updatedDevice;
      
      debugPrint('🔗 Device paired with user: $userId');
      _eventController.add(DeviceEvent(DeviceEventType.paired, 'Device paired with user: $userId'));
      
    } catch (e) {
      debugPrint('❌ Failed to pair device: $e');
    }
  }

  Future<void> unpairDevice() async {
    if (_currentDevice == null) return;

    try {
      final updatedDevice = _currentDevice!.copyWith(
        pairedUserId: null,
        isPaired: false,
        pairedAt: null,
        pairedBy: null,
      );

      await _devicesCollection.doc(_deviceId).update(updatedDevice.toFirestore());
      _currentDevice = updatedDevice;
      
      debugPrint('🔓 Device unpaired');
      _eventController.add(DeviceEvent(DeviceEventType.unpaired, 'Device unpaired'));
      
    } catch (e) {
      debugPrint('❌ Failed to unpair device: $e');
    }
  }

  /// ===========================================================
  /// NOTIFICATION SETTINGS
  /// ===========================================================
  Future<void> updateNotificationSettings({
    bool? alertEnable,
    bool? notificationEnabled,
    String? fcmToken,
  }) async {
    if (_currentDevice == null) return;

    try {
      final updates = <String, dynamic>{};
      
      if (alertEnable != null) updates['alertEnable'] = alertEnable;
      if (notificationEnabled != null) updates['notificationEnabled'] = notificationEnabled;
      if (fcmToken != null) {
        updates['fcmToken'] = fcmToken;
        updates['fcmTokenUpdatedAt'] = Timestamp.now();
      }

      await _devicesCollection.doc(_deviceId).update(updates);
      
      // Refresh current device
      final updatedDoc = await _devicesCollection.doc(_deviceId).get();
      _currentDevice = updatedDoc.data();
      
      debugPrint('🔔 Notification settings updated');
      _eventController.add(DeviceEvent(DeviceEventType.settingsUpdated, 'Notification settings updated'));
      
    } catch (e) {
      debugPrint('❌ Failed to update notification settings: $e');
    }
  }

  Future<void> updateWhatsAppSettings({
    bool? alertEnable,
    List<String>? phoneNumbers,
  }) async {
    if (_currentDevice == null) return;

    try {
      final whatsappConfig = WhatsAppConfig(
        alertEnable: alertEnable ?? _currentDevice!.whatsapp.alertEnable,
        phoneNumbers: phoneNumbers ?? _currentDevice!.whatsapp.phoneNumbers,
      );

      await _devicesCollection.doc(_deviceId).update({
        'whatsapp': whatsappConfig.toMap(),
      });
      
      // Refresh current device
      final updatedDoc = await _devicesCollection.doc(_deviceId).get();
      _currentDevice = updatedDoc.data();
      
      debugPrint('📱 WhatsApp settings updated');
      _eventController.add(DeviceEvent(DeviceEventType.settingsUpdated, 'WhatsApp settings updated'));
      
    } catch (e) {
      debugPrint('❌ Failed to update WhatsApp settings: $e');
    }
  }

  /// ===========================================================
  /// REAL-TIME LISTENER
  /// ===========================================================
  void _setupDeviceListener() {
    _deviceSubscription = _devicesCollection
        .doc(_deviceId)
        .snapshots()
        .listen(
          (snapshot) => _handleDeviceUpdate(snapshot),
          onError: (error) {
            debugPrint('❌ Device listener error: $error');
            _eventController.add(DeviceEvent(DeviceEventType.error, 'Listener error: $error'));
          },
        );
  }

  void _handleDeviceUpdate(DocumentSnapshot<FirestoreDevice> snapshot) {
    if (!snapshot.exists) return;

    final updatedDevice = snapshot.data();
    if (updatedDevice == null) return;

    final previousStatus = _currentDevice?.status;
    _currentDevice = updatedDevice;

    // Check for status changes
    if (previousStatus != updatedDevice.status) {
      debugPrint('📱 Device status changed: ${previousStatus?.value} → ${updatedDevice.status.value}');
      _eventController.add(DeviceEvent(
        DeviceEventType.statusChanged,
        'Status: ${updatedDevice.status.value}',
      ));
    }

    // Check for hard restart flag
    if (updatedDevice.hardRestart && _currentDevice?.hardRestart != updatedDevice.hardRestart) {
      debugPrint('🔄 Hard restart requested from server');
      _eventController.add(DeviceEvent(DeviceEventType.hardRestart, 'Hard restart requested'));
      // Handle restart logic here
    }
  }

  /// ===========================================================
  /// UTILITY METHODS
  /// ===========================================================
  String _getDeviceName() {
    // In a real implementation, this would get the actual device name
    // For now, return a default name based on device ID
    return 'Smart Vision Device ${_deviceId?.substring(0, 8).toUpperCase()}';
  }

  String _getAppVersion() {
    // In a real implementation, this would get the actual app version
    return '1.0.0';
  }

  /// ===========================================================
  /// DISPOSAL
  /// ===========================================================
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await _deviceSubscription?.cancel();
    await _eventController.close();
    
    _isInitialized = false;
    _isOnline = false;
    
    debugPrint('📱 Device Management Service disposed');
  }
}

/// ===========================================================
/// DEVICE EVENT MODEL
/// ===========================================================
class DeviceEvent {
  final DeviceEventType type;
  final String message;
  final DateTime timestamp;

  DeviceEvent(this.type, this.message) : timestamp = DateTime.now();

  @override
  String toString() => 'DeviceEvent($type, $message, $timestamp)';
}

enum DeviceEventType {
  initialized,
  heartbeat,
  statusChanged,
  maintenanceMode,
  hardRestart,
  paired,
  unpaired,
  settingsUpdated,
  error,
}
