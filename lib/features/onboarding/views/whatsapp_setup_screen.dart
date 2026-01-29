import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/whatsapp_setup_controller.dart';

class WhatsAppSetupScreen extends StatelessWidget {
  const WhatsAppSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WhatsAppSetupController>();

    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: Container(
              width: 300.adaptSize,
              padding: EdgeInsets.all(48.adaptSize),
              color: AppTheme.surfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: controller.navigateBack,
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  SizedBox(height: 48.adaptSize),
                  Text(
                    'WhatsApp\nAlerts',
                    style: TextStyle(
                      fontSize: 32.adaptSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.adaptSize),
                  const Text(
                    'Receive instant notifications with detection clips on your WhatsApp.',
                    style: TextStyle(color: AppTheme.mutedTextColor),
                  ),
                  SizedBox(height: 48.adaptSize),
                ],
              ),
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(64.adaptSize),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter WhatsApp Number',
                      style: TextStyle(
                        fontSize: 24.adaptSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.adaptSize),
                    const Text(
                      'Verification code will be sent to this number.',
                      style: TextStyle(color: AppTheme.mutedTextColor),
                    ),
                    SizedBox(height: 32.adaptSize),
                    
                    Container(
                      width: 400.adaptSize,
                      decoration: AppTheme.glassDecoration,
                      child: TextFormField(
                        controller: controller.phoneController,
                        style: TextStyle(
                          fontSize: 20.adaptSize,
                          letterSpacing: 1.2,
                        ),
                        decoration: InputDecoration(
                          hintText: '+91 99999 99999',
                          hintStyle: TextStyle(
                            color: AppTheme.mutedTextColor.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.phone_android,
                            color: AppTheme.primaryColor,
                            size: 24.adaptSize,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.adaptSize),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 24.adaptSize,
                            vertical: 20.adaptSize,
                          ),
                          errorStyle: TextStyle(
                            fontSize: 12.adaptSize,
                            color: Colors.red,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: controller.validatePhoneNumber,
                        onChanged: controller.onPhoneChanged,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    Row(
                      children: [
                        SizedBox(
                          width: 200.adaptSize,
                          child: Obx(() => ElevatedButton(
                            onPressed: controller.isValidNumber.value 
                                ? controller.verifyAndContinue
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: controller.isValidNumber.value ? AppTheme.successColor : Colors.grey,
                              padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                            ),
                            child: const Text('VERIFY & CONTINUE'),
                          )),
                        ),
                        SizedBox(width: 24.adaptSize),
                        TextButton(
                          onPressed: controller.skipSetup,
                          child: const Text('SKIP FOR NOW'),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32.adaptSize),
                    
                    // Phone number tips
                    Container(
                      width: 400.adaptSize,
                      padding: EdgeInsets.all(16.adaptSize),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.adaptSize),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Tips:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.adaptSize,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(height: 8.adaptSize),
                          Text(
                            '• Enter country code followed by phone number\n'
                            '• Example: +91 98765 43210\n'
                            '• Make sure the number has WhatsApp enabled',
                            style: TextStyle(
                              fontSize: 14.adaptSize,
                              color: AppTheme.mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
