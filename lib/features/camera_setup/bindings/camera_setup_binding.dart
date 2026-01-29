import 'package:get/get.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../views/camera_setup_screen.dart';

class CameraSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CameraSetupController>(() => CameraSetupController());
  }
}
