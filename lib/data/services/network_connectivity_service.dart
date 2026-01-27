import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

// Enhanced WiFi network model with detailed information
class WiFiNetworkInfo {
  final String ssid;
  final String? bssid;
  final int signalStrength;
  final int frequency;
  final String band;
  final bool isSecured;
  final String securityType;
  final int channel;
  final bool isConnected;
  final String? ipAddress;
  final String? gateway;
  final String? dns1;
  final String? dns2;
  final DateTime lastSeen;

  WiFiNetworkInfo({
    required this.ssid,
    this.bssid,
    required this.signalStrength,
    required this.frequency,
    required this.band,
    required this.isSecured,
    required this.securityType,
    required this.channel,
    this.isConnected = false,
    this.ipAddress,
    this.gateway,
    this.dns1,
    this.dns2,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory WiFiNetworkInfo.fromScanResult(dynamic result, String? currentSSID) {
    String ssid = '';
    String? bssid;
    int signalStrength = 50;
    int frequency = 2400;
    String band = '2.4 GHz';
    bool isSecured = false;
    String securityType = 'Open';
    int channel = 1;
    
    debugPrint('[NETWORK] Parsing WiFi result: $result');
    debugPrint('[NETWORK] Result type: ${result.runtimeType}');
    
    if (result is Map) {
      ssid = result['ssid']?.toString() ?? 'Unknown Network';
      bssid = result['bssid']?.toString();
      
      // Signal strength (RSSI)
      int? rssi = result['level'] as int?;
      signalStrength = _calculateSignalStrength(rssi);
      
      // Frequency and band calculation
      int? freq = result['frequency'] as int?;
      if (freq != null) {
        frequency = freq;
        band = freq > 5000 ? '5 GHz' : '2.4 GHz';
        channel = _frequencyToChannel(freq);
      }
      
      // Security capabilities
      String capabilities = result['capabilities']?.toString() ?? '';
      isSecured = capabilities.isNotEmpty;
      securityType = _parseSecurityType(capabilities);
    } else if (result.toString().contains('WiFiNetwork') || result.toString().contains('WifiNetwork')) {
      // Handle WiFiNetwork object - try to extract SSID using reflection or string parsing
      String resultStr = result.toString();
      debugPrint('[NETWORK] WiFiNetwork object string: $resultStr');
      
      // Try to extract SSID from the string representation
      if (resultStr.contains('ssid:')) {
        int ssidStart = resultStr.indexOf('ssid:') + 5;
        int ssidEnd = resultStr.indexOf(',', ssidStart);
        if (ssidEnd == -1) ssidEnd = resultStr.indexOf('}', ssidStart);
        if (ssidEnd == -1) ssidEnd = resultStr.length;
        ssid = resultStr.substring(ssidStart, ssidEnd).trim().replaceAll("'", "").replaceAll('"', '');
      } else {
        // Fallback: try to get SSID via wifi_iot API directly
        ssid = 'Unknown Network';
      }
      
      // Set default values for other properties
      signalStrength = 50;
      isSecured = true; // Assume secured for unknown networks
      securityType = 'Unknown';
    } else {
      ssid = result.toString();
    }
    
    debugPrint('[NETWORK] Parsed SSID: "$ssid"');
    
    return WiFiNetworkInfo(
      ssid: ssid.isNotEmpty ? ssid : 'Unknown Network',
      bssid: bssid,
      signalStrength: signalStrength,
      frequency: frequency,
      band: band,
      isSecured: isSecured,
      securityType: securityType,
      channel: channel,
      isConnected: ssid == currentSSID,
    );
  }

  static int _calculateSignalStrength(int? rssi) {
    if (rssi == null) return 50;
    if (rssi <= -100) return 0;
    if (rssi >= -30) return 100;
    return ((rssi + 100) * 100 ~/ 70);
  }

  static String _parseSecurityType(String capabilities) {
    if (capabilities.contains('WPA3')) return 'WPA3';
    if (capabilities.contains('WPA2')) return 'WPA2';
    if (capabilities.contains('WPA')) return 'WPA';
    if (capabilities.contains('WEP')) return 'WEP';
    return 'Open';
  }

  static int _frequencyToChannel(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      return ((frequency - 2412) ~/ 5) + 1;
    } else if (frequency >= 5170 && frequency <= 5865) {
      return ((frequency - 5170) ~/ 5) + 34;
    }
    return 1;
  }

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'signalStrength': signalStrength,
      'frequency': frequency,
      'band': band,
      'isSecured': isSecured,
      'securityType': securityType,
      'channel': channel,
      'isConnected': isConnected,
      'ipAddress': ipAddress,
      'gateway': gateway,
      'dns1': dns1,
      'dns2': dns2,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }
}

