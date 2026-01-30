import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/logging/logger_service.dart';
import '../../../data/models/camera_config.dart';
import '../../../data/services/device_camera_firebase_service.dart';
import '../../../data/repositories/simple_storage_service.dart';

class CameraSetupController extends GetxController {
  late final Player player;
  late final VideoController videoController;
  
  final RxString rtspUrl = ''.obs;
  final RxString cameraName = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isStreamValid = false.obs;
  final RxString statusMessage = 'Enter RTSP URL to begin'.obs;
  final RxBool isEditingMode = true.obs; // Start in editing mode

  // Camera management
  final RxList<CameraConfig> cameras = <CameraConfig>[].obs;
  final RxInt currentCameraIndex = 0.obs;
  
  static const String _camerasKey = 'saved_cameras';

  @override
  void onInit() {
    super.onInit();
    player = Player(configuration: PlayerConfiguration(
      title: 'RTSP Preview',
      logLevel: MPVLogLevel.info,
    ));
    videoController = VideoController(player);
    
    _loadCameras();
    _generateCameraNumber(); // Generate camera number on init
  }

  @override
  void onClose() {
    player.dispose();
    super.onClose();
  }

  Future<void> validateStream(String url) async {
    if (url.isEmpty) return;
    
    rtspUrl.value = url;
    isConnecting.value = true;
    statusMessage.value = 'Validating stream...';
    isStreamValid.value = false;

    try {
      LoggerService.i('Attempting to open RTSP stream: $url');
      
      // Clear any previous media
      await player.stop();
      
      // Configure Media Kit for RTSP with proper settings
      final media = Media(url);
      await player.open(media, play: true);
      
      // Set RTSP-specific properties for better streaming
      await player.setVolume(0.0); // Mute for preview
      await player.setRate(1.0); // Normal playback rate
      
      // Wait longer for RTSP connection and buffer
      await Future.delayed(const Duration(seconds: 8));
      
      // Check multiple indicators for successful stream
      final hasValidDimensions = player.state.width != null && player.state.width! > 0;
      final hasValidDuration = player.state.duration != null && player.state.duration! > Duration.zero;
      final isPlaying = player.state.playing;
      
      LoggerService.i('Stream validation - Dimensions: $hasValidDimensions, Duration: $hasValidDuration, Playing: $isPlaying');
      
      if (hasValidDimensions || hasValidDuration || isPlaying) {
        isStreamValid.value = true;
        statusMessage.value = 'Stream validated successfully!';
        LoggerService.i('RTSP stream validation successful');
        LoggerService.i('isStreamValid set to: ${isStreamValid.value}');
      } else {
        statusMessage.value = 'Could not detect video stream. Check URL format and network connectivity.';
        LoggerService.w('Stream validation failed - no valid video detected');
      }
    } catch (e) {
      LoggerService.e('Failed to validate stream', e);
      statusMessage.value = 'Connection failed: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}...';
    } finally {
      isConnecting.value = false;
    }
  }
  
  void enterEditMode() {
    isEditingMode.value = true;
    isStreamValid.value = false;
    rtspUrl.value = '';
    statusMessage.value = 'Enter RTSP URL to begin';
    
    // Stop the player when going back to edit mode
    player.stop();
  }

  void enterPreviewMode() {
    if (isStreamValid.value) {
      isEditingMode.value = false;
    }
  }

  void stopStream() {
    try {
      LoggerService.i('Stopping RTSP stream');
      player.stop();
      isStreamValid.value = false;
      statusMessage.value = 'Stream stopped';
    } catch (e) {
      LoggerService.e('Error stopping stream: $e');
    }
  }

