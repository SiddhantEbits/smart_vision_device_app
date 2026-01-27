import 'package:flutter/material.dart';
import 'device_id_manager.dart';

/// Example usage of DeviceIdManager
class DeviceIdExample extends StatefulWidget {
  const DeviceIdExample({super.key});

  @override
  State<DeviceIdExample> createState() => _DeviceIdExampleState();
}

class _DeviceIdExampleState extends State<DeviceIdExample> {
  String? deviceId;
  String? deviceName;
  Map<String, String>? deviceInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  Future<void> _loadDeviceData() async {
    try {
      // Get device ID
      final id = await DeviceIdManager.getDeviceId();
      
      // Get device name
      final name = await DeviceIdManager.getDeviceName();
      
      // Get full device info
      final info = await DeviceIdManager.getDeviceInfo();
      
      setState(() {
        deviceId = id;
        deviceName = name;
        deviceInfo = info;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading device data: $e');
    }
  }

  Future<void> _resetDeviceId() async {
    final newId = await DeviceIdManager.resetDeviceId();
    setState(() {
      deviceId = newId;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Device ID reset to: $newId')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device ID Example'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Information',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device ID: $deviceId'),
                          const SizedBox(height: 8),
                          Text('Device Name: $deviceName'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Full Device Info:'),
                          const SizedBox(height: 8),
                          if (deviceInfo != null)
                            ...deviceInfo!.entries.map(
                              (entry) => Text('${entry.key}: ${entry.value}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  ElevatedButton(
                    onPressed: _resetDeviceId,
                    child: const Text('Reset Device ID'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alternative Methods:'),
                          const SizedBox(height: 8),
                          Text('Simple: ${DeviceIdManager.generateSimpleDeviceId()}'),
                          Text('Timestamp: ${DeviceIdManager.generateTimestampDeviceId()}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
