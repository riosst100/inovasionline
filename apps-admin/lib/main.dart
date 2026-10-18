import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/env.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'features/shell/intro.dart';

Future<void> bootstrap({required String envFile, required bool isDev}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.isDev = isDev;
  await Future.wait([
    dotenv.load(fileName: envFile),
    initializeDateFormatting('id_ID'),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    precacheSplashLogo(),
  ]);

  runApp(const ProviderScope(child: AdminApp()));
}

Future<void> main() async {
  await bootstrap(envFile: '.env', isDev: false);
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Inovasi Online Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => IntroGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