  // ==================================================
  // CAMERA MANAGEMENT
  // ==================================================
  Future<void> _loadCameras() async {
    try {
      final simpleStorage = SimpleStorageService.instance;
      final cameraConfigs = simpleStorage.getCameraConfigs();
      
      if (cameraConfigs.isNotEmpty) {
        cameras.value = cameraConfigs;
        LoggerService.i('Loaded ${cameras.length} cameras from SimpleStorageService');
        
        // Log camera names for debugging
        for (final camera in cameras) {
          LoggerService.d('📷 Found camera: ${camera.name}');
        }
      } else {
        // Clear any existing cameras and start fresh - no default cameras
        cameras.clear();
        _saveCameras();
        LoggerService.i('No cameras found - starting with empty camera list');
      }
    } catch (e) {
      LoggerService.e('Error loading cameras: $e');
      cameras.clear();
    }
  }

  void _saveCameras() {
    try {
      final simpleStorage = SimpleStorageService.instance;
      // Save each camera using SimpleStorageService
      for (int i = 0; i < cameras.length; i++) {
        final camera = cameras[i];
        // Use the camera config save method from SimpleStorageService
        simpleStorage.saveCameraConfig(camera);
      }
      LoggerService.d('Saved ${cameras.length} cameras to SimpleStorageService');
    } catch (e) {
      LoggerService.e('Error saving cameras: $e');
    }
  }

  void addCamera(CameraConfig camera) {
    cameras.add(camera);
    _saveCameras();
    LoggerService.i('Added camera: ${camera.name}');
  }

  void updateCamera(int index, CameraConfig camera) {
    if (index >= 0 && index < cameras.length) {
      cameras[index] = camera;
      _saveCameras();
      LoggerService.i('Updated camera at index $index: ${camera.name}');
    }
  }

  void removeCamera(int index) {
    if (index >= 0 && index < cameras.length) {
      final removedCamera = cameras[index];
      cameras.removeAt(index);
      
      // Adjust current index if needed
      if (currentCameraIndex.value >= cameras.length) {
        currentCameraIndex.value = cameras.length - 1;
      }
      
      _saveCameras();
      LoggerService.i('Removed camera: ${removedCamera.name}');
    }
  }

  /// Clear all cameras (for debugging/testing)
  Future<void> clearAllCameras() async {
    try {
      final simpleStorage = SimpleStorageService.instance;
      cameras.clear();
      await simpleStorage.storage.remove('camera_configs');
      LoggerService.i('✅ All cameras cleared from storage');
    } catch (e) {
      LoggerService.e('❌ Error clearing cameras: $e');
    }
  }

  /// Ensure only one camera exists (keep the first one)
  void ensureSingleCamera() {
    if (cameras.length > 1) {
      final firstCamera = cameras.first;
      cameras.clear();
      cameras.add(firstCamera);
      _saveCameras();
      LoggerService.i('🎯 Ensured single camera: ${firstCamera.name} (removed ${cameras.length - 1} extra cameras)');
    }
  }

  void selectCamera(int index) {
    if (index >= 0 && index < cameras.length) {
      currentCameraIndex.value = index;
      final selectedCamera = cameras[index];
      rtspUrl.value = selectedCamera.url;
      LoggerService.i('Selected camera: ${selectedCamera.name}');
    }
  }

  CameraConfig? get currentCamera {
    if (cameras.isEmpty) return null;
    if (currentCameraIndex.value >= cameras.length) {
      currentCameraIndex.value = 0;
    }
    return cameras[currentCameraIndex.value];
  }

  void resetCamera() {
    rtspUrl.value = '';
    cameraName.value = '';
    isConnecting.value = false;
    isStreamValid.value = false;
    statusMessage.value = 'Enter RTSP URL to begin';
    isEditingMode.value = true;
    currentCameraIndex.value = 0;
    
    // Clear current player state
    player.stop();
    player.setVolume(0.0);
    
    // Generate new camera number
    _generateCameraNumber();
    
    LoggerService.i('Camera setup controller reset for new camera');
  }

  // ==================================================
  // CAMERA NUMBER GENERATION
  // ==================================================
  void _generateCameraNumber() {
    final existingCameraCount = cameras.length;
    final cameraNumber = (existingCameraCount + 1).toString().padLeft(2, '0');
    cameraName.value = 'CAM$cameraNumber';
    LoggerService.i('Generated camera number: ${cameraName.value}');
  }

