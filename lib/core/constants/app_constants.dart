class AppConstants {
  AppConstants._();

  // ==================================================
  // NETWORK / API
  // ==================================================
  static const String baseUrl =
      "http://13.201.143.150:5002";

  static const String apiKey =
      "AmCckmfnkASub1uWzyzexTb2CqjxC";

  // ==================================================
  // WHATSAPP
  // ==================================================
  static const String phoneNumberId = "619930564526184";
  static const String imageTemplate = "ebits_utility_image";

  static const String alertMaxPeople = "maxCapacity";
  static const String alertAbsent = "absentAlert";
  static const String alertRestrictedZone = "restrictedZone";
  static const String alertTheft = "theftAlert";

  // ==================================================
  // YOLO (OPTIMIZED FOR SPEED)
  // ==================================================
  static const String yoloModelName = "yolo11n";
  static const String defaultDetectClass = 'person';

  // Keep CPU-only for stability on TV box
  static const bool useGpu = false;

  // Standard IOU for better detection accuracy
  static const double iouThreshold = 0.35;

  // Match model requirements for better accuracy
  static const int yoloInputSize = 320;

  static const String yoloDownloadBase =
      "https://github.com/ultralytics/yolo-flutter-app/releases/download/v0.0.0";

  // ==================================================
  // VIDEO / FRAME CAPTURE (SMOOTHNESS FIRST)
  // ==================================================

  // Faster detection response
  // Was 450
  static const Duration frameCaptureInterval =
  Duration(milliseconds: 333);

  // Better image quality for accurate detection
  // Was 0.35
  static const double capturePixelRatio = 0.6;

  // Good balance of quality and speed
  // Was 60
  static const int jpegQuality = 75;

  // ==================================================
  // ALERT SNAPSHOT (KEEP HIGH QUALITY)
  // ==================================================

  // Alerts need clarity → keep this high
  static const double snapshotPixelRatio = 2.0;

  static const int snapshotJpegQuality = 90;

  // ==================================================
  // SNAPSHOT STORAGE / CLEANUP
  // ==================================================
  static const Duration snapshotRetention =
  Duration(minutes: 10);

  static const Duration snapshotCleanupInterval =
  Duration(minutes: 5);

  // ==================================================
  // FOOTFALL
  // ==================================================
  static const int footfallIntervalMinutes = 60;

  // ==================================================
  // EXTENDED APP SETTINGS (LOGGING & ALERTS)
  // ==================================================

  // 🔴 MASTER SWITCH FOR LOGGING & LOW-RES SNAPSHOTS
  static const bool testMode = true; 

  // Retention: 7 days for logs and low-res snapshots
  static const Duration longTermRetention = Duration(days: 7);

  // Retention: 2 minutes for high-res alert cache
  static const Duration shortTermRetention = Duration(minutes: 2);

  // ==================================================
  // DRIVE UPLOAD SETTINGS (SUPABASE)
  // ==================================================
  
  // Upload interval in hours (configurable)
  static const int driveUploadIntervalMinutes = 1;
  
  // Supabase configuration
  static const String supabaseUrl = 'https://byltgbfrtitqykbxqpar.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5bHRnYmZydGl0cXlrYnhxcGFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NTAzMDUsImV4cCI6MjA4NDEyNjMwNX0.fRaNv4B0uTTEZV0M2upvUijQj7QgGkl61l62fx4s3HE';
  
  // Supabase storage bucket name for logs
  static const String supabaseBucketName = 'smartvision-logs';
  
  // Drive upload settings
  static const int driveUploadMaxFiles = 50; // Max files per upload
  static const int driveUploadMaxFileSizeMB = 50; // Max file size in MB
  static const Duration driveUploadTimeout = Duration(minutes: 5); // Upload timeout

  // ==================================================
  // FIREBASE COLLECTIONS
  // ==================================================
  static const String devicesCollection = 'devices';
  static const String alertsCollection = 'alerts';
  static const String configsCollection = 'configs';

  // ==================================================
  // STORAGE KEYS
  // ==================================================
  static const String previewEnabledKey = 'preview_enabled';

  // ==================================================
  // APP VERSION
  // ==================================================
  static const String appVersion = "1.0.0";
  static const String buildNumber = "1";
}
