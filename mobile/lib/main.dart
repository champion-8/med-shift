import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/locale/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/storage/auth_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/job_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authStorage = AuthStorage();
  await authStorage.init();

  final apiClient = ApiClient();
  apiClient.setTokenProvider(() => authStorage.token);

  final fcmService = FcmService();
  final pushNotificationService =
      PushNotificationService(apiClient, fcmService);

  fcmService.onTokenRefresh = (_) {
    pushNotificationService.registerDevice();
  };
  await fcmService.init();

  runApp(MedShiftApp(
    apiClient: apiClient,
    authStorage: authStorage,
    pushNotificationService: pushNotificationService,
  ));
}

class MedShiftApp extends StatelessWidget {
  final ApiClient apiClient;
  final AuthStorage authStorage;
  final PushNotificationService pushNotificationService;

  const MedShiftApp({
    super.key,
    required this.apiClient,
    required this.authStorage,
    required this.pushNotificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            apiClient,
            authStorage,
            pushNotificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => JobProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => MaterialApp(
          title: 'MedShift Thailand',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('th'),
            Locale('en'),
          ],
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

/// Wrapper widget to handle authentication routing
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // No logged-in user → always show login (never stay on app screens).
        if (authProvider.hasUser) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
