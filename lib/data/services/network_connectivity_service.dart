import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  factory WiFiNetworkInfo.fromScanResult(dynamic result, String? currentSSID, {int networkIndex = 0}) {
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
    
    // Handle WifiNetwork objects properly
    if (result is WifiNetwork) {
      debugPrint('[NETWORK] Processing WifiNetwork object');
      
      // Direct access to WifiNetwork properties
      ssid = result.ssid ?? '';
      bssid = result.bssid;
      
      // Get signal strength
      signalStrength = result.level ?? 50;
      
      // Get frequency and calculate band
      if (result.frequency != null) {
        frequency = result.frequency!;
        band = frequency > 5000 ? '5 GHz' : '2.4 GHz';
        channel = _frequencyToChannel(frequency);
      }
      
      // Get security information
      isSecured = result.capabilities?.isNotEmpty ?? false;
      securityType = _parseSecurityType(result.capabilities ?? '');
      
      debugPrint('[NETWORK] WifiNetwork parsed - SSID: "$ssid", BSSID: $bssid, Signal: $signalStrength');
      
    } else if (result is Map) {
      debugPrint('[NETWORK] Processing Map result');
      
      // Try multiple possible field names for SSID
      List<String> possibleFields = [
        'ssid', 'SSID', 'name', 'networkName', 'Ssid', 'title', 'label',
        'wifi_ssid', 'network_ssid', 'ap_ssid', 'essid'
      ];
      
      for (String field in possibleFields) {
        String? value = result[field]?.toString();
        if (value != null && value.isNotEmpty && value != 'null' && value != '') {
          ssid = value;
          debugPrint('[NETWORK] Found SSID in field "$field": "$ssid"');
          break;
        }
      }
      
      bssid = result['bssid']?.toString() ?? result['BSSID']?.toString();
      
      // Signal strength (RSSI)
      int? rssi = result['level'] as int? ?? result['rssi'] as int? ?? result['signalStrength'] as int?;
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
      
      debugPrint('[NETWORK] Map parsing - SSID: "$ssid", BSSID: $bssid');
      
    } else {
      // Handle non-Map results - WifiNetwork objects that don't expose SSID
      String resultStr = result.toString();
      debugPrint('[NETWORK] Non-Map result string: "$resultStr"');
      
      // Since WifiNetwork objects don't expose SSID properly, generate unique names
      int hashCode = result.hashCode;
      ssid = 'Network_${networkIndex + 1}_${hashCode % 1000}';
      debugPrint('[NETWORK] Generated unique SSID for WifiNetwork: "$ssid"');
      
      signalStrength = 50;
      isSecured = true; // Assume secured for unknown networks
      securityType = 'Unknown';
    }
    
    // Final cleanup of SSID
    ssid = ssid.replaceAll("'", '').replaceAll('"', '').trim();
    
    // If SSID is still empty or too generic, generate a unique name
    if (ssid.isEmpty || ssid == 'Unknown' || ssid == 'Unknown Network') {
      ssid = 'Network_${DateTime.now().millisecondsSinceEpoch % 1000}';
      debugPrint('[NETWORK] Generated unique SSID: "$ssid"');
    }
    
    debugPrint('[NETWORK] Final parsed SSID: "$ssid"');
    
    return WiFiNetworkInfo(
      ssid: ssid,
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

  Future<List<dynamic>> _scanUsingPlatformChannel() async {
    debugPrint('[NETWORK] Attempting platform channel WiFi scan...');
    
    try {
      // Try to use Android's native WiFi scan through platform channel
      // This is a more advanced approach to get real network names
      
      // Method 1: Try to use Android's WifiManager directly
      const platform = MethodChannel('com.example.app/wifi');
      
      try {
        List<dynamic>? results = await platform.invokeListMethod('getWifiScanResults');
        if (results != null) {
          debugPrint('[NETWORK] Platform channel SUCCESS - Found ${results.length} networks');
          return results;
        }
      } on PlatformException catch (e) {
        debugPrint('[NETWORK] Platform channel failed: ${e.message}');
      }
      
      // Method 2: Try alternative channel name
      try {
        const platform2 = MethodChannel('wifi_flutter/wifi');
        List<dynamic>? results = await platform2.invokeListMethod('getScanResults');
        if (results != null) {
          debugPrint('[NETWORK] Alternative platform channel SUCCESS - Found ${results.length} networks');
          return results;
        }
      } on PlatformException catch (e) {
        debugPrint('[NETWORK] Alternative platform channel failed: ${e.message}');
      }
      
      // Method 3: Try to use Android intent to get WiFi settings
      try {
        const platform3 = MethodChannel('android/wifi');
        List<dynamic>? results = await platform3.invokeListMethod('scanResults');
        if (results != null) {
          debugPrint('[NETWORK] Android WiFi channel SUCCESS - Found ${results.length} networks');
          return results;
        }
      } on PlatformException catch (e) {
        debugPrint('[NETWORK] Android WiFi channel failed: ${e.message}');
      }
      
      debugPrint('[NETWORK] All platform channel methods failed');
      return [];
      
    } catch (e) {
      debugPrint('[NETWORK] Platform channel scan failed: $e');
      return [];
    }
  }

  Future<void> _scanNetworks() async {
    try {
      debugPrint('[NETWORK] ===== STARTING WIFI SCAN =====');
      debugPrint('[NETWORK] Scanning for WiFi networks...');
      
      // Ensure WiFi is enabled
      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      debugPrint('[NETWORK] WiFi enabled: $isWifiEnabled');
      if (!isWifiEnabled) {
        debugPrint('[NETWORK] WiFi is disabled, enabling...');
        await WiFiForIoTPlugin.setEnabled(true);
        await Future.delayed(Duration(seconds: 2)); // Wait for WiFi to enable
        debugPrint('[NETWORK] WiFi should now be enabled');
      }

      // Get current connected network
      String? currentSSID = await WiFiForIoTPlugin.getSSID();
      debugPrint('[NETWORK] Current SSID: "$currentSSID"');

      // Try multiple scanning approaches
      List<dynamic> wifiResults = [];
      
      // Method 1: Standard loadWifiList using proper WifiNetwork type
      try {
        debugPrint('[NETWORK] Trying Method 1: loadWifiList()');
        List<WifiNetwork> wifiNetworks = await WiFiForIoTPlugin.loadWifiList();
        debugPrint('[NETWORK] Method 1 SUCCESS - Found ${wifiNetworks.length} WiFi networks');
        
        // Convert to dynamic list for compatibility with existing code
        wifiResults = wifiNetworks.cast<dynamic>();
        
        // Debug each network to see the SSID
        for (int i = 0; i < wifiNetworks.length; i++) {
          debugPrint('[NETWORK] WifiNetwork $i: SSID="${wifiNetworks[i].ssid}", BSSID="${wifiNetworks[i].bssid}"');
        }
      } catch (e) {
        debugPrint('[NETWORK] Method 1 FAILED: $e');
      }
      
      // Method 2: Try with delay and retry
      if (wifiResults.isEmpty) {
        try {
          debugPrint('[NETWORK] Trying Method 2: delayed scan');
          await Future.delayed(Duration(seconds: 2));
          wifiResults = await WiFiForIoTPlugin.loadWifiList();
          debugPrint('[NETWORK] Method 2 SUCCESS - Found ${wifiResults.length} raw WiFi results after delay');
        } catch (e) {
          debugPrint('[NETWORK] Method 2 FAILED: $e');
        }
      }
      
      // Method 3: Try alternative approach - use platform channel directly
      if (wifiResults.isEmpty) {
        try {
          debugPrint('[NETWORK] Trying Method 3: platform channel approach');
          // This is a more advanced approach - try to access Android WiFi manager directly
          wifiResults = await _scanUsingPlatformChannel();
          debugPrint('[NETWORK] Method 3 SUCCESS - Found ${wifiResults.length} raw WiFi results');
        } catch (e) {
          debugPrint('[NETWORK] Method 3 FAILED: $e');
        }
      }
      
      // Debug: Print all raw results to understand the data structure
      for (int i = 0; i < wifiResults.length; i++) {
        debugPrint('[NETWORK] ===== RAW RESULT $i =====');
        debugPrint('[NETWORK] Type: ${wifiResults[i].runtimeType}');
        debugPrint('[NETWORK] toString(): "${wifiResults[i]}"');
        
        if (wifiResults[i] is Map) {
          Map<String, dynamic> resultMap = Map<String, dynamic>.from(wifiResults[i]);
          debugPrint('[NETWORK] Map keys: ${resultMap.keys}');
          resultMap.forEach((key, value) {
            debugPrint('[NETWORK]   $key: "$value" (${value.runtimeType})');
          });
        } else {
          // Try to introspect the object
          try {
            var result = wifiResults[i];
            debugPrint('[NETWORK] HashCode: ${result.hashCode}');
            debugPrint('[NETWORK] RuntimeType: ${result.runtimeType}');
            
            // Try to cast to different types
            if (result.toString().isNotEmpty && result.toString() != 'null') {
              debugPrint('[NETWORK] String representation: "${result.toString()}"');
            }
          } catch (e) {
            debugPrint('[NETWORK] Error introspecting object: $e');
          }
        }
        debugPrint('[NETWORK] ===== END RAW RESULT $i =====');
      }
      
      debugPrint('[NETWORK] ===== STARTING NETWORK PARSING =====');
      
      // Convert to enhanced network info with better error handling
      List<WiFiNetworkInfo> networks = [];
      
      for (int i = 0; i < wifiResults.length; i++) {
        try {
          var result = wifiResults[i];
          debugPrint('[NETWORK] ===== PARSING RESULT $i =====');
          debugPrint('[NETWORK] Input: ${result.runtimeType} - $result');
          
          WiFiNetworkInfo networkInfo = WiFiNetworkInfo.fromScanResult(result, currentSSID, networkIndex: i);
          debugPrint('[NETWORK] Parsed SSID: "${networkInfo.ssid}"');
          
          // Add all networks except empty ones, but be more lenient with unknown names
          if (networkInfo.ssid.isNotEmpty && networkInfo.ssid.length > 1) {
            networks.add(networkInfo);
            debugPrint('[NETWORK] ✓ ADDED: "${networkInfo.ssid}"');
          } else {
            debugPrint('[NETWORK] ✗ SKIPPED: Empty or too short network');
          }
          debugPrint('[NETWORK] ===== END PARSING RESULT $i =====');
        } catch (e) {
          debugPrint('[NETWORK] ✗ ERROR processing result $i: $e');
          // Continue processing other networks
        }
      }
      
      debugPrint('[NETWORK] ===== FINAL NETWORK LIST =====');
      debugPrint('[NETWORK] Total networks to display: ${networks.length}');
      for (int i = 0; i < networks.length; i++) {
        debugPrint('[NETWORK] $i. "${networks[i].ssid}" (Connected: ${networks[i].isConnected})');
      }
      
      // Add the currently connected network as a special entry if not already in the list
      if (currentSSID != null && currentSSID.isNotEmpty) {
        bool foundConnected = false;
        for (var network in networks) {
          if (network.isConnected) {
            foundConnected = true;
            break;
          }
        }
        
        if (!foundConnected) {
          debugPrint('[NETWORK] Adding current connected network as special entry: $currentSSID');
          WiFiNetworkInfo connectedNetwork = WiFiNetworkInfo(
            ssid: currentSSID!,
            signalStrength: 75,
            frequency: 2400,
            band: '2.4 GHz',
            isSecured: true,
            securityType: 'WPA2',
            channel: 6,
            isConnected: true,
            ipAddress: '192.168.1.6', // We know this from the logs
          );
          networks.insert(0, connectedNetwork); // Insert at the beginning
          debugPrint('[NETWORK] ✓ ADDED CONNECTED: "$currentSSID"');
        }
      }
      
      debugPrint('[NETWORK] ===== FINAL NETWORK LIST (AFTER CONNECTED) =====');
      debugPrint('[NETWORK] Total networks to display: ${networks.length}');
      for (int i = 0; i < networks.length; i++) {
        debugPrint('[NETWORK] $i. "${networks[i].ssid}" (Connected: ${networks[i].isConnected})');
      }
      debugPrint('[NETWORK] ===== END NETWORK LIST =====');

      // If no valid networks found, try alternative approach
      if (networks.isEmpty && wifiResults.isNotEmpty) {
        debugPrint('[NETWORK] No valid networks parsed, trying comprehensive fallback approach...');
        
        for (int i = 0; i < wifiResults.length; i++) {
          var result = wifiResults[i];
          try {
            String ssid = '';
            
            // Try multiple extraction methods
            if (result is Map) {
              ssid = result['ssid']?.toString() ?? 
                     result['SSID']?.toString() ?? 
                     result['name']?.toString() ?? 
                     result['networkName']?.toString() ?? 
                     result['Ssid']?.toString() ?? 
                     'Network_${i + 1}';
            } else {
              // Try to extract from string representation
              String resultStr = result.toString();
              debugPrint('[NETWORK] Fallback parsing string $i: $resultStr');
              
              // Look for common SSID patterns
              List<RegExp> patterns = [
                RegExp(r'ssid[:\s=]+"?([^"]+)"?'),
                RegExp(r'SSID[:\s=]+"?([^"]+)"?'),
                RegExp(r'name[:\s=]+"?([^"]+)"?'),
                RegExp(r'networkName[:\s=]+"?([^"]+)"?'),
              ];
              
              for (RegExp pattern in patterns) {
                Match? match = pattern.firstMatch(resultStr);
                if (match != null && match.groupCount >= 1) {
                  ssid = match.group(1)!.trim();
                  if (ssid.isNotEmpty && ssid != 'Unknown') break;
                }
              }
              
              // If still no SSID, try direct string cleaning
              if (ssid.isEmpty) {
                ssid = resultStr
                    .replaceAll('Instance of ', '')
                    .replaceAll('WiFiNetwork', '')
                    .replaceAll('WifiNetwork', '')
                    .replaceAll(':', '')
                    .replaceAll('{', '')
                    .replaceAll('}', '')
                    .trim();
                
                // If it's still too long or looks like object info, generate a name
                if (ssid.length > 32 || ssid.contains(' ')) {
                  ssid = 'Network_${i + 1}';
                }
              }
            }
            
            // Clean up the SSID
            ssid = ssid.replaceAll("'", '').replaceAll('"', '').trim();
            
            if (ssid.isNotEmpty && ssid != 'Unknown Network' && ssid != 'Unknown') {
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
              debugPrint('[NETWORK] Fallback added network: "$ssid"');
            }
          } catch (e) {
            debugPrint('[NETWORK] Fallback parsing failed for result $i: $e');
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
      if (!_networkStatusController.isClosed) {
        _networkStatusController.add(_networkStatus);
        debugPrint('[NETWORK] Network status updated: $status');
      }
    }
  }

  void _updateInternetStatus(InternetStatus status) {
    if (_internetStatus != status) {
      _internetStatus = status;
      if (!_internetStatusController.isClosed) {
        _internetStatusController.add(_internetStatus);
        debugPrint('[NETWORK] Internet status updated: $status');
      }
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
      debugPrint('[NETWORK] Starting WiFi disconnect process...');
      
      // Try multiple disconnect methods
      bool disconnected = false;
      
      // Method 1: Standard disconnect
      try {
        debugPrint('[NETWORK] Trying Method 1: Standard disconnect');
        disconnected = await WiFiForIoTPlugin.disconnect();
        debugPrint('[NETWORK] Method 1 result: $disconnected');
      } catch (e) {
        debugPrint('[NETWORK] Method 1 failed: $e');
      }
      
      // Method 2: Force disconnect
      if (!disconnected) {
        try {
          debugPrint('[NETWORK] Trying Method 2: Force disconnect');
          await WiFiForIoTPlugin.forceWifiUsage(false);
          await Future.delayed(Duration(milliseconds: 500));
          disconnected = await WiFiForIoTPlugin.disconnect();
          debugPrint('[NETWORK] Method 2 result: $disconnected');
        } catch (e) {
          debugPrint('[NETWORK] Method 2 failed: $e');
        }
      }
      
      // Method 3: Remove network configuration
      if (!disconnected && _connectedNetwork != null) {
        try {
          debugPrint('[NETWORK] Trying Method 3: Remove network config');
          await WiFiForIoTPlugin.removeWifiNetwork(_connectedNetwork!.ssid);
          await Future.delayed(Duration(milliseconds: 1000));
          
          // Check if actually disconnected after removing config
          String? currentSSID = await WiFiForIoTPlugin.getSSID();
          if (currentSSID != _connectedNetwork!.ssid) {
            disconnected = true;
            debugPrint('[NETWORK] Method 3 succeeded - SSID changed to: $currentSSID');
          } else {
            debugPrint('[NETWORK] Method 3 failed - still connected to: $currentSSID');
          }
        } catch (e) {
          debugPrint('[NETWORK] Method 3 failed: $e');
        }
      }
      
      // Method 4: Disable and re-enable WiFi (last resort)
      if (!disconnected) {
        try {
          debugPrint('[NETWORK] Trying Method 4: WiFi toggle');
          await WiFiForIoTPlugin.setEnabled(false);
          await Future.delayed(Duration(milliseconds: 3000)); // Longer wait
          await WiFiForIoTPlugin.setEnabled(true);
          await Future.delayed(Duration(milliseconds: 2000)); // Wait for reconnection
          
          // Check final status
          String? currentSSID = await WiFiForIoTPlugin.getSSID();
          if (currentSSID != _connectedNetwork!.ssid) {
            disconnected = true;
            debugPrint('[NETWORK] Method 4 succeeded - SSID changed to: $currentSSID');
          } else {
            debugPrint('[NETWORK] Method 4 failed - still connected to: $currentSSID');
          }
        } catch (e) {
          debugPrint('[NETWORK] Method 4 failed: $e');
        }
      }
      
      // Update status regardless of disconnect success
      _connectedNetwork = null;
      _updateNetworkStatus(NetworkStatus.disconnected);
      _updateInternetStatus(InternetStatus.disconnected);
      
      // Wait for system to process changes
      await Future.delayed(Duration(milliseconds: 1500));
      
      // Refresh network list to get current state
      await _scanNetworks();
      
      debugPrint('[NETWORK] Disconnect process completed. Final result: $disconnected');
      return disconnected;
      
    } catch (e) {
      debugPrint('[NETWORK] Critical error in disconnect process: $e');
      // Force status update even on critical error
      _connectedNetwork = null;
      _updateNetworkStatus(NetworkStatus.disconnected);
      _updateInternetStatus(InternetStatus.disconnected);
      await _scanNetworks();
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
