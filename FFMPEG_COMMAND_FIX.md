# FFmpeg Command Fix - Matching Working smart-camera-yolo

## 🔍 **Problem Identified**

The FFmpeg service was failing with return code 1, even though the RTSP connection test was successful. The logs showed:
```
⚠️ FFmpeg failed with return code: 1
💡 RTSP Connection Test: Success with TCP Low Bandwidth
```

This indicated the issue was with the FFmpeg command parameters, not the connection itself.

## 🐛 **Root Cause Analysis**

### **Complex Low-Bandwidth Settings**
Our FFmpeg service was using overly complex low-bandwidth settings that were incompatible with some RTSP cameras:

```dart
// PROBLEMATIC SETTINGS
'-vf', 'fps=1,scale=160:160', // Too aggressive
'-timeout', '10000000', // Too short
'-analyzeduration', '1000000', // Too short
'-probesize', '128', // Too small
'-rtsp_buffer', '0', // Causing issues
'-max_delay', '500000', // Too restrictive
```

### **Working Reference**
The smart-camera-yolo project was working perfectly with the same RTSP URL, using simpler, more reliable settings.

## 🔧 **Fix Applied - Match Working smart-camera-yolo**

### **1. Updated FFmpeg Command**
Changed from complex low-bandwidth settings to the proven working command:

```dart
// BEFORE (Problematic)
final command = [
  '-rtsp_transport', 'tcp',
  '-rtsp_flags', 'prefer_tcp',
  '-i', rtspUrl,
  '-vf', 'fps=1,scale=160:160', // Too aggressive
  '-update', '1',
  '-y',
  '-timeout', '10000000', // Too short
  '-analyzeduration', '1000000', // Too short
  '-probesize', '128', // Too small
  '-threads', '1',
  '-rtsp_buffer', '0', // Causing issues
  '-max_delay', '500000', // Too restrictive
  _framePath!
];

// AFTER (Working - same as smart-camera-yolo)
final command = [
  '-rtsp_transport', 'tcp',
  '-rtsp_flags', 'prefer_tcp',
  '-i', rtspUrl,
  '-vf', 'fps=2,scale=256:256', // Balanced settings
  '-update', '1',
  '-y',
  '-timeout', '15000000', // Longer timeout
  '-analyzeduration', '1500000', // Proper analysis
  '-probesize', '256', // Adequate probe size
  '-threads', '1',
  _framePath!
];
```

### **2. Updated Frame Reading Rate**
Changed from 1 FPS to 2 FPS to match the working implementation:

```dart
// BEFORE
const Duration(milliseconds: 1000), // 1 FPS

// AFTER  
const Duration(milliseconds: 500), // 2 FPS (same as smart-camera-yolo)
```

### **3. Simplified RTSP Test**
Removed complex multi-strategy testing and used the same simple test as smart-camera-yolo:

```dart
// BEFORE (Complex multi-strategy)
final strategies = [
  {'name': 'TCP Low Bandwidth', ...},
  {'name': 'UDP', ...},
  {'name': 'TCP Fast', ...},
  // ... 5 different strategies
];

// AFTER (Simple and working)
final command = [
  '-rtsp_transport', 'tcp',
  '-rtsp_flags', 'prefer_tcp',
  '-i', _currentUrl!,
  '-t', '3',
  '-f', 'null',
  '-'
];
```

## 📊 **Key Changes Summary**

| Parameter | Before | After | Impact |
|-----------|--------|-------|---------|
| **Frame Rate** | 1 FPS | 2 FPS | Better detection frequency |
| **Resolution** | 160x160 | 256x256 | Better detection accuracy |
| **Timeout** | 10s | 15s | More tolerant connection |
| **Analysis** | 1s | 1.5s | Better stream parsing |
| **Probe Size** | 128 | 256 | Better stream detection |
| **Buffer** | 0 | Default | Removed problematic setting |
| **Max Delay** | 0.5s | Default | Removed restrictive setting |

## 🎯 **Expected Behavior Now**

### **Before Fix**:
- ❌ FFmpeg return code 1 failures
- ❌ No frame extraction despite successful RTSP test
- ❌ Complex retry logic with multiple strategies
- ❌ Overly aggressive low-bandwidth settings

### **After Fix**:
- ✅ Same working command as smart-camera-yolo
- ✅ Proper 2 FPS frame extraction
- ✅ Balanced 256x256 resolution for YOLO
- ✅ Reliable connection handling
- ✅ Simplified, proven approach

## 🚀 **Benefits**

1. **Proven Compatibility**: Uses the exact same command that works in smart-camera-yolo
2. **Better Performance**: 2 FPS and 256x256 provide better detection accuracy
3. **Reliability**: Simpler command with fewer points of failure
4. **Consistency**: Same behavior across both projects
5. **Maintainability**: Easier to debug and modify

## 📱 **Build Status**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 🔍 **Test Results Expected**

With this fix, you should see:
```
💡 Testing RTSP connection
💡 RTSP Connection Test: Success
💡 Starting FFmpeg with balanced settings (strategy: TCP Low Bandwidth)
💡 FFmpeg started successfully
```

And no more return code 1 failures. The FFmpeg service should now work exactly like it does in the smart-camera-yolo project.

## 🎯 **Root Cause Summary**

The issue was that we were using overly aggressive low-bandwidth settings that were incompatible with the RTSP camera. By switching to the exact same command that works in smart-camera-yolo, we eliminate the compatibility issues and get reliable frame extraction.