  // ==================================================
  // FIREBASE INTEGRATION
  // ==================================================
  Future<void> saveCameraToFirebase() async {
    if (!isStreamValid.value || cameraName.value.isEmpty || rtspUrl.value.isEmpty) {
      LoggerService.w('Cannot save camera: missing required fields or invalid stream');
      return;
    }

    try {
      // Initialize Firebase service if needed
      await DeviceCameraFirebaseService.instance.initialize();
      await DeviceCameraFirebaseService.instance.ensureDeviceExists();
      
      // Create camera config with current settings
      final cameraConfig = CameraConfig(
        name: cameraName.value,
        url: rtspUrl.value,
        confidenceThreshold: 0.15,
        peopleCountEnabled: true,
        maxPeople: 5,
      );

      // Save to Firebase using DeviceCameraFirebaseService
      await DeviceCameraFirebaseService.instance.saveCamera(cameraConfig);
      
      // Add to local cameras list
      addCamera(cameraConfig);
      
      LoggerService.i('Camera ${cameraName.value} saved to Firebase successfully');
      statusMessage.value = 'Camera saved to Firebase successfully!';
    } catch (e) {
      LoggerService.e('Failed to save camera to Firebase: $e');
      statusMessage.value = 'Failed to save to Firebase: ${e.toString()}';
    }
  }

  /// Save verified RTSP camera locally without Firebase
  Future<void> saveVerifiedCameraLocally({bool clearForm = true}) async {
    if (!isStreamValid.value || cameraName.value.isEmpty || rtspUrl.value.isEmpty) {
      LoggerService.w('Cannot save camera: missing required fields or invalid stream');
      statusMessage.value = 'Please verify stream and enter camera name';
      return;
    }

    try {
      // Generate camera ID based on current cameras count
      final cameraId = 'CAM${(cameras.length + 1).toString().padLeft(2, '0')}';
      
      // Create camera config with current settings
      final cameraConfig = CameraConfig(
        name: cameraName.value,
        url: rtspUrl.value,
        confidenceThreshold: 0.15,
        peopleCountEnabled: true,
        maxPeople: 5,
      );

      // Add to local cameras list
      addCamera(cameraConfig);
      
      LoggerService.i('✅ Camera ${cameraName.value} saved locally with ID: $cameraId');
      statusMessage.value = 'Camera saved locally successfully!';
      
      // Clear form for next camera (optional)
      if (clearForm) {
        cameraName.value = '';
        rtspUrl.value = '';
        isStreamValid.value = false;
        statusMessage.value = 'Enter RTSP URL to begin';
      }
      
    } catch (e) {
      LoggerService.e('Failed to save camera locally: $e');
      statusMessage.value = 'Failed to save camera: ${e.toString()}';
    }
  }

  Future<void> updateCameraInFirebase() async {
    if (cameraName.value.isEmpty) {
      LoggerService.w('Cannot update camera: missing camera name');
      return;
    }

    try {
      // Initialize Firebase service if needed
      await DeviceCameraFirebaseService.instance.initialize();
      
      // Find existing camera config
      final existingCamera = cameras.firstWhereOrNull(
        (cam) => cam.name == cameraName.value,
      );

      if (existingCamera != null) {
        // Update with new RTSP URL
        final updatedCamera = existingCamera.copyWith(
          url: rtspUrl.value,
        );

        // Save to Firebase
        await DeviceCameraFirebaseService.instance.updateCamera(updatedCamera);
        
        // Update local cameras list
        final index = cameras.indexWhere((cam) => cam.name == cameraName.value);
        if (index != -1) {
          updateCamera(index, updatedCamera);
        }
        
        LoggerService.i('Camera ${cameraName.value} updated in Firebase successfully');
        statusMessage.value = 'Camera updated in Firebase successfully!';
      } else {
        // If not found, save as new camera
        await saveCameraToFirebase();
      }
    } catch (e) {
      LoggerService.e('Failed to update camera in Firebase: $e');
      statusMessage.value = 'Failed to update camera: $e';
    }
  }
}
