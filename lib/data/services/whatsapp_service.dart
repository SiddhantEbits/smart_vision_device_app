import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';
import '../repositories/local_storage_service.dart';

class WhatsAppAlertService extends GetxService {
  final dio.Dio _dio = dio.Dio();

  @override
  void onInit() {
    super.onInit();
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.headers["Authorization"] = "Bearer ${AppConstants.apiKey}";
    _dio.options.connectTimeout = const Duration(seconds: 15);
  }

  Future<void> sendAlert({
    File? mediaFile,
    required String alertType, // theftAlert | maxCapacity | absentAlert | footFall | restrictedZone
    required String cameraNo,
    int? maxCount,
    int? maxLimit,
    int? footfallCount,
    int? hours,
    int? detectionCount,
  }) async {
    // Get phone numbers from local storage
    final phoneNumbers = LocalStorageService.instance.getWhatsAppPhoneNumbers();
    
    // Check if WhatsApp alerts are enabled and phone numbers exist
    final isWhatsAppEnabled = LocalStorageService.instance.getWhatsAppAlertsEnabled();
    
    if (!isWhatsAppEnabled || phoneNumbers.isEmpty) {
      LoggerService.w('⚠️ WhatsApp alerts disabled or no phone numbers configured');
      return;
    }

    try {
      // Convert phone numbers list to comma-separated string
      final phoneNumbersString = phoneNumbers.join(',');
      
      final Map<String, dynamic> data = {
        "phoneNumbers": phoneNumbersString,
        "phoneNumberId": AppConstants.phoneNumberId,
        "alertType": alertType,
        "cameraNo": cameraNo,
      };

      // Handle Media
      if (alertType != "footFall" && mediaFile != null) {
        data.addAll({
          "mediaType": "image",
          "media": await dio.MultipartFile.fromFile(
            mediaFile.path,
            filename: mediaFile.path.split('/').last,
          ),
        });
      }

      // Alert Specific Logic
      switch (alertType) {
        case "maxCapacity":
          data["max_count"] = maxCount ?? 0;
          data["max_limit"] = maxLimit ?? 0;
          break;
        case "footFall":
          data["footfall_count"] = footfallCount ?? 0;
          data["hours"] = hours ?? 1;
          break;
        case "detection":
          data["detection_count"] = detectionCount ?? 0;
          break;
      }

      final formData = dio.FormData.fromMap(data);
      
      LoggerService.i('Sending WhatsApp Alert [$alertType] to $phoneNumbersString via API...');
      
      final response = await _dio.post(
        "/api/uploadMedia", // Endpoint from reference project
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('✅ WhatsApp Alert sent successfully to $phoneNumbersString');
      } else {
        LoggerService.w('⚠️ WhatsApp API returned non-200: ${response.statusCode}');
      }
    } catch (e, stack) {
      LoggerService.e('❌ Failed to send WhatsApp alert', e, stack);
    }
  }
}
