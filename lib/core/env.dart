import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get baseUrl {
    final v = (dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:3000').trim();
    // Debug
    // ignore: avoid_print
    print('BASE_URL (Flutter) -> $v');
    return v;
  }

  static String get mapboxToken => (dotenv.env['MAPBOX_TOKEN'] ?? '').trim();

  // Opcional: threshold para /routes/fastest
  static double get fastestThresholdM =>
      double.tryParse((dotenv.env['FASTEST_THRESHOLD_M'] ?? '200').trim()) ??
          200.0;
}