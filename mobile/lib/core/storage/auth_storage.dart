import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../models/staff_profile_model.dart';

class AuthStorage {
  SharedPreferences? _prefs;
  String? _cachedToken;

  String? get token => _cachedToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedToken = _prefs!.getString(AppConstants.userTokenKey);
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _prefs!.setString(AppConstants.userTokenKey, token);
  }

  Future<void> saveSession({
    required String token,
    required StaffProfileModel user,
  }) async {
    _cachedToken = token;
    await _prefs!.setString(AppConstants.userTokenKey, token);
    await _prefs!.setString(AppConstants.userIdKey, user.id);
    await _prefs!.setString(
      AppConstants.userProfileKey,
      jsonEncode(user.toJson()),
    );
  }

  Future<StaffProfileModel?> loadUser() async {
    final profileJson = _prefs?.getString(AppConstants.userProfileKey);
    if (profileJson == null) return null;

    try {
      return StaffProfileModel.fromJson(
        jsonDecode(profileJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserId() async => _prefs?.getString(AppConstants.userIdKey);

  Future<void> clear() async {
    _cachedToken = null;
    await _prefs!.remove(AppConstants.userTokenKey);
    await _prefs!.remove(AppConstants.userIdKey);
    await _prefs!.remove(AppConstants.userProfileKey);
  }
}
