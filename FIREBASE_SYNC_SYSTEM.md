# Firebase Synchronization System

## Overview

This document describes the comprehensive Firebase synchronization system implemented for the Smart Vision Device App. The system provides real-time data synchronization between local storage and Firebase Firestore with robust conflict resolution and data validation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SMART VISION APP                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   UI Layer      │  │  Controllers    │  │   Widgets       │ │
│  │                 │  │                 │  │                 │ │
│  │ • Camera Setup  │  │ • Enhanced      │  │ • Sync Status   │ │
│  │ • Settings      │  │   Camera        │  │   Widget        │ │
│  │ • Stream View   │  │   Settings      │  │                 │ │
│  └─────────────────┘  │   Controller    │  └─────────────────┘ │
│           └───────────┼─────────────────┼───────────────────┘ │
│                        │                 │                   │
│  ┌─────────────────────▼─────────────────▼───────────────────┐ │
│  │                 SERVICE LAYER                           │ │
│  │                                                         │ │
│  │ ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐ │ │
│  │ │ App             │ │ Local Storage   │ │ Firebase      │ │ │
│  │ │ Initialization  │ │ Service         │ │ Sync Service  │ │ │
│  │ │ Service         │ │                 │ │               │ │ │
│  │ └─────────────────┘ └─────────────────┘ └───────────────┘ │ │
│  │                                                         │ │
│  │ ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐ │ │
│  │ │ Data Validation │ │ Existing        │ │ Firebase      │ │ │
│  │ │ Service         │ │ Services        │ │ Firestore     │ │ │
│  │ │                 │ │ (YOLO, RTSP,    │ │               │ │ │
│  │ └─────────────────┘ │ etc.)           │ └───────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  FIREBASE      │
                    │  FIRESTORE     │
                    │  CLOUD         │
                    └─────────────────┘
```

## Key Components

### 1. FirestoreCameraConfig Model
- **Location**: `lib/data/models/firestore_camera_config.dart`
- **Purpose**: Firebase-compatible data model with proper serialization
- **Features**:
  - Version control for conflict resolution
  - Device-specific data isolation
  - Complete ROI data preservation
  - Timestamp tracking for audit

### 2. LocalStorageService
- **Location**: `lib/data/repositories/local_storage_service.dart`
- **Purpose**: Persistent local storage with GetStorage
- **Features**:
  - Structured data storage
  - Pending changes tracking
  - Data validation
  - Import/export capabilities
  - Device ID management

### 3. FirebaseSyncService
- **Location**: `lib/data/repositories/firebase_sync_service.dart`
- **Purpose**: Real-time Firebase synchronization
- **Features**:
  - Bidirectional sync
  - Conflict resolution
  - Real-time listeners
  - Automatic retry
  - Sync event broadcasting

### 4. DataValidationService
- **Location**: `lib/data/repositories/data_validation_service.dart`
- **Purpose**: Comprehensive data validation
- **Features**:
  - Camera config validation
  - ROI validation
  - Schedule validation
  - Conflict resolution strategies
  - Batch validation

### 5. AppInitializationService
- **Location**: `lib/core/services/app_initialization_service.dart`
- **Purpose**: Centralized app initialization
- **Features**:
  - Step-by-step initialization
  - Error handling
  - Data migration
  - Service status monitoring

### 6. EnhancedCameraSettingsController
- **Location**: `lib/features/camera_settings/controller/enhanced_camera_settings_controller.dart`
- **Purpose**: Camera settings with sync integration
- **Features**:
  - Real-time sync status
  - Validation feedback
  - Pending changes tracking
  - Error handling

### 7. SyncStatusWidget
- **Location**: `lib/widgets/common/sync_status_widget.dart`
- **Purpose**: Visual sync status indicator
- **Features**:
  - Real-time status updates
  - Connection status
  - Pending changes display
  - Manual sync controls
  - Error reporting

## Data Structure

### Camera Configuration
```dart
CameraConfig {
  // Basic Info
  String name;
  String url;
  double confidenceThreshold;
  
  // Features
  bool peopleCountEnabled;
  bool footfallEnabled;
  bool maxPeopleEnabled;
  bool absentAlertEnabled;
  bool theftAlertEnabled;
  bool restrictedAreaEnabled;
  
  // ROI Data (Properly Structured)
  RoiAlertConfig footfallConfig {
    Rect roi;           // Normalized 0-1 coordinates
    Offset lineStart;   // Footfall line start
    Offset lineEnd;     // Footfall line end
    Offset direction;   // Crossing direction
  }
  
  RoiAlertConfig restrictedAreaConfig {
    Rect roi;           // Restricted area rectangle
    // Line data unused for restricted area
  }
  
  // Schedules
  AlertSchedule? footfallSchedule;
  AlertSchedule? maxPeopleSchedule;
  AlertSchedule? absentSchedule;
  AlertSchedule? theftSchedule;
  AlertSchedule? restrictedAreaSchedule;
  
  // Timing
  int footfallIntervalMinutes;
  int maxPeopleCooldownSeconds;
  int absentCooldownSeconds;
  int theftCooldownSeconds;
  int restrictedAreaCooldownSeconds;
}
```

### Firestore Document Structure
```json
{
  "id": "camera_config_123456",
  "deviceId": "device_unique_id",
  "name": "Entrance Lobby",
  "url": "rtsp://192.168.1.100:554/stream",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T14:20:00Z",
  "version": 3,
  
  "peopleCountEnabled": true,
  "confidenceThreshold": 0.15,
  
  "footfallEnabled": true,
  "footfallConfig": {
    "roi": {"l": 0.1, "t": 0.1, "r": 0.9, "b": 0.9},
    "lineStart": {"x": 0.3, "y": 0.5},
    "lineEnd": {"x": 0.7, "y": 0.5},
    "direction": {"x": 0, "y": 1}
  },
  "footfallSchedule": {
    "startHour": 9, "startMinute": 0,
    "endHour": 17, "endMinute": 0,
    "activeDays": [1, 2, 3, 4, 5]
  },
  "footfallIntervalMinutes": 60,
  
  "restrictedAreaEnabled": true,
  "restrictedAreaConfig": {
    "roi": {"l": 0.3, "t": 0.3, "r": 0.7, "b": 0.7},
    "lineStart": {"x": 0, "y": 0},
    "lineEnd": {"x": 0, "y": 0},
    "direction": {"x": 0, "y": 0}
  },
  "restrictedAreaCooldownSeconds": 300,
  
  // ... other feature configurations
}
```

## Synchronization Flow

### 1. App Initialization
```
App Start → AppInitializationService.initialize()
    ↓
