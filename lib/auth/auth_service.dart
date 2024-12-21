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
  Future<CustomAuthUser> createUser({
    required String email, 
    required String password,
    }) 
    => provider.createUser(email: email, password: password);
  
  @override
  CustomAuthUser? get currentUser => provider.currentUser;
  
  @override
  Future<CustomAuthUser> login({
    required String email, 
    required String password,
    }) => provider.login(email: email, password: password);
  
  @override
  Future<void> logout() => provider.logout();
  
  @override
  Future<void> resendEmailVerification() => provider.resendEmailVerification();

  @override
  Future<bool> isEmailVerified() => provider.isEmailVerified();
  
  @override
  Future<void> sendPasswordReset({required String toEmail}) => provider.sendPasswordReset(toEmail: toEmail);
  
  @override
  Future<CustomAuthUser> signInWithGoogle() => provider.signInWithGoogle();
  
  @override
  Future<CustomAuthUser> signInWithFacebook() => provider.signInWithFacebook(); 
  
}