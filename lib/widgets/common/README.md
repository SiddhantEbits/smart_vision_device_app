# Common Widgets

## RTSPPreviewWidget

A reusable RTSP video preview widget that handles Media Kit initialization, error states, and proper aspect ratio display.

### Features
- **Real Dimensions**: Shows RTSP streams with their actual aspect ratio (no forced filling)
- **Error Handling**: Displays error states when RTSP connection fails
- **Loading States**: Shows loading indicator while connecting
- **Customizable**: Configurable styling, borders, and placeholders
- **Memory Efficient**: Proper cleanup of Media Kit resources

### Usage Examples

#### Basic Usage
```dart
RTSPPreviewWidget(
  rtspUrl: 'rtsp://admin:admin@192.168.1.204:554/profile2',
)
```

#### With Custom Styling
```dart
RTSPPreviewWidget(
  rtspUrl: 'rtsp://admin:admin@192.168.1.204:554/profile2',
  width: double.infinity,
  height: 200,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white.withOpacity(0.2)),
  backgroundColor: Colors.black,
  fit: BoxFit.contain,
)
```

#### With Custom Placeholder
```dart
RTSPPreviewWidget(
  rtspUrl: 'rtsp://admin:admin@192.168.1.204:554/profile2',
  placeholder: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.videocam_off, size: 48, color: Colors.white54),
      SizedBox(height: 8),
      Text('Camera Offline', style: TextStyle(color: Colors.white54)),
    ],
  ),
)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `rtspUrl` | `String` | **Required** | RTSP stream URL |
| `width` | `double?` | `null` | Widget width |
| `height` | `double?` | `null` | Widget height |
| `borderRadius` | `BorderRadius?` | `null` | Border radius for corners |
| `border` | `Border?` | `null` | Border styling |
| `backgroundColor` | `Color` | `Colors.black` | Background color |
| `placeholder` | `Widget?` | `null` | Custom loading widget |
| `showControls` | `bool` | `false` | Show Media Kit controls |
| `fit` | `BoxFit` | `BoxFit.contain` | Video fit mode |

### Integration in Screens

#### Detection Testing Screen
```dart
RTSPPreviewWidget(
  rtspUrl: cameraSetupController.rtspUrl.value,
  width: double.infinity,
  height: double.infinity,
  borderRadius: BorderRadius.circular(16.adaptSize),
  backgroundColor: Colors.black,
  fit: BoxFit.contain,
)
```

#### Camera Setup Screen
```dart
RTSPPreviewWidget(
  rtspUrl: controller.rtspUrl.value,
  width: double.infinity,
  height: double.infinity,
  borderRadius: BorderRadius.circular(8.adaptSize),
  backgroundColor: Colors.black,
  fit: BoxFit.contain,
)
```

### Error Handling

The widget automatically handles:
- **Connection Errors**: Shows error icon and message
- **Invalid URLs**: Displays appropriate error state
- **Network Issues**: Handles timeout and connection failures
- **Resource Cleanup**: Properly disposes Media Kit resources

### Best Practices

1. **Use Real Dimensions**: The widget preserves original video aspect ratio
2. **Handle Empty URLs**: Check if RTSP URL is valid before using
3. **Memory Management**: Widget handles cleanup automatically
4. **Error States**: Customize error display with placeholder if needed
5. **Responsive Design**: Use responsive sizing with `adaptSize` extensions

### Migration from Direct Video Widget

**Before:**
```dart
Video(
  controller: controller.videoController,
  controls: NoVideoControls,
  fit: BoxFit.contain,
  wakelock: false,
)
```

**After:**
```dart
RTSPPreviewWidget(
  rtspUrl: controller.rtspUrl.value,
  fit: BoxFit.contain,
)
```

This simplifies the code while adding error handling and proper resource management.
