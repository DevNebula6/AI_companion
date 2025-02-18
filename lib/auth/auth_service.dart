// import 'package:samadhan_chat/Auth/supabase_authProvider.dart';
import 'package:ai_companion/auth/supabase_authProvider.dart';

import 'auth_providers.dart';
import 'custom_auth_user.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;
  AuthService(this.provider);
  
  factory AuthService.supabase() => AuthService(SupabaseAuthProvider() as AuthProvider);

  @override
  Future<void> initialize() => (provider.initialize());

  @override
  Future<void> initializeHive() => provider.initializeHive();

  @override
  CustomAuthUser? get currentUser => provider.currentUser;
  
  @override
  Future<void> logout() => provider.logout();
  
  @override
  Future<CustomAuthUser> signInWithGoogle() => provider.signInWithGoogle();
  
  @override
  Future<CustomAuthUser> signInWithFacebook() => provider.signInWithFacebook(); 
  
}