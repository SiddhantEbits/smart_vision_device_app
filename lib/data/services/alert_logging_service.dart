import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/firestore_models.dart';
import '../repositories/local_storage_service.dart';
import '../services/device_management_service.dart';

/// ===========================================================
/// ALERT LOGGING SERVICE
/// Handles real-time alert logging and synchronization with Firebase
/// ===========================================================
class AlertLoggingService {
  static AlertLoggingService? _instance;
  static AlertLoggingService get instance => _instance ??= AlertLoggingService._();
  
  AlertLoggingService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final DeviceManagementService _deviceService;
  late final CollectionReference<AlertLog> _alertLogsCollection;
  
  // Local cache for offline support
  final List<AlertLog> _localAlerts = [];
  final Map<String, AlertLog> _pendingAlerts = {};
  
  // Stream controllers
  final StreamController<AlertEvent> _eventController = StreamController<AlertEvent>.broadcast();
  final StreamController<List<AlertLog>> _alertsController = StreamController<List<AlertLog>>.broadcast();
  
  // State
  bool _isInitialized = false;
  bool _isOnline = false;
  Timer? _syncTimer;
  Timer? _cleanupTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  List<AlertLog> get localAlerts => List.unmodifiable(_localAlerts);
  Stream<AlertEvent> get events => _eventController.stream;
  Stream<List<AlertLog>> get alerts => _alertsController.stream;

  /// ===========================================================
  /// INITIALIZATION
  /// ===========================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      _localStorage = LocalStorageService.instance;
      _deviceService = DeviceManagementService.instance;
      
      // Setup collection reference
      _alertLogsCollection = _firestore
          .collection('alertLogs')
          .withConverter<AlertLog>(
            fromFirestore: AlertLog.fromFirestore,
            toFirestore: (alert, options) => alert.toFirestore(),
          );

      // Load cached alerts
      await _loadCachedAlerts();
      
      // Setup device status listener
      _setupDeviceStatusListener();
      
      // Start sync timer
      _startSyncTimer();
      
      // Start cleanup timer
      _startCleanupTimer();
      
      _isInitialized = true;
      _isOnline = _deviceService.isOnline;
      
