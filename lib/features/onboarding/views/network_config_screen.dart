import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/responsive_num_extension.dart';
import '../../../../data/services/network_connectivity_service.dart';

class NetworkConfigScreen extends StatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  State<NetworkConfigScreen> createState() => _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends State<NetworkConfigScreen> {
  bool _isScanning = false;
  List<WiFiNetworkInfo> _networks = [];
  WiFiNetworkInfo? _connectedNetwork;
  bool _isConnecting = false;
  String _connectionStatus = '';
  
  // Network status monitoring
  NetworkStatus _networkStatus = NetworkStatus.disconnected;
  InternetStatus _internetStatus = InternetStatus.unknown;
  LANStatus? _lanStatus;
  
  // Stream subscriptions
  StreamSubscription<List<WiFiNetworkInfo>>? _networksSubscription;
  StreamSubscription<NetworkStatus>? _networkStatusSubscription;
  StreamSubscription<InternetStatus>? _internetStatusSubscription;
  StreamSubscription<LANStatus>? _lanStatusSubscription;
  
  final NetworkConnectivityService _networkService = NetworkConnectivityService();

  @override
  void initState() {
    super.initState();
    _initializeNetworkService();
  }
  
  void _initializeNetworkService() {
    // Initialize the network service
    _networkService.initialize();
    
    // Subscribe to network streams
    _networksSubscription = _networkService.networksStream.listen((networks) {
      if (mounted) {
        setState(() {
          _networks = networks;
          _connectedNetwork = _networkService.connectedNetwork;
          _isScanning = false;
          _connectionStatus = 'Found ${networks.length} WiFi networks';
        });
      }
    });
    
    _networkStatusSubscription = _networkService.networkStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _networkStatus = status;
          _updateConnectionStatus();
        });
      }
    });
    
    _internetStatusSubscription = _networkService.internetStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _internetStatus = status;
          _updateConnectionStatus();
        });
      }
    });
    
    _lanStatusSubscription = _networkService.lanStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _lanStatus = status;
        });
      }
    });
    
    // Initial load
    _loadNetworks();
  }
  
  void _updateConnectionStatus() {
    if (_connectedNetwork != null) {
      switch (_internetStatus) {
        case InternetStatus.connected:
          _connectionStatus = 'Connected to ${_connectedNetwork!.ssid} with Internet access';
          break;
        case InternetStatus.disconnected:
          _connectionStatus = 'Connected to ${_connectedNetwork!.ssid} but no Internet access';
          break;
        case InternetStatus.checking:
          _connectionStatus = 'Checking Internet connectivity...';
          break;
        default:
          _connectionStatus = 'Connected to ${_connectedNetwork!.ssid}';
      }
    } else {
      switch (_networkStatus) {
        case NetworkStatus.connecting:
          _connectionStatus = 'Connecting to network...';
          break;
        case NetworkStatus.connected:
          _connectionStatus = 'Network connected';
          break;
        case NetworkStatus.disconnected:
          _connectionStatus = 'Disconnected from network';
          break;
        default:
          _connectionStatus = 'Network status unknown';
      }
    }
  }
  
  @override
  void dispose() {
    _networksSubscription?.cancel();
    _networkStatusSubscription?.cancel();
    _internetStatusSubscription?.cancel();
    _lanStatusSubscription?.cancel();
    _networkService.dispose();
    super.dispose();
  }

  Future<void> _loadNetworks() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _connectionStatus = 'Scanning for WiFi networks...';
    });

    try {
      await _networkService.refreshNetworks();
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error scanning networks: ${e.toString()}';
        _isScanning = false;
      });
      debugPrint('[WIFI] Error scanning networks: $e');
    }
  }


  Future<void> _connectToNetwork(WiFiNetworkInfo network) async {
    if (network.isSecured) {
      _showPasswordDialog(network);
    } else {
      _connectToUnsecuredNetwork(network);
    }
  }

  Future<void> _connectToUnsecuredNetwork(WiFiNetworkInfo network) async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting to ${network.ssid}...';
    });

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
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showPasswordDialog(WiFiNetworkInfo network) {
    final passwordController = TextEditingController();
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_lock, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Text('Connect to ${network.ssid}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This network is secured. Please enter the password.\n\nNetwork Details:\n• Band: ${network.band}\n• Channel: ${network.channel}\n• Security: ${network.securityType}',
                style: TextStyle(color: AppTheme.mutedTextColor),
              ),
              SizedBox(height: 16),
              TextField(
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
              SizedBox(height: 12),
              Text(
                'Signal Strength: ${network.signalStrength}%',
                style: TextStyle(
                  color: AppTheme.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _connectToSecuredNetwork(network, passwordController.text);
              },
              child: Text('CONNECT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionSuccess(String ssid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Successfully connected to $ssid'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showConnectionError(String ssid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text('Failed to connect to $ssid. Please check password.'),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _connectToSecuredNetwork(WiFiNetworkInfo network, String password) async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting to ${network.ssid}...';
    });

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
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnectFromNetwork() async {
    if (_connectedNetwork == null) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Disconnecting from ${_connectedNetwork!.ssid}...';
    });

    try {
      bool disconnected = await _networkService.disconnectFromNetwork();

      if (disconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Successfully disconnected from WiFi'),
              ],
            ),
            backgroundColor: AppTheme.mutedTextColor,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to disconnect');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Could not disconnect from WiFi'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (Navigation Info)
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
                  'Network\nSetup',
                  style: TextStyle(
                    fontSize: 32.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.adaptSize),
                const Text(
                  'Ensure your device is connected to the internet for cloud sync and alerts.',
                  style: TextStyle(color: AppTheme.mutedTextColor),
                ),
                SizedBox(height: 64.adaptSize),
              ],
            ),
          ),
          
          // Right Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(64.adaptSize),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 300.adaptSize, // Minimum height for content
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Available Networks',
                          style: TextStyle(
                            fontSize: 24.adaptSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? null : _loadNetworks,
                          icon: _isScanning 
                              ? SizedBox(
                                  width: 16.adaptSize,
                                  height: 16.adaptSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.refresh),
                          label: Text(_isScanning ? 'SCANNING...' : 'REFRESH'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32.adaptSize),
                  
                  // Connection Status
                  if (_connectionStatus.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.adaptSize),
                      decoration: BoxDecoration(
                        color: _getConnectionStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.adaptSize),
                        border: Border.all(
                          color: _getConnectionStatusColor(),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getConnectionStatusIcon(),
                            color: _getConnectionStatusColor(),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _connectionStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _getConnectionStatusColor(),
                                  ),
                                ),
                                if (_connectedNetwork != null) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    'IP: ${_connectedNetwork!.ipAddress ?? 'Unknown'}',
                                    style: TextStyle(
                                      color: AppTheme.mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isConnecting)
                            SizedBox(
                              width: 16.adaptSize,
                              height: 16.adaptSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.adaptSize),
                    
                    // Network Status Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'Internet',
                            status: _getInternetStatusText(),
                            subtitle: _getInternetStatusSubtitle(),
                            icon: _getInternetStatusIcon(),
                            isActive: _internetStatus == InternetStatus.connected,
                          ),
                        ),
                        SizedBox(width: 8.adaptSize),
                        IconButton(
                          onPressed: () {
                            _networkService.forceInternetCheck();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.sync, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Checking internet connectivity...'),
                                  ],
                                ),
                                backgroundColor: AppTheme.primaryColor,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh Internet Status',
                        ),
                        SizedBox(width: 16.adaptSize),
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'LAN',
                            status: _getLANStatusText(),
                            subtitle: _getLANStatusSubtitle(),
                            icon: _getLANStatusIcon(),
                            isActive: _lanStatus?.isConnected == true,
                          ),
                        ),
                        SizedBox(width: 8.adaptSize),
                        IconButton(
                          onPressed: () {
                            _networkService.forceLANCheck();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.sync, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Checking LAN connectivity...'),
                                  ],
                                ),
                                backgroundColor: AppTheme.primaryColor,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh LAN Status',
                        ),
                      ],
                    ),
                    SizedBox(height: 24.adaptSize),
                  ],
                  
                  // WiFi Networks List
                  if (_networks.isNotEmpty) ...[
                    ..._networks.map((network) => _buildNetworkCard(network)),
                  ] else if (!_isScanning) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(32.adaptSize),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16.adaptSize),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 48.adaptSize,
                            color: AppTheme.mutedTextColor,
                          ),
                          SizedBox(height: 16.adaptSize),
                          Text(
                            'No networks found',
                            style: TextStyle(
                              fontSize: 18.adaptSize,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.mutedTextColor,
                            ),
                          ),
                          SizedBox(height: 8.adaptSize),
                          Text(
                            'Try refreshing to scan for available networks',
                            style: TextStyle(
                              color: AppTheme.mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 64.adaptSize),
                  
                  // Action Buttons
                  Row(
                    children: [
                      if (_connectedNetwork != null) ...[
                        SizedBox(
                          width: 200.adaptSize,
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting ? null : _disconnectFromNetwork,
                            icon: Icon(Icons.wifi_off),
                            label: Text('DISCONNECT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.adaptSize),
                      ],
                      SizedBox(
                        width: 200.adaptSize,
                        child: ElevatedButton(
                          onPressed: _connectedNetwork != null 
                              ? () => Get.toNamed(AppRoutes.qrScan)
                              : null,
                          child: const Text('CONTINUE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          )],
      ),
    );
  }

  Widget _buildNetworkCard(WiFiNetworkInfo network) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.adaptSize),
      decoration: BoxDecoration(
        color: network.isConnected 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16.adaptSize),
        border: Border.all(
          color: network.isConnected 
              ? AppTheme.successColor
              : Colors.white.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(20.adaptSize),
        leading: Container(
          padding: EdgeInsets.all(12.adaptSize),
          decoration: BoxDecoration(
            color: network.isConnected 
                ? AppTheme.successColor.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.adaptSize),
          ),
          child: Icon(
            network.isSecured ? Icons.wifi_lock : Icons.wifi,
            color: network.isConnected 
                ? AppTheme.successColor
                : AppTheme.primaryColor,
            size: 28.adaptSize,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    network.ssid,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.adaptSize,
                      color: network.isConnected 
                          ? AppTheme.successColor
                          : Colors.white,
                    ),
                  ),
                  if (network.bssid != null) ...[
                    SizedBox(height: 2),
                    Text(
                      'BSSID: ${network.bssid!}',
                      style: TextStyle(
                        color: AppTheme.mutedTextColor,
                        fontSize: 10.adaptSize,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (network.isConnected) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.adaptSize,
                  vertical: 4.adaptSize,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(20.adaptSize),
                ),
                child: Text(
                  'CONNECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.adaptSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.adaptSize),
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  size: 16.adaptSize,
                  color: _getSignalColor(network.signalStrength),
                ),
                SizedBox(width: 8),
                Text(
                  '${network.signalStrength}% signal strength',
                  style: TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 14.adaptSize,
                  ),
                ),
                SizedBox(width: 16),
                Icon(
                  network.isSecured ? Icons.lock : Icons.lock_open,
                  size: 16.adaptSize,
                  color: AppTheme.mutedTextColor,
                ),
                SizedBox(width: 4),
                Text(
                  network.securityType,
                  style: TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 14.adaptSize,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.adaptSize),
            Row(
              children: [
                Icon(
                  Icons.settings_input_antenna,
                  size: 16.adaptSize,
                  color: AppTheme.mutedTextColor,
                ),
                SizedBox(width: 8),
                Text(
                  '${network.band} • Channel ${network.channel} • ${network.frequency} MHz',
                  style: TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 12.adaptSize,
                  ),
                ),
              ],
            ),
            if (network.isConnected && network.ipAddress != null) ...[
              SizedBox(height: 4.adaptSize),
              Row(
                children: [
                  Icon(
                    Icons.settings_ethernet,
                    size: 16.adaptSize,
                    color: AppTheme.mutedTextColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'IP: ${network.ipAddress}',
                    style: TextStyle(
                      color: AppTheme.mutedTextColor,
                      fontSize: 12.adaptSize,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 80.adaptSize,
          child: network.isConnected 
              ? IconButton(
                  onPressed: _isConnecting ? null : () => _disconnectFromNetwork(),
                  icon: Icon(Icons.wifi_off, color: AppTheme.errorColor),
                  tooltip: 'Disconnect',
                )
              : ElevatedButton(
                  onPressed: _isConnecting ? null : () => _connectToNetwork(network),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.adaptSize,
                      vertical: 8.adaptSize,
                    ),
                  ),
                  child: Text('CONNECT', style: TextStyle(fontSize: 10.adaptSize)),
                ),
        ),
      ),
    );
  }

  Color _getSignalColor(int signalStrength) {
    if (signalStrength >= 70) return AppTheme.successColor;
    if (signalStrength >= 40) return Colors.orange;
    return AppTheme.errorColor;
  }
  
  // Helper methods for status display
  Color _getConnectionStatusColor() {
    if (_internetStatus == InternetStatus.connected) return AppTheme.successColor;
    if (_internetStatus == InternetStatus.disconnected && _connectedNetwork != null) return Colors.orange;
    if (_networkStatus == NetworkStatus.connecting) return AppTheme.primaryColor;
    if (_networkStatus == NetworkStatus.connected) return AppTheme.successColor;
    return AppTheme.errorColor;
  }
  
  IconData _getConnectionStatusIcon() {
    if (_internetStatus == InternetStatus.connected) return Icons.check_circle;
    if (_internetStatus == InternetStatus.checking) return Icons.sync;
    if (_networkStatus == NetworkStatus.connecting) return Icons.sync;
    if (_networkStatus == NetworkStatus.connected) return Icons.wifi;
    return Icons.wifi_off;
  }
  
  String _getInternetStatusText() {
    switch (_internetStatus) {
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
    switch (_internetStatus) {
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
    switch (_internetStatus) {
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
    if (_lanStatus?.isConnected == true) {
      return 'Connected';
    } else {
      return 'Disconnected';
    }
  }
  
  String _getLANStatusSubtitle() {
    if (_lanStatus?.isConnected == true) {
      return 'IP: ${_lanStatus?.localIP ?? 'Unknown'}';
    } else {
      return 'No local network';
    }
  }
  
  IconData _getLANStatusIcon() {
    if (_lanStatus?.isConnected == true) {
      return Icons.router;
    } else {
      return Icons.router_outlined;
    }
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String status,
    required String subtitle,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      width: 240.adaptSize,
      constraints: BoxConstraints(
        minWidth: 200.adaptSize,
        maxWidth: 280.adaptSize,
      ),
      padding: EdgeInsets.all(24.adaptSize),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.successColor : AppTheme.mutedTextColor,
            size: 32.adaptSize,
          ),
          SizedBox(height: 24.adaptSize),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.adaptSize,
            ),
          ),
          SizedBox(height: 8.adaptSize),
          Text(
            status,
            style: TextStyle(
              color: isActive ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.mutedTextColor,
              fontSize: 13.adaptSize,
            ),
          ),
        ],
      ),
    );
  }
}

