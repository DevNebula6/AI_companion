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