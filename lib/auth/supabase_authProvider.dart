import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_companion/auth/auth_exceptions.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'auth_providers.dart';
import 'custom_auth_user.dart';

class SupabaseAuthProvider implements AuthProvider {
  late final SupabaseClient _supabase;
  CustomAuthUser? _cachedUser;
  final _log = Logger('SupabaseAuthProvider');

  @override
  Future<void> initialize() async {
    try {
      await SupabaseClientManager().initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_KEY']!,
      );
      _supabase = SupabaseClientManager().client;
    } catch (e) {
      _log.severe('Failed to initialize Supabase client: $e');
      throw SupabaseInitializationException();
    }
  }
  @override
  Future<CustomAuthUser> createUser({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        return CustomAuthUser.fromSupabase(user);
      } else {
        throw UserNotLoggedInAuthException();
      }
    } on AuthException catch (e) {
      _log.warning('AuthException during user creation: ${e.message}');
      switch (e.message) {
        case 'User already registered':
          throw EmailAlreadyInUseAuthException();
        case 'Invalid email':
          throw InvalidEmailAuthException();
        case 'Password should be at least 6 characters':
          throw WeakPasswordAuthException();
        case 'Unable to validate email address: invalid format':
          throw InvalidEmailAuthException();
        default:
          _log.severe('Unhandled AuthException during user creation: ${e.message}');
          throw GenericAuthException();
      }
    } catch (e) {
      _log.severe('Unexpected error during user creation: $e');
      throw GenericAuthException();
    }
  }
  @override
  CustomAuthUser? get currentUser {
    try {
      if (_cachedUser != null) return _cachedUser;
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _cachedUser = CustomAuthUser.fromSupabase(user);
        return _cachedUser;
      }
      return null;
    } catch (e) {
      _log.warning('Error getting current user: $e');
      return null;
    }
  }

  @override
  Future<CustomAuthUser> login({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        return CustomAuthUser.fromSupabase(user);
      } else {
        throw UserNotLoggedInAuthException();
      }
    } on AuthException catch (e) {
      _log.warning('AuthException during login: ${e.message}');
      switch (e.message) {
        case 'Invalid login credentials':
          throw InvalidCredentialAuthException();
        case 'User Bad Email Address':
          throw InvalidEmailAuthException();
        case 'Usernotfound':
          throw UserNotFoundAuthException();
        default:
          throw GenericAuthException();
      }
    } catch (e) {
      _log.severe('Unexpected error during login: $e');
      throw GenericAuthException();
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      _cachedUser = null;
    } catch (e) {
      _log.warning('Error during logout: $e');
      throw LogoutException();
    }
  }

  @override
  Future<void> resendEmailVerification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw UserNotLoggedInAuthException();
      
      await _supabase.auth.resend(type: OtpType.signup, email: user.email);
    } on AuthException catch (e) {
      _log.warning('AuthException during email verification resend: ${e.message}');
      throw EmailVerificationException();
    } catch (e) {
      _log.severe('Unexpected error during email verification resend: $e');
      throw EmailVerificationException();
    }
  }

  @override
  Future<bool> isEmailVerified() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw UserNotLoggedInAuthException();
      
      final updatedUser = await _supabase.auth.getUser();
      return updatedUser.user?.emailConfirmedAt != null;
    } catch (e) {
      _log.warning('Error checking email verification status: $e');
      throw EmailVerificationCheckException();
    }
  }

  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (e) {
      _log.warning('Error refreshing session: $e');
      throw SessionRefreshException();
    }
  }

  @override
  Future<void> sendPasswordReset({required String toEmail}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(toEmail);
    } on AuthException catch (e) {
      _log.warning('AuthException during password reset: ${e.message}');
      throw PasswordResetException();
    } catch (e) {
      _log.severe('Unexpected error during password reset: $e');
      throw PasswordResetException();
    }
  }
  
  Future<String?> getSignInMethod() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      
      return user.appMetadata['provider'] as String? ?? 'email';
    } catch (e) {
      _log.warning('Error getting sign-in method: $e');
      return null;
    }
  }

@override
Future<CustomAuthUser> signInWithGoogle() async {
  try {
    final response = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
       redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      authScreenLaunchMode: LaunchMode.inAppWebView,
    );
    if (!response) {
      throw GoogleLoginFailureException();
    }
    
    final completer = Completer<AuthState>();
    final subscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        if (data.session != null && !completer.isCompleted) {
          completer.complete(data);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    final authState = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        subscription.cancel();
        throw LoginTimeoutException();
      },
    );

    subscription.cancel();

    final user = authState.session?.user;
    if (user == null) {
      throw UserNotLoggedInAuthException();
    }
    return CustomAuthUser.fromSupabase(user);
  } on AuthException catch (e) {
    _log.warning('AuthException during facebook sign-in: ${e.message}');
    if (e.message.toLowerCase().contains('popup_closed_by_user') ||
        e.message.toLowerCase().contains('canceled')) {
      throw CancelledByUserAuthException();
    } else {
      throw GoogleLoginFailureException();
    }
  } on TimeoutException {
    _log.warning('Timeout during Google sign-in');
    throw LoginTimeoutException();
  } catch (e) {
    _log.severe('Unexpected error during Google sign-in: $e');
    throw GoogleLoginFailureException();
  }
}

  @override
  Future<CustomAuthUser> signInWithFacebook() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      
      if (!response) {
        throw FacebookLoginFailureException();
      }

      final completer = Completer<AuthState>();
      final subscription = _supabase.auth.onAuthStateChange.listen(
        (data) {
          if (data.session != null && !completer.isCompleted) {
            completer.complete(data);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      final authState = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          throw LoginTimeoutException();
        },
      );

      subscription.cancel();

      final user = authState.session?.user;
      if (user == null) {
        throw UserNotLoggedInAuthException();
      }

      return CustomAuthUser.fromSupabase(user);
    } on AuthException catch (e) {
      _log.warning('AuthException during facebook sign-in: ${e.message}');
      if (e.message.toLowerCase().contains('popup_closed_by_user') ||
          e.message.toLowerCase().contains('canceled')) {
        throw CancelledByUserAuthException();
      } else {
        throw FacebookLoginFailureException();
      }
    } on TimeoutException {
      _log.warning('Timeout during Facebook sign-in');
      throw LoginTimeoutException();
    } catch (e) {
      _log.severe('Unexpected error during Facebook sign-in: $e');
      throw FacebookLoginFailureException();
    }
  }
}