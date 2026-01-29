import 'package:get/get.dart';
import '../controllers/qr_scan_controller.dart';

class QRScanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QRScanController>(() => QRScanController());
  }
}