1. Initialize LocalStorageService
2. Initialize DataValidationService  
3. Initialize FirebaseSyncService
4. Perform Data Migration
5. Validate Stored Data
    ↓
Ready for User Interaction
```

### 2. Real-time Sync
```
Local Change → LocalStorageService.saveCameraConfig()
    ↓
Mark as Pending Change
    ↓
FirebaseSyncService.saveCameraConfig()
    ↓
Firestore Document Updated
    ↓
Real-time Listener Triggered
    ↓
Other Devices Receive Update
```

### 3. Conflict Resolution
```
Conflict Detected → DataValidationService.resolveConfigConflict()
    ↓
Compare Versions & Validation
    ↓
Choose Resolution Strategy:
    • Use Local (if remote invalid)
    • Use Remote (if higher version)
    • Use Merged (if both partially valid)
    • Error (if both invalid)
    ↓
Apply Resolution
    ↓
Update Both Local & Remote
```

## ROI Data Preservation

### Footfall ROI
```dart
RoiAlertConfig footfallConfig = RoiAlertConfig.forFootfall();
// Contains:
// - roi: Detection area (Rect)
// - lineStart: Crossing line start (Offset)
// - lineEnd: Crossing line end (Offset)  
// - direction: Crossing direction (Offset)
```

### Restricted Area ROI
```dart
RoiAlertConfig restrictedAreaConfig = RoiAlertConfig.forRestrictedArea(
  roi: Rect.fromLTWH(0.3, 0.3, 0.4, 0.4)
);
// Contains:
// - roi: Restricted area rectangle (Rect)
// - lineStart/End/direction: Unused (set to zero)
```

### Data Serialization
```dart
// To JSON
Map<String, dynamic> roiJson = {
  'roi': {
    'l': config.roi.left,    // Normalized 0-1
    't': config.roi.top,     // Normalized 0-1
    'r': config.roi.right,  // Normalized 0-1
    'b': config.roi.bottom   // Normalized 0-1
  },
  'lineStart': {'x': config.lineStart.dx, 'y': config.lineStart.dy},
  'lineEnd': {'x': config.lineEnd.dx, 'y': config.lineEnd.dy},
  'direction': {'x': config.direction.dx, 'y': config.direction.dy}
};

