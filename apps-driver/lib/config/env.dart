import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Root of the dedicated admin API (`/api/admin/*`); drivers sign in as admin users.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api';
}
