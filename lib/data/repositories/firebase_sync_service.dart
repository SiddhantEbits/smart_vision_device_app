import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/firestore_camera_config.dart';
import '../models/camera_config.dart';
import 'local_storage_service.dart';

/// ===========================================================
/// FIREBASE SYNC SERVICE
/// Handles real-time synchronization between local storage
/// and Firebase Firestore with conflict resolution
/// ===========================================================
class FirebaseSyncService {
  static FirebaseSyncService? _instance;
  static FirebaseSyncService get instance => _instance ??= FirebaseSyncService._();
  
  FirebaseSyncService._();

  late final FirebaseFirestore _firestore;
  late final LocalStorageService _localStorage;
  late final CollectionReference<FirestoreCameraConfig> _cameraConfigsCollection;
  
  StreamSubscription<QuerySnapshot<FirestoreCameraConfig>>? _cameraConfigsSubscription;
  final StreamController<SyncEvent> _syncEventController = StreamController<SyncEvent>.broadcast();
  
  // Sync state
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _deviceId;

  /// ===========================================================
  /// GETTERS
  /// ===========================================================
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get deviceId => _deviceId ?? '';
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

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
      _cameraConfigsCollection = _firestore
          .collection(FirestoreCameraConfigSerializer.collectionName)
          .withConverter<FirestoreCameraConfig>(
            fromFirestore: FirestoreCameraConfigSerializer.deserialize,
            toFirestore: (config, options) => FirestoreCameraConfigSerializer.serialize(config),
          );
      
      // Setup real-time listener
      _setupRealtimeListener();
      
      _isInitialized = true;
      _syncEventController.add(SyncEvent(SyncEventType.initialized, 'Firebase sync initialized'));
      
