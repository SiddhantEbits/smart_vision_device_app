import 'dart:ui';
import '../models/camera_config.dart';
import '../models/firestore_camera_config.dart';
import '../models/roi_config.dart';
import '../models/alert_schedule.dart';

/// ===========================================================
/// DATA VALIDATION SERVICE
/// Provides comprehensive validation for all camera
/// configuration data and conflict resolution
/// ===========================================================
class DataValidationService {
  static DataValidationService? _instance;
  static DataValidationService get instance => _instance ??= DataValidationService._();
  
  DataValidationService._();

  /// ===========================================================
  /// CAMERA CONFIG VALIDATION
  /// ===========================================================
  
  /// Validate complete camera configuration
  ValidationResult validateCameraConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic field validation
    if (config.name.trim().isEmpty) {
      errors.add('Camera name cannot be empty');
    }

    if (config.url.trim().isEmpty) {
      errors.add('Camera URL cannot be empty');
    }

    // URL format validation
    final urlValidation = _validateUrl(config.url);
    if (!urlValidation.isValid) {
      errors.addAll(urlValidation.errors);
    }

    // Confidence threshold validation
    if (config.confidenceThreshold < 0.0 || config.confidenceThreshold > 1.0) {
      errors.add('Confidence threshold must be between 0.0 and 1.0');
    }

    // Feature-specific validation
    if (config.footfallEnabled) {
      final footfallValidation = _validateFootfallConfig(config);
      errors.addAll(footfallValidation.errors);
      warnings.addAll(footfallValidation.warnings);
    }

    if (config.restrictedAreaEnabled) {
      final restrictedValidation = _validateRestrictedAreaConfig(config);
      errors.addAll(restrictedValidation.errors);
      warnings.addAll(restrictedValidation.warnings);
    }

    if (config.maxPeopleEnabled) {
      final maxPeopleValidation = _validateMaxPeopleConfig(config);
      errors.addAll(maxPeopleValidation.errors);
      warnings.addAll(maxPeopleValidation.warnings);
    }

    if (config.absentAlertEnabled) {
      final absentValidation = _validateAbsentConfig(config);
      errors.addAll(absentValidation.errors);
      warnings.addAll(absentValidation.warnings);
    }

    if (config.theftAlertEnabled) {
      final theftValidation = _validateTheftConfig(config);
      errors.addAll(theftValidation.errors);
      warnings.addAll(theftValidation.warnings);
    }

