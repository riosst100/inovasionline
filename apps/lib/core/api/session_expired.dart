import 'package:flutter/foundation.dart';

/// Raised when the server rejects the saved login token (401) while the app thinks the user is
/// signed in, e.g. the token expired or was revoked. The auth state listens and signs the user out,
/// so pages show the "Masuk" prompt instead of an "Unauthenticated" error.
class SessionExpired {
  SessionExpired._();

  static final ValueNotifier<int> signal = ValueNotifier<int>(0);

  static void notify() => signal.value++;
}
