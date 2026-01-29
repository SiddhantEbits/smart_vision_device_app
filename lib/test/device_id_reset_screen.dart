import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/utils/device_id_manager.dart';

class DeviceIdResetScreen extends StatelessWidget {
  const DeviceIdResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Device ID'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.refresh,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Reset Device ID',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This will clear the old device ID and generate a new one with the format SV-SDDMMYY@HHMMSS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final oldDeviceId = await DeviceIdManager.getDeviceId();
                    final newDeviceId = await DeviceIdManager.regenerateDeviceId();
                    
                    Get.snackbar(
                      'Device ID Reset',
                      'Old: $oldDeviceId\nNew: $newDeviceId',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 5),
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to reset device ID: $e',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('RESET DEVICE ID'),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
