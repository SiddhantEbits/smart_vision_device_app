import 'package:get/get.dart';
import '../controllers/whatsapp_setup_controller.dart';

class WhatsAppSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WhatsAppSetupController>(() => WhatsAppSetupController());
  }
}
