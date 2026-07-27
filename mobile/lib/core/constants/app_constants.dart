class AppConstants {
  // App Info
  static const String appName = 'MedShift Thailand';
  static const String appVersion = '1.0.0';

  // Development Mode - Bypass Login (ไม่ต้องต่อ API)
  static const bool isDevelopmentMode = true; // เปลี่ยนเป็น false เมื่อ production
  static const bool bypassLogin = false; // keep false — use real API


  // Mock User Data (สำหรับ Development Mode)
  static const String mockUserId = 'mock-user-001';
  static const String mockUserEmail = 'nurse@test.com';
  static const String mockUserFirstName = 'สมหญิง';
  static const String mockUserLastName = 'ใจดี';
  static const String mockUserPhone = '081-234-5678';
  static const String mockLicenseNumber = 'RN-12345';
  static const String mockToken = 'mock-jwt-token-for-development';

  // API Configuration — local MedShift API
  // Android emulator: http://10.0.2.2:5080
  // iOS simulator / desktop: http://localhost:5080
  static const String baseUrl = 'http://localhost:5080';
  static const String authApiPrefix = '/api/auth';
  static const String staffApiPrefix = '/api/staff';
  @Deprecated('Use authApiPrefix / staffApiPrefix')
  static const String nurseApiPrefix = staffApiPrefix;
  static const Duration apiTimeout = Duration(seconds: 30);

  // Date & Time Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Business Rules
  static const double cancellationFee = 50.0; // THB
  static const int maxTravelTimeMinutes = 120; // 2 hours max travel
  static const double hourlyRateMin = 200.0; // THB
  static const double hourlyRateMax = 1000.0; // THB

  // Waitlist Configuration
  static const int maxWaitlistSize = 10;
  static const Duration autoConfirmDuration = Duration(hours: 2);

  // Map Configuration
  static const double defaultLatitude = 13.7563; // Bangkok
  static const double defaultLongitude = 100.5018;
  static const double defaultZoom = 12.0;

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String userProfileKey = 'user_profile';
}
