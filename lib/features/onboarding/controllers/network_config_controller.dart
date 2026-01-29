import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/network_connectivity_service.dart';

class NetworkConfigController extends GetxController {
  // Network scanning state
  final isScanning = false.obs;
  final networks = <WiFiNetworkInfo>[].obs;
  final connectedNetwork = Rx<WiFiNetworkInfo?>(null);
  final isConnecting = false.obs;
  final connectionStatus = ''.obs;
  
  // Network status monitoring
  final networkStatus = NetworkStatus.disconnected.obs;
  final internetStatus = InternetStatus.unknown.obs;
  final lanStatus = Rx<LANStatus?>(null);
  
  // Stream subscriptions
  StreamSubscription<List<WiFiNetworkInfo>>? networksSubscription;
  StreamSubscription<NetworkStatus>? networkStatusSubscription;
  StreamSubscription<InternetStatus>? internetStatusSubscription;
  StreamSubscription<LANStatus>? lanStatusSubscription;
  
  final NetworkConnectivityService _networkService = NetworkConnectivityService();

  @override
  void onInit() {
    super.onInit();
    _initializeNetworkService();
  }
  
  void _initializeNetworkService() {
    debugPrint('[CONTROLLER] Initializing network service...');
    
    // Initialize the network service
    _networkService.initialize();
    
    // Subscribe to network streams
    networksSubscription = _networkService.networksStream.listen((networks) {
      debugPrint('[CONTROLLER] Networks stream updated: ${networks.length} networks');
      debugPrint('[CONTROLLER] Networks data: ${networks.map((n) => n.ssid).toList()}');
      
      // Clear and assign properly
      networks.clear();
      networks.addAll(networks);
      
      connectedNetwork.value = _networkService.connectedNetwork;
      isScanning.value = false;
      connectionStatus.value = 'Found ${networks.length} WiFi networks';
      debugPrint('[CONTROLLER] Networks list updated: ${networks.length} items');
      debugPrint('[CONTROLLER] Connected network: ${connectedNetwork.value?.ssid}');
      debugPrint('[CONTROLLER] UI networks count: ${networks.length}');
    });
    
    networkStatusSubscription = _networkService.networkStatusStream.listen((status) {
      debugPrint('[CONTROLLER] Network status: $status');
      networkStatus.value = status;
      _updateConnectionStatus();
    });
    
    internetStatusSubscription = _networkService.internetStatusStream.listen((status) {
      debugPrint('[CONTROLLER] Internet status: $status');
      internetStatus.value = status;
      _updateConnectionStatus();
    });
    
    lanStatusSubscription = _networkService.lanStatusStream.listen((status) {
      debugPrint('[CONTROLLER] LAN status: ${status?.isConnected}');
      lanStatus.value = status;
    });
    
    // Initial load with delay to ensure service is ready
    Future.delayed(Duration(milliseconds: 500), () {
      debugPrint('[CONTROLLER] Triggering initial network load...');
      loadNetworks();
    });
  }
  
  void _updateConnectionStatus() {
    if (connectedNetwork.value != null) {
      switch (internetStatus.value) {
        case InternetStatus.connected:
          connectionStatus.value = 'Connected to ${connectedNetwork.value!.ssid} with Internet access';
          break;
        case InternetStatus.disconnected:
          connectionStatus.value = 'Connected to ${connectedNetwork.value!.ssid} but no Internet access';
          break;
        case InternetStatus.checking:
          connectionStatus.value = 'Checking Internet connectivity...';
          break;
        default:
          connectionStatus.value = 'Connected to ${connectedNetwork.value!.ssid}';
      }
    } else {
      switch (networkStatus.value) {
        case NetworkStatus.connecting:
          connectionStatus.value = 'Connecting to network...';
          break;
        case NetworkStatus.connected:
          connectionStatus.value = 'Network connected';
          break;
        case NetworkStatus.disconnected:
          connectionStatus.value = 'Disconnected from network';
          break;
        default:
          connectionStatus.value = 'Network status unknown';
      }
    }
  }
  
  @override
  void onClose() {
    networksSubscription?.cancel();
    networkStatusSubscription?.cancel();
    internetStatusSubscription?.cancel();
    lanStatusSubscription?.cancel();
    _networkService.dispose();
    super.onClose();
  }

