import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/logging/logger_service.dart';

class CameraSetupController extends GetxController {
  late final Player player;
  late final VideoController videoController;
  
  final RxString rtspUrl = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxBool isStreamValid = false.obs;
  final RxString statusMessage = 'Enter RTSP URL to begin'.obs;

  @override
  void onInit() {
    super.onInit();
    player = Player();
    videoController = VideoController(player);
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
      await player.open(Media(url), play: true);
      
      // Wait for a bit or listen to stream state
      await Future.delayed(const Duration(seconds: 3));
      
      if (player.state.width != null && player.state.width! > 0) {
        isStreamValid.value = true;
        statusMessage.value = 'Stream validated successfully!';
      } else {
        statusMessage.value = 'Could not detect video stream.';
      }
    } catch (e) {
      LoggerService.e('Failed to validate stream', e);
      statusMessage.value = 'Connection failed. Check URL and network.';
    } finally {
      isConnecting.value = false;
    }
  }
}
