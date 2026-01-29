import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/firestore_models.dart';
import '../repositories/local_storage_service.dart';
import '../services/device_management_service.dart';

/// ===========================================================
/// ERROR LOGGING SERVICE
/// Handles real-time error and crash logging with Firebase synchronization
/// ===========================================================
class ErrorLoggingService {
  static ErrorLoggingService? _instance;
  static ErrorLoggingService get instance => _instance ??= ErrorLoggingService._();
  
  ErrorLoggingService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final DeviceManagementService _deviceService;
  late final CollectionReference<ErrorLog> _errorLogsCollection;
  
  // Local cache for offline support
  final List<ErrorLog> _localErrors = [];
  final Map<String, ErrorLog> _pendingErrors = {};
  
  // Stream controllers
  final StreamController<ErrorEvent> _eventController = StreamController<ErrorEvent>.broadcast();
  final StreamController<List<ErrorLog>> _errorsController = StreamController<List<ErrorLog>>.broadcast();
  
  // State
  bool _isInitialized = false;
  bool _isOnline = false;
  Timer? _syncTimer;
  Timer? _cleanupTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  List<ErrorLog> get localErrors => List.unmodifiable(_localErrors);
  Stream<ErrorEvent> get events => _eventController.stream;
  Stream<List<ErrorLog>> get errors => _errorsController.stream;

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
      _errorLogsCollection = _firestore
          .collection('errorLogs')
          .withConverter<ErrorLog>(
            fromFirestore: ErrorLog.fromFirestore,
            toFirestore: (error, options) => error.toFirestore(),
          );

      // Load cached errors
      await _loadCachedErrors();
      
      // Setup device status listener
      _setupDeviceStatusListener();
      
      // Setup global error handlers
      _setupGlobalErrorHandlers();
      
      // Start sync timer
      _startSyncTimer();
      
      // Start cleanup timer
      _startCleanupTimer();
      
      _isInitialized = true;
      _isOnline = _deviceService.isOnline;
      
