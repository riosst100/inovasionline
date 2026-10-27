import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';

import 'push_notification_handler.dart';

/// Thin, fire-and-forget wrapper around Firebase Analytics. Every call waits
/// for Firebase to be initialised and swallows errors: analytics is best
/// effort and must never affect the app.
class Analytics {
  Analytics._();

  static Future<void> _run(Future<void> Function(FirebaseAnalytics a) call) async {
    try {
      await firebaseReady.future;
      await call(FirebaseAnalytics.instance);
    } catch (_) {}
  }

  static void event(String name, [Map<String, Object>? params]) {
    unawaited(_run((a) => a.logEvent(name: name, parameters: params)));
  }

  static void screen(String name) {
    unawaited(_run((a) => a.logScreenView(screenName: name)));
  }

  static void setUser(String? id) {
    unawaited(_run((a) => a.setUserId(id: id)));
  }

  /// Logs a screen view for every route change, including tab switches in the
  /// bottom navigation (a NavigatorObserver would miss those).
  static void trackRouter(GoRouter router) {
    String? last;
    router.routerDelegate.addListener(() {
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path == last) return;
      last = path;
      screen(path);
    });
  }

  // Permission / location flow.
  static void locationIntroShown() => event('location_intro_shown');
  static void locationButtonTapped() => event('location_button_tapped');
  static void locationPermission({required bool granted, required bool permanent}) =>
      event('location_permission_result', {
        'granted': granted ? 1 : 0,
        'permanently_denied': permanent ? 1 : 0,
      });
  static void locationServiceResult({required bool enabled}) =>
      event('location_service_result', {'enabled': enabled ? 1 : 0});
  static void outOfArea() => event('location_out_of_area');
}
