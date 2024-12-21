
import 'custom_auth_user.dart';

abstract class AuthProvider {
  
    Future<void> initialize();

    CustomAuthUser? get currentUser;
    
    Future<CustomAuthUser> login({
      required String email,
      required String password,
    });

    Future<CustomAuthUser> createUser({
      required String email,
      required String password,  
    });
    Future<void> logout();
    Future<bool> isEmailVerified();
    Future<void> resendEmailVerification();
    Future<void> sendPasswordReset({required String toEmail});
    Future<CustomAuthUser> signInWithGoogle();
    Future<CustomAuthUser> signInWithFacebook();
}   
