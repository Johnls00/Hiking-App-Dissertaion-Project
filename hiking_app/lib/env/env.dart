import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get mapboxKey {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) {
      debugPrint('Warning: MAPBOX_ACCESS_TOKEN not found in .env file');
    }
    return token;
  }
}
