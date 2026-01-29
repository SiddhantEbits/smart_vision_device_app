import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';

class WhatsAppSetupController extends GetxController {
  final TextEditingController phoneController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final isValidNumber = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }

  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10) {
      return 'Please enter a valid phone number (at least 10 digits)';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number is too long';
    }
    
    return null;
  }

  void formatPhoneNumber(String value) {
    // Simple phone number formatting
    String formatted = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (formatted.startsWith('91') && formatted.length > 10) {
      // Indian number format: +91 XXXXX XXXXX
      formatted = '+91 ${formatted.substring(2, 7)} ${formatted.substring(7)}';
    } else if (formatted.length >= 10) {
      // General format: +1 XXX XXX XXXX
      final countryCode = formatted.substring(0, 1);
      final firstPart = formatted.substring(1, 4);
      final secondPart = formatted.substring(4, 7);
      final thirdPart = formatted.substring(7, 11);
      formatted = '+$countryCode $firstPart $secondPart $thirdPart';
    } else {
      formatted = '+$formatted';
    }
    
    phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void onPhoneChanged(String value) {
    final isValid = validatePhoneNumber(value) == null;
    if (isValid != isValidNumber.value) {
      isValidNumber.value = isValid;
    }
  }

  void verifyAndContinue() {
    if (formKey.currentState?.validate() ?? false) {
      Get.toNamed(AppRoutes.cameraSetup);
    }
  }

  void skipSetup() {
    Get.toNamed(AppRoutes.cameraSetup);
  }

  void navigateBack() {
    Get.back();
  }
}