    // Schedule validation
    final scheduleValidation = _validateSchedules(config);
    errors.addAll(scheduleValidation.errors);
    warnings.addAll(scheduleValidation.warnings);

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// URL VALIDATION
  /// ===========================================================
  ValidationResult _validateUrl(String url) {
    final errors = <String>[];
    final warnings = <String>[];

    // Basic format validation
    if (!url.startsWith('rtsp://') && !url.startsWith('http://') && !url.startsWith('https://')) {
      errors.add('URL must start with rtsp://, http://, or https://');
    }

    // RTSP specific validation
    if (url.startsWith('rtsp://')) {
      if (!url.contains('@') && !url.contains('://')) {
        warnings.add('RTSP URL may require authentication credentials');
      }
      
      if (url.length < 10) {
        errors.add('RTSP URL appears to be incomplete');
      }
    }

    // HTTP/HTTPS validation
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (!url.contains('.')) {
        errors.add('Invalid HTTP/HTTPS URL format');
      }
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// FOOTFALL CONFIG VALIDATION
  /// ===========================================================
  ValidationResult _validateFootfallConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    final footfallConfig = config.footfallConfig;

    // ROI validation
    final roiValidation = _validateRoi(footfallConfig.roi, 'Footfall');
    errors.addAll(roiValidation.errors);
    warnings.addAll(roiValidation.warnings);

    // Line validation (required for footfall)
    if (footfallConfig.lineStart == Offset.zero || footfallConfig.lineEnd == Offset.zero) {
      errors.add('Footfall line start and end points must be configured');
    }

    // Direction validation
    if (footfallConfig.direction == Offset.zero) {
      errors.add('Footfall direction must be configured');
    }

    // Interval validation
    if (config.footfallIntervalMinutes < 1 || config.footfallIntervalMinutes > 1440) {
      errors.add('Footfall interval must be between 1 and 1440 minutes');
    }

    if (config.footfallIntervalMinutes < 5) {
      warnings.add('Very short footfall interval may cause excessive alerts');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// RESTRICTED AREA CONFIG VALIDATION
  /// ===========================================================
  ValidationResult _validateRestrictedAreaConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    final restrictedConfig = config.restrictedAreaConfig;

    // ROI validation
    final roiValidation = _validateRoi(restrictedConfig.roi, 'Restricted Area');
    errors.addAll(roiValidation.errors);
    warnings.addAll(roiValidation.warnings);

    // Cooldown validation
    if (config.restrictedAreaCooldownSeconds < 10 || config.restrictedAreaCooldownSeconds > 3600) {
      errors.add('Restricted area cooldown must be between 10 and 3600 seconds');
    }

    if (config.restrictedAreaCooldownSeconds < 30) {
      warnings.add('Short cooldown may cause excessive alerts');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// MAX PEOPLE CONFIG VALIDATION
  /// ===========================================================
  ValidationResult _validateMaxPeopleConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Max people count validation
    if (config.maxPeople < 1 || config.maxPeople > 100) {
      errors.add('Max people count must be between 1 and 100');
    }

    if (config.maxPeople > 20) {
      warnings.add('High max people count may not be practical for most areas');
    }

    // Cooldown validation
    if (config.maxPeopleCooldownSeconds < 30 || config.maxPeopleCooldownSeconds > 3600) {
      errors.add('Max people cooldown must be between 30 and 3600 seconds');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// ABSENT ALERT CONFIG VALIDATION
  /// ===========================================================
  ValidationResult _validateAbsentConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Absent seconds validation
    if (config.absentSeconds < 10 || config.absentSeconds > 3600) {
      errors.add('Absent alert time must be between 10 and 3600 seconds');
    }

    if (config.absentSeconds < 30) {
      warnings.add('Very short absent time may cause false alerts');
    }

    // Cooldown validation
    if (config.absentCooldownSeconds < 60 || config.absentCooldownSeconds > 7200) {
      errors.add('Absent alert cooldown must be between 60 and 7200 seconds');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// THEFT ALERT CONFIG VALIDATION
  /// ===========================================================
  ValidationResult _validateTheftConfig(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Cooldown validation
    if (config.theftCooldownSeconds < 30 || config.theftCooldownSeconds > 3600) {
      errors.add('Theft alert cooldown must be between 30 and 3600 seconds');
    }

    if (config.theftCooldownSeconds < 60) {
      warnings.add('Short theft cooldown may cause excessive alerts');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// SCHEDULE VALIDATION
  /// ===========================================================
  ValidationResult _validateSchedules(CameraConfig config) {
    final errors = <String>[];
    final warnings = <String>[];

    final schedules = [
      ('Footfall', config.footfallSchedule),
      ('Max People', config.maxPeopleSchedule),
      ('Absent Alert', config.absentSchedule),
      ('Theft Alert', config.theftSchedule),
      ('Restricted Area', config.restrictedAreaSchedule),
    ];

    for (final (featureName, schedule) in schedules) {
      if (schedule != null) {
        final scheduleValidation = _validateSchedule(schedule, featureName);
        errors.addAll(scheduleValidation.errors);
        warnings.addAll(scheduleValidation.warnings);
      }
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  ValidationResult _validateSchedule(AlertSchedule schedule, String featureName) {
    final errors = <String>[];
    final warnings = <String>[];

    // Active days validation
    if (schedule.activeDays.isEmpty) {
      errors.add('$featureName schedule must have at least one active day');
    }

    if (schedule.activeDays.any((day) => day < 1 || day > 7)) {
      errors.add('$featureName schedule contains invalid day numbers');
    }

    // Time validation
    final startMinutes = schedule.start.hour * 60 + schedule.start.minute;
    final endMinutes = schedule.end.hour * 60 + schedule.end.minute;

    if (startMinutes == endMinutes) {
      warnings.add('$featureName schedule has same start and end time');
    }

    // Check for very short schedules
    if (startMinutes != endMinutes) {
      int duration;
      if (startMinutes < endMinutes) {
        duration = endMinutes - startMinutes;
      } else {
        duration = (24 * 60 - startMinutes) + endMinutes;
      }

      if (duration < 15) {
        warnings.add('$featureName schedule duration is very short (less than 15 minutes)');
      }
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// ROI VALIDATION
  /// ===========================================================
  ValidationResult _validateRoi(Rect roi, String featureName) {
    final errors = <String>[];
    final warnings = <String>[];

    // Bounds validation
    if (roi.left < 0.0 || roi.left > 1.0) {
      errors.add('$featureName ROI left coordinate must be between 0.0 and 1.0');
    }

    if (roi.top < 0.0 || roi.top > 1.0) {
      errors.add('$featureName ROI top coordinate must be between 0.0 and 1.0');
    }

    if (roi.right < 0.0 || roi.right > 1.0) {
      errors.add('$featureName ROI right coordinate must be between 0.0 and 1.0');
    }

    if (roi.bottom < 0.0 || roi.bottom > 1.0) {
      errors.add('$featureName ROI bottom coordinate must be between 0.0 and 1.0');
    }

    // Logical validation
    if (roi.left >= roi.right) {
      errors.add('$featureName ROI left must be less than right');
    }

    if (roi.top >= roi.bottom) {
      errors.add('$featureName ROI top must be less than bottom');
    }

    // Size validation
    final width = roi.right - roi.left;
    final height = roi.bottom - roi.top;

    if (width < 0.05) {
      errors.add('$featureName ROI is too narrow (minimum 5% of image width)');
    }

    if (height < 0.05) {
      errors.add('$featureName ROI is too short (minimum 5% of image height)');
    }

    if (width > 0.9) {
      warnings.add('$featureName ROI is very wide (may include unwanted areas)');
    }

    if (height > 0.9) {
      warnings.add('$featureName ROI is very tall (may include unwanted areas)');
    }

    // Area validation
    final area = width * height;
    if (area < 0.01) {
      errors.add('$featureName ROI area is too small (minimum 1% of image)');
    }

    if (area > 0.8) {
      warnings.add('$featureName ROI covers most of the image (may reduce detection accuracy)');
    }

    return ValidationResult(
      errors.isEmpty,
      errors,
      warnings,
    );
  }

  /// ===========================================================
  /// CONFLICT RESOLUTION
  /// ===========================================================
  
  /// Resolve conflicts between local and remote configurations
  ConflictResolution resolveConfigConflict(
    CameraConfig localConfig,
    FirestoreCameraConfig remoteConfig,
  ) {
    final localValidation = validateCameraConfig(localConfig);
    final remoteValidation = validateCameraConfig(remoteConfig.toCameraConfig());

    // If both are valid, use version-based resolution
    if (localValidation.isValid && remoteValidation.isValid) {
      if (remoteConfig.version > 1) {
        return ConflictResolution.useRemote('Remote config has higher version');
      } else {
        return ConflictResolution.useLocal('Local config is newer');
      }
    }

    // If only local is valid
    if (localValidation.isValid && !remoteValidation.isValid) {
      return ConflictResolution.useLocal('Remote config has validation errors: ${remoteValidation.errors.join(', ')}');
    }

    // If only remote is valid
    if (!localValidation.isValid && remoteValidation.isValid) {
      return ConflictResolution.useRemote('Local config has validation errors: ${localValidation.errors.join(', ')}');
    }

    // If neither is valid, try to merge
    if (!localValidation.isValid && !remoteValidation.isValid) {
      final mergedConfig = _mergeConfigs(localConfig, remoteConfig);
      final mergedValidation = validateCameraConfig(mergedConfig);
      
      if (mergedValidation.isValid) {
        return ConflictResolution.useMerged(mergedConfig, 'Merged config resolves validation issues');
      } else {
        return ConflictResolution.error('Both configs have validation errors and merge failed');
      }
    }

    return ConflictResolution.error('Unexpected conflict resolution state');
  }

  /// Merge two configurations, preferring valid values
  CameraConfig _mergeConfigs(CameraConfig local, FirestoreCameraConfig remote) {
    final remoteCamera = remote.toCameraConfig();

    // Start with local config and replace invalid fields with remote
    CameraConfig merged = local;

    // Replace invalid URL
    if (!_validateUrl(local.url).isValid && _validateUrl(remoteCamera.url).isValid) {
      merged = merged.copyWith(url: remoteCamera.url);
    }

    // Replace invalid confidence threshold
    if (local.confidenceThreshold < 0.0 || local.confidenceThreshold > 1.0) {
      merged = merged.copyWith(confidenceThreshold: remoteCamera.confidenceThreshold);
    }

    // Replace invalid footfall config
    if (local.footfallEnabled && !_validateFootfallConfig(local).isValid) {
      if (remoteCamera.footfallEnabled && _validateFootfallConfig(remoteCamera).isValid) {
        merged = merged.copyWith(
          footfallConfig: remoteCamera.footfallConfig,
          footfallIntervalMinutes: remoteCamera.footfallIntervalMinutes,
        );
      }
    }

    // Replace invalid restricted area config
    if (local.restrictedAreaEnabled && !_validateRestrictedAreaConfig(local).isValid) {
      if (remoteCamera.restrictedAreaEnabled && _validateRestrictedAreaConfig(remoteCamera).isValid) {
        merged = merged.copyWith(
          restrictedAreaConfig: remoteCamera.restrictedAreaConfig,
          restrictedAreaCooldownSeconds: remoteCamera.restrictedAreaCooldownSeconds,
        );
      }
    }

    return merged;
  }

  /// ===========================================================
  /// BATCH VALIDATION
  /// ===========================================================
  
  /// Validate multiple camera configurations
  BatchValidationResult validateBatchConfigs(List<CameraConfig> configs) {
    final results = <ValidationResult>[];
    final duplicateNames = <String>[];
    final nameSet = <String>{};

    for (final config in configs) {
      // Check for duplicate names
      if (nameSet.contains(config.name)) {
        duplicateNames.add(config.name);
      } else {
        nameSet.add(config.name);
      }

      // Validate individual config
      results.add(validateCameraConfig(config));
    }

    final hasErrors = results.any((r) => !r.isValid);
    final allErrors = results.expand((r) => r.errors).toList();
    final allWarnings = results.expand((r) => r.warnings).toList();

    if (duplicateNames.isNotEmpty) {
      allErrors.addAll(duplicateNames.map((name) => 'Duplicate camera name: $name'));
    }

    return BatchValidationResult(
      !hasErrors && duplicateNames.isEmpty,
      results,
      allErrors,
      allWarnings,
      duplicateNames,
    );
  }
}

/// ===========================================================
/// VALIDATION RESULT MODELS
/// ===========================================================
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult(this.isValid, this.errors, this.warnings);

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasIssues => hasErrors || hasWarnings;
}

class BatchValidationResult {
  final bool isValid;
  final List<ValidationResult> individualResults;
  final List<String> allErrors;
  final List<String> allWarnings;
  final List<String> duplicateNames;

  BatchValidationResult(
    this.isValid,
    this.individualResults,
    this.allErrors,
    this.allWarnings,
    this.duplicateNames,
  );

  int get validCount => individualResults.where((r) => r.isValid).length;
  int get invalidCount => individualResults.where((r) => !r.isValid).length;
  int get totalCount => individualResults.length;
}

/// ===========================================================
/// CONFLICT RESOLUTION MODELS
/// ===========================================================
class ConflictResolution {
  final ConflictResolutionType type;
  final String reason;
  final CameraConfig? mergedConfig;

  ConflictResolution(this.type, this.reason, [this.mergedConfig]);

  factory ConflictResolution.useLocal(String reason) =>
      ConflictResolution(ConflictResolutionType.useLocal, reason);

  factory ConflictResolution.useRemote(String reason) =>
      ConflictResolution(ConflictResolutionType.useRemote, reason);

  factory ConflictResolution.useMerged(CameraConfig config, String reason) =>
      ConflictResolution(ConflictResolutionType.useMerged, reason, config);

  factory ConflictResolution.error(String reason) =>
      ConflictResolution(ConflictResolutionType.error, reason);
}

enum ConflictResolutionType {
  useLocal,
  useRemote,
  useMerged,
  error,
}
