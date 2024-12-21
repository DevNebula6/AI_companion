import 'package:flutter/material.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class CustomAuthUser {
  final String id;
  final String email;
  final String? avatarUrl;
  final String? providerType;
  final Map<String, dynamic> metadata;

  const CustomAuthUser({
    required this.id,
    required this.email,
    this.avatarUrl,
    this.providerType,
    this.metadata = const {},
  });
  bool get isEmailVerified {
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    return currentUser?.emailConfirmedAt != null;
  }

  static Future<CustomAuthUser?> getCurrentUser() async {
    try {
      final supabase = SupabaseClientManager().client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Refresh the session to get the most up-to-date user data
        await supabase.auth.refreshSession();
        final refreshedUser = supabase.auth.currentUser;
        if (refreshedUser != null && refreshedUser.email != null) {
          return CustomAuthUser(
            id: refreshedUser.id,
            email: refreshedUser.email!,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  factory CustomAuthUser.fromSupabase(User user) {
    return CustomAuthUser(
      id: user.id,
      email: user.email ?? '',
      avatarUrl: user.userMetadata?['avatar_url'],
      providerType: user.appMetadata['provider'],
      metadata: user.userMetadata ?? {},
    );
  }
}