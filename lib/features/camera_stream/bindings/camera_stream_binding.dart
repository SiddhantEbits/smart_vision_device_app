import 'package:get/get.dart';
import '../../camera_stream/controller/camera_stream_controller.dart';
import '../views/camera_stream_screen.dart';

class CameraStreamBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CameraStreamController>(() => CameraStreamController());
  }
}
