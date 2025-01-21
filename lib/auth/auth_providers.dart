
import 'custom_auth_user.dart';

abstract class AuthProvider {
  
    Future<void> initialize();
    CustomAuthUser? get currentUser;
    Future<void> logout();
    Future<CustomAuthUser> signInWithGoogle();
    Future<CustomAuthUser> signInWithFacebook();
}   
