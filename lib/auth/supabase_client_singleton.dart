import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientManager {
  static final SupabaseClientManager _instance = SupabaseClientManager._internal();

  factory SupabaseClientManager() {
    return _instance;
  }

  SupabaseClientManager._internal();

  late SupabaseClient _client;

  Future<void> initialize({required String url, required String anonKey}) async {
    await Supabase.initialize(
      url: url, 
      anonKey: anonKey
      );
    _client = Supabase.instance.client;
  }

  SupabaseClient get client => _client;
}
//usage
//  = SupabaseClientManager().client