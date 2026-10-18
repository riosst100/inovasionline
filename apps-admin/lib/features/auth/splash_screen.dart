import 'package:flutter/material.dart';

import '../shell/intro.dart';

/// Shown while the session is restored; only visible once the intro has
/// faded out, if that takes longer than the intro itself.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: splashColor,
    body: Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}
