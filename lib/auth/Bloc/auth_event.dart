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


class AuthEventUserProfile extends AuthEvents {
  final CustomAuthUser user;
 const AuthEventUserProfile({
  required  this.user,
  });
}

class NavigateToHome extends AuthEvents {
  final CustomAuthUser user;
 const NavigateToHome({
  required this.user,
  });
}



class AuthEventLogOut extends AuthEvents {
 const AuthEventLogOut();
}