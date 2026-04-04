import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'providers/project_provider.dart';
import 'providers/session_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'router/app_router.dart';
import 'utils/app_theme.dart';

/// Replace this stub with the generated firebase_options.dart:
///   Run: flutterfire configure
/// Then import and pass DefaultFirebaseOptions.currentPlatform below.
///
/// For now Firebase is initialized without explicit options, which works
/// when google-services.json (Android) / GoogleService-Info.plist (iOS)
/// are present at build time.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (picks up google-services.json / GoogleService-Info.plist).
  // If you have firebase_options.dart from flutterfire configure, pass:
  //   options: DefaultFirebaseOptions.currentPlatform
  await Firebase.initializeApp();

  await NotificationService.instance.initialize();

  runApp(const MernG11App());
}

class MernG11App extends StatelessWidget {
  const MernG11App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.createRouter(context);
          return MaterialApp.router(
            title: 'G11 Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
