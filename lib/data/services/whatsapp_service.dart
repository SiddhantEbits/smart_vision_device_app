import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger_service.dart';
import '../repositories/local_storage_service.dart';

class WhatsAppAlertService {
  static Future<void> sendAlert({
    File? mediaFile,                // nullable (not needed for footFall)
    String? mediaType,              // image | video
    required String alertType,      // theftAlert | maxCapacity | absentAlert | footFall | detection | restrictedZone
    required String cameraNo,

    // optional params (used per alert type)
    int? maxCount,
    int? maxLimit,                  // New parameter for max capacity limit
    int? footfallCount,
    int? hours,
    int? detectionCount, // New parameter for detection alerts
  }) async {
    // Get phone numbers from local storage
    final phoneNumbers = LocalStorageService.instance.getWhatsAppPhoneNumbers();
    
    // Check if WhatsApp alerts are enabled and phone numbers exist
    final isWhatsAppEnabled = LocalStorageService.instance.getWhatsAppAlertsEnabled();
    
    if (!isWhatsAppEnabled || phoneNumbers.isEmpty) {
      LoggerService.w('⚠️ WhatsApp alerts disabled or no phone numbers configured');
      return;
    }

    final phoneNumbersString = phoneNumbers.join(',');

    final _dio = dio.Dio();
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.headers["Authorization"] = "Bearer ${AppConstants.apiKey}";
    _dio.options.connectTimeout = const Duration(seconds: 15);

    try {
      final Map<String, dynamic> data = {
        "phoneNumbers": phoneNumbersString,
        "phoneNumberId": AppConstants.phoneNumberId,
        "alertType": alertType,
        "cameraNo": cameraNo,
      };

      // -------------------- MEDIA ALERTS --------------------
      if (alertType != "footFall") {
        if (mediaFile == null || mediaType == null) {
          throw Exception("mediaFile & mediaType are required for $alertType");
        }

        data.addAll({
          "mediaType": mediaType,
          "media": await dio.MultipartFile.fromFile(
            mediaFile.path,
            filename: mediaFile.path.split('/').last,
          ),
        });
      }

      // -------------------- ALERT SPECIFIC FIELDS --------------------
      switch (alertType) {
        case "maxCapacity":
          data["max_count"] = maxCount ?? 0;
          data["max_limit"] = maxLimit ?? 0; // Include the configured limit
          break;

        case "footFall":
          data["footfall_count"] = footfallCount ?? 0;
          data["hours"] = hours ?? 1;
          LoggerService.i("WhatsApp footfall alert data: Count=$footfallCount, Interval=$hours hours");
          break;

        case "theftAlert":
        case "absentAlert":
        case "restrictedZone":// Support both for backward compatibility
          // no extra fields
          break;

        case "detection":
          data["detection_count"] = detectionCount ?? 0;
          break;

        default:
          throw Exception("Unknown alertType: $alertType");
      }

      final formData = dio.FormData.fromMap(data);

      LoggerService.i('💡 Sending WhatsApp Alert [$alertType] to $phoneNumbersString via API...');
      
      final response = await _dio.post(
        "/api/upload-media", // Corrected endpoint from working project
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        LoggerService.i('✅ WhatsApp Alert sent successfully to $phoneNumbersString');
        LoggerService.i('📸 Camera: $cameraNo | Details: ${_getAlertDetails(alertType, footfallCount, hours, maxCount, maxLimit, detectionCount)}');
      } else {
        LoggerService.w('⚠️ WhatsApp API returned non-200: ${response.statusCode}');
      }
      
    } catch (e, stack) {
      LoggerService.e('❌ Failed to send WhatsApp alert | Type: $alertType | Camera: $cameraNo | Error: $e', e, stack);
      
      // Log additional error context
      if (e.toString().contains('SocketException')) {
        LoggerService.w('🌐 Network error - Check internet connection');
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        LoggerService.w('🔑 Authentication error - Check API credentials');
      } else if (e.toString().contains('timeout')) {
        LoggerService.w('⏰ Timeout error - Server may be busy');
      }
    }
  }

  /// Helper method to format alert details for logging
  static String _getAlertDetails(String alertType, int? footfallCount, int? hours, int? maxCount, int? maxLimit, int? detectionCount) {
    switch (alertType) {
      case "footFall":
        return "Footfall=$footfallCount people in $hours hours";
      case "maxCapacity":
        return "Detected=$maxCount people, Limit=$maxLimit";
      case "detection":
        return "Detection count=$detectionCount";
      default:
        return "Standard alert";
    }
  }
}
