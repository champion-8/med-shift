import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';
import 'fcm_service.dart';

class PushNotificationService {
  final ApiClient _apiClient;
  final FcmService _fcmService;

  PushNotificationService(this._apiClient, this._fcmService);

  Future<void> registerDevice() async {
    final fcmToken = await _fcmService.getToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('FCM token unavailable, skipping device registration');
      return;
    }

    try {
      await _apiClient.put(
        '${AppConstants.staffApiPrefix}/notifications/device',
        data: {
          'firebaseDeviceToken': fcmToken,
          'platform': defaultTargetPlatform.name,
        },
      );
      debugPrint('FCM device registered');
    } catch (e) {
      debugPrint('FCM device registration failed: $e');
    }
  }
}
