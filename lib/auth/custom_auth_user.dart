import 'package:flutter/material.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class CustomAuthUser {
  final String id;
  final String email;
  final String? fullName;
  final String? dob;
  final String? gender;
  final String? avatarUrl;
  final String? preferences;
  final String? aiModel;
  final String? chatLanguage;
  final Map<String, dynamic> metadata;
  final String? deviceToken; // For push notifications


  const CustomAuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.dob,
    this.gender,
    this.avatarUrl,
    this.preferences,
    this.chatLanguage,
    this.metadata = const {},
    this.deviceToken,
    this.aiModel,
  });

  static Future<CustomAuthUser?> getCurrentUser() async {
    try {
      final supabase = SupabaseClientManager().client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Refresh the session to get the most up-to-date user data
        await supabase.auth.refreshSession();
        final refreshedUser = supabase.auth.currentUser;
        if (refreshedUser != null && refreshedUser.email != null) {
          return CustomAuthUser.fromSupabase(refreshedUser);
        }
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
  // Create from Supabase User
  factory CustomAuthUser.fromSupabase(User user) {
    return CustomAuthUser(
      id: user.id,
      email: user.email ?? '',
      avatarUrl: user.userMetadata?['avatar_url'],
      fullName: user.userMetadata?['full_name'],
      metadata: user.userMetadata ?? {},
      deviceToken: user.userMetadata?['device_token'],
    );
  }
  
  // Create from database record
  factory CustomAuthUser.fromJson(Map<String, dynamic> json) {
    return CustomAuthUser(
      id: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'],
      avatarUrl: json['img_url'],
      metadata: json['metadata'] ?? {},

      deviceToken: json['device_token'],
    );
  }

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'uid': id,
      'email': email,
      'full_name': fullName,
      'img_url': avatarUrl,
      'metadata': metadata,
      'device_token': deviceToken,
      'dob': dob,
    };
  }

  // Create copy with modifications
  CustomAuthUser copyWith({
    String? fullName,
    String? dob,
    String? avatarUrl,
    String? preferences,
    String? aiModel,
    String? deviceToken,

  }) {
    return CustomAuthUser(
      id: id,
      email: email,
      dob: dob ?? this.dob,
      preferences: preferences ?? this.preferences, 
      aiModel: aiModel ?? this.aiModel, 
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata,
      deviceToken: deviceToken ?? this.deviceToken,
    );
  }

   // Utility methods
  bool get hasCompletedProfile => 
      preferences != null && fullName != null ;

}