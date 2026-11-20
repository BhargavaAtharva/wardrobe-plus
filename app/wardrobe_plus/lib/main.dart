import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/config.dart';
import 'services/image_store.dart';
import 'services/user_profile.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([AppConfig.load(), ImageStore.init()]);
  ApiClient.onUnauthorized = _backToSignIn;
  runApp(const WardrobePlusApp());
}

final navigatorKey = GlobalKey<NavigatorState>();
bool _redirecting = false;

/// The server rejected our token (e.g. account removed): sign out and show sign in.
Future<void> _backToSignIn() async {
  if (_redirecting) return;
  _redirecting = true;
  await UserProfile.signOut(tellServer: false);
  navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  _redirecting = false;
}

class WardrobePlusApp extends StatelessWidget {
  const WardrobePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACloset AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}
