
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
abstract class AuthEvents{
  const AuthEvents();
}

class AuthEventInitialise extends AuthEvents {
  const AuthEventInitialise();
}

class AuthEventGoogleSignIn extends AuthEvents {
  const AuthEventGoogleSignIn();
}

class AuthEventSignInWithFacebook extends AuthEvents {
 const AuthEventSignInWithFacebook();
}

class AuthEventUserProfile extends AuthEvents {
  final CustomAuthUser user;
 const AuthEventUserProfile({
  required  this.user,
  });
}

class AuthEventCompanionSelection extends AuthEvents {
  const AuthEventCompanionSelection();
}

class AuthEventNavigateToSignIn extends AuthEvents {
 const AuthEventNavigateToSignIn();
}

class AuthEventNavigateToOnboarding extends AuthEvents {
 const AuthEventNavigateToOnboarding();
}

class AuthEventLogOut extends AuthEvents {
 const AuthEventLogOut();
}