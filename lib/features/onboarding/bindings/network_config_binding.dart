import 'package:get/get.dart';
import '../controllers/network_config_controller.dart';

class NetworkConfigBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NetworkConfigController>(() => NetworkConfigController());
  }
}