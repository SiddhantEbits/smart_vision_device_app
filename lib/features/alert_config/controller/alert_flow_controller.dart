import 'package:get/get.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../core/constants/app_routes.dart';
import '../../monitoring/controller/monitoring_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';

class AlertFlowController extends GetxController {
  final RxList<DetectionType> selectedDetections = <DetectionType>[].obs;
  final RxInt currentConfigIndex = 0.obs;
  
  // Store the actual configurations being built
  final Map<DetectionType, AlertConfig> configs = {};

  void selectDetections(List<DetectionType> types) {
    selectedDetections.assignAll(types);
    currentConfigIndex.value = 0;
    configs.clear();
  }

  DetectionType? get currentAlert => 
      currentConfigIndex.value < selectedDetections.length 
          ? selectedDetections[currentConfigIndex.value] 
          : null;

  void saveConfig(AlertConfig config) {
    configs[config.type] = config;
  }

  void finishSetup() {
    final monitoring = Get.put(MonitoringController());
    final cameraSetup = Get.find<CameraSetupController>();
    
    monitoring.startMonitoring(
      rtspUrl: cameraSetup.rtspUrl.value,
      configs: configs.values.toList(),
    );
    
    Get.offAllNamed(AppRoutes.dashboard);
  }

  void nextAlert() {
    if (currentConfigIndex.value < selectedDetections.length - 1) {
      currentConfigIndex.value++;
    } else {
      finishSetup();
    }
  }

  bool get isLastAlert => currentConfigIndex.value == selectedDetections.length - 1;
}
