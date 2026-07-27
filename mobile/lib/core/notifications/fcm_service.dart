import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  String? _cachedToken;
  bool _initialized = false;
  void Function(String token)? onTokenRefresh;
  void Function(RemoteMessage message)? onForegroundMessage;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      _cachedToken = await messaging.getToken();

      messaging.onTokenRefresh.listen((token) {
        _cachedToken = token;
        onTokenRefresh?.call(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint(
          'FCM foreground: ${message.notification?.title} — ${message.notification?.body}',
        );
        onForegroundMessage?.call(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint(
          'FCM opened: ${message.notification?.title} type=${message.data['type']}',
        );
      });

      _initialized = true;
      debugPrint(
        'FCM initialized token=${_cachedToken == null ? "null" : "…${_cachedToken!.substring(_cachedToken!.length > 8 ? _cachedToken!.length - 8 : 0)}"}',
      );
    } catch (e) {
      debugPrint('FCM init skipped (add Firebase options / google-services): $e');
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) {
      await init();
    }

    if (_cachedToken != null) return _cachedToken;

    try {
      _cachedToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }

    // Local/web without Firebase project: still register a stable fake token
    // so API device + dry-run push pipeline can be exercised.
    if ((_cachedToken == null || _cachedToken!.isEmpty) && kDebugMode) {
      _cachedToken =
          'dev-${defaultTargetPlatform.name.toLowerCase()}-placeholder';
      debugPrint('FCM using debug placeholder token');
    }

    return _cachedToken;
  }
}
