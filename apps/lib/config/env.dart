import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Set by bootstrap() from the entrypoint (main_dev.dart / main_prod.dart).
  static bool isDev = false;

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';

  static String get appBaseUrl => dotenv.env['APP_BASE_URL'] ?? 'http://10.0.2.2:8000';

  /// Folder with release.json + the APK that CI publishes (the /download
  /// page). Null in dev, which turns the in-app update check off: the dev
  /// flavor has its own application id, so the prod APK would not replace it.
  static String? get releaseBaseUrl =>
      dotenv.env['RELEASE_BASE_URL'] ??
      (isDev ? null : 'https://inovasionline.com/download');

  static String? get googleServerClientId => dotenv.env['GOOGLE_SERVER_CLIENT_ID'];

  static String get reverbHost => dotenv.env['REVERB_HOST'] ?? '10.0.2.2';

  static int get reverbPort => int.tryParse(dotenv.env['REVERB_PORT'] ?? '') ?? 8080;

  static String get reverbScheme => dotenv.env['REVERB_SCHEME'] ?? 'http';

  static String get reverbAppKey => dotenv.env['REVERB_APP_KEY'] ?? 'inovasionline-key';
}
