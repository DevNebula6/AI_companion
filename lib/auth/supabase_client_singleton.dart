import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseClientManager {
  static final SupabaseClientManager _instance = SupabaseClientManager._internal();
  SupabaseClient? _client;
  bool _initialized = false;
  
  factory SupabaseClientManager() {
    return _instance;
  }

  SupabaseClientManager._internal();

  Future<void> initialize({String? url, String? anonKey}) async {
    if (_initialized) return;
    
    final supabaseUrl = url ?? dotenv.env['SUPABASE_URL'];
    final supabaseKey = anonKey ?? dotenv.env['SUPABASE_KEY'];
    
    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception('Supabase URL or key not found');
    }
    
    await Supabase.initialize(
      url: supabaseUrl, 
      anonKey: supabaseKey
    );
    _client = Supabase.instance.client;
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase client not initialized. Call initialize() first.');
    }
    return _client!;
  }
}