  Future<void> loadNetworks() async {
    if (isScanning.value) return;
    
    isScanning.value = true;
    connectionStatus.value = 'Scanning for WiFi networks...';
    debugPrint('[CONTROLLER] Starting network scan...');

    try {
      await _networkService.refreshNetworks();
      debugPrint('[CONTROLLER] Network scan completed');
      
      // Force update after a short delay
      Future.delayed(Duration(milliseconds: 1000), () {
        final currentNetworks = _networkService.networks;
        debugPrint('[CONTROLLER] Force updating networks: ${currentNetworks.length} items');
        debugPrint('[CONTROLLER] Force networks data: ${currentNetworks.map((n) => n.ssid).toList()}');
        
        // Clear and assign properly
        networks.clear();
        networks.addAll(currentNetworks);
        
        connectedNetwork.value = _networkService.connectedNetwork;
        isScanning.value = false;
        connectionStatus.value = 'Found ${currentNetworks.length} WiFi networks';
        debugPrint('[CONTROLLER] Force updated networks list: ${networks.length} items');
      });
    } catch (e) {
      debugPrint('[CONTROLLER] Error scanning networks: $e');
      connectionStatus.value = 'Error scanning networks: ${e.toString()}';
      isScanning.value = false;
    }
  }

  Future<void> connectToNetwork(WiFiNetworkInfo network) async {
    if (network.isSecured) {
      // For secured networks, show password dialog
      _showPasswordDialog(network);
    } else {
      await _connectToUnsecuredNetwork(network);
    }
  }

