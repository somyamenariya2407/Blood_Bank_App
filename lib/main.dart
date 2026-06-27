import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'services/app_preferences_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/common/auth_gate.dart';
import 'utils/app_text.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _openNotificationDestination() {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNotificationDestination();
    });
    return;
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  final destination = currentUser == null
      ? const LoginScreen()
      : const AuthGate();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destination),
    (route) => false,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  OneSignal.initialize("88d53344-cd26-470f-a728-38df931e0f4c");
  OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });

  OneSignal.Notifications.addClickListener((event) {
    _openNotificationDestination();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPreferencesService.themeMode,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppPreferencesService.locale,
          builder: (context, locale, localeChild) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Blood Bank App',
              themeMode: themeMode,
              locale: locale,
              supportedLocales: AppText.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFB71C1C),
                ),
                scaffoldBackgroundColor: const Color(0xFFF4F1EE),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFB71C1C),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
              ),
              home: const AuthGate(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/home': (context) => const AuthGate(),
              },
            );
          },
        );
      },
    );
  }
}
