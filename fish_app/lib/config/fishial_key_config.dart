import 'package:flutter_dotenv/flutter_dotenv.dart';

class FishialConfig {
  static String get clientId => dotenv.env['FISHIAL_CLIENT_ID'] ?? '';
  static String get clientSecret => dotenv.env['FISHIAL_CLIENT_SECRET'] ?? '';
}