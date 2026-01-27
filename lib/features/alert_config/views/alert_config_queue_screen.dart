import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/alert_flow_controller.dart';
import '../../../data/models/alert_config_model.dart';
import '../../../data/models/roi_config_model.dart';
import '../../../core/constants/responsive_num_extension.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/roi/footfall_canvas.dart';

class AlertConfigQueueScreen extends StatefulWidget {
  const AlertConfigQueueScreen({super.key});

  @override
  State<AlertConfigQueueScreen> createState() => _AlertConfigQueueScreenState();
}

class _AlertConfigQueueScreenState extends State<AlertConfigQueueScreen> {
  final AlertFlowController flowController = Get.find<AlertFlowController>();
  RoiAlertConfig roiConfig = RoiAlertConfig.forFootfall();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentType = flowController.currentAlert;
      if (currentType == null) return const Center(child: CircularProgressIndicator());

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Step ${flowController.currentConfigIndex.value + 1} of ${flowController.selectedDetections.length}: ${_getTitle(currentType)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Column(
              children: [
                _buildConfigContent(currentType),
                
                // Bottom Actions
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 48.adaptSize,
                    vertical: 24.adaptSize,
                  ),
                  color: AppTheme.surfaceColor,
                  child: Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(200.adaptSize, 56.adaptSize),
                        ),
                        child: Text(flowController.isLastAlert ? 'FINISH SETUP' : 'NEXT ALERT'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final currentType = flowController.currentAlert!;
    
    // Save the config built in this step
    flowController.saveConfig(AlertConfig(
      type: currentType,
      schedule: AlertSchedule(startTime: '00:00', endTime: '23:59', days: [1,2,3,4,5,6,7]),
      roiPoints: [roiConfig.lineStart, roiConfig.lineEnd], // Using simplified mapping for now
      // ... (other params from UI state)
    ));

    if (flowController.isLastAlert) {
       flowController.finishSetup();
    } else {
      flowController.nextAlert();
      setState(() {
        roiConfig = RoiAlertConfig.forFootfall(); // Reset for next
      });
    }
  }

  Widget _buildConfigContent(DetectionType type) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(48.adaptSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Common Parameters for all detection types
          Text(
            'Common Parameters',
            style: TextStyle(
              fontSize: 20.adaptSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.adaptSize),
          _buildSliderSetting('Sensitivity Threshold', 0.5, '0.1', '1.0'),
          _buildSliderSetting('Alert Cooldown (seconds)', 30, '5', '300'),
          SizedBox(height: 48.adaptSize),
          
          // Scheduling
          Text(
            'Scheduling',
            style: TextStyle(
              fontSize: 20.adaptSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.adaptSize),
          Row(
            children: [
              _buildTimePicker('Start Time', '09:00'),
              SizedBox(width: 24.adaptSize),
              _buildTimePicker('End Time', '18:00'),
            ],
          ),
          
          // Detection-specific parameters
          _buildDetectionSpecificFields(type),
          
          // ROI Setup for detection types that need it
          if (type == DetectionType.footfallDetection || type == DetectionType.restrictedArea) ...[
            SizedBox(height: 48.adaptSize),
            _buildROISection(type),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDetectionSpecificFields(DetectionType type) {
    switch (type) {
      case DetectionType.crowdDetection:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 48.adaptSize),
            Text(
              'Crowd Settings',
              style: TextStyle(
                fontSize: 20.adaptSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.adaptSize),
            _buildSliderSetting('Max Capacity', 5, '2', '50'),
          ],
        );
        
      case DetectionType.absentAlert:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 48.adaptSize),
            Text(
              'Absent Settings',
              style: TextStyle(
                fontSize: 20.adaptSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.adaptSize),
            _buildSliderSetting('Absent Interval (seconds)', 60, '10', '600'),
          ],
        );
        
      case DetectionType.footfallDetection:
      case DetectionType.restrictedArea:
      case DetectionType.sensitiveAlert:
        // These don't have additional specific fields beyond ROI
        return const SizedBox();
    }
  }
  
  Widget _buildROISection(DetectionType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROI Setup',
          style: TextStyle(
            fontSize: 20.adaptSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24.adaptSize),
        Container(
          height: 300.adaptSize,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24.adaptSize),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.adaptSize),
            child: Stack(
              children: [
                // Live stream placeholder
                Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(
                      Icons.videocam,
                      size: 80.adaptSize,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                FootfallCanvas(
                  config: roiConfig,
                  onChanged: (newConfig) {
                    setState(() => roiConfig = newConfig);
                  },
                  showLine: type == DetectionType.footfallDetection,
                ),
                
                Positioned(
                  top: 16.adaptSize,
                  right: 16.adaptSize,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.adaptSize,
                      vertical: 6.adaptSize,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.adaptSize),
                    ),
                    child: Text(
                      type == DetectionType.footfallDetection 
                          ? 'Adjust ROI box and Crossing Line'
                          : 'Adjust Restricted Area ROI',
                      style: TextStyle(
                        fontSize: 12.adaptSize,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting(String title, double value, String min, String max) {
    final minValue = double.tryParse(min) ?? 0.0;
    final maxValue = double.tryParse(max) ?? 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        Row(
          children: [
            Text(min),
            SizedBox(
              width: 200.adaptSize,
              child: Slider(
                value: value.clamp(minValue, maxValue),
                min: minValue,
                max: maxValue,
                onChanged: (_) {},
                divisions: 10,
              ),
            ),
            Text(max),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, String time) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 24.adaptSize,
        vertical: 16.adaptSize,
      ),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.adaptSize,
              color: AppTheme.mutedTextColor,
            ),
          ),
          SizedBox(height: 4.adaptSize),
          Text(
            time,
            style: TextStyle(
              fontSize: 18.adaptSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}
