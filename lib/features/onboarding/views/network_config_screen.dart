import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/responsive_num_extension.dart';
import '../../../../data/services/network_connectivity_service.dart';
import '../controllers/network_config_controller.dart';

class NetworkConfigScreen extends StatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  State<NetworkConfigScreen> createState() => _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends State<NetworkConfigScreen> {
  late final NetworkConfigController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<NetworkConfigController>();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (Navigation Info)
          Container(
            width: 300.adaptSize,
            padding: EdgeInsets.all(32.adaptSize),
            color: AppTheme.surfaceColor,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: controller.navigateBack,
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  SizedBox(height: 14.adaptSize),
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
                  SizedBox(height: 32.adaptSize),
                  
                  // Continue Button in Left Panel
                  Obx(() {
                    debugPrint('[UI] Continue button - connectedNetwork: ${controller.connectedNetwork.value?.ssid}');
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.connectedNetwork.value != null 
                            ? controller.navigateToNext
                            : null,
                        child: const Text('CONTINUE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: controller.connectedNetwork.value != null 
                              ? AppTheme.primaryColor 
                              : AppTheme.mutedTextColor,
                          padding: EdgeInsets.symmetric(vertical: 16.adaptSize),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // Right Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(64.adaptSize),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 300.adaptSize,
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
                            onPressed: controller.isScanning.value ? null : controller.loadNetworks,
                            icon: controller.isScanning.value 
                                ? SizedBox(
                                    width: 16.adaptSize,
                                    height: 16.adaptSize,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.refresh),
                            label: Text(controller.isScanning.value ? 'SCANNING...' : 'REFRESH'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.adaptSize),
                    
                    // Connection Status
                    Obx(() {
                      if (controller.connectionStatus.value.isNotEmpty) {
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.adaptSize),
                              decoration: BoxDecoration(
                                color: controller.getConnectionStatusColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.adaptSize),
                                border: Border.all(
                                  color: controller.getConnectionStatusColor(),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    controller.getConnectionStatusIcon(),
                                    color: controller.getConnectionStatusColor(),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          controller.connectionStatus.value,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: controller.getConnectionStatusColor(),
                                          ),
                                        ),
                                        if (controller.connectedNetwork.value != null) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            'IP: ${controller.connectedNetwork.value!.ipAddress ?? 'Unknown'}',
                                            style: TextStyle(
                                              color: AppTheme.mutedTextColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (controller.isConnecting.value)
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
                          ],
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                    
                    // Network Status Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'Internet',
                            status: controller.getInternetStatusText(),
                            subtitle: controller.getInternetStatusSubtitle(),
                            icon: controller.getInternetStatusIcon(),
                            isActive: controller.internetStatus.value == InternetStatus.connected,
                          ),
                        ),
                        SizedBox(width: 8.adaptSize),
                        IconButton(
                          onPressed: controller.forceInternetCheck,
                          icon: Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh Internet Status',
                        ),
                        SizedBox(width: 16.adaptSize),
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'LAN',
                            status: controller.getLANStatusText(),
                            subtitle: controller.getLANStatusSubtitle(),
                            icon: controller.getLANStatusIcon(),
                            isActive: controller.lanStatus.value?.isConnected == true,
                          ),
                        ),
                        SizedBox(width: 8.adaptSize),
                        IconButton(
                          onPressed: controller.forceLANCheck,
                          icon: Icon(Icons.refresh, size: 20),
                          tooltip: 'Refresh LAN Status',
                        ),
                      ],
                    ),
                    SizedBox(height: 24.adaptSize),
                    
                    // Connected Network Card (Top)
                    Obx(() {
                      if (controller.connectedNetwork.value != null) {
                        final network = controller.connectedNetwork.value!;
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20.adaptSize),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.adaptSize),
                                border: Border.all(
                                  color: AppTheme.successColor,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12.adaptSize),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12.adaptSize),
                                        ),
                                        child: Icon(
                                          Icons.wifi,
                                          color: AppTheme.successColor,
                                          size: 24.adaptSize,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'CONNECTED',
                                              style: TextStyle(
                                                color: AppTheme.successColor,
                                                fontSize: 12.adaptSize,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              network.ssid,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18.adaptSize,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (network.ipAddress != null) ...[
                                              SizedBox(height: 4),
                                              Text(
                                                'IP: ${network.ipAddress}',
                                                style: TextStyle(
                                                  color: AppTheme.mutedTextColor,
                                                  fontSize: 12.adaptSize,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: controller.isConnecting.value ? null : controller.disconnectFromNetwork,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 12.adaptSize, vertical: 8.adaptSize),
                                        ),
                                        child: Text(
                                          'DISCONNECT',
                                          style: TextStyle(
                                            color: AppTheme.errorColor,
                                            fontSize: 12.adaptSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.adaptSize),
                                  Row(
                                    children: [
                                      Icon(Icons.signal_cellular_alt, size: 16.adaptSize, color: controller.getSignalColor(network.signalStrength)),
                                      SizedBox(width: 8),
                                      Text('${network.signalStrength}% signal strength', style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 14.adaptSize)),
                                      SizedBox(width: 16),
                                      Icon(network.isSecured ? Icons.lock : Icons.lock_open, size: 16.adaptSize, color: AppTheme.mutedTextColor),
                                      SizedBox(width: 4),
                                      Text(network.securityType, style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 14.adaptSize)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.adaptSize),
                          ],
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                    
                    // WiFi Networks List (excluding connected network)
                    Obx(() {
                      debugPrint('[UI] Building networks list - count: ${controller.networks.length}');
                      debugPrint('[UI] Is scanning: ${controller.isScanning.value}');
                      if (controller.networks.isNotEmpty) {
                        return Column(
                          children: controller.networks
                              .where((network) => !network.isConnected)
                              .map((network) => _buildNetworkCard(network, controller))
                              .toList(),
                        );
                      } else if (!controller.isScanning.value) {
                        return Container(
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
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(WiFiNetworkInfo network, NetworkConfigController controller) {
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
                  color: controller.getSignalColor(network.signalStrength),
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
                  onPressed: controller.isConnecting.value ? null : controller.disconnectFromNetwork,
                  icon: Icon(Icons.wifi_off, color: AppTheme.errorColor),
                  tooltip: 'Disconnect',
                )
              : ElevatedButton(
                  onPressed: controller.isConnecting.value ? null : () {
                    if (network.isSecured) {
                      _showPasswordDialog(network);
                    } else {
                      controller.connectToNetwork(network);
                    }
                  },
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

  void _showPasswordDialog(WiFiNetworkInfo network) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_lock, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connect to ${network.ssid}',
                style: TextStyle(fontSize: 18),
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
                  'This network is secured. Please enter the password to connect.',
                  style: TextStyle(color: AppTheme.mutedTextColor),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter WiFi password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  autofocus: true,
                  onSubmitted: (value) {
                    Navigator.pop(context);
                    controller.connectToSecuredNetwork(network, value);
                  },
                ),
                SizedBox(height: 12),
                Text(
                  'Signal: ${network.signalStrength}% | Security: ${network.securityType}',
                  style: TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.connectToSecuredNetwork(network, passwordController.text);
            },
            child: Text('CONNECT'),
          ),
        ],
      ),
    );
  }
}