      debugPrint('🚨 Error Logging Service initialized');
      _eventController.add(ErrorEvent(ErrorEventType.initialized, 'Error service initialized'));
      
    } catch (e) {
      debugPrint('❌ Error initializing Error Logging Service: $e');
      _eventController.add(ErrorEvent(ErrorEventType.error, 'Initialization failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// ERROR LOGGING METHODS
  /// ===========================================================
  Future<void> logError({
    required String errorType,
    required String message,
    String cameraId = 'system',
    ErrorSeverity severity = ErrorSeverity.error,
    StackTrace? stackTrace,
  }) async {
    if (!_isInitialized) return;

    try {
      final deviceId = _deviceService.deviceId;
      final now = Timestamp.now();
      
      final fullMessage = stackTrace != null 
          ? '$message\n\nStack Trace:\n${stackTrace.toString()}'
          : message;
      
      final error = ErrorLog(
        deviceId: deviceId,
        cameraId: cameraId,
        errorType: errorType,
        severity: severity,
        message: fullMessage,
        timestamp: now,
        createdAt: now,
      );

      // Add to local cache
      _localErrors.insert(0, error);
      if (_localErrors.length > 1000) {
        _localErrors.removeLast(); // Keep only last 1000 errors
      }
      
      // Broadcast update
      _errorsController.add(List.unmodifiable(_localErrors));

      if (_isOnline) {
        // Send to Firebase immediately
        await _sendErrorToFirebase(error);
      } else {
        // Queue for later sync
        final documentId = ErrorLog.generateDocumentId(
          deviceId: deviceId,
          cameraId: cameraId,
          timestamp: now,
        );
        _pendingErrors[documentId] = error;
        
        debugPrint('📴 Error queued for sync: $errorType');
        _eventController.add(ErrorEvent(ErrorEventType.queued, 'Error queued: $errorType'));
      }

      debugPrint('🚨 Error logged: $errorType - $message');
      _eventController.add(ErrorEvent(ErrorEventType.logged, 'Error logged: $errorType'));
      
    } catch (e) {
      debugPrint('❌ Error logging error: $e');
      _eventController.add(ErrorEvent(ErrorEventType.error, 'Log failed: $e'));
    }
  }

  /// Convenience methods for different error types
  Future<void> logInfo(String message, {String cameraId = 'system'}) async {
    await logError(
      errorType: 'INFO',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.info,
    );
  }

  Future<void> logWarning(String message, {String cameraId = 'system'}) async {
    await logError(
      errorType: 'WARNING',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.warn,
    );
  }

  Future<void> logCrash(String message, {String cameraId = 'system', StackTrace? stackTrace}) async {
    await logError(
      errorType: 'CRASH',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.error,
      stackTrace: stackTrace,
    );
  }

  Future<void> logRTSPError(String message, String cameraId) async {
    await logError(
      errorType: 'RTSP_ERROR',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.error,
    );
  }

  Future<void> logYOLOError(String message, String cameraId) async {
    await logError(
      errorType: 'YOLO_ERROR',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.error,
    );
  }

  Future<void> logNetworkError(String message, {String cameraId = 'system'}) async {
    await logError(
      errorType: 'NETWORK_ERROR',
      message: message,
      cameraId: cameraId,
      severity: ErrorSeverity.warn,
    );
  }

  Future<void> logFirebaseError(String message) async {
    await logError(
      errorType: 'FIREBASE_ERROR',
      message: message,
      cameraId: 'system',
      severity: ErrorSeverity.error,
    );
  }

  /// ===========================================================
  /// FIREBASE SYNC
  /// ===========================================================
  Future<void> _sendErrorToFirebase(ErrorLog error) async {
    try {
      final documentId = ErrorLog.generateDocumentId(
        deviceId: error.deviceId,
        cameraId: error.cameraId,
        timestamp: error.timestamp,
      );

      await _errorLogsCollection.doc(documentId).set(error);
      
      // Remove from pending if it was there
      _pendingErrors.remove(documentId);
      
      debugPrint('☁️ Error synced to Firebase: ${error.errorType}');
      _eventController.add(ErrorEvent(ErrorEventType.synced, 'Error synced: ${error.errorType}'));
      
    } catch (e) {
      debugPrint('❌ Failed to sync error to Firebase: $e');
      
      // Re-queue for later
      final documentId = ErrorLog.generateDocumentId(
        deviceId: error.deviceId,
        cameraId: error.cameraId,
        timestamp: error.timestamp,
      );
      _pendingErrors[documentId] = error;
      
      _eventController.add(ErrorEvent(ErrorEventType.error, 'Sync failed: $e'));
    }
  }

  Future<void> syncPendingErrors() async {
    if (!_isOnline || _pendingErrors.isEmpty) return;

    debugPrint('🔄 Syncing ${_pendingErrors.length} pending errors...');
    
    final errorsToSync = Map<String, ErrorLog>.from(_pendingErrors);
    
    for (final entry in errorsToSync.entries) {
      try {
        await _sendErrorToFirebase(entry.value);
      } catch (e) {
        debugPrint('❌ Failed to sync error ${entry.key}: $e');
      }
    }
    
    debugPrint('✅ Error sync completed. Pending: ${_pendingErrors.length}');
    _eventController.add(ErrorEvent(ErrorEventType.syncCompleted, 'Sync completed: ${_pendingErrors.length} pending'));
  }

  /// ===========================================================
  /// ERROR MANAGEMENT
  /// ===========================================================
  Future<void> deleteError(String documentId) async {
    try {
      // Remove from local cache
      _localErrors.removeWhere(
        (error) => ErrorLog.generateDocumentId(
          deviceId: error.deviceId,
          cameraId: error.cameraId,
          timestamp: error.timestamp,
        ) == documentId,
      );
      _errorsController.add(List.unmodifiable(_localErrors));

      // Remove from pending
      _pendingErrors.remove(documentId);

      // Delete from Firebase if online
      if (_isOnline) {
        await _errorLogsCollection.doc(documentId).delete();
      }
      
      debugPrint('🗑️ Error deleted: $documentId');
      _eventController.add(ErrorEvent(ErrorEventType.deleted, 'Error deleted'));
      
    } catch (e) {
      debugPrint('❌ Failed to delete error: $e');
      _eventController.add(ErrorEvent(ErrorEventType.error, 'Delete failed: $e'));
    }
  }

  Future<void> clearAllErrors() async {
    try {
      // Clear local cache
      _localErrors.clear();
      _pendingErrors.clear();
      _errorsController.add(const []);

      // Delete from Firebase if online
      if (_isOnline) {
        final deviceId = _deviceService.deviceId;
        final snapshot = await _errorLogsCollection
            .where('deviceId', isEqualTo: deviceId)
            .get();
        
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      debugPrint('🗑️ All errors cleared');
      _eventController.add(ErrorEvent(ErrorEventType.cleared, 'All errors cleared'));
      
    } catch (e) {
      debugPrint('❌ Failed to clear errors: $e');
      _eventController.add(ErrorEvent(ErrorEventType.error, 'Clear failed: $e'));
    }
  }

  /// ===========================================================
  /// QUERY METHODS
  /// ===========================================================
  Stream<List<ErrorLog>> getErrorsForCamera(String cameraId) {
    return _errorsController.stream.map(
      (errors) => errors.where((error) => error.cameraId == cameraId).toList(),
    );
  }

  Stream<List<ErrorLog>> getErrorsForType(String errorType) {
    return _errorsController.stream.map(
      (errors) => errors.where((error) => error.errorType == errorType).toList(),
    );
  }

  Stream<List<ErrorLog>> getErrorsBySeverity(ErrorSeverity severity) {
    return _errorsController.stream.map(
      (errors) => errors.where((error) => error.severity == severity).toList(),
    );
  }

  List<ErrorLog> getErrorsInRange(DateTime start, DateTime end) {
    return _localErrors.where((error) {
      final errorTime = error.timestamp.toDate();
      return errorTime.isAfter(start) && errorTime.isBefore(end);
    }).toList();
  }

  Map<String, int> getErrorTypeCounts() {
    final counts = <String, int>{};
    for (final error in _localErrors) {
      counts[error.errorType] = (counts[error.errorType] ?? 0) + 1;
    }
    return counts;
  }

  Map<ErrorSeverity, int> getErrorSeverityCounts() {
    final counts = <ErrorSeverity, int>{};
    for (final error in _localErrors) {
      counts[error.severity] = (counts[error.severity] ?? 0) + 1;
    }
    return counts;
  }

  /// ===========================================================
  /// DEVICE STATUS LISTENER
  /// ===========================================================
  void _setupDeviceStatusListener() {
    _deviceService.events.listen((event) {
      if (event.type == DeviceEventType.statusChanged) {
        _isOnline = _deviceService.isOnline;
        
        if (_isOnline && _pendingErrors.isNotEmpty) {
          // Sync pending errors when coming back online
          Future.delayed(const Duration(seconds: 2), () {
            syncPendingErrors();
          });
        }
      }
    });
  }

  /// ===========================================================
  /// GLOBAL ERROR HANDLERS
  /// ===========================================================
  void _setupGlobalErrorHandlers() {
    // Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      logCrash(
        'Flutter Error: ${details.exception}',
        cameraId: 'flutter',
        stackTrace: details.stack,
      );
    };

    // Zone error handler
    runZonedGuarded(
      () {
        // App code runs here
      },
      (error, stackTrace) {
        logCrash(
          'Uncaught Error: $error',
          cameraId: 'zone',
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// ===========================================================
  /// TIMERS
  /// ===========================================================
  void _startSyncTimer() {
    // Sync pending errors every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _pendingErrors.isNotEmpty) {
        syncPendingErrors();
      }
    });
  }

  void _startCleanupTimer() {
    // Clean up old errors every hour (Firebase TTL handles this, but we'll clean local cache)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldErrors();
    });
  }

  void _cleanupOldErrors() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final initialCount = _localErrors.length;
    
    _localErrors.removeWhere(
      (error) => error.timestamp.toDate().isBefore(cutoff),
    );
    
    if (_localErrors.length != initialCount) {
      _errorsController.add(List.unmodifiable(_localErrors));
      debugPrint('🧹 Cleaned up ${initialCount - _localErrors.length} old errors');
    }
  }

  /// ===========================================================
  /// LOCAL STORAGE
  /// ===========================================================
  Future<void> _loadCachedErrors() async {
    try {
      // Load cached errors from local storage
      final cachedData = _localStorage.storage.read('cached_errors') as List<dynamic>? ?? [];
      
      for (final errorData in cachedData) {
        try {
          final error = _errorFromJson(errorData as Map<String, dynamic>);
          _localErrors.add(error);
        } catch (e) {
          debugPrint('⚠️ Failed to parse cached error: $e');
        }
      }
      
      // Sort by timestamp (newest first)
      _localErrors.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      debugPrint('📂 Loaded ${_localErrors.length} cached errors');
      
    } catch (e) {
      debugPrint('⚠️ Failed to load cached errors: $e');
    }
  }

  Future<void> _saveCachedErrors() async {
    try {
      final errorsData = _localErrors.map(_errorToJson).toList();
      await _localStorage.storage.write('cached_errors', errorsData);
    } catch (e) {
      debugPrint('⚠️ Failed to save cached errors: $e');
    }
  }

  ErrorLog _errorFromJson(Map<String, dynamic> json) {
    return ErrorLog(
      deviceId: json['deviceId'],
      cameraId: json['cameraId'],
      errorType: json['errorType'],
      severity: ErrorSeverity.fromString(json['severity']),
      message: json['message'],
      timestamp: Timestamp.fromMillisecondsSinceEpoch(json['timestamp']),
      createdAt: Timestamp.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }

  Map<String, dynamic> _errorToJson(ErrorLog error) {
    return {
      'deviceId': error.deviceId,
      'cameraId': error.cameraId,
      'errorType': error.errorType,
      'severity': error.severity.value,
      'message': error.message,
      'timestamp': error.timestamp.millisecondsSinceEpoch,
      'createdAt': error.createdAt.millisecondsSinceEpoch,
    };
  }

  /// ===========================================================
  /// DISPOSAL
  /// ===========================================================
  Future<void> dispose() async {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    await _eventController.close();
    await _errorsController.close();
    
    // Save cached errors
    await _saveCachedErrors();
    
    _isInitialized = false;
    
    debugPrint('🚨 Error Logging Service disposed');
  }
}

/// ===========================================================
/// ERROR EVENT MODEL
/// ===========================================================
class ErrorEvent {
  final ErrorEventType type;
  final String message;
  final DateTime timestamp;

  ErrorEvent(this.type, this.message) : timestamp = DateTime.now();

  @override
  String toString() => 'ErrorEvent($type, $message, $timestamp)';
}

enum ErrorEventType {
  initialized,
  logged,
  queued,
  synced,
  syncCompleted,
  deleted,
  cleared,
  error,
}
