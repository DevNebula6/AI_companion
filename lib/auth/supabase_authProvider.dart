import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/hive_adapter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_companion/ErrorHandling/auth_exceptions.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'auth_providers.dart';
import 'custom_auth_user.dart';

class SupabaseAuthProvider implements AuthProvider {
   SupabaseClient? _supabase;
  CustomAuthUser? _cachedUser;
  final _log = Logger('SupabaseAuthProvider');

  @override
  Future<void> initialize() async {
    try {
      // Make sure the manager is initialized
      final manager = SupabaseClientManager();
      if (!manager.isInitialized) {
        await manager.initialize(
          url: dotenv.env['SUPABASE_URL']!,
          anonKey: dotenv.env['SUPABASE_KEY']!,
        );
      }
      
      // Always get the client from the singleton after ensuring initialization
      _supabase = manager.client;
    } catch (e) {
      _log.severe('Failed to initialize Supabase client: $e');
      throw SupabaseInitializationException();
    }
  }

  @override
  Future<void> initializeHive() async {
    await Hive.initFlutter();
    Hive.registerAdapter(AICompanionAdapter());
    Hive.registerAdapter(PhysicalAttributesAdapter());
    Hive.registerAdapter(PersonalityTraitsAdapter());
    await Hive.openBox<AICompanion>('companions');
  }

  SupabaseClient get _client {
    if (_supabase == null) {
      // Try to get it if already initialized
      if (SupabaseClientManager().isInitialized) {
        _supabase = SupabaseClientManager().client;
      } else {
        // If we reach here, something is wrong with initialization
        _log.severe('Trying to use uninitialized Supabase client');
        throw SupabaseInitializationException();
      }
    }
    return _supabase!;
  }
  @override
  CustomAuthUser? get currentUser {
    try {
      if (_cachedUser != null) return _cachedUser;
      final user = _client.auth.currentUser;
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
  Future<void> updateUserProfile(CustomAuthUser user) async {
    try {
      final Map<String, dynamic> userData = {
        'id': user.id,
        'email': user.email,
        'full_name': user.fullName,
        'dob': user.dob,
        'gender': user.gender,
        'avatar_url': user.avatarUrl,
        'interests': user.interests,
        'personality_traits': user.personalityTraits,
        'chat_language': user.chatLanguage ?? 'English',
        'metadata': user.metadata,
        'device_token': user.deviceToken,
      };
      
      await _client
      .from('user_profiles')
      .upsert(userData);
        
      // Update cached user
      _cachedUser = user;
      
      // Also save to shared preferences for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toJson()));
    } catch (e) {
      _log.warning('Error updating user profile: $e');
      throw UserProfileUpdateException();
    }
  }
  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );
      _cachedUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');

    } catch (e) {
      _log.warning('Error during logout: $e');
      throw LogoutException();
    }
  }

  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      _log.warning('Error refreshing session: $e');
      throw SessionRefreshException();
    }
  }

  Future<String?> getSignInMethod() async {
    try {
      final user = _client.auth.currentUser;
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
      const webClientId = '927852452160-mngsnd3fetppnmo9fsapq70fjecnonbt.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: [
          'email',
          'profile',
        ],
      );
      
      // Sign out first to ensure clean state
      await googleSignIn.signOut();
      await _client.auth.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw CancelledByUserAuthException();
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      
      if (accessToken == null || idToken == null) {
        print("Failed to get Google access token or ID token");
        throw GoogleLoginFailureException();
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    
    if (response.session == null) {
      throw GoogleLoginFailureException();
    }
    
    final user = response.session?.user;
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
      final response = await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      
      if (!response) {
        throw FacebookLoginFailureException();
      }

      final completer = Completer<AuthState>();
      final subscription = _client.auth.onAuthStateChange.listen(
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