      print('Firebase Sync Service initialized for device: $_deviceId');
    } catch (e) {
      print('Error initializing Firebase Sync Service: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Initialization failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// REAL-TIME SYNCHRONIZATION
  /// ===========================================================
  void _setupRealtimeListener() {
    _cameraConfigsSubscription = _cameraConfigsCollection
        .where('deviceId', isEqualTo: _deviceId)
        .snapshots()
        .listen(
          (snapshot) => _handleFirestoreChanges(snapshot),
          onError: (error) => _syncEventController.add(
            SyncEvent(SyncEventType.error, 'Firestore listener error: $error'),
          ),
        );
  }

  Future<void> _handleFirestoreChanges(QuerySnapshot<FirestoreCameraConfig> snapshot) async {
    try {
      _isSyncing = true;
      _syncEventController.add(SyncEvent(SyncEventType.syncStarted, 'Syncing Firestore changes'));

      final localConfigs = _localStorage.getFirestoreCameraConfigs();
      final remoteConfigs = snapshot.docs.map((doc) => doc.data()).toList();

      // Handle changes
      for (final remoteConfig in remoteConfigs) {
        final localConfig = localConfigs.firstWhere(
          (config) => config.id == remoteConfig.id,
          orElse: () => localConfigs.firstWhere(
            (config) => config.name == remoteConfig.name,
            orElse: () => remoteConfig, // Will be handled as new
          ),
        );

        // Conflict resolution
        if (localConfig.id == remoteConfig.id) {
          if (remoteConfig.version > localConfig.version) {
            // Remote is newer, update local
            await _localStorage.saveFirestoreCameraConfig(remoteConfig);
            await _updateLocalCameraConfig(remoteConfig);
            _syncEventController.add(
              SyncEvent(SyncEventType.updated, 'Updated config: ${remoteConfig.name}'),
            );
          } else if (remoteConfig.version < localConfig.version) {
            // Local is newer, push to remote
            await _pushLocalConfigToFirestore(localConfig);
          }
        } else {
          // New config from remote
          await _localStorage.saveFirestoreCameraConfig(remoteConfig);
          await _updateLocalCameraConfig(remoteConfig);
          _syncEventController.add(
            SyncEvent(SyncEventType.added, 'Added config: ${remoteConfig.name}'),
          );
        }
      }

      // Handle deletions
      for (final localConfig in localConfigs) {
        if (!remoteConfigs.any((remote) => remote.id == localConfig.id || remote.name == localConfig.name)) {
          await _localStorage.deleteFirestoreCameraConfig(localConfig.id);
          await _localStorage.deleteCameraConfig(localConfig.name);
          _syncEventController.add(
            SyncEvent(SyncEventType.deleted, 'Deleted config: ${localConfig.name}'),
          );
        }
      }

      _lastSyncTime = DateTime.now();
      await _localStorage.updateLastSyncTime();
      
      _isSyncing = false;
      _syncEventController.add(SyncEvent(SyncEventType.syncCompleted, 'Sync completed'));
    } catch (e) {
      _isSyncing = false;
      print('Error handling Firestore changes: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Sync error: $e'));
    }
  }

  /// ===========================================================
  /// MANUAL SYNC OPERATIONS
  /// ===========================================================
  
  /// Sync all local changes to Firestore
  Future<SyncResult> syncToFirestore() async {
    if (!_isInitialized) {
      return SyncResult(false, 'Service not initialized');
    }

    try {
      _isSyncing = true;
      _syncEventController.add(SyncEvent(SyncEventType.syncStarted, 'Manual sync to Firestore'));

      final pendingChanges = _localStorage.pendingChanges;
      int syncedCount = 0;
      int errorCount = 0;

      for (final entry in pendingChanges.entries) {
        try {
          final key = entry.key;
          final operation = entry.value;

          if (key.startsWith('camera_config_')) {
            final cameraName = key.replaceFirst('camera_config_', '');
            
            if (operation == 'delete') {
              await _deleteCameraConfigFromFirestore(cameraName);
            } else if (operation == 'update') {
              await _syncCameraConfigToFirestore(cameraName);
            }
            
            await _localStorage.clearPendingChange(key);
            syncedCount++;
          }
        } catch (e) {
          print('Error syncing change ${entry.key}: $e');
          errorCount++;
        }
      }

      _isSyncing = false;
      _lastSyncTime = DateTime.now();
      await _localStorage.updateLastSyncTime();

      final result = SyncResult(
        errorCount == 0,
        'Synced $syncedCount items, $errorCount errors',
        syncedCount: syncedCount,
        errorCount: errorCount,
      );

      _syncEventController.add(
        SyncEvent(
          result.success ? SyncEventType.syncCompleted : SyncEventType.error,
          result.message,
        ),
      );

      return result;
    } catch (e) {
      _isSyncing = false;
      print('Error syncing to Firestore: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Manual sync failed: $e'));
      return SyncResult(false, 'Manual sync failed: $e');
    }
  }

  /// Sync all changes from Firestore to local
  Future<SyncResult> syncFromFirestore() async {
    if (!_isInitialized) {
      return SyncResult(false, 'Service not initialized');
    }

    try {
      _isSyncing = true;
      _syncEventController.add(SyncEvent(SyncEventType.syncStarted, 'Manual sync from Firestore'));

      final snapshot = await _cameraConfigsCollection
          .where('deviceId', isEqualTo: _deviceId)
          .get();

      await _handleFirestoreChanges(snapshot);

      _isSyncing = false;
      _lastSyncTime = DateTime.now();

      final result = SyncResult(true, 'Synced ${snapshot.docs.length} configs from Firestore');
      _syncEventController.add(
        SyncEvent(SyncEventType.syncCompleted, result.message),
      );

      return result;
    } catch (e) {
      _isSyncing = false;
      print('Error syncing from Firestore: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Manual sync from failed: $e'));
      return SyncResult(false, 'Manual sync from failed: $e');
    }
  }

  /// Full bidirectional sync
  Future<SyncResult> fullSync() async {
    final toFirestoreResult = await syncToFirestore();
    if (!toFirestoreResult.success) {
      return toFirestoreResult;
    }

    final fromFirestoreResult = await syncFromFirestore();
    return fromFirestoreResult;
  }

  /// ===========================================================
  /// INDIVIDUAL CONFIG OPERATIONS
  /// ===========================================================
  
  /// Save a single camera config to Firestore
  Future<void> saveCameraConfig(CameraConfig cameraConfig) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      // Save to local first
      await _localStorage.saveCameraConfig(cameraConfig);

      // Convert to Firestore config
      final existingFirestoreConfigs = _localStorage.getFirestoreCameraConfigs();
      final existingConfig = existingFirestoreConfigs.firstWhere(
        (config) => config.name == cameraConfig.name,
        orElse: () => FirestoreCameraConfig.fromCameraConfig(
          cameraConfig,
          deviceId: _deviceId!,
        ),
      );

      final updatedConfig = existingConfig.copyWithVersionIncrement(
        name: cameraConfig.name,
        url: cameraConfig.url,
        peopleCountEnabled: cameraConfig.peopleCountEnabled,
        footfallEnabled: cameraConfig.footfallEnabled,
        footfallConfig: cameraConfig.footfallConfig,
        footfallSchedule: cameraConfig.footfallSchedule,
        footfallIntervalMinutes: cameraConfig.footfallIntervalMinutes,
        maxPeopleEnabled: cameraConfig.maxPeopleEnabled,
        maxPeople: cameraConfig.maxPeople,
        maxPeopleCooldownSeconds: cameraConfig.maxPeopleCooldownSeconds,
        maxPeopleSchedule: cameraConfig.maxPeopleSchedule,
        absentAlertEnabled: cameraConfig.absentAlertEnabled,
        absentSeconds: cameraConfig.absentSeconds,
        absentCooldownSeconds: cameraConfig.absentCooldownSeconds,
        absentSchedule: cameraConfig.absentSchedule,
        theftAlertEnabled: cameraConfig.theftAlertEnabled,
        theftCooldownSeconds: cameraConfig.theftCooldownSeconds,
        theftSchedule: cameraConfig.theftSchedule,
        restrictedAreaEnabled: cameraConfig.restrictedAreaEnabled,
        restrictedAreaConfig: cameraConfig.restrictedAreaConfig,
        restrictedAreaCooldownSeconds: cameraConfig.restrictedAreaCooldownSeconds,
        restrictedAreaSchedule: cameraConfig.restrictedAreaSchedule,
        confidenceThreshold: cameraConfig.confidenceThreshold,
      );

      // Save to Firestore
      await _cameraConfigsCollection.doc(updatedConfig.id).set(updatedConfig);
      await _localStorage.saveFirestoreCameraConfig(updatedConfig);

      _syncEventController.add(
        SyncEvent(SyncEventType.updated, 'Saved config to Firestore: ${cameraConfig.name}'),
      );
    } catch (e) {
      print('Error saving camera config to Firestore: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Save failed: $e'));
      rethrow;
    }
  }

  /// Delete a camera config from Firestore
  Future<void> deleteCameraConfig(String cameraName) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      // Find Firestore config
      final firestoreConfigs = _localStorage.getFirestoreCameraConfigs();
      final config = firestoreConfigs.firstWhere(
        (config) => config.name == cameraName,
        orElse: () => throw Exception('Camera config not found: $cameraName'),
      );

      // Delete from Firestore
      await _cameraConfigsCollection.doc(config.id).delete();
      
      // Delete from local
      await _localStorage.deleteCameraConfig(cameraName);
      await _localStorage.deleteFirestoreCameraConfig(config.id);

      _syncEventController.add(
        SyncEvent(SyncEventType.deleted, 'Deleted config from Firestore: $cameraName'),
      );
    } catch (e) {
      print('Error deleting camera config from Firestore: $e');
      _syncEventController.add(SyncEvent(SyncEventType.error, 'Delete failed: $e'));
      rethrow;
    }
  }

  /// ===========================================================
  /// PRIVATE HELPER METHODS
  /// ===========================================================
  
  Future<void> _syncCameraConfigToFirestore(String cameraName) async {
    final localConfig = _localStorage.getCameraConfig(cameraName);
    if (localConfig == null) {
      throw Exception('Local camera config not found: $cameraName');
    }

    await saveCameraConfig(localConfig);
  }

  Future<void> _deleteCameraConfigFromFirestore(String cameraName) async {
    final firestoreConfigs = _localStorage.getFirestoreCameraConfigs();
    final config = firestoreConfigs.firstWhere(
      (config) => config.name == cameraName,
      orElse: () => throw Exception('Firestore camera config not found: $cameraName'),
    );

    await _cameraConfigsCollection.doc(config.id).delete();
  }

  Future<void> _pushLocalConfigToFirestore(FirestoreCameraConfig localConfig) async {
    await _cameraConfigsCollection.doc(localConfig.id).set(localConfig);
    _syncEventController.add(
      SyncEvent(SyncEventType.updated, 'Pushed local config to Firestore: ${localConfig.name}'),
    );
  }

  Future<void> _updateLocalCameraConfig(FirestoreCameraConfig firestoreConfig) async {
    final localConfig = firestoreConfig.toCameraConfig();
    await _localStorage.saveCameraConfig(localConfig);
  }

  /// ===========================================================
  /// DISPOSAL
  /// ===========================================================
  Future<void> dispose() async {
    await _cameraConfigsSubscription?.cancel();
    await _syncEventController.close();
    _isInitialized = false;
    _isSyncing = false;
  }
}

/// ===========================================================
/// SYNC EVENT MODEL
/// ===========================================================
class SyncEvent {
  final SyncEventType type;
  final String message;
  final DateTime timestamp;

  SyncEvent(this.type, this.message) : timestamp = DateTime.now();

  @override
  String toString() => 'SyncEvent($type, $message, $timestamp)';
}

enum SyncEventType {
  initialized,
  syncStarted,
  syncCompleted,
  added,
  updated,
  deleted,
  error,
}

/// ===========================================================
/// SYNC RESULT MODEL
/// ===========================================================
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int errorCount;
  final DateTime timestamp;

  SyncResult(
    this.success,
    this.message, {
    this.syncedCount = 0,
    this.errorCount = 0,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'SyncResult(success: $success, message: $message, synced: $syncedCount, errors: $errorCount)';
}
