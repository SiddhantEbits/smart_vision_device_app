import 'package:get/get.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/device_id_manager.dart';

class QRScanController extends GetxController {
  final deviceId = ''.obs;
  final deviceName = ''.obs;
  final isLoading = true.obs;
  final isScanning = true.obs;
  final isFlashOn = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      isLoading.value = true;
      final id = await DeviceIdManager.getDeviceId();
      final name = await DeviceIdManager.getDeviceName();
      deviceId.value = id;
      deviceName.value = name;
      isLoading.value = false;
    } catch (e) {
      deviceId.value = 'SV-ERROR-LOADING';
      deviceName.value = 'Unknown Device';
      isLoading.value = false;
    }
  }

  void toggleFlash() {
    isFlashOn.value = !isFlashOn.value;
  }

  void resumeScanning() {
    isScanning.value = true;
  }

  void navigateToNext() {
    Get.toNamed(AppRoutes.whatsappSetup);
  }

  void navigateBack() {
    Get.back();
  }
}
