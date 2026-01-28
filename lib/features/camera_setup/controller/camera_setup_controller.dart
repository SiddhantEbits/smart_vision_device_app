import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/logging/logger_service.dart';
import '../../../data/models/camera_config.dart';

class CameraSetupController extends GetxController {
  late final Player player;
  late final VideoController videoController;
  
  final RxString rtspUrl = ''.obs;
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
  void _loadCameras() {
    try {
      final storage = GetStorage();
      final camerasData = storage.read(_camerasKey);
      
      if (camerasData != null && camerasData is List) {
        cameras.value = (camerasData as List)
            .map((json) => CameraConfig.fromJson(json as Map<String, dynamic>))
            .toList();
        LoggerService.i('Loaded ${cameras.length} cameras from storage');
      } else {
        // Add default cameras for demo
        cameras.addAll([
          CameraConfig(
            name: 'Entrance Lobby',
            url: 'rtsp://192.168.1.100:554/stream',
            confidenceThreshold: 0.15,
            peopleCountEnabled: true,
            maxPeople: 5,
          ),
          CameraConfig(
            name: 'Office Hall',
            url: 'rtsp://192.168.1.101:554/stream',
            confidenceThreshold: 0.15,
            footfallEnabled: true,
          ),
          CameraConfig(
            name: 'Warehouse',
            url: 'rtsp://192.168.1.102:554/stream',
            confidenceThreshold: 0.15,
            restrictedAreaEnabled: true,
          ),
        ]);
        _saveCameras();
        LoggerService.i('Created default cameras');
      }
    } catch (e) {
      LoggerService.e('Error loading cameras: $e');
      cameras.clear();
    }
  }

  void _saveCameras() {
    try {
      final storage = GetStorage();
      final camerasData = cameras.map((cam) => cam.toJson()).toList();
      storage.write(_camerasKey, camerasData);
      LoggerService.d('Saved ${cameras.length} cameras to storage');
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

  String get cameraName {
    return currentCamera?.name ?? 'Unknown Camera';
  }

  void resetCamera() {
    rtspUrl.value = '';
    isConnecting.value = false;
    isStreamValid.value = false;
    statusMessage.value = 'Enter RTSP URL to begin';
    isEditingMode.value = true;
    currentCameraIndex.value = 0;
    
    // Clear current player state
    player.stop();
    player.setVolume(0.0);
    
    LoggerService.i('Camera setup controller reset for new camera');
  }
}
