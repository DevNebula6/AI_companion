
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
abstract class AuthEvents{
  const AuthEvents();
}

class AuthEventInitialise extends AuthEvents {
  const AuthEventInitialise();
}
class AuthEventNavigateToHome extends AuthEvents {
  final CustomAuthUser user;
  
  const AuthEventNavigateToHome({required this.user});
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

class AuthEventSelectCompanion extends AuthEvents {
  final CustomAuthUser user;
 const AuthEventSelectCompanion({
  required this.user,
  });
}

class AuthEventCompanionSelection extends AuthEvents {
  const AuthEventCompanionSelection();
}

class AuthEventNavigateToCompanion extends AuthEvents {
  final CustomAuthUser user;
  const AuthEventNavigateToCompanion({required this.user});
}

class AuthEventNavigateToChat extends AuthEvents {
  final CustomAuthUser user;
  final AICompanion companion;
  final String conversationId;
  
  const AuthEventNavigateToChat({
    required this.conversationId,
    required this.user,
    required this.companion,
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