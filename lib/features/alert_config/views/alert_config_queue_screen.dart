import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/alert_flow_controller.dart';
import '../../camera_setup/controller/camera_setup_controller.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/camera_config.dart';
import '../../../data/repositories/simple_storage_service.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/logging/logger_service.dart';

class AlertConfigQueueScreen extends StatefulWidget {
  const AlertConfigQueueScreen({super.key});

  @override
  State<AlertConfigQueueScreen> createState() => _AlertConfigQueueScreenState();
}

class _AlertConfigQueueScreenState extends State<AlertConfigQueueScreen> {
  final AlertFlowController flowController = Get.find<AlertFlowController>();
  
  // Form controllers and state
  late TextEditingController _sensitivityController;
  late TextEditingController _cooldownController;
  late TextEditingController _maxCapacityController;
  late TextEditingController _absentIntervalController;
  
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All days selected by default
  bool _schedulingEnabled = true;
  
  // Handle reconfigure detection type
  DetectionType? _reconfigureDetectionType;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _handleArguments();
  }
  
  void _handleArguments() {
    // Check if we're being called with a specific detection type (for reconfigure)
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('detectionType')) {
      _reconfigureDetectionType = arguments['detectionType'] as DetectionType;
    }
  }
  
  DetectionType get currentDetectionType {
    // If reconfigure detection type is set, use that, otherwise use flow controller
    return _reconfigureDetectionType ?? flowController.currentAlert!;
  }
  
  void _initializeControllers() {
    _sensitivityController = TextEditingController(text: '0.5');
    _cooldownController = TextEditingController(text: '30');
    _maxCapacityController = TextEditingController(text: '5');
    _absentIntervalController = TextEditingController(text: '60');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentType = currentDetectionType;
      if (currentType == null) return const Center(child: CircularProgressIndicator());

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Step ${flowController.currentConfigIndex.value + 1} of ${flowController.selectedDetections.length}: ${_getTitle(currentType)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            // Main Content - Scrollable
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.adaptSize),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 100.adaptSize,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Side - Parameters
                        Expanded(
                          flex: 2,
                          child: _buildParametersSection(currentType),
                        ),
                        
                        SizedBox(width: 24.adaptSize),
                        
                        // Right Side - Scheduling
                        Expanded(
                          flex: 1,
                          child: _buildSchedulingSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Floating NEXT Button
            Positioned(
              bottom: 24.adaptSize,
              right: 24.adaptSize,
              child: FloatingActionButton.extended(
                onPressed: _saveAndContinue,
                backgroundColor: AppTheme.primaryColor,
                icon: Icon(Icons.arrow_forward),
                label: Text(flowController.isLastAlert ? 'FINISH' : 'NEXT'),
              ),
            ),
          ],
        ),
      );
    });
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

  void _saveAndContinue() {
    final currentType = currentDetectionType;
    
    // Collect form data
    final sensitivity = double.tryParse(_sensitivityController.text) ?? 0.5;
    final cooldown = int.tryParse(_cooldownController.text) ?? 30;
    
    // Create alert schedule
    AlertSchedule schedule;
    if (_schedulingEnabled) {
      schedule = AlertSchedule(
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        days: _selectedDays,
      );
    } else {
      // Always active - full day, every day
      schedule = AlertSchedule(
        startTime: '00:00',
        endTime: '23:59',
        days: [1, 2, 3, 4, 5, 6, 7],
      );
    }
    
    // Get detection-specific values
    Map<String, dynamic> additionalParams = {};
    switch (currentType) {
      case DetectionType.crowdDetection:
        additionalParams['maxCapacity'] = int.tryParse(_maxCapacityController.text) ?? 5;
        break;
      case DetectionType.absentAlert:
        additionalParams['absentInterval'] = int.tryParse(_absentIntervalController.text) ?? 60;
        break;
      case DetectionType.footfallDetection:
      case DetectionType.restrictedArea:
        // ROI will be handled in separate screen
        break;
      case DetectionType.sensitiveAlert:
        break;
    }
    
    // Save the config built in this step (without ROI for now)
    final alertConfig = AlertConfig(
      type: currentType,
      threshold: sensitivity,
      cooldown: cooldown,
      schedule: schedule,
      maxCapacity: additionalParams['maxCapacity'],
      interval: additionalParams['absentInterval'],
      roiPoints: null, // Will be set in ROI screen
      roiType: null, // Will be set in ROI screen
    );

    // Save to flow controller for navigation
    flowController.saveConfig(alertConfig);

    // Save alert configuration to current camera in local storage
    _saveAlertConfigToCurrentCamera(currentType, alertConfig);

    // Check if we need to go to ROI screen or go to testing
    if (currentType == DetectionType.footfallDetection || currentType == DetectionType.restrictedArea) {
      // Navigate to ROI screen
      Get.toNamed('/roi-setup', arguments: {
        'detectionType': currentType,
        'onComplete': (List<Offset> roiPoints, String roiType) {
          // Debug logging for ROI points received
          final currentType = currentDetectionType;
          LoggerService.i('Alert Queue - ROI Complete Callback');
          LoggerService.i('Alert Queue - Detection Type: $currentType');
          LoggerService.i('Alert Queue - ROI Type: $roiType');
          LoggerService.i('Alert Queue - ROI Points: $roiPoints');
          
          // Update the last saved config with ROI data
          if (flowController.configs.containsKey(currentType)) {
            final lastConfig = flowController.configs[currentType]!;
            final updatedConfig = AlertConfig(
              type: lastConfig.type,
              threshold: lastConfig.threshold,
              cooldown: lastConfig.cooldown,
              schedule: lastConfig.schedule,
              maxCapacity: lastConfig.maxCapacity,
              interval: lastConfig.interval,
              roiPoints: roiPoints,
              roiType: roiType,
            );
            flowController.configs[currentType] = updatedConfig;
            LoggerService.i('Alert Queue - Updated config with ROI points');
          }
          
          // Go to testing screen
          _goToTestingScreen();
        }
      });
    } else {
      // Go directly to testing screen for non-ROI detections
      _goToTestingScreen();
    }
  }

  void _goToTestingScreen() {
    // Navigate to testing screen with the current detection config
    Get.toNamed('/detection-testing', arguments: {
      'detectionType': currentDetectionType,
      'config': flowController.configs[currentDetectionType]!,
      'onTestComplete': (bool isSuccessful) {
        if (isSuccessful) {
          // Test successful, move to next detection or finish
          if (flowController.isLastAlert) {
            flowController.finishSetup();
          } else {
            flowController.nextAlert();
            setState(() {
              _initializeControllers(); // Reset controllers
            });
          }
        } else {
          // Test failed, user wants to reconfigure - do nothing, stay on current detection
          // User can modify the config and test again
        }
      },
      'onReconfigure': () {
        // User wants to reconfigure - just return to this screen
        // No action needed as we're already here
      },
    });
  }

  Widget _buildParametersSection(DetectionType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detection Type Title
        Text(
          _getTitle(type),
          style: TextStyle(
            fontSize: 18.adaptSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.adaptSize),
        
        // Parameters
        _buildTextField('Sensitivity Threshold', _sensitivityController),
        SizedBox(height: 12.adaptSize),
        _buildTextField('Alert Cooldown (seconds)', _cooldownController),
        SizedBox(height: 12.adaptSize),
        
        // Detection-specific parameters
        _buildDetectionSpecificTextFields(type),
        
        // ROI Setup for detection types that need it - Show only info message
        if (type == DetectionType.footfallDetection || type == DetectionType.restrictedArea) ...[
          SizedBox(height: 16.adaptSize),
          Container(
            padding: EdgeInsets.all(16.adaptSize),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.adaptSize),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.crop_free,
                  color: AppTheme.primaryColor,
                  size: 20.adaptSize,
                ),
                SizedBox(width: 12.adaptSize),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROI Configuration',
                        style: TextStyle(
                          fontSize: 14.adaptSize,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.adaptSize),
                      Text(
                        'ROI will be configured on the next screen',
                        style: TextStyle(
                          fontSize: 12.adaptSize,
                          color: AppTheme.primaryColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.primaryColor,
                  size: 16.adaptSize,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSchedulingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alert Scheduling',
          style: TextStyle(
            fontSize: 16.adaptSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.adaptSize),
        
        // Scheduling Toggle
        Row(
          children: [
            Text(
              'Enable Scheduling',
              style: TextStyle(
                fontSize: 14.adaptSize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 12.adaptSize),
            Switch(
              value: _schedulingEnabled,
              onChanged: (value) {
                setState(() {
                  _schedulingEnabled = value;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
        SizedBox(height: 16.adaptSize),
        
        // Conditional content based on toggle
        if (_schedulingEnabled) ...[
          // Time Pickers
          _buildTimeTextField('Start Time', _startTime, (time) => setState(() => _startTime = time)),
          SizedBox(height: 12.adaptSize),
          _buildTimeTextField('End Time', _endTime, (time) => setState(() => _endTime = time)),
          SizedBox(height: 16.adaptSize),
          
          // Days Selection
          Text(
            'Active Days',
            style: TextStyle(
              fontSize: 14.adaptSize,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8.adaptSize),
          
          Wrap(
            spacing: 6.adaptSize,
            runSpacing: 6.adaptSize,
            children: [
              {'day': 'Mon', 'value': 1},
              {'day': 'Tue', 'value': 2},
              {'day': 'Wed', 'value': 3},
              {'day': 'Thu', 'value': 4},
              {'day': 'Fri', 'value': 5},
              {'day': 'Sat', 'value': 6},
              {'day': 'Sun', 'value': 7},
            ].map((dayData) {
              final day = dayData['day'] as String;
              final value = dayData['value'] as int;
              return FilterChip(
                label: Text(day, style: TextStyle(fontSize: 10.adaptSize)),
                selected: _selectedDays.contains(value),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(value);
                    } else {
                      _selectedDays.remove(value);
                    }
                  });
                },
                backgroundColor: Colors.white.withOpacity(0.1),
                selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                labelStyle: TextStyle(color: Colors.white70),
              );
            }).toList(),
          ),
        ] else ...[
          // Always Active Message
          Container(
            padding: EdgeInsets.all(16.adaptSize),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.adaptSize),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  color: Colors.green,
                  size: 20.adaptSize,
                ),
                SizedBox(width: 12.adaptSize),
                Text(
                  'Always Active',
                  style: TextStyle(
                    fontSize: 16.adaptSize,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Text(
                  '24/7 Monitoring',
                  style: TextStyle(
                    fontSize: 12.adaptSize,
                    color: Colors.green.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.adaptSize,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.adaptSize),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 14.adaptSize,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.adaptSize,
              vertical: 10.adaptSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeTextField(String label, TimeOfDay time, Function(TimeOfDay) onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.adaptSize,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6.adaptSize),
        TextField(
          readOnly: true,
          controller: TextEditingController(
            text: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          ),
          style: TextStyle(
            fontSize: 14.adaptSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.adaptSize),
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.adaptSize,
              vertical: 10.adaptSize,
            ),
            suffixIcon: Icon(Icons.access_time, size: 18.adaptSize, color: Colors.white54),
          ),
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked != null) {
              onTimeChanged(picked);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDetectionSpecificTextFields(DetectionType type) {
    switch (type) {
      case DetectionType.crowdDetection:
        return Column(
          children: [
            _buildTextField('Max Capacity', _maxCapacityController),
            SizedBox(height: 12.adaptSize),
          ],
        );
        
      case DetectionType.absentAlert:
        return Column(
          children: [
            _buildTextField('Absent Interval (seconds)', _absentIntervalController),
            SizedBox(height: 12.adaptSize),
          ],
        );
        
      case DetectionType.footfallDetection:
      case DetectionType.restrictedArea:
      case DetectionType.sensitiveAlert:
        // These don't have additional specific fields beyond ROI
        return const SizedBox();
    }
  }

  void _saveAlertConfigToCurrentCamera(DetectionType detectionType, AlertConfig alertConfig) {
    try {
      // Get the current camera from CameraSetupController
      final cameraSetupController = Get.find<CameraSetupController>();
      final currentCamera = cameraSetupController.currentCamera;
      
      if (currentCamera == null) {
        LoggerService.w('❌ No current camera found to save alert configuration');
        Get.snackbar(
          'Error',
          'No camera selected. Please select a camera first.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Create a copy of the current camera with updated alert configuration
      final updatedCamera = _applyAlertConfigToCamera(currentCamera, detectionType, alertConfig);
      
      // Update the camera in the list
      final cameraIndex = cameraSetupController.cameras.indexWhere((c) => c.name == currentCamera.name);
      if (cameraIndex != -1) {
        cameraSetupController.updateCamera(cameraIndex, updatedCamera); // Use public method
        
        LoggerService.i('✅ Alert configuration saved to camera: ${currentCamera.name} for detection: $detectionType');
        
        Get.snackbar(
          'Configuration Saved',
          'Alert settings saved to ${currentCamera.name}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        LoggerService.e('❌ Camera not found in list: ${currentCamera.name}');
      }
    } catch (e) {
      LoggerService.e('❌ Failed to save alert configuration to camera', e);
      Get.snackbar(
        'Save Failed',
        'Failed to save alert configuration: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  CameraConfig _applyAlertConfigToCamera(CameraConfig camera, DetectionType detectionType, AlertConfig alertConfig) {
    // Create a copy of the camera with updated alert configuration
    final updatedCamera = CameraConfig(
      name: camera.name,
      url: camera.url,
      confidenceThreshold: camera.confidenceThreshold,
      
      // Apply detection-specific settings
      peopleCountEnabled: detectionType == DetectionType.crowdDetection ? true : camera.peopleCountEnabled,
      maxPeople: detectionType == DetectionType.crowdDetection ? alertConfig.maxCapacity ?? camera.maxPeople : camera.maxPeople,
      maxPeopleCooldownSeconds: detectionType == DetectionType.crowdDetection ? alertConfig.cooldown : camera.maxPeopleCooldownSeconds,
      maxPeopleSchedule: detectionType == DetectionType.crowdDetection ? alertConfig.schedule : camera.maxPeopleSchedule,
      
      footfallEnabled: detectionType == DetectionType.footfallDetection ? true : camera.footfallEnabled,
      footfallIntervalMinutes: detectionType == DetectionType.footfallDetection ? alertConfig.interval ?? camera.footfallIntervalMinutes : camera.footfallIntervalMinutes,
      footfallSchedule: detectionType == DetectionType.footfallDetection ? alertConfig.schedule : camera.footfallSchedule,
      
      restrictedAreaEnabled: detectionType == DetectionType.restrictedArea ? true : camera.restrictedAreaEnabled,
      restrictedAreaCooldownSeconds: detectionType == DetectionType.restrictedArea ? alertConfig.cooldown : camera.restrictedAreaCooldownSeconds,
      restrictedAreaSchedule: detectionType == DetectionType.restrictedArea ? alertConfig.schedule : camera.restrictedAreaSchedule,
      
      theftAlertEnabled: detectionType == DetectionType.sensitiveAlert ? true : camera.theftAlertEnabled,
      theftCooldownSeconds: detectionType == DetectionType.sensitiveAlert ? alertConfig.cooldown : camera.theftCooldownSeconds,
      theftSchedule: detectionType == DetectionType.sensitiveAlert ? alertConfig.schedule : camera.theftSchedule,
      
      absentAlertEnabled: detectionType == DetectionType.absentAlert ? true : camera.absentAlertEnabled,
      absentSeconds: detectionType == DetectionType.absentAlert ? alertConfig.interval ?? camera.absentSeconds : camera.absentSeconds,
      absentCooldownSeconds: detectionType == DetectionType.absentAlert ? alertConfig.cooldown : camera.absentCooldownSeconds,
      absentSchedule: detectionType == DetectionType.absentAlert ? alertConfig.schedule : camera.absentSchedule,
      
      // Preserve ROI configurations
      footfallConfig: camera.footfallConfig,
      restrictedAreaConfig: camera.restrictedAreaConfig,
    );
    
    return updatedCamera;
  }

}
