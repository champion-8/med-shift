import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/api/document_upload_client.dart';
import '../core/constants/app_constants.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/storage/auth_storage.dart';
import '../models/staff_profile_model.dart';
import '../models/skill_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final PushNotificationService _pushNotificationService;
  late final DocumentUploadClient _documentUploadClient;

  StaffProfileModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider(
    this._apiClient,
    this._authStorage,
    this._pushNotificationService, {
    DocumentUploadClient? documentUploadClient,
  }) {
    _documentUploadClient =
        documentUploadClient ?? ApiDocumentUploadClient(_apiClient);
    _apiClient.onUnauthorized = () async {
      if (!_isAuthenticated && _currentUser == null) return;
      await logout();
    };
    checkAuthStatus();
  }

  StaffProfileModel? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  /// True only when session has both a token flag and a loaded user profile.
  bool get hasUser => _isAuthenticated && _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        return await _mockLogin(email);
      }

      final response = await _apiClient.post(
        '${AppConstants.authApiPrefix}/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;
      if (data == null) {
        _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: ไม่ได้รับข้อมูลจากเซิร์ฟเวอร์';
        return false;
      }

      final token = _extractToken(data);
      if (token == null) {
        _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: ไม่พบ access token';
        return false;
      }

      _apiClient.setAuthToken(token);
      await _authStorage.saveToken(token);

      StaffProfileModel? user;
      final userData = _extractUserData(data);
      if (userData != null) {
        final map = _asStringKeyMap(userData);
        if (map != null) {
          user = StaffProfileModel.fromJson(map);
        }
      } else {
        user = await _fetchCurrentUser();
      }

      if (user == null) {
        await _authStorage.clear();
        _apiClient.clearAuthToken();
        _currentUser = null;
        _isAuthenticated = false;
        _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: ไม่พบข้อมูลผู้ใช้';
        return false;
      }

      await _authStorage.saveSession(token: token, user: user);
      _currentUser = user;
      _isAuthenticated = true;
      await _pushNotificationService.registerDevice();
      debugPrint('Login successful');
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('Login error: $e');
    } catch (e) {
      _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: ${e.toString()}';
      debugPrint('Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  Future<bool> _mockLogin(String email) async {
    debugPrint('🚀 BYPASS LOGIN MODE: ข้ามการเชื่อมต่อ API');

    _currentUser = StaffProfileModel(
      id: AppConstants.mockUserId,
      email: email.isNotEmpty ? email : AppConstants.mockUserEmail,
      firstName: AppConstants.mockUserFirstName,
      lastName: AppConstants.mockUserLastName,
      phone: AppConstants.mockUserPhone,
      licenseNumber: AppConstants.mockLicenseNumber,
      specialty: 'พยาบาลวิชาชีพ',
      yearsExperience: 5,
      skills: [
        SkillModel(
          id: 'mock-1',
          name: 'การดูแลผู้ป่วย',
          minRate: 250,
          maxRate: 250,
          yearsExperience: 5,
          isVerified: true,
        ),
        SkillModel(
          id: 'mock-2',
          name: 'ฉีดยา',
          minRate: 300,
          maxRate: 300,
          yearsExperience: 5,
          isVerified: true,
          certification: 'BLS',
        ),
        SkillModel(
          id: 'mock-3',
          name: 'วัดสัญญาณชีพ',
          minRate: 200,
          maxRate: 200,
          yearsExperience: 5,
        ),
      ],
      certifications: ['BLS', 'ACLS'],
      rating: 4.8,
      totalJobsCompleted: 120,
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
      updatedAt: DateTime.now(),
      bankName: 'ธนาคารกสิกรไทย',
      bankAccountNumber: '123-4-56789-0',
      bankAccountName:
          '${AppConstants.mockUserFirstName} ${AppConstants.mockUserLastName}',
      bankAccountVerified: true,
      status: 'Approved',
    );
    _isAuthenticated = true;

    debugPrint(
      '✅ Mock Login สำเร็จ: ${_currentUser?.firstName} ${_currentUser?.lastName}',
    );

    await Future.delayed(const Duration(milliseconds: 500));
    _isLoading = false;
    notifyListeners();
    return true;
  }

  String? _extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final token = data['accessToken'] ?? data['token'] ?? data['access_token'];
    if (token is String && token.isNotEmpty) return token;

    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final nestedToken =
          nested['accessToken'] ?? nested['token'] ?? nested['access_token'];
      if (nestedToken is String && nestedToken.isNotEmpty) return nestedToken;
    }

    return null;
  }

  Map<String, dynamic>? _extractUserData(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final user = data['user'] ?? data['staff'] ?? data['nurse'] ?? data['profile'];
    if (user is Map<String, dynamic>) return user;

    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final nestedUser =
          nested['user'] ?? nested['staff'] ?? nested['nurse'] ?? nested['profile'];
      if (nestedUser is Map<String, dynamic>) return nestedUser;
    }

    return null;
  }

  Map<String, dynamic>? _parseUserResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _extractUserData(data) ?? data;
    }
    return null;
  }

  Future<StaffProfileModel?> _fetchCurrentUser() async {
    try {
      final response =
          await _apiClient.get('${AppConstants.authApiPrefix}/me');
      final raw = _asStringKeyMap(response.data);
      final userData = raw == null ? null : (_parseUserResponse(raw) ?? raw);
      if (userData != null) {
        return StaffProfileModel.fromJson(userData);
      }
    } catch (e) {
      debugPrint('Fetch current user failed: $e');
    }
    return null;
  }

  /// Full staff registration (wizard). Saves session on success so docs can upload.
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String profession = 'Nurse',
    String? licenseNumber,
    String? nationalId,
    DateTime? licenseExpiryDate,
    String? laserCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    bool? bankAccountVerified,
    String? promptPayId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        '${AppConstants.authApiPrefix}/register/staff',
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'profession': profession,
          'licenseNumber': licenseNumber,
          'nationalId': nationalId,
          'licenseExpiryDate': licenseExpiryDate?.toUtc().toIso8601String(),
          'laserCode': laserCode,
          'bankName': bankName,
          'bankAccountNumber': bankAccountNumber,
          'bankAccountName': bankAccountName,
          'bankAccountVerified': bankAccountVerified,
          'promptPayId': promptPayId,
        },
      );

      final data = response.data;
      if (data == null) {
        _errorMessage = 'สมัครสมาชิกไม่สำเร็จ';
        return false;
      }

      final token = _extractToken(data);
      if (token == null) {
        _errorMessage = 'สมัครสมาชิกสำเร็จ แต่ไม่พบ access token';
        return false;
      }

      _apiClient.setAuthToken(token);
      await _authStorage.saveToken(token);

      StaffProfileModel? user;
      final userData = _extractUserData(data);
      if (userData != null) {
        final map = _asStringKeyMap(userData);
        if (map != null) {
          user = StaffProfileModel.fromJson(map);
        }
      }

      if (user == null) {
        await _authStorage.clear();
        _apiClient.clearAuthToken();
        _errorMessage = 'สมัครสมาชิกไม่สำเร็จ: ไม่พบข้อมูลผู้ใช้';
        return false;
      }

      await _authStorage.saveSession(token: token, user: user);
      _currentUser = user;
      _isAuthenticated = true;
      await _pushNotificationService.registerDevice();
      debugPrint('Registration successful');
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('Registration error: $e');
    } catch (e) {
      _errorMessage = 'สมัครสมาชิกไม่สำเร็จ: ${e.toString()}';
      debugPrint('Registration error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// Upload a KYC document after registration (via [DocumentUploadClient]).
  Future<bool> uploadStaffDocument({
    required String documentType,
    required String fileName,
    String? filePath,
    List<int>? bytes,
  }) async {
    try {
      await _documentUploadClient.upload(
        documentType: documentType,
        fileName: fileName,
        filePath: filePath,
        bytes: bytes,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('Document upload error: $e');
      return false;
    } catch (e) {
      _errorMessage = 'อัปโหลดเอกสารไม่สำเร็จ: ${e.toString()}';
      debugPrint('Document upload error: $e');
      return false;
    }
  }

  /// Request password reset code. Returns payload on success, null on failure.
  Future<PasswordResetRequestResult?> requestPasswordReset({
    required String email,
  }) async {
    _errorMessage = null;
    try {
      final response = await _apiClient.post(
        '${AppConstants.authApiPrefix}/forgot-password',
        data: {'email': email},
      );

      final map = _asStringKeyMap(response.data);
      if (map == null) {
        _errorMessage = 'ขอรหัสรีเซ็ตไม่สำเร็จ';
        return null;
      }

      return PasswordResetRequestResult(
        message: (map['message'] ?? 'ส่งรหัสรีเซ็ตแล้ว').toString(),
        resetCode: map['resetCode']?.toString(),
        expiresAt: DateTime.tryParse((map['expiresAt'] ?? '').toString()),
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('Forgot password error: ${e.message}');
    } catch (e) {
      _errorMessage = 'ขอรหัสรีเซ็ตไม่สำเร็จ: ${e.toString()}';
      debugPrint('Forgot password error: $e');
    }
    return null;
  }

  /// Reset password with email + code.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _errorMessage = null;
    try {
      final response = await _apiClient.post(
        '${AppConstants.authApiPrefix}/reset-password',
        data: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      debugPrint('Reset password error: ${e.message}');
    } catch (e) {
      _errorMessage = 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ: ${e.toString()}';
      debugPrint('Reset password error: $e');
    }
    return false;
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      // Local JWT logout — clear client session only
    } catch (e) {
      debugPrint('Logout API error: $e');
    }

    await _authStorage.clear();
    _apiClient.clearAuthToken();
    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Check if user is already logged in (from stored token)
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS AUTH CHECK: อัตโนมัติเข้าสู่ระบบด้วย Mock User');
        _isAuthenticated = false;
        return;
      }

      final token = _authStorage.token;
      if (token == null || token.isEmpty) {
        _isAuthenticated = false;
        return;
      }

      _apiClient.setAuthToken(token);
      final cachedUser = await _authStorage.loadUser();
      final user = cachedUser ?? await _fetchCurrentUser();

      if (user == null) {
        await _authStorage.clear();
        _apiClient.clearAuthToken();
        _currentUser = null;
        _isAuthenticated = false;
        return;
      }

      if (cachedUser == null) {
        await _authStorage.saveSession(token: token, user: user);
      }
      _currentUser = user;
      _isAuthenticated = true;
      await _pushNotificationService.registerDevice();
    } catch (e) {
      debugPrint('Auth check error: $e');
      await _authStorage.clear();
      _apiClient.clearAuthToken();
      _currentUser = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh current user profile
  Future<void> refreshProfile([String? staffId]) async {
    final id = staffId ?? _currentUser?.id;
    if (id == null) {
      final user = await _fetchCurrentUser();
      if (user != null) {
        final token = _authStorage.token;
        if (token != null) {
          await _authStorage.saveSession(token: token, user: user);
        }
        _currentUser = user;
        _isAuthenticated = true;
        notifyListeners();
      }
      return;
    }

    try {
      final response =
          await _apiClient.get('${AppConstants.staffApiPrefix}/profile');
      final raw = _asStringKeyMap(response.data);
      final userData = raw == null ? null : (_parseUserResponse(raw) ?? raw);

      if (userData != null) {
        _currentUser = StaffProfileModel.fromJson(userData);
        _isAuthenticated = true;

        final token = _authStorage.token;
        if (token != null) {
          await _authStorage.saveSession(token: token, user: _currentUser!);
        }

        notifyListeners();
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile(StaffProfileModel updatedProfile) async {
    try {
      final response = await _apiClient.put(
        '${AppConstants.staffApiPrefix}/profile',
        data: {
          'firstName': updatedProfile.firstName,
          'lastName': updatedProfile.lastName,
          'phone': updatedProfile.phone,
          'specialty': updatedProfile.specialty,
          'licenseNumber': updatedProfile.licenseNumber,
          'nationalId': updatedProfile.nationalId,
          'yearsExperience': updatedProfile.yearsExperience,
          'bankName': updatedProfile.bankName,
          'bankAccountNumber': updatedProfile.bankAccountNumber,
          'bankAccountName': updatedProfile.bankAccountName,
          'bankAccountVerified': updatedProfile.bankAccountVerified,
          'currentLocationLat': updatedProfile.currentLocationLat,
          'currentLocationLng': updatedProfile.currentLocationLng,
          'isAvailable': updatedProfile.isAvailable,
          'skills':
              updatedProfile.skills.map((s) => s.toUpsertJson()).toList(),
        },
      );

      final userData = _asStringKeyMap(response.data);
      if (userData != null) {
        final parsed = _parseUserResponse(userData) ?? userData;
        _currentUser = StaffProfileModel.fromJson(parsed);

        final token = _authStorage.token;
        if (token != null) {
          await _authStorage.saveSession(token: token, user: _currentUser!);
        }

        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'อัปเดตโปรไฟล์ไม่สำเร็จ: ${e.toString()}';
      debugPrint('Profile update error: $e');
    }

    return false;
  }

  /// Toggle staff availability for new job applications.
  Future<bool> setAvailability(bool isAvailable) async {
    final current = _currentUser;
    if (current == null) return false;

    try {
      final response = await _apiClient.put(
        '${AppConstants.staffApiPrefix}/profile',
        data: {
          'firstName': current.firstName,
          'lastName': current.lastName,
          'phone': current.phone,
          'specialty': current.specialty,
          'licenseNumber': current.licenseNumber,
          'nationalId': current.nationalId,
          'yearsExperience': current.yearsExperience,
          'bankName': current.bankName,
          'bankAccountNumber': current.bankAccountNumber,
          'bankAccountName': current.bankAccountName,
          'currentLocationLat': current.currentLocationLat,
          'currentLocationLng': current.currentLocationLng,
          'isAvailable': isAvailable,
        },
      );

      final userData = _asStringKeyMap(response.data);
      if (userData != null) {
        final parsed = _parseUserResponse(userData) ?? userData;
        _currentUser = StaffProfileModel.fromJson(parsed);

        final token = _authStorage.token;
        if (token != null) {
          await _authStorage.saveSession(token: token, user: _currentUser!);
        }

        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'อัปเดตสถานะรับงานไม่สำเร็จ: ${e.toString()}';
      debugPrint('Availability update error: $e');
    }

    return false;
  }

  /// Upload profile photo (multipart) and refresh session user.
  Future<bool> uploadProfileImage({
    required String fileName,
    String? filePath,
    List<int>? bytes,
  }) async {
    try {
      final MultipartFile part;
      if (bytes != null) {
        part = MultipartFile.fromBytes(bytes, filename: fileName);
      } else if (filePath != null && filePath.isNotEmpty) {
        part = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        _errorMessage = 'ไม่พบไฟล์รูปภาพ';
        return false;
      }

      final formData = FormData.fromMap({'file': part});

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/profile/image',
        data: formData,
      );

      final userData = _asStringKeyMap(response.data);
      if (userData != null) {
        final parsed = _parseUserResponse(userData) ?? userData;
        _currentUser = StaffProfileModel.fromJson(parsed);

        final token = _authStorage.token;
        if (token != null) {
          await _authStorage.saveSession(token: token, user: _currentUser!);
        }

        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'อัปโหลดรูปไม่สำเร็จ: ${e.toString()}';
      debugPrint('Profile image upload error: $e');
    }

    return false;
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

class PasswordResetRequestResult {
  final String message;
  final String? resetCode;
  final DateTime? expiresAt;

  PasswordResetRequestResult({
    required this.message,
    this.resetCode,
    this.expiresAt,
  });
}