  void _showPasswordDialog(WiFiNetworkInfo network) {
    final passwordController = TextEditingController();
    bool showPassword = false;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_lock, color: Get.theme.primaryColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connect to ${network.ssid}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This network is secured. Please enter the password.\n\nNetwork Details:\n• Band: ${network.band}\n• Channel: ${network.channel}\n• Security: ${network.securityType}',
                  style: TextStyle(color: Get.theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
                ),
                SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setState) => TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter WiFi password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Signal Strength: ${network.signalStrength}%',
                  style: TextStyle(
                    color: Get.theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('CANCEL'),
          ),
          Obx(() => ElevatedButton(
            onPressed: isConnecting.value
              ? null
              : () {
                  Get.back();
                  connectToSecuredNetwork(network, passwordController.text);
                },
            child: isConnecting.value
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('CONNECT'),
          )),
        ],
      ),
    );
  }

  Future<void> connectToSecuredNetwork(WiFiNetworkInfo network, String password) async {
    isConnecting.value = true;
    connectionStatus.value = 'Connecting to ${network.ssid}...';

    try {
      bool connected = await _networkService.connectToNetwork(network, password: password);

      if (connected) {
        _showConnectionSuccess(network.ssid);
      } else {
        throw Exception('Failed to connect to network');
      }
    } catch (e) {
      _showConnectionError(network.ssid);
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> _connectToUnsecuredNetwork(WiFiNetworkInfo network) async {
    isConnecting.value = true;
    connectionStatus.value = 'Connecting to ${network.ssid}...';

    try {
      bool connected = await _networkService.connectToNetwork(network);

      if (connected) {
        _showConnectionSuccess(network.ssid);
      } else {
        throw Exception('Failed to connect to network');
      }
    } catch (e) {
      _showConnectionError(network.ssid);
    } finally {
      isConnecting.value = false;
    }
  }

  void _showConnectionSuccess(String ssid) {
    Get.snackbar(
      'Connection Successful',
      'Successfully connected to $ssid',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Colors.white,
      icon: Icon(Icons.check_circle, color: Colors.white),
    );
  }

  void _showConnectionError(String ssid) {
    Get.snackbar(
      'Connection Failed',
      'Failed to connect to $ssid. Please check password.',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      icon: Icon(Icons.error, color: Colors.white),
    );
  }

  Future<void> disconnectFromNetwork() async {
    if (connectedNetwork.value == null) return;

    isConnecting.value = true;
    connectionStatus.value = 'Disconnecting from ${connectedNetwork.value!.ssid}...';

    try {
      bool disconnected = await _networkService.disconnectFromNetwork();

      if (disconnected) {
        Get.snackbar(
          'Disconnected',
          'Successfully disconnected from WiFi',
          backgroundColor: Colors.grey,
          colorText: Colors.white,
          icon: Icon(Icons.wifi_off, color: Colors.white),
        );
      } else {
        throw Exception('Failed to disconnect');
      }
    } catch (e) {
      Get.snackbar(
        'Disconnect Failed',
        'Could not disconnect from WiFi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: Icon(Icons.error, color: Colors.white),
      );
    } finally {
      isConnecting.value = false;
    }
  }

  void forceInternetCheck() {
    _networkService.forceInternetCheck();
    Get.snackbar(
      'Checking Internet',
      'Checking internet connectivity...',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Colors.white,
      icon: Icon(Icons.sync, color: Colors.white),
      duration: Duration(seconds: 2),
    );
  }

  void forceLANCheck() {
    _networkService.forceLANCheck();
    Get.snackbar(
      'Checking LAN',
      'Checking LAN connectivity...',
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Colors.white,
      icon: Icon(Icons.sync, color: Colors.white),
      duration: Duration(seconds: 2),
    );
  }

  void navigateToNext() {
    if (connectedNetwork.value != null) {
      Get.toNamed('/qr-scan');
    } else {
      Get.snackbar(
        'No Connection',
        'Please connect to a network first',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: Icon(Icons.warning, color: Colors.white),
      );
    }
  }

  void navigateBack() {
    Get.back();
  }

  // Helper methods for status display
  Color getConnectionStatusColor() {
    if (internetStatus.value == InternetStatus.connected) return Colors.green;
    if (internetStatus.value == InternetStatus.disconnected && connectedNetwork.value != null) return Colors.orange;
    if (networkStatus.value == NetworkStatus.connecting) return Colors.blue;
    if (networkStatus.value == NetworkStatus.connected) return Colors.green;
    return Colors.red;
  }
  
  IconData getConnectionStatusIcon() {
    if (internetStatus.value == InternetStatus.connected) return Icons.check_circle;
    if (internetStatus.value == InternetStatus.checking) return Icons.sync;
    if (networkStatus.value == NetworkStatus.connecting) return Icons.sync;
    if (networkStatus.value == NetworkStatus.connected) return Icons.wifi;
    return Icons.wifi_off;
  }
  
  String _getInternetStatusText() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return 'Connected';
      case InternetStatus.disconnected:
        return 'No Internet';
      case InternetStatus.checking:
        return 'Checking';
      default:
        return 'Unknown';
    }
  }
  
  String _getInternetStatusSubtitle() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return 'Internet access available';
      case InternetStatus.disconnected:
        return 'Cannot reach internet';
      case InternetStatus.checking:
        return 'Testing connectivity...';
      default:
        return 'Status unknown';
    }
  }
  
  IconData _getInternetStatusIcon() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return Icons.public;
      case InternetStatus.disconnected:
        return Icons.public_off;
      case InternetStatus.checking:
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getLANStatusText() {
    if (lanStatus.value?.isConnected == true) {
      return 'Connected';
    } else {
      return 'Disconnected';
    }
  }
  
  String _getLANStatusSubtitle() {
    if (lanStatus.value?.isConnected == true) {
      return 'IP: ${lanStatus.value?.localIP ?? 'Unknown'}';
    } else {
      return 'No local network';
    }
  }
  
  IconData _getLANStatusIcon() {
    if (lanStatus.value?.isConnected == true) {
      return Icons.router;
    } else {
      return Icons.router_outlined;
    }
  }

  Color getSignalColor(int signalStrength) {
    if (signalStrength >= 70) return Colors.green;
    if (signalStrength >= 40) return Colors.orange;
    return Colors.red;
  }
  
  // Helper methods for status display
  String getInternetStatusText() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return 'Connected';
      case InternetStatus.disconnected:
        return 'No Internet';
      case InternetStatus.checking:
        return 'Checking';
      default:
        return 'Unknown';
    }
  }
  
  String getInternetStatusSubtitle() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return 'Internet access available';
      case InternetStatus.disconnected:
        return 'Cannot reach internet';
      case InternetStatus.checking:
        return 'Testing connectivity...';
      default:
        return 'Status unknown';
    }
  }
  
  IconData getInternetStatusIcon() {
    switch (internetStatus.value) {
      case InternetStatus.connected:
        return Icons.public;
      case InternetStatus.disconnected:
        return Icons.public_off;
      case InternetStatus.checking:
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }
  
  String getLANStatusText() {
    if (lanStatus.value?.isConnected == true) {
      return 'Connected';
    } else {
      return 'Disconnected';
    }
  }
  
  String getLANStatusSubtitle() {
    if (lanStatus.value?.isConnected == true) {
      return 'IP: ${lanStatus.value?.localIP ?? 'Unknown'}';
    } else {
      return 'No local network';
    }
  }
  
  IconData getLANStatusIcon() {
    if (lanStatus.value?.isConnected == true) {
      return Icons.router;
    } else {
      return Icons.router_outlined;
    }
  }
}