// Network connectivity status
enum NetworkStatus {
  disconnected,
  connecting,
  connected,
  limited,
  noInternet,
}

// Internet connectivity status
enum InternetStatus {
  unknown,
  connected,
  disconnected,
  checking,
}

// LAN connectivity status
class LANStatus {
  final bool isConnected;
  final String? localIP;
  final String? gateway;
  final String? subnetMask;
  final List<String> dnsServers;
  final bool hasDHCP;
  final DateTime lastChecked;

  LANStatus({
    required this.isConnected,
    this.localIP,
    this.gateway,
    this.subnetMask,
    this.dnsServers = const [],
    this.hasDHCP = true,
    DateTime? lastChecked,
  }) : lastChecked = lastChecked ?? DateTime.now();
}

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Stream controllers
  final StreamController<List<WiFiNetworkInfo>> _networksController = 
      StreamController<List<WiFiNetworkInfo>>.broadcast();
  final StreamController<NetworkStatus> _networkStatusController = 
      StreamController<NetworkStatus>.broadcast();
  final StreamController<InternetStatus> _internetStatusController = 
      StreamController<InternetStatus>.broadcast();
  final StreamController<LANStatus> _lanStatusController = 
      StreamController<LANStatus>.broadcast();

  // Public streams
  Stream<List<WiFiNetworkInfo>> get networksStream => _networksController.stream;
  Stream<NetworkStatus> get networkStatusStream => _networkStatusController.stream;
  Stream<InternetStatus> get internetStatusStream => _internetStatusController.stream;
  Stream<LANStatus> get lanStatusStream => _lanStatusController.stream;

  // Current state
  List<WiFiNetworkInfo> _networks = [];
  NetworkStatus _networkStatus = NetworkStatus.disconnected;
  InternetStatus _internetStatus = InternetStatus.unknown;
  LANStatus? _lanStatus;
  WiFiNetworkInfo? _connectedNetwork;
  
  // Timer for periodic checks
  Timer? _internetCheckTimer;
  Timer? _lanCheckTimer;

  // Getters
  List<WiFiNetworkInfo> get networks => List.unmodifiable(_networks);
  NetworkStatus get networkStatus => _networkStatus;
  InternetStatus get internetStatus => _internetStatus;
  LANStatus? get lanStatus => _lanStatus;
  WiFiNetworkInfo? get connectedNetwork => _connectedNetwork;

  void initialize() {
    debugPrint('[NETWORK] Initializing network connectivity service');
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Start periodic checks
    _startPeriodicChecks();
    
    // Initial scan
    _scanNetworks();
    _checkInternetConnectivity();
    _checkLANStatus();
  }

  void dispose() {
    _internetCheckTimer?.cancel();
    _lanCheckTimer?.cancel();
    _networksController.close();
    _networkStatusController.close();
    _internetStatusController.close();
    _lanStatusController.close();
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    debugPrint('[NETWORK] Connectivity changed: $results');
    
    if (results.contains(ConnectivityResult.wifi)) {
      _updateNetworkStatus(NetworkStatus.connecting);
      await _scanNetworks();
      await _checkInternetConnectivity();
      await _checkLANStatus();
    } else if (results.contains(ConnectivityResult.ethernet)) {
      _updateNetworkStatus(NetworkStatus.connected);
      await _checkInternetConnectivity();
      await _checkLANStatus();
    } else {
      _updateNetworkStatus(NetworkStatus.disconnected);
      _updateInternetStatus(InternetStatus.disconnected);
      _lanStatus = LANStatus(isConnected: false);
      _lanStatusController.add(_lanStatus!);
    }
  }

  Future<void> _scanNetworks() async {
    try {
      debugPrint('[NETWORK] Scanning for WiFi networks...');
      
      // Ensure WiFi is enabled
      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
        await WiFiForIoTPlugin.setEnabled(true);
        await Future.delayed(Duration(seconds: 2)); // Wait for WiFi to enable
      }

      // Get current connected network
      String? currentSSID = await WiFiForIoTPlugin.getSSID();
      debugPrint('[NETWORK] Current SSID: $currentSSID');

      // Scan for networks
      List<dynamic> wifiResults = await WiFiForIoTPlugin.loadWifiList();
      debugPrint('[NETWORK] Found ${wifiResults.length} raw WiFi results');
      
      // Convert to enhanced network info with better error handling
      List<WiFiNetworkInfo> networks = [];
      
      for (int i = 0; i < wifiResults.length; i++) {
        try {
          var result = wifiResults[i];
          debugPrint('[NETWORK] Processing result $i: ${result.runtimeType} - $result');
          
          WiFiNetworkInfo networkInfo = WiFiNetworkInfo.fromScanResult(result, currentSSID);
          debugPrint('[NETWORK] Parsed network $i: SSID="${networkInfo.ssid}"');
          
          // Only add networks with valid SSIDs
          if (networkInfo.ssid.isNotEmpty && networkInfo.ssid != 'Unknown Network') {
            networks.add(networkInfo);
          }
        } catch (e) {
          debugPrint('[NETWORK] Error processing network result $i: $e');
          // Continue processing other networks
        }
      }

      // If no valid networks found, try alternative approach
      if (networks.isEmpty && wifiResults.isNotEmpty) {
        debugPrint('[NETWORK] No valid networks parsed, trying fallback approach...');
        for (var result in wifiResults) {
          try {
            // Try different property names that might contain the SSID
            String ssid = '';
            if (result is Map) {
              ssid = result['SSID']?.toString() ?? 
                     result['ssid']?.toString() ?? 
                     result['name']?.toString() ?? 
                     result['networkName']?.toString() ?? 
                     'Unknown Network';
            } else {
              // Last resort - use toString but clean it up
              ssid = result.toString()
                  .replaceAll('Instance of ', '')
                  .replaceAll('WiFiNetwork', '')
                  .replaceAll('WifiNetwork', '')
                  .replaceAll(':', '')
                  .trim();
              
              if (ssid.isEmpty || ssid == 'Instance of') {
                ssid = 'Network_${networks.length + 1}';
              }
            }
            
            if (ssid.isNotEmpty && ssid != 'Unknown Network') {
              networks.add(WiFiNetworkInfo(
                ssid: ssid,
                signalStrength: 50,
                frequency: 2400,
                band: '2.4 GHz',
                isSecured: true,
                securityType: 'Unknown',
                channel: 1,
                isConnected: ssid == currentSSID,
              ));
            }
          } catch (e) {
            debugPrint('[NETWORK] Fallback parsing failed: $e');
          }
        }
      }

      // Sort by signal strength (descending)
      networks.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));

      // Update connected network info
      if (currentSSID != null) {
        _connectedNetwork = networks.firstWhere(
          (network) => network.ssid == currentSSID,
          orElse: () => WiFiNetworkInfo(
            ssid: currentSSID!,
            signalStrength: 100,
            frequency: 2400,
            band: '2.4 GHz',
            isSecured: false,
            securityType: 'Unknown',
            channel: 1,
            isConnected: true,
          ),
        );
        
        // Get detailed connection info
        await _updateConnectedNetworkInfo();
      }

      _networks = networks;
      _networksController.add(_networks);
      
      debugPrint('[NETWORK] Successfully processed ${networks.length} networks');
      for (var network in networks) {
        debugPrint('[NETWORK] - ${network.ssid} (${network.signalStrength}% ${network.band})');
      }
      
      if (_connectedNetwork != null) {
        debugPrint('[NETWORK] Connected to: ${_connectedNetwork!.ssid}');
        _updateNetworkStatus(NetworkStatus.connected);
      }
      
    } catch (e) {
      debugPrint('[NETWORK] Error scanning networks: $e');
    }
  }

  Future<void> _updateConnectedNetworkInfo() async {
    if (_connectedNetwork == null) return;

    try {
      // Get IP address
      String? ipAddress = await WiFiForIoTPlugin.getIP();
      
      // Get network info using Android-specific methods if available
      String? gateway;
      String? dns1;
      String? dns2;

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 21) {
          // Use network interface info for Android 5.0+
          var interfaces = await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);
          for (var interface in interfaces) {
            if (interface.name == 'wlan0' || interface.name == 'eth0') {
              for (var addr in interface.addresses) {
                if (addr.type == InternetAddressType.IPv4) {
                  ipAddress = addr.address;
                  break;
                }
              }
            }
          }
        }
      }

      // Update connected network with IP info
      _connectedNetwork = WiFiNetworkInfo(
        ssid: _connectedNetwork!.ssid,
        bssid: _connectedNetwork!.bssid,
        signalStrength: _connectedNetwork!.signalStrength,
        frequency: _connectedNetwork!.frequency,
        band: _connectedNetwork!.band,
        isSecured: _connectedNetwork!.isSecured,
        securityType: _connectedNetwork!.securityType,
        channel: _connectedNetwork!.channel,
        isConnected: true,
        ipAddress: ipAddress,
        gateway: gateway,
        dns1: dns1,
        dns2: dns2,
        lastSeen: DateTime.now(),
      );

    } catch (e) {
      debugPrint('[NETWORK] Error updating connected network info: $e');
    }
  }

  Future<void> _checkInternetConnectivity() async {
    _updateInternetStatus(InternetStatus.checking);
    
    try {
      // Test connectivity to multiple endpoints
      final endpoints = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://8.8.8.8', // DNS
      ];
      
      bool hasInternet = false;
      
      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse(endpoint),
          ).timeout(Duration(seconds: 5));
          
          if (response.statusCode >= 200 && response.statusCode < 400) {
            hasInternet = true;
            break;
          }
        } catch (e) {
          debugPrint('[NETWORK] Endpoint $endpoint failed: $e');
          continue;
        }
      }
      
      _updateInternetStatus(hasInternet ? InternetStatus.connected : InternetStatus.disconnected);
      
    } catch (e) {
      debugPrint('[NETWORK] Internet connectivity check failed: $e');
      _updateInternetStatus(InternetStatus.disconnected);
    }
  }

  Future<void> _checkLANStatus() async {
    try {
      String? localIP;
      String? gateway;
      String? subnetMask;
      List<String> dnsServers = [];
      bool hasDHCP = true;
      bool isActuallyConnected = false;

      debugPrint('[NETWORK] Checking LAN status...');

      // Get network interface information
      var interfaces = await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);
      debugPrint('[NETWORK] Found ${interfaces.length} network interfaces');
      
      for (var interface in interfaces) {
        debugPrint('[NETWORK] Interface: ${interface.name} - ${interface.addresses}');
        
        // Check for WiFi (wlan0) and Ethernet (eth0) interfaces
        if (interface.name == 'wlan0' || interface.name == 'eth0' || interface.name.contains('wlan') || interface.name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              localIP = addr.address;
              debugPrint('[NETWORK] Found IPv4 address: $localIP on interface ${interface.name}');
              
              // Check if it's a valid private IP address (indicating LAN connection)
              if (_isPrivateIP(localIP)) {
                isActuallyConnected = true;
                debugPrint('[NETWORK] Valid private IP detected: $localIP');
              }
              break;
            }
          }
          
          // Try to get additional interface info
          try {
            // For Android, we can try to get more network info
            if (Platform.isAndroid) {
              // Use WiFiForIoTPlugin to get current IP as fallback
              String? wifiIP = await WiFiForIoTPlugin.getIP();
              if (wifiIP != null && wifiIP.isNotEmpty && _isPrivateIP(wifiIP)) {
                localIP = wifiIP;
                isActuallyConnected = true;
                debugPrint('[NETWORK] WiFi IP detected: $wifiIP');
              }
            }
          } catch (e) {
            debugPrint('[NETWORK] Error getting WiFi IP: $e');
          }
        }
      }

      // Try to determine gateway and DNS if connected
      if (isActuallyConnected && localIP != null) {
        try {
          // Parse the IP to determine typical gateway
          List<String> ipParts = localIP.split('.');
          if (ipParts.length == 4) {
            gateway = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.1';
            debugPrint('[NETWORK] Determined gateway: $gateway');
          }
          
          // Common DNS servers
          dnsServers = ['8.8.8.8', '8.8.4.4', '1.1.1.1'];
          
          // Try to ping the gateway to verify LAN connectivity
          bool canReachGateway = await _canReachHost(gateway ?? '192.168.1.1');
          if (!canReachGateway) {
            debugPrint('[NETWORK] Cannot reach gateway, marking LAN as disconnected');
            isActuallyConnected = false;
          } else {
            debugPrint('[NETWORK] Successfully reached gateway: $gateway');
          }
          
        } catch (e) {
          debugPrint('[NETWORK] Error determining network details: $e');
          // If we can't determine details but have a private IP, still consider it connected
        }
      }

      _lanStatus = LANStatus(
        isConnected: isActuallyConnected,
        localIP: localIP,
        gateway: gateway,
        subnetMask: subnetMask,
        dnsServers: dnsServers,
        hasDHCP: hasDHCP,
      );
      
      _lanStatusController.add(_lanStatus!);
      
      debugPrint('[NETWORK] LAN Status Updated:');
      debugPrint('[NETWORK] - Connected: ${isActuallyConnected}');
      debugPrint('[NETWORK] - IP: $localIP');
      debugPrint('[NETWORK] - Gateway: $gateway');
      debugPrint('[NETWORK] - DNS: $dnsServers');
      
    } catch (e) {
      debugPrint('[NETWORK] Error checking LAN status: $e');
      _lanStatus = LANStatus(isConnected: false);
      _lanStatusController.add(_lanStatus!);
    }
  }

  // Helper method to check if an IP is a private/local network IP
  bool _isPrivateIP(String? ip) {
    if (ip == null || ip.isEmpty) return false;
    
    try {
      var addr = InternetAddress(ip);
      if (addr.type != InternetAddressType.IPv4) return false;
      
      List<String> parts = ip.split('.');
      if (parts.length != 4) return false;
      
      int first = int.parse(parts[0]);
      int second = int.parse(parts[1]);
      
      // 10.0.0.0 - 10.255.255.255 (Class A private)
      if (first == 10) return true;
      
      // 172.16.0.0 - 172.31.255.255 (Class B private)
      if (first == 172 && second >= 16 && second <= 31) return true;
      
      // 192.168.0.0 - 192.168.255.255 (Class C private)
      if (first == 192 && second == 168) return true;
      
      // 169.254.0.0 - 169.254.255.255 (APIPA - Link-local)
      if (first == 169 && second == 254) return true;
      
      return false;
    } catch (e) {
      debugPrint('[NETWORK] Error parsing IP $ip: $e');
      return false;
    }
  }

  // Helper method to test if we can reach a host (basic connectivity test)
  Future<bool> _canReachHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('[NETWORK] Cannot reach host $host: $e');
      return false;
    }
  }

  void _startPeriodicChecks() {
    // Check internet connectivity every 30 seconds
    _internetCheckTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_networkStatus == NetworkStatus.connected) {
        _checkInternetConnectivity();
      }
    });

    // Check LAN status every 60 seconds
    _lanCheckTimer = Timer.periodic(Duration(seconds: 60), (_) {
      if (_networkStatus == NetworkStatus.connected) {
        _checkLANStatus();
      }
    });
  }

  void _updateNetworkStatus(NetworkStatus status) {
    if (_networkStatus != status) {
      _networkStatus = status;
      _networkStatusController.add(_networkStatus);
      debugPrint('[NETWORK] Network status updated: $status');
    }
  }

  void _updateInternetStatus(InternetStatus status) {
    if (_internetStatus != status) {
      _internetStatus = status;
      _internetStatusController.add(_internetStatus);
      debugPrint('[NETWORK] Internet status updated: $status');
    }
  }

  // Public methods for UI interaction
  Future<bool> connectToNetwork(WiFiNetworkInfo network, {String? password}) async {
    try {
      _updateNetworkStatus(NetworkStatus.connecting);
      
      bool connected = await WiFiForIoTPlugin.connect(
        network.ssid,
        password: password ?? '',
      );

      if (connected) {
        await Future.delayed(Duration(seconds: 3)); // Wait for connection to establish
        await _scanNetworks(); // Refresh network list
        await _checkInternetConnectivity();
        await _checkLANStatus();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[NETWORK] Error connecting to ${network.ssid}: $e');
      _updateNetworkStatus(NetworkStatus.disconnected);
      return false;
    }
  }

  Future<bool> disconnectFromNetwork() async {
    try {
      bool disconnected = await WiFiForIoTPlugin.disconnect();
      
      if (disconnected) {
        _connectedNetwork = null;
        _updateNetworkStatus(NetworkStatus.disconnected);
        _updateInternetStatus(InternetStatus.disconnected);
        await _scanNetworks(); // Refresh network list
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[NETWORK] Error disconnecting: $e');
      return false;
    }
  }

  Future<void> refreshNetworks() async {
    await _scanNetworks();
  }

  Future<void> forceInternetCheck() async {
    await _checkInternetConnectivity();
  }

  Future<void> forceLANCheck() async {
    await _checkLANStatus();
  }
}
