import 'package:ai_companion/Companion/ai_model.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:equatable/equatable.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';

enum AuthView {
  signIn,
  register,
  onboarding,
}

@immutable
abstract class AuthState {
  final bool isLoading;
  final String? loadingText;
  const AuthState({
    required this.isLoading,
    this.loadingText = 'Please wait a moment',
  });
}

class AuthStateUninitialized extends AuthState {
  const AuthStateUninitialized({required super.isLoading});
}


class AuthStateLoggedIn extends AuthState {
  final CustomAuthUser user;
  final Exception? exception;
  const AuthStateLoggedIn({
    required this.user,
    required super.isLoading,
    this.exception,
  });
}
class AuthStateUserProfile extends AuthState {
  final CustomAuthUser user;
  final Exception? exception;
  const AuthStateUserProfile({
    required this.user,
    required super.isLoading,
    this.exception,
  });
}

class AuthStateChatPage extends AuthState {
  final CustomAuthUser user;
  final AICompanion companion;
  final String conversationId;
  final String? navigationSource; // Add this parameter
  
  const AuthStateChatPage({
    required this.conversationId,
    required this.user,
    required this.companion, 
    required super.isLoading,
    this.navigationSource,
  });
  
  
  List<Object?> get props => [user, companion, isLoading, navigationSource];
}

class AuthStateSelectCompanion extends AuthState {
  final CustomAuthUser user;
  final Exception? exception;
  const AuthStateSelectCompanion({
    required this.user,
    required super.isLoading,
    this.exception,
  });
}

class AuthStateLoggedOut extends AuthState with EquatableMixin {
  final Exception? exception;
  @override
  final bool isLoading;
  @override
  final String? loadingText;
  final AuthView intendedView; 
  
  const AuthStateLoggedOut({
    required this.exception,
    required this.isLoading,
    this.loadingText ,
    this.intendedView = AuthView.signIn, // Default to sign in view
  }) : super(isLoading: false);

  @override
  List<Object?> get props => [exception, isLoading, intendedView];
}