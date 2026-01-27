class AppConstants {
  static const String yoloModelName = 'yolov8n';
  static const bool useGpu = true;
  static const double iouThreshold = 0.45;
  static const String yoloDownloadBase = 'https://raw.githubusercontent.com/ultralytics/assets/main/yolofiles';
  
  // Firebase Collections
  static const String devicesCollection = 'devices';
  static const String alertsCollection = 'alerts';
  static const String configsCollection = 'configs';
  static const String defaultDetectClass = 'person';

  // Network / API
  static const String baseUrl = "http://13.201.143.150:5002";
  static const String apiKey = "AmCckmfnkASub1uWzyzexTb2CqjxC";
  
  // WhatsApp
  static const String phoneNumberId = "619930564526184";
  static const String alertMaxPeople = "maxCapacity";
  static const String alertAbsent = "absentAlert";
  static const String alertRestrictedZone = "restrictedZone";
  static const String alertTheft = "theftAlert";

  // System Settings
  static const bool testMode = true;
  static const Duration shortTermRetention = Duration(minutes: 2);
  static const Duration longTermRetention = Duration(days: 7);
}
