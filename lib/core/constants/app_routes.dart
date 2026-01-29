import 'package:get/get.dart';
import '../../features/onboarding/views/welcome_screen.dart';
import '../../features/onboarding/views/network_config_screen.dart';
import '../../features/onboarding/bindings/network_config_binding.dart';
import '../../features/onboarding/views/qr_scan_screen.dart';
import '../../features/onboarding/bindings/qr_scan_binding.dart';
import '../../features/onboarding/views/whatsapp_setup_screen.dart';
import '../../features/onboarding/bindings/whatsapp_setup_binding.dart';
import '../../features/camera_setup/views/camera_setup_screen.dart';
import '../../features/camera_stream/views/camera_stream_screen.dart';
import '../../features/detection_config/views/detection_selection_screen.dart';
import '../../features/detection_config/bindings/detection_selection_binding.dart';
import '../../features/alert_config/views/alert_config_queue_screen.dart';
import '../../features/alert_config/views/roi_setup_screen.dart';
import '../../features/alert_config/views/detection_testing_screen.dart';
import '../../features/alert_config/views/camera_setup_finish_screen.dart';
import '../../features/monitoring/views/monitoring_screen.dart';

class AppRoutes {
  static const welcome = '/welcome';
  static const networkConfig = '/network-config';
  static const qrScan = '/qr-scan';
  static const whatsappSetup = '/whatsapp-setup';
  static const cameraSetup = '/camera-setup';
  static const cameraStream = '/camera-stream';
  static const detectionSelection = '/detection-selection';
  static const alertConfig = '/alert-config';
  static const alertConfigQueue = '/alert-config-queue';
  static const roiSetup = '/roi-setup';
  static const detectionTesting = '/detection-testing';
  static const cameraSetupFinish = '/camera-setup-finish';
  static const dashboard = '/dashboard';

  static final pages = [
    GetPage(name: welcome, page: () => const WelcomeScreen()),
    GetPage(
      name: networkConfig, 
      page: () => const NetworkConfigScreen(),
      binding: NetworkConfigBinding(),
    ),
    GetPage(
      name: qrScan, 
      page: () => const QRScanScreen(),
      binding: QRScanBinding(),
    ),
    GetPage(
      name: whatsappSetup, 
      page: () => const WhatsAppSetupScreen(),
      binding: WhatsAppSetupBinding(),
    ),
    GetPage(name: cameraSetup, page: () => CameraSetupScreen()),
    GetPage(name: cameraStream, page: () => const CameraStreamScreen()),
    GetPage(
      name: detectionSelection, 
      page: () => const DetectionSelectionScreen(),
      binding: DetectionSelectionBinding(),
    ),
    GetPage(name: alertConfig, page: () => const AlertConfigQueueScreen()),
    GetPage(name: alertConfigQueue, page: () => const AlertConfigQueueScreen()),
    GetPage(name: roiSetup, page: () => const RoiSetupScreen()),
    GetPage(name: detectionTesting, page: () => const DetectionTestingScreen()),
    GetPage(name: cameraSetupFinish, page: () => const CameraSetupFinishScreen()),
    GetPage(name: dashboard, page: () => const MonitoringScreen()),
  ];
}
