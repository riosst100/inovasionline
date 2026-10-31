import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Set by bootstrap() from the entrypoint (main_dev.dart / main_prod.dart).
  static bool isDev = false;

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';

  static String get appBaseUrl => dotenv.env['APP_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static String? get googleServerClientId => dotenv.env['GOOGLE_SERVER_CLIENT_ID'];

  static String get reverbHost => _nonEmpty('REVERB_HOST') ?? '10.0.2.2';

  static int get reverbPort => int.tryParse(dotenv.env['REVERB_PORT'] ?? '') ?? 8080;

  static String get reverbScheme => dotenv.env['REVERB_SCHEME'] ?? 'http';

  static String get reverbAppKey => _nonEmpty('REVERB_APP_KEY') ?? 'inovasionline-key';

  /// Order tracking map: `maptiler` (default) or `google` (needs the Google Maps key in the native config).
  static bool get useGoogleMaps => dotenv.env['MAP_PROVIDER'] == 'google';

  /// Null falls back to OpenStreetMap's own tiles, which are fine for testing but not for release.
  static String? get maptilerKey => _nonEmpty('MAPTILER_KEY');

  static String? _nonEmpty(String key) {
    final value = dotenv.env[key];
    return value == null || value.isEmpty ? null : value;
  }
}
