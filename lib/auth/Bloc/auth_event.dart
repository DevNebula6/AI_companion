import 'package:flutter/foundation.dart' show immutable;

@immutable
abstract class AuthEvents{
  const AuthEvents();
}

class AuthEventInitialise extends AuthEvents {
  const AuthEventInitialise();
}

class AuthEventLogIn extends AuthEvents {
  final String email;
  final String password;
  const AuthEventLogIn(this.email, this.password);
}

class AuthEventGoogleSignIn extends AuthEvents {
  const AuthEventGoogleSignIn();
}

class AuthEventSignInWithTwitter extends AuthEvents {
 const AuthEventSignInWithTwitter();
}

class AuthEventSignInWithFacebook extends AuthEvents {
 const AuthEventSignInWithFacebook();
}

class AuthEventRegister extends AuthEvents {
  final String email;
  final String password;
  const AuthEventRegister(this.email, this.password);
}

class AuthEventNavigateToRegister extends AuthEvents {
  const AuthEventNavigateToRegister();
}

class AuthEventNavigateToSignIn extends AuthEvents {
 const AuthEventNavigateToSignIn();
}

class AuthEventNavigateToOnboarding extends AuthEvents {
 const AuthEventNavigateToOnboarding();
}

class AuthEventForgotPassword extends AuthEvents {
  final String? email;
  const AuthEventForgotPassword({this.email});
}

class AuthEventEmailVerification extends AuthEvents {
  const AuthEventEmailVerification();
}

class AuthEventResendVerificationEmail extends AuthEvents {
  const AuthEventResendVerificationEmail();
}

class AuthEventLogOut extends AuthEvents {
  const AuthEventLogOut();
}