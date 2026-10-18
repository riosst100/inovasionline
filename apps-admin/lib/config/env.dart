import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Set by bootstrap() from the entrypoint (main_dev.dart / main_prod.dart).
  static bool isDev = false;

  /// Root of the dedicated admin API (`/api/admin/*`), not the customer `/api/v1`.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api';
}
