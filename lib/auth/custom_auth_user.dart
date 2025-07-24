import 'dart:convert';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:flutter/material.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class CustomAuthUser {
  final String id;
  final String email;
  final String? fullName;
  final String? dob;
  final String? gender;
  final String? avatarUrl;
  final String? interests;
  final String? personalityTraits;
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
    this.interests,
    this.personalityTraits,
    this.chatLanguage,
    this.metadata = const {},
    this.deviceToken,
  });

  static Future<CustomAuthUser?> getCurrentUser() async {
    try {
      // First try to get from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      
      if (userData != null && userData.isNotEmpty) {
        final Map<String, dynamic> jsonData = jsonDecode(userData);
        if (jsonData.isNotEmpty) {
          return CustomAuthUser.fromJson(jsonData);
        }
      }
      
      // If not found locally, get from Supabase
      final supabase = SupabaseClientManager().client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Get basic user from auth
        final basicUser = CustomAuthUser.fromSupabase(currentUser);
        
        // Fetch full profile data
        try {
          final profileData = await supabase
            .from('user_profiles')
            .select()
            .eq('id', basicUser.id)
            .single();
            
          // Return complete user with profile data
          return CustomAuthUser(
            id: basicUser.id,
            email: basicUser.email,
            fullName: profileData['full_name'] ?? basicUser.fullName,
            avatarUrl: profileData['avatar_url'] ?? basicUser.avatarUrl,
            dob: profileData['dob'],
            gender: profileData['gender'],
            interests: profileData['interests'],
            personalityTraits: profileData['personality_traits'],
            chatLanguage: profileData['chat_language'],
            metadata: profileData['metadata'] ?? basicUser.metadata,
            deviceToken: profileData['device_token'] ?? basicUser.deviceToken,
          );
        } catch (e) {
          print('Error fetching user profile: $e');
          return basicUser; // Return basic user if profile fetch fails
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
    dob: json['dob'],
    interests: json['interests'],
    personalityTraits: json['personality_traits'],
    deviceToken: json['device_token'],
    chatLanguage: json['chat_language'],
    gender: json['gender'], 
  );
}
  // Add getters for lists
  List<String> get interestsList => 
      interests?.split(',').map((e) => e.trim()).toList() ?? [];

  List<String> get personalityTraitsList => 
      personalityTraits?.split(',').map((e) => e.trim()).toList() ?? [];

  Map<String, dynamic> toJson() {
    return {
      'uid': id,
      'email': email,
      'full_name': fullName,
      'img_url': avatarUrl,
      'metadata': metadata,
      'device_token': deviceToken,
      'dob': dob,
      'interests': interests,
      'personality_traits': personalityTraits,
      'chat_language': chatLanguage,
      'gender': gender,
    };
    }

  // Add method to get AI-ready format
  Map<String, dynamic> toAIFormat() {
    return {
      'name': fullName ?? '',
      'interests': interestsList,
      'personality_traits': personalityTraitsList,
      'age': dob != null ? _calculateAge(DateTime.parse(dob!)) : null,
      'gender': gender ?? '',
      'chat_language': chatLanguage ?? 'English',
    };
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
       (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }


  // Create copy with modifications
  CustomAuthUser copyWith({
    String? fullName,
    String? dob,
    String? avatarUrl,
    String? interests,
    AICompanion? aiModel,
    String? gender,
    String? deviceToken,
    String? chatLanguage,
    String? personalityTraits,
    Map<String, dynamic>? metadata,
  }) {
    return CustomAuthUser(
      id: id,
      email: email,
      dob: dob ?? this.dob,
      interests: interests ?? this.interests, 
      gender: gender ?? this.gender,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
      deviceToken: deviceToken ?? this.deviceToken,
      chatLanguage: chatLanguage ?? this.chatLanguage,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      
    );
  }

   // Utility methods
  bool get hasCompletedProfile => 
      fullName != null && 
      fullName!.isNotEmpty &&
      interestsList.isNotEmpty &&
      personalityTraitsList.isNotEmpty;

}