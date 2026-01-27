import 'package:get/get.dart';
import '../../features/onboarding/views/welcome_screen.dart';
import '../../features/onboarding/views/network_config_screen.dart';
import '../../features/onboarding/views/qr_scan_screen.dart';
import '../../features/onboarding/views/whatsapp_setup_screen.dart';
import '../../features/camera_setup/views/camera_setup_screen.dart';
import '../../features/detection_config/views/detection_selection_screen.dart';
import '../../features/alert_config/views/alert_config_queue_screen.dart';
import '../../features/monitoring/views/monitoring_screen.dart';

class AppRoutes {
  static const welcome = '/welcome';
  static const networkConfig = '/network-config';
  static const qrScan = '/qr-scan';
  static const whatsappSetup = '/whatsapp-setup';
  static const cameraSetup = '/camera-setup';
  static const detectionSelection = '/detection-selection';
  static const alertConfigQueue = '/alert-config-queue';
  static const dashboard = '/dashboard';

  static final pages = [
    GetPage(name: welcome, page: () => const WelcomeScreen()),
    GetPage(name: networkConfig, page: () => const NetworkConfigScreen()),
    GetPage(name: qrScan, page: () => const QRScanScreen()),
    GetPage(name: whatsappSetup, page: () => const WhatsAppSetupScreen()),
    GetPage(name: cameraSetup, page: () => const CameraSetupScreen()),
    GetPage(name: detectionSelection, page: () => const DetectionSelectionScreen()),
    GetPage(name: alertConfigQueue, page: () => const AlertConfigQueueScreen()),
    GetPage(name: dashboard, page: () => const MonitoringScreen()),
  ];
}
