import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get azureKey => dotenv.env['AZURE_KEY'] ?? '';
  
  static const String appName = 'ReadRight';
  static const int primaryColor = 0xFF6BD425;
  static const int secondaryColor = 0xFF4DB6E2;
}