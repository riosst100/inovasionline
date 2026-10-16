// File generated manually from android/app/google-services.json.
// iOS/web are not configured yet — add those platforms here once their
// config files are available.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  /// [isDev] must match the running flavor: main_dev.dart -> true (flavor
  /// `dev`, package com.inovasionline.twa.dev), main_prod.dart -> false
  /// (flavor `prod`, package com.inovasionline.app). Each is a distinct
  /// Firebase Android app with its own appId in google-services.json.
  static FirebaseOptions currentPlatform({required bool isDev}) {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return isDev ? androidDev : androidProd;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions androidProd = FirebaseOptions(
    apiKey: 'AIzaSyBUClz3FZvWgB12VQiKMRO9hOObW6KVtvo',
    appId: '1:962366033380:android:6c9e226fdf90ace37f4bf1',
    messagingSenderId: '962366033380',
    projectId: 'inovasi-online-b56b6',
    storageBucket: 'inovasi-online-b56b6.firebasestorage.app',
  );

  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyBUClz3FZvWgB12VQiKMRO9hOObW6KVtvo',
    appId: '1:962366033380:android:7180e3192cad8b297f4bf1',
    messagingSenderId: '962366033380',
    projectId: 'inovasi-online-b56b6',
    storageBucket: 'inovasi-online-b56b6.firebasestorage.app',
  );
}