// From JSON
RoiAlertConfig config = RoiAlertConfig(
  roi: Rect.fromLTRB(
    json['roi']['l'], json['roi']['t'],
    json['roi']['r'], json['roi']['b']
  ),
  lineStart: Offset(json['lineStart']['x'], json['lineStart']['y']),
  lineEnd: Offset(json['lineEnd']['x'], json['lineEnd']['y']),
  direction: Offset(json['direction']['x'], json['direction']['y'])
);
```

## Validation Rules

### Camera Configuration
- **Name**: Required, unique per device
- **URL**: Required, valid RTSP/HTTP/HTTPS format
- **Confidence Threshold**: 0.0 to 1.0

### ROI Validation
- **Coordinates**: Must be normalized 0.0 to 1.0
- **Logical**: left < right, top < bottom
- **Size**: Minimum 5% width/height, maximum 90% area
- **Footfall Line**: Required for footfall configs
- **Direction**: Required for footfall configs

### Schedule Validation
- **Active Days**: At least one day (1-7)
- **Time**: Valid hour/minute combinations
- **Duration**: Minimum 15 minutes recommended

## Error Handling

### Network Errors
- Automatic retry with exponential backoff
- Offline mode with local storage
- Sync queue for pending changes

### Validation Errors
- Detailed error messages
- Warnings for non-critical issues
- Prevent invalid data saving

### Conflict Resolution
- Version-based resolution
- Validation-based resolution
- Merge strategies for partial conflicts

## Usage Examples

### Adding a Camera with Sync
```dart
final controller = Get.find<EnhancedCameraSettingsController>();

// Configure camera
controller.cameraName.value = 'New Camera';
controller.cameraUrl.value = 'rtsp://192.168.1.100/stream';
controller.footfallEnabled.value = true;

// Save (automatically syncs to Firebase)
await controller.saveCamera();
```

### Monitoring Sync Status
```dart
// Add SyncStatusWidget to your UI
SyncStatusWidget()

// Or listen programmatically
FirebaseSyncService.instance.syncEvents.listen((event) {
  print('Sync event: ${event.type} - ${event.message}');
});
```

### Manual Sync
```dart
final syncService = FirebaseSyncService.instance;
final result = await syncService.fullSync();

if (result.success) {
  print('Sync completed: ${result.message}');
} else {
  print('Sync failed: ${result.message}');
}
```

## Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own device's camera configs
    match /camera_configs/{configId} {
      allow read, write, delete: if request.auth != null && 
        request.auth.uid == resource.data.deviceId;
      
      // Device ID must match authenticated user
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.deviceId;
    }
  }
}
```

## Performance Considerations

### Local Storage
- Uses GetStorage for fast access
- Structured data organization
- Efficient serialization

### Firebase Usage
- Real-time listeners for instant updates
- Batch operations for multiple changes
- Offline support with sync queue

### Memory Management
- Lazy loading of camera configs
- Efficient data structures
- Proper disposal of listeners

## Troubleshooting

### Common Issues

1. **Sync Not Working**
   - Check Firebase initialization
   - Verify network connectivity
   - Check device ID generation

2. **Data Validation Errors**
   - Review ROI coordinates (must be 0-1)
   - Check URL format
   - Verify schedule configurations

3. **Conflict Resolution Issues**
   - Check version numbers
   - Review validation results
   - Verify device ID consistency

### Debug Logging
```dart
// Enable debug logging
FirebaseSyncService.instance.syncEvents.listen((event) {
  debugPrint('Sync: ${event.type} - ${event.message}');
});

// Check service status
final status = AppInitializationService.instance.getServiceStatus();
print('Service status: $status');
```

## Migration Guide

### From Old Storage
1. Install new version
2. App automatically migrates data
3. Verify configurations in settings
4. Test sync functionality

### Manual Data Export/Import
```dart
// Export all data
final initService = AppInitializationService.instance;
final exportData = await initService.exportAllData();

// Import data
await initService.importAllData(exportData);
```

## Future Enhancements

1. **Multi-device Support**: Share configurations across devices
2. **Configuration Templates**: Predefined camera setups
3. **Backup & Restore**: Cloud backup solutions
4. **Analytics**: Usage statistics and insights
5. **Advanced Scheduling**: More complex time-based rules

## Conclusion

The Firebase synchronization system provides a robust, scalable solution for managing camera configurations across multiple devices with real-time updates, conflict resolution, and comprehensive data validation. All ROI data is properly structured and preserved during synchronization, ensuring consistent behavior across all platforms.
