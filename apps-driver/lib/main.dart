import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/theme.dart';
import 'core/permissions.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'providers/providers.dart';

Future<void> bootstrap({required String envFile}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    dotenv.load(fileName: envFile),
    initializeDateFormatting('id_ID'),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]);

  runApp(const ProviderScope(child: DriverApp()));
}

Future<void> main() => bootstrap(envFile: '.env');

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  @override
  void initState() {
    super.initState();
    // Right after the splash (first frame): camera + location prompts up front, not mid-scan.
    WidgetsBinding.instance.addPostFrameCallback((_) => requestStartupPermissions());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inovasi Online Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AuthGate(),
    );
  }
}

/// Login when signed out, the parcel list when signed in.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(authProvider).status) {
      AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => const HomeScreen(),
    };
  }
}