      debugPrint('🚨 Alert Logging Service initialized');
      _eventController.add(AlertEvent(AlertEventType.initialized, 'Alert service initialized'));
      
    } catch (e) {
      debugPrint('❌ Error initializing Alert Logging Service: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Initialization failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// ALERT LOGGING
  /// ===========================================================
  Future<void> logAlert({
    required String cameraId,
    required String cameraName,
    required String algorithmType,
    required String message,
    int? currentCount,
    String? imageUrl,
    List<String> sentTo = const [],
  }) async {
    if (!_isInitialized) return;

    try {
      final deviceId = _deviceService.deviceId;
      final deviceName = _deviceService.currentDevice?.deviceName ?? 'Unknown Device';
      final now = Timestamp.now();
      
      final alert = AlertLog(
        deviceId: deviceId,
        deviceName: deviceName,
        cameraId: cameraId,
        camName: cameraName,
        algorithmType: algorithmType,
        alertTime: now,
        createdAt: now,
        message: message,
        currentCount: currentCount,
        imgUrl: imageUrl,
        sentTo: sentTo,
      );

      // Add to local cache
      _localAlerts.insert(0, alert);
      if (_localAlerts.length > 1000) {
        _localAlerts.removeLast(); // Keep only last 1000 alerts
      }
      
      // Broadcast update
      _alertsController.add(List.unmodifiable(_localAlerts));

      if (_isOnline) {
        // Send to Firebase immediately
        await _sendAlertToFirebase(alert);
      } else {
        // Queue for later sync
        final documentId = AlertLog.generateDocumentId(
          deviceId: deviceId,
          cameraId: cameraId,
          algorithmType: algorithmType,
          timestamp: now,
        );
        _pendingAlerts[documentId] = alert;
        
        debugPrint('📴 Alert queued for sync: $message');
        _eventController.add(AlertEvent(AlertEventType.queued, 'Alert queued: $message'));
      }

      debugPrint('🚨 Alert logged: $message');
      _eventController.add(AlertEvent(AlertEventType.logged, 'Alert logged: $message'));
      
    } catch (e) {
      debugPrint('❌ Error logging alert: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Log failed: $e'));
    }
  }

  /// ===========================================================
  /// FIREBASE SYNC
  /// ===========================================================
  Future<void> _sendAlertToFirebase(AlertLog alert) async {
    try {
      final documentId = AlertLog.generateDocumentId(
        deviceId: alert.deviceId,
        cameraId: alert.cameraId,
        algorithmType: alert.algorithmType,
        timestamp: alert.alertTime,
      );

      await _alertLogsCollection.doc(documentId).set(alert);
      
      // Remove from pending if it was there
      _pendingAlerts.remove(documentId);
      
      debugPrint('☁️ Alert synced to Firebase: ${alert.message}');
      _eventController.add(AlertEvent(AlertEventType.synced, 'Alert synced: ${alert.message}'));
      
    } catch (e) {
      debugPrint('❌ Failed to sync alert to Firebase: $e');
      
      // Re-queue for later
      final documentId = AlertLog.generateDocumentId(
        deviceId: alert.deviceId,
        cameraId: alert.cameraId,
        algorithmType: alert.algorithmType,
        timestamp: alert.alertTime,
      );
      _pendingAlerts[documentId] = alert;
      
      _eventController.add(AlertEvent(AlertEventType.error, 'Sync failed: $e'));
    }
  }

  Future<void> syncPendingAlerts() async {
    if (!_isOnline || _pendingAlerts.isEmpty) return;

    debugPrint('🔄 Syncing ${_pendingAlerts.length} pending alerts...');
    
    final alertsToSync = Map<String, AlertLog>.from(_pendingAlerts);
    
    for (final entry in alertsToSync.entries) {
      try {
        await _sendAlertToFirebase(entry.value);
      } catch (e) {
        debugPrint('❌ Failed to sync alert ${entry.key}: $e');
      }
    }
    
    debugPrint('✅ Alert sync completed. Pending: ${_pendingAlerts.length}');
    _eventController.add(AlertEvent(AlertEventType.syncCompleted, 'Sync completed: ${_pendingAlerts.length} pending'));
  }

  /// ===========================================================
  /// ALERT MANAGEMENT
  /// ===========================================================
  Future<void> markAlertAsRead(String documentId) async {
    try {
      // Update local cache
      final alertIndex = _localAlerts.indexWhere(
        (alert) => AlertLog.generateDocumentId(
          deviceId: alert.deviceId,
          cameraId: alert.cameraId,
          algorithmType: alert.algorithmType,
          timestamp: alert.alertTime,
        ) == documentId,
      );
      
      if (alertIndex != -1) {
        final updatedAlert = _localAlerts[alertIndex].copyWith(isRead: true);
        _localAlerts[alertIndex] = updatedAlert;
        _alertsController.add(List.unmodifiable(_localAlerts));
      }

      // Update Firebase if online
      if (_isOnline) {
        await _alertLogsCollection.doc(documentId).update({'isRead': true});
      }
      
      debugPrint('📖 Alert marked as read: $documentId');
      _eventController.add(AlertEvent(AlertEventType.updated, 'Alert marked as read'));
      
    } catch (e) {
      debugPrint('❌ Failed to mark alert as read: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Update failed: $e'));
    }
  }

  Future<void> markAllAlertsAsRead() async {
    try {
      // Update local cache
      for (int i = 0; i < _localAlerts.length; i++) {
        _localAlerts[i] = _localAlerts[i].copyWith(isRead: true);
      }
      _alertsController.add(List.unmodifiable(_localAlerts));

      // Update Firebase if online
      if (_isOnline) {
        final batch = _firestore.batch();
        for (final alert in _localAlerts) {
          final documentId = AlertLog.generateDocumentId(
            deviceId: alert.deviceId,
            cameraId: alert.cameraId,
            algorithmType: alert.algorithmType,
            timestamp: alert.alertTime,
          );
          batch.update(_alertLogsCollection.doc(documentId), {'isRead': true});
        }
        await batch.commit();
      }
      
      debugPrint('📖 All alerts marked as read');
      _eventController.add(AlertEvent(AlertEventType.updated, 'All alerts marked as read'));
      
    } catch (e) {
      debugPrint('❌ Failed to mark all alerts as read: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Batch update failed: $e'));
    }
  }

  Future<void> deleteAlert(String documentId) async {
    try {
      // Remove from local cache
      _localAlerts.removeWhere(
        (alert) => AlertLog.generateDocumentId(
          deviceId: alert.deviceId,
          cameraId: alert.cameraId,
          algorithmType: alert.algorithmType,
          timestamp: alert.alertTime,
        ) == documentId,
      );
      _alertsController.add(List.unmodifiable(_localAlerts));

      // Remove from pending
      _pendingAlerts.remove(documentId);

      // Delete from Firebase if online
      if (_isOnline) {
        await _alertLogsCollection.doc(documentId).delete();
      }
      
      debugPrint('🗑️ Alert deleted: $documentId');
      _eventController.add(AlertEvent(AlertEventType.deleted, 'Alert deleted'));
      
    } catch (e) {
      debugPrint('❌ Failed to delete alert: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Delete failed: $e'));
    }
  }

  Future<void> clearAllAlerts() async {
    try {
      // Clear local cache
      _localAlerts.clear();
      _pendingAlerts.clear();
      _alertsController.add(const []);

      // Delete from Firebase if online
      if (_isOnline) {
        final deviceId = _deviceService.deviceId;
        final snapshot = await _alertLogsCollection
            .where('deviceId', isEqualTo: deviceId)
            .get();
        
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      debugPrint('🗑️ All alerts cleared');
      _eventController.add(AlertEvent(AlertEventType.cleared, 'All alerts cleared'));
      
    } catch (e) {
      debugPrint('❌ Failed to clear alerts: $e');
      _eventController.add(AlertEvent(AlertEventType.error, 'Clear failed: $e'));
    }
  }

  /// ===========================================================
  /// QUERY METHODS
  /// ===========================================================
  Stream<List<AlertLog>> getAlertsForCamera(String cameraId) {
    return _alertsController.stream.map(
      (alerts) => alerts.where((alert) => alert.cameraId == cameraId).toList(),
    );
  }

  Stream<List<AlertLog>> getAlertsForAlgorithm(String algorithmType) {
    return _alertsController.stream.map(
      (alerts) => alerts.where((alert) => alert.algorithmType == algorithmType).toList(),
    );
  }

  Stream<List<AlertLog>> getUnreadAlerts() {
    return _alertsController.stream.map(
      (alerts) => alerts.where((alert) => !alert.isRead).toList(),
    );
  }

  List<AlertLog> getAlertsInRange(DateTime start, DateTime end) {
    return _localAlerts.where((alert) {
      final alertTime = alert.alertTime.toDate();
      return alertTime.isAfter(start) && alertTime.isBefore(end);
    }).toList();
  }

  /// ===========================================================
  /// DEVICE STATUS LISTENER
  /// ===========================================================
  void _setupDeviceStatusListener() {
    _deviceService.events.listen((event) {
      if (event.type == DeviceEventType.statusChanged) {
        _isOnline = _deviceService.isOnline;
        
        if (_isOnline && _pendingAlerts.isNotEmpty) {
          // Sync pending alerts when coming back online
          Future.delayed(const Duration(seconds: 2), () {
            syncPendingAlerts();
          });
        }
      }
    });
  }

  /// ===========================================================
  /// TIMERS
  /// ===========================================================
  void _startSyncTimer() {
    // Sync pending alerts every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _pendingAlerts.isNotEmpty) {
        syncPendingAlerts();
      }
    });
  }

  void _startCleanupTimer() {
    // Clean up old alerts every hour (Firebase TTL handles this, but we'll clean local cache)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldAlerts();
    });
  }

  void _cleanupOldAlerts() {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final initialCount = _localAlerts.length;
    
    _localAlerts.removeWhere(
      (alert) => alert.alertTime.toDate().isBefore(cutoff),
    );
    
    if (_localAlerts.length != initialCount) {
      _alertsController.add(List.unmodifiable(_localAlerts));
      debugPrint('🧹 Cleaned up ${initialCount - _localAlerts.length} old alerts');
    }
  }

  /// ===========================================================
  /// LOCAL STORAGE
  /// ===========================================================
  Future<void> _loadCachedAlerts() async {
    try {
      // Load cached alerts from local storage
      final cachedData = _localStorage.storage.read('cached_alerts') as List<dynamic>? ?? [];
      
      for (final alertData in cachedData) {
        try {
          final alert = _alertFromJson(alertData as Map<String, dynamic>);
          _localAlerts.add(alert);
        } catch (e) {
          debugPrint('⚠️ Failed to parse cached alert: $e');
        }
      }
      
      // Sort by alert time (newest first)
      _localAlerts.sort((a, b) => b.alertTime.compareTo(a.alertTime));
      
      debugPrint('📂 Loaded ${_localAlerts.length} cached alerts');
      
    } catch (e) {
      debugPrint('⚠️ Failed to load cached alerts: $e');
    }
  }

  Future<void> _saveCachedAlerts() async {
    try {
      final alertsData = _localAlerts.map(_alertToJson).toList();
      await _localStorage.storage.write('cached_alerts', alertsData);
    } catch (e) {
      debugPrint('⚠️ Failed to save cached alerts: $e');
    }
  }

  AlertLog _alertFromJson(Map<String, dynamic> json) {
    return AlertLog(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      cameraId: json['cameraId'],
      camName: json['camName'],
      algorithmType: json['algorithmType'],
      alertTime: Timestamp.fromMillisecondsSinceEpoch(json['alertTime']),
      createdAt: Timestamp.fromMillisecondsSinceEpoch(json['createdAt']),
      message: json['message'],
      currentCount: json['currentCount'],
      imgUrl: json['imgUrl'],
      isRead: json['isRead'] ?? false,
      sentTo: List<String>.from(json['sentTo'] ?? []),
    );
  }

  Map<String, dynamic> _alertToJson(AlertLog alert) {
    return {
      'deviceId': alert.deviceId,
      'deviceName': alert.deviceName,
      'cameraId': alert.cameraId,
      'camName': alert.camName,
      'algorithmType': alert.algorithmType,
      'alertTime': alert.alertTime.millisecondsSinceEpoch,
      'createdAt': alert.createdAt.millisecondsSinceEpoch,
      'message': alert.message,
      'currentCount': alert.currentCount,
      'imgUrl': alert.imgUrl,
      'isRead': alert.isRead,
      'sentTo': alert.sentTo,
    };
  }

  /// ===========================================================
  /// DISPOSAL
  /// ===========================================================
  Future<void> dispose() async {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    await _eventController.close();
    await _alertsController.close();
    
    // Save cached alerts
    await _saveCachedAlerts();
    
    _isInitialized = false;
    
    debugPrint('🚨 Alert Logging Service disposed');
  }
}

/// ===========================================================
/// ALERT EVENT MODEL
/// ===========================================================
class AlertEvent {
  final AlertEventType type;
  final String message;
  final DateTime timestamp;

  AlertEvent(this.type, this.message) : timestamp = DateTime.now();

  @override
  String toString() => 'AlertEvent($type, $message, $timestamp)';
}

enum AlertEventType {
  initialized,
  logged,
  queued,
  synced,
  syncCompleted,
  updated,
  deleted,
  cleared,
  error,
}
