import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'features/shell/blocked_account_gate.dart';
import 'features/shell/connectivity_gate.dart';
import 'features/shell/permission_gate.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/core_providers.dart';
import 'services/analytics.dart';
import 'services/app_presence.dart';
import 'services/push_notification_handler.dart';

Future<void> bootstrap({required String envFile, required bool isDev}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.isDev = isDev;
  // Independent of each other, so run side by side: the native splash stays
  // up until all of this is done.
  await Future.wait([
    dotenv.load(fileName: envFile),
    initializeDateFormatting('id_ID'),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    precacheSplashLogo(),
  ]);

  final container = ProviderContainer();
  // Starts restoring the session (currentUser API call) right away, so it
  // runs during the splash and intro instead of after them.
  container.read(authProvider);

  // Install / online / checkout counts for the admin dashboard.
  unawaited(AppPresence(container.read(apiClientProvider), router).start());

  // Screens, funnel and retention go to Firebase Analytics.
  Analytics.trackScreens(router);
  container.listen<String?>(
    authProvider.select((auth) => auth.user?.id),
    (_, userId) => Analytics.setUser(userId),
  );

  // Firebase + push are not needed for the first frames, so they are set up
  // behind the intro; whatever uses FirebaseMessaging awaits firebaseReady.
  unawaited(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform(isDev: isDev),
      );
      await PushNotificationHandler(container).initialize();
    } finally {
      firebaseReady.complete();
    }
  }());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const InovasiOnlineApp(),
    ),
  );
}

Future<void> main() async {
  await bootstrap(envFile: '.env', isDev: false);
}

class InovasiOnlineApp extends StatelessWidget {
  const InovasiOnlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Inovasi Online',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // Android 15+ forces edge-to-edge; keep every screen above the system
      // navigation buttons on a solid strip instead of drawing behind them.
      builder: (context, child) => ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: ConnectivityGate(
            child: PermissionGate(
              child: BlockedAccountGate(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
