import 'package:flutter/foundation.dart' show immutable;
import 'package:equatable/equatable.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';

enum AuthView {
  signIn,
  register,
  onboarding,
}
enum LoggedInView {
  home,
  userProfile,
  companionSelection,
  chat,
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


class AuthStateLoggedIn extends AuthState with EquatableMixin {
  final CustomAuthUser user;
  final Exception? exception;
  final LoggedInView intendedView; 

  const AuthStateLoggedIn({
    required this.user,
    required super.isLoading,
    this.exception,
    this.intendedView = LoggedInView.home,
  });

  @override
  List<Object?> get props => [user, isLoading, exception, intendedView];
}

class AuthStateLoggedOut extends AuthState with EquatableMixin {
  final Exception? exception;
  final AuthView intendedView; 
  @override
  final String? loadingText;

  const AuthStateLoggedOut({
    required this.exception,
    required super.isLoading,
    this.loadingText ,
    this.intendedView = AuthView.signIn, // Default to sign in view
  });

  @override
  List<Object?> get props => [exception, isLoading, intendedView];
}