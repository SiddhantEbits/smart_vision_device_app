import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Stack(
          children: [
            // Background Decorative Elements
            Positioned(
              right: (-100).adaptSize,
              top: (-100).adaptSize,
              child: Container(
                width: 400.adaptSize,
                height: 400.adaptSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 64.adaptSize),
              child: Row(
                children: [
                  // Left Side: Text and CTA
                  Flexible(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.adaptSize,
                            vertical: 8.adaptSize,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.adaptSize),
                          ),
                          child: Text(
                            'AI POWERED VISION',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.adaptSize),
                        Text(
                          'Transform your Camera\ninto a Smart Guard',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 48.adaptSize,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 16.adaptSize),
                        Text(
                          'Real-time detection, instant alerts, and advanced area monitoring for your security needs.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: 40.adaptSize),
                        SizedBox(
                          width: 240.adaptSize,
                          child: ElevatedButton(
                            onPressed: () => Get.toNamed(AppRoutes.networkConfig),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 20.adaptSize),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('GET STARTED'),
                                SizedBox(width: 8.adaptSize),
                                Icon(Icons.arrow_forward, size: 20.adaptSize),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                  
                  // Right Side: Graphic/Logo
                  Flexible(
                    flex: 1,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(32.adaptSize),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 2.adaptSize,
                          ),
                        ),
                        child: Icon(
                          Icons.visibility_rounded,
                          size: 200.adaptSize,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
