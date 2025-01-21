import 'dart:io';

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
 const AuthEventUserProfile({
  required String fullName, 
  required String username, 
  File? profileImage
  });
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