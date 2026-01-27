import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../logging/logger_service.dart';

class CooldownManager extends GetxService {
  final _storage = GetStorage();
  static const String _storageKey = 'alert_cooldowns';

  // Map<CameraId(String), Map<FeatureKey(String), LastAlertTime(DateTime)>>
  final Map<String, Map<String, DateTime>> _lastAlerts = {};

  Future<CooldownManager> init() async {
    _loadFromStorage();
    return this;
  }

  void _loadFromStorage() {
    try {
      final storedData = _storage.read<Map<String, dynamic>>(_storageKey);
      if (storedData != null) {
        storedData.forEach((camId, features) {
          if (features is Map) {
            final featureMap = <String, DateTime>{};
            features.forEach((featureKey, timestampStr) {
              if (timestampStr is String) {
                final timestamp = DateTime.tryParse(timestampStr);
                if (timestamp != null) {
                  featureMap[featureKey] = timestamp;
                }
              }
            });
            _lastAlerts[camId] = featureMap;
          }
        });
      }
    } catch (e) {
      LoggerService.e("Error loading cooldowns from storage", e);
    }
  }

  void _saveToStorage() {
    try {
      final dataToStore = <String, Map<String, String>>{};
      _lastAlerts.forEach((camId, features) {
        final featureMap = <String, String>{};
        features.forEach((featureKey, timestamp) {
          featureMap[featureKey] = timestamp.toIso8601String();
        });
        dataToStore[camId] = featureMap;
      });
      _storage.write(_storageKey, dataToStore);
    } catch (e) {
      LoggerService.e("Error saving cooldowns to storage", e);
    }
  }

  /// Check if an alert is allowed (cooldown expired)
  /// Updates the timestamp if allowed.
  bool checkCooldown({
    required String cameraId,
    required String feature,
    required int cooldownSeconds,
  }) {
    if (cooldownSeconds <= 0) return true;

    final now = DateTime.now();
    final cameraAlerts = _lastAlerts.putIfAbsent(cameraId, () => {});
    final lastAlert = cameraAlerts[feature];

    if (lastAlert == null ||
        now.difference(lastAlert).inSeconds >= cooldownSeconds) {
      cameraAlerts[feature] = now;
      _saveToStorage();
      LoggerService.d("Cooldown PASS: Cam $cameraId | $feature");
      return true;
    }

    return false;
  }

  void resetCooldown({required String cameraId, required String feature}) {
    if (_lastAlerts.containsKey(cameraId)) {
      _lastAlerts[cameraId]?.remove(feature);
      _saveToStorage();
    }
  }

  void clearAll() {
    _lastAlerts.clear();
    _storage.remove(_storageKey);
  }
}
