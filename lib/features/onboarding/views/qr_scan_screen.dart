import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/device_id_manager.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  String? deviceId;
  String? deviceName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final id = await DeviceIdManager.getDeviceId();
      final name = await DeviceIdManager.getDeviceName();
      setState(() {
        deviceId = id;
        deviceName = name;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        deviceId = 'SV-ERROR-LOADING';
        deviceName = 'Unknown Device';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 300.adaptSize,
            padding: EdgeInsets.all(48.adaptSize),
            color: AppTheme.surfaceColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                  ),
                ),
                SizedBox(height: 64.adaptSize),
                Text(
                  'Link\nDevice',
                  style: TextStyle(
                    fontSize: 32.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.adaptSize),
                const Text(
                  'Scan this QR code with your Smart Vision Mobile App to link this device to your account.',
                  style: TextStyle(color: AppTheme.mutedTextColor),
                ),
                SizedBox(height: 64.adaptSize),
              ],
            ),
          ),
          
          // Right Content
          Flexible(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.adaptSize),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.adaptSize),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 40.adaptSize,
                          spreadRadius: 10.adaptSize,
                        ),
                      ],
                    ),
                    child: isLoading
                        ? Container(
                            width: 200.adaptSize,
                            height: 200.adaptSize,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : QrImageView(
                            data: deviceId ?? 'ERROR',
                            version: QrVersions.auto,
                            size: 200.adaptSize,
                          ),
                  ),
                  SizedBox(height: 32.adaptSize),
                  if (!isLoading && deviceId != null) ...[
                    Text(
                      deviceName ?? 'Smart Vision Device',
                      style: TextStyle(
                        fontSize: 20.adaptSize,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.adaptSize),
                    Text(
                      deviceId!,
                      style: TextStyle(
                        fontSize: 14.adaptSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: AppTheme.mutedTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 48.adaptSize),
                  
                  // Mock "Connected" Trigger for Demo
                  SizedBox(
                    width: 240.adaptSize,
                    child: OutlinedButton(
                      onPressed: () => Get.toNamed(AppRoutes.whatsappSetup),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                      ),
                      child: const Text('DEVICE CONNECTED (DEMO)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
