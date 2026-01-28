import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/services/yolo_service.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../controller/alert_flow_controller.dart';
import '../../monitoring/controller/monitoring_controller.dart';
import '../../../features/camera_setup/controller/camera_setup_controller.dart';
import '../../../widgets/common/rtsp_preview_widget.dart';

class DetectionTestingScreen extends StatefulWidget {
  const DetectionTestingScreen({super.key});

  @override
  State<DetectionTestingScreen> createState() => _DetectionTestingScreenState();
}

class _DetectionTestingScreenState extends State<DetectionTestingScreen> {
  late DetectionType detectionType;
  late AlertConfig config;
  late Function(bool) onTestComplete;
  late Function() onReconfigure;
  
  bool isTestRunning = false;
  bool testResult = false;
  bool alertTriggered = false;
  bool verified = false;
  String testMessage = 'Press "Start Test" to begin testing';
  
  // Detection-specific counters
  int peopleCount = 0;
  int footfallCount = 0;
  DateTime? lastAlertTime;
  Timer? alertTimer;
  
  final AlertFlowController flowController = Get.put(AlertFlowController());
  final CameraSetupController cameraSetupController = Get.find<CameraSetupController>();
  MonitoringController? monitoringController;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>;
    detectionType = arguments['detectionType'] as DetectionType;
    config = arguments['config'] as AlertConfig;
    onTestComplete = arguments['onTestComplete'] as Function(bool);
    onReconfigure = arguments['onReconfigure'] as Function();
  }

  @override
  void dispose() {
    alertTimer?.cancel();
    if (isTestRunning && monitoringController != null) {
      monitoringController!.stopMonitoring();
    }
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      isTestRunning = true;
      testResult = false;
      alertTriggered = false;
      verified = false;
      peopleCount = 0;
      footfallCount = 0;
      testMessage = 'Detection system initializing...';
    });

    try {
      // Validate RTSP URL first
      final rtspUrl = cameraSetupController.rtspUrl.value;
      if (rtspUrl.isEmpty || rtspUrl == 'rtsp://') {
        setState(() {
          isTestRunning = false;
          testMessage = '❌ Invalid RTSP URL';
        });
        return;
      }

      // Check YOLO model availability first
      final yoloService = Get.find<YoloService>();
      if (!yoloService.isModelLoaded.value) {
        setState(() {
          isTestRunning = false;
          testMessage = '❌ YOLO model not loaded';
        });
        return;
      }

      // Initialize monitoring controller if not already done
      if (monitoringController == null) {
        monitoringController = Get.put(MonitoringController());
      }

      // Set the alert configuration for monitoring
      monitoringController!.setConfigs([config]);

      // Start monitoring with current detection config
      await monitoringController!.startMonitoring();

      setState(() {
        testMessage = 'Testing ${_getTitle(detectionType)}...';
      });

      // Start monitoring detection changes
      _monitorDetectionChanges();

    } catch (e) {
      setState(() {
        isTestRunning = false;
        testResult = false;
        testMessage = '❌ Test Error: ${e.toString()}';
      });
    }
  }

  Future<void> _stopTest() async {
    if (monitoringController != null) {
      await monitoringController!.stopMonitoring();
    }
    alertTimer?.cancel();
    if (mounted) {
      setState(() {
        isTestRunning = false;
      });
    }
  }

  void _handleTestResult(bool approved) {
    _stopTest();
    
    // Save the current config result
    flowController.saveConfig(config);
    
    if (approved) {
      // Move to next detection configuration (back to screen B - AlertConfigQueue)
      flowController.nextAlert();
      
      // Check if there are more detections to configure
      if (flowController.currentAlert != null) {
        // Navigate to next detection configuration screen (screen B)
        Get.offAllNamed('/alert-config-queue');
      } else {
        // All detections configured, go to finish screen (screen E)
        Get.offAllNamed('/camera-setup-finish');
      }
    } else {
      // Reconfigure current detection (back to screen B - AlertConfigQueue)
      Get.offAllNamed('/alert-config-queue', arguments: {
        'detectionType': detectionType,
        'reconfigure': true,
      });
    }
  }

  void _handleVerify() async {
    // Stop YOLO and FFmpeg when verify is pressed (if still running)
    if (isTestRunning) {
      await _stopTest();
    }
    
    setState(() {
      verified = true;
      isTestRunning = false;
      testMessage = 'Detection verified! FFmpeg and YOLO stopped. Click "Next Detection" to continue.';
    });
  }

  void _monitorDetectionChanges() {
    if (monitoringController == null) return;

    // Use periodic timer to check detection changes
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isTestRunning) {
        timer.cancel();
        return;
      }

      final detections = monitoringController!.currentDetections;
      final currentPeopleCount = detections.length;
      
      setState(() {
        peopleCount = currentPeopleCount;
      });

      // Check detection-specific conditions
      switch (detectionType) {
        case DetectionType.crowdDetection:
          _checkCrowdDetection(currentPeopleCount);
          break;
        case DetectionType.absentAlert:
          _checkAbsentAlert(currentPeopleCount);
          break;
        case DetectionType.footfallDetection:
          _checkFootfallDetection();
          break;
        case DetectionType.restrictedArea:
          _checkRestrictedArea();
          break;
        case DetectionType.sensitiveAlert:
          _checkSensitiveAlert(currentPeopleCount);
          break;
      }
    });
  }

  void _checkCrowdDetection(int currentCount) {
    final maxCapacity = config.maxCapacity ?? 5;
    if (currentCount >= maxCapacity) {
      _triggerAlert();
    }
  }

  void _checkAbsentAlert(int currentCount) {
    if (currentCount == 0) {
      // Start timer for absent alert
      final absentInterval = config.interval ?? 60;
      alertTimer?.cancel();
      alertTimer = Timer(Duration(seconds: absentInterval), () {
        if (isTestRunning && currentCount == 0) {
          _triggerAlert();
        }
      });
    } else if (currentCount > 0) {
      alertTimer?.cancel();
    }
  }

  void _checkFootfallDetection() {
    // Monitor footfall count from monitoring controller
    final currentFootfall = monitoringController?.footfallTotal.value ?? 0;
    if (currentFootfall > footfallCount) {
      footfallCount = currentFootfall;
      _triggerAlert();
    }
  }

  void _checkRestrictedArea() {
    // Check if any restricted IDs exist
    final restrictedIds = monitoringController?.restrictedIds ?? <int>{};
    if (restrictedIds.isNotEmpty) {
      _triggerAlert();
    }
  }

  void _checkSensitiveAlert(int currentCount) {
    if (currentCount > 0) {
      _triggerAlert();
    }
  }

  DateTime? _lastAlertTime;
  
  void _triggerAlert() {
    if (alertTriggered) return; // Prevent multiple alerts
    
    // Check cooldown period
    final cooldownSeconds = config.cooldown ?? 30;
    final now = DateTime.now();
    
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = now.difference(_lastAlertTime!).inSeconds;
      if (timeSinceLastAlert < cooldownSeconds) {
        // Still in cooldown period, don't trigger alert
        setState(() {
          testMessage = 'Detection detected (cooldown: ${cooldownSeconds - timeSinceLastAlert}s remaining)';
        });
        return;
      }
    }
    
    // Cooldown period passed, trigger alert
    _lastAlertTime = now;
    
    setState(() {
      alertTriggered = true;
      testMessage = '🚨 Alert Triggered! Detection is working properly.';
      testResult = true;
    });
    
    // Reset alert after cooldown period for testing purposes
    Future.delayed(Duration(seconds: cooldownSeconds), () {
      if (mounted && isTestRunning) {
        setState(() {
          alertTriggered = false;
          testMessage = 'Ready for next detection (cooldown: ${cooldownSeconds}s)';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Left Side - Controls (35%)
          Expanded(
            flex: 35,
            child: Container(
              padding: EdgeInsets.all(24.adaptSize),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
              ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () async {
                            await _stopTest();
                            onReconfigure();
                            Get.back();
                          },
                        ),
                        SizedBox(width: 8.adaptSize),
                        Text(
                          'Testing: ${_getTitle(detectionType)}',
                          style: TextStyle(
                            fontSize: 16.adaptSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16.adaptSize),
                  
                  // Test Status Card
                  Container(
                    padding: EdgeInsets.all(12.adaptSize),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12.adaptSize),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              alertTriggered ? Icons.warning : Icons.info,
                              color: alertTriggered ? Colors.orange : AppTheme.primaryColor,
                              size: 16.adaptSize,
                            ),
                            SizedBox(width: 8.adaptSize),
                            Text(
                              'Detection Status',
                              style: TextStyle(
                                fontSize: 12.adaptSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 8.adaptSize),
                        
                        // Detection-specific metrics
                        _buildDetectionMetrics(),
                        
                        SizedBox(height: 8.adaptSize),
                        Text(
                          testMessage,
                          style: TextStyle(
                            fontSize: 9.adaptSize,
                            color: alertTriggered ? Colors.orange : Colors.white70,
                            height: 1.2,
                          ),
                        ),
                        
                        // Alert Triggered Label
                        if (alertTriggered) ...[
                          SizedBox(height: 6.adaptSize),
                          Container(
                            padding: EdgeInsets.all(6.adaptSize),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8.adaptSize),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                  size: 14.adaptSize,
                                ),
                                SizedBox(width: 6.adaptSize),
                                Text(
                                  'Alert Triggered!',
                                  style: TextStyle(
                                    fontSize: 10.adaptSize,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (verified)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 14.adaptSize,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12.adaptSize),
                  
                  // Test Status Indicator
                  if (isTestRunning) ...[
                    Container(
                      padding: EdgeInsets.all(12.adaptSize),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.adaptSize),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8.adaptSize,
                            height: 8.adaptSize,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8.adaptSize),
                          Text(
                            'TEST IN PROGRESS',
                            style: TextStyle(
                              fontSize: 12.adaptSize,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.adaptSize),
                  ],
                  
                  SizedBox(height: 32.adaptSize),
                  
                  // Action Buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Verify Button (always shown when test is running)
                      if (isTestRunning) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: verified ? null : _handleVerify,
                            icon: Icon(Icons.check, size: 16.adaptSize),
                            label: Text(
                              verified ? 'Verified ✓' : 'Verify Detection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.adaptSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verified ? Colors.grey : Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 10.adaptSize),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.adaptSize),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.adaptSize),
                      ],
                      
                      // Test Result Actions (shown when test is not running)
                      if (!isTestRunning) ...[
                        if (!verified) ...[
                          // Manual Verify Button (for cases where no alert was triggered)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleVerify,
                              icon: Icon(Icons.check_circle, size: 16.adaptSize),
                              label: Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.adaptSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 10.adaptSize),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.adaptSize),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8.adaptSize),
                        ],
                        
                        if (verified) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleTestResult(true),
                                  icon: Icon(Icons.check, size: 14.adaptSize),
                                  label: Text(
                                    'Next Detection',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.adaptSize,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.symmetric(vertical: 10.adaptSize),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.adaptSize),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.adaptSize),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleTestResult(false),
                                  icon: Icon(Icons.refresh, size: 14.adaptSize),
                                  label: Text(
                                    'Reconfigure',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12.adaptSize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 10.adaptSize),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.adaptSize),
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.adaptSize),
                        ],
                      ],
                      
                      // Start/Stop Test Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isTestRunning ? _stopTest : _startTest,
                          icon: Icon(isTestRunning ? Icons.stop : Icons.play_arrow, size: 16.adaptSize),
                          label: Text(
                            isTestRunning ? 'Stop Test' : 'Start Test',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.adaptSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTestRunning ? Colors.red : AppTheme.primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 12.adaptSize),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.adaptSize),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16.adaptSize),
                ],
              ),
            ),
          ),
          ),
          // Right Side - Preview (65%)
          Expanded(
            flex: 65,
            child: Container(
              margin: EdgeInsets.all(16.adaptSize),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16.adaptSize),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.adaptSize),
                child: Stack(
                  children: [
                    // Video Stream - Using common RTSP preview widget
                    RTSPPreviewWidget(
                      rtspUrl: cameraSetupController.rtspUrl.value,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(16.adaptSize),
                      backgroundColor: Colors.black,
                      fit: BoxFit.contain,
                    ),
                    
                    // Detection Overlay
                    if (monitoringController != null)
                      Positioned.fill(
                        child: Obx(() {
                          final detections = monitoringController!.currentDetections;
                          if (detections.isEmpty) return const SizedBox.shrink();
                          
                          return Stack(
                            children: [
                              // Detection count indicator
                              Positioned(
                                top: 16.adaptSize,
                                left: 16.adaptSize,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.adaptSize,
                                    vertical: 6.adaptSize,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8.adaptSize),
                                  ),
                                  child: Text(
                                    '${detections.length} People',
                                    style: TextStyle(
                                      fontSize: 12.adaptSize,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    
                    // Test Status Indicator
                    if (isTestRunning)
                      Positioned(
                        top: 16.adaptSize,
                        right: 16.adaptSize,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.adaptSize,
                            vertical: 4.adaptSize,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6.adaptSize),
                          ),
                          child: Text(
                            'TESTING',
                            style: TextStyle(
                              fontSize: 10.adaptSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(DetectionType type) {
    switch (type) {
      case DetectionType.crowdDetection: return 'Crowd Detection';
      case DetectionType.absentAlert: return 'Absent Alert';
      case DetectionType.footfallDetection: return 'Footfall Detection';
      case DetectionType.restrictedArea: return 'Restricted Area';
      case DetectionType.sensitiveAlert: return 'Sensitive Alert';
    }
  }

  Widget _buildDetectionMetrics() {
    switch (detectionType) {
      case DetectionType.crowdDetection:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'People Count: $peopleCount / ${config.maxCapacity ?? 5}',
              style: TextStyle(
                fontSize: 16.adaptSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.adaptSize),
            LinearProgressIndicator(
              value: (peopleCount / (config.maxCapacity ?? 5)).clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                peopleCount >= (config.maxCapacity ?? 5) ? Colors.red : Colors.green,
              ),
            ),
          ],
        );
        
      case DetectionType.absentAlert:
        return Text(
          'People Count: $peopleCount',
          style: TextStyle(
            fontSize: 16.adaptSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
        
      case DetectionType.footfallDetection:
        return Text(
          'Footfall Count: $footfallCount',
          style: TextStyle(
            fontSize: 16.adaptSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
        
      case DetectionType.restrictedArea:
        final restrictedCount = monitoringController?.restrictedIds.length ?? 0;
        return Text(
          'People in Restricted Area: $restrictedCount',
          style: TextStyle(
            fontSize: 16.adaptSize,
            color: restrictedCount > 0 ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
        
      case DetectionType.sensitiveAlert:
        return Text(
          'People Detected: $peopleCount',
          style: TextStyle(
            fontSize: 16.adaptSize,
            color: peopleCount > 0 ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }
}
