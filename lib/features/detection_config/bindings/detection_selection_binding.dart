import 'package:get/get.dart';
import '../controllers/detection_selection_controller.dart';

class DetectionSelectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DetectionSelectionController>(() => DetectionSelectionController());
  }
}
