import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/utils/device_id_manager.dart';
import '../data/services/device_firebase_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String? deviceId;
  String? deviceName;
  bool isLoading = true;
  String testResult = '';

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
  }

  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        isLoading = true;
        testResult = 'Loading device info...';
      });

      // Get device info
      final id = await DeviceIdManager.getDeviceId();
      final name = await DeviceIdManager.getDeviceName();
      
      setState(() {
        deviceId = id;
        deviceName = name;
        testResult = 'Device info loaded. Testing Firebase...';
      });

      // Test Firebase save
      await DeviceFirebaseService.saveDevice(
        deviceId: id,
        deviceName: name,
        platform: 'android',
        appVersion: '1.0.0',
        linked: false,
      );

      setState(() {
        isLoading = false;
        testResult = '✅ Firebase save successful!\nDevice ID: $id\nDevice Name: $name';
      });

    } catch (e) {
      setState(() {
        isLoading = false;
        testResult = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            if (deviceId != null) ...[
              Text('Device ID: $deviceId'),
              Text('Device Name: $deviceName'),
            ],
            const SizedBox(height: 16),
            Text(
              'Firebase Test Result:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Text(
                          testResult,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: testResult.contains('✅') ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testFirebaseConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Firebase'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
