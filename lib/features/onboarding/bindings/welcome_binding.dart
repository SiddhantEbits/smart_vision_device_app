import 'package:get/get.dart';
import '../views/welcome_screen.dart';

class WelcomeBinding extends Bindings {
  @override
  void dependencies() {
    // WelcomeScreen doesn't use a controller
    // It's a simple StatelessWidget
  }
}
