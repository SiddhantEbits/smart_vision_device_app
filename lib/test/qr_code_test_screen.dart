import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/utils/device_id_manager.dart';

class QRCodeTestScreen extends StatefulWidget {
  const QRCodeTestScreen({super.key});

  @override
  State<QRCodeTestScreen> createState() => _QRCodeTestScreenState();
}

class _QRCodeTestScreenState extends State<QRCodeTestScreen> {
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
      appBar: AppBar(
        title: const Text('Device QR Code Test'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const CircularProgressIndicator()
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: deviceId!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                deviceName!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                deviceId!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loadDeviceInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Generate New Device ID'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
