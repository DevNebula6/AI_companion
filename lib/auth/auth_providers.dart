
import 'custom_auth_user.dart';

abstract class AuthProvider {
  
    Future<void> initialize();
    Future<void> initializeHive();
    Future<void> updateUserProfile(CustomAuthUser user);
    CustomAuthUser? get currentUser;
    Future<void> logout();
    Future<CustomAuthUser> signInWithGoogle();
    Future<CustomAuthUser> signInWithFacebook();
}   
