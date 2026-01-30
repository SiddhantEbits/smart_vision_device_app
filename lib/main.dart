import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/sizer.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_routes.dart';
import 'core/logging/logger_service.dart';
import 'core/utils/device_id_coordinator.dart';

import 'data/services/yolo_service.dart';
import 'data/services/alert_manager.dart';
import 'data/services/ffmpeg_service.dart';
import 'data/services/whatsapp_service.dart';
import 'data/services/snapshot_manager.dart';
import 'data/services/rtsp_snapshot_service.dart';
import 'data/services/frame_snapshot_service.dart';
import 'data/services/camera_log_service.dart';
import 'data/repositories/simple_storage_service.dart';
import 'core/utils/cooldown_manager.dart';
import 'features/camera_setup/controller/camera_setup_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MediaKit Initialization
  MediaKit.ensureInitialized();
  
  // Initialize DeviceIdCoordinator FIRST to ensure single device ID
  try {
    await DeviceIdCoordinator.initialize();
    LoggerService.i('DeviceIdCoordinator Initialized');
  } catch (e) {
    LoggerService.e('DeviceIdCoordinator initialization failed', e);
  }
  
  // Firebase Initialization
  try {
    await Firebase.initializeApp();
    LoggerService.i('Firebase Initialized');
  } catch (e) {
    LoggerService.e('Firebase initialization failed', e);
  }

  // Force Landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const SmartVisionApp());
}

class SmartVisionApp extends StatelessWidget {
  const SmartVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation) => GetMaterialApp(
        title: 'Smart Vision Device',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.welcome,
        getPages: AppRoutes.pages,
        initialBinding: GlobalBinding(),
      ),
    );
  }
}

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    // Storage - Initialize first (synchronous)
    Get.put(SimpleStorageService.instance, permanent: true);
    
    // Infrastructure - Register dependencies first
    Get.put(CooldownManager(), permanent: true);
    Get.put(CameraLogService(), permanent: true);
    
    // Media & Hardware
    Get.put(FFmpegService(), permanent: true);
    Get.put(RTSPSnapshotService(), permanent: true);
    Get.put(FrameSnapshotService(), permanent: true);
    Get.put(SnapshotManager(), permanent: true);
    
    // Core AI & Messaging
    Get.put(YoloService(), permanent: true);
    
    // Alert Management - Depends on all above services
    Get.put(AlertManager(), permanent: true);
    
    // Camera Management
    Get.put(CameraSetupController(), permanent: true);
    
    // Initialize async services after registration
    _initializeAsyncServices();
  }
  
  Future<void> _initializeAsyncServices() async {
    try {
      debugPrint('🚀 Starting async services initialization...');
      
      // Initialize SimpleStorageService asynchronously
      debugPrint('📦 Initializing SimpleStorageService...');
      await SimpleStorageService.instance.init();
      debugPrint('✅ SimpleStorageService initialized');
      
      // Initialize YOLO model asynchronously
      debugPrint('🤖 Initializing YOLO model...');
      final yoloService = Get.find<YoloService>();
      final modelLoaded = await yoloService.initModel();
      
      if (modelLoaded) {
        debugPrint('✅ YOLO model loaded successfully');
      } else {
        debugPrint('❌ YOLO model failed to load');
      }
      
      debugPrint('🎉 Async services initialization completed');
    } catch (e) {
      debugPrint('❌ Error initializing async services: $e');
    }
  }
}
