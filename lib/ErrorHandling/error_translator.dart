import 'package:ai_companion/ErrorHandling/auth_exceptions.dart';

class ErrorTranslator {
  static String translate(Exception exception) {
    if (exception is InvalidCredentialAuthException) {
      return 'The email or password you entered is incorrect. Please try again.';
    } else if (exception is UserNotFoundAuthException) {
      return 'No account found with this email. Please check your email or sign up.';
    } else if (exception is IllegalArgumentException) {
      return 'Please fill in all required fields correctly.';
    } else if (exception is InvalidEmailAuthException) {
      return 'Please enter a valid email address.';
    } else if (exception is WeakPasswordAuthException) {
      return 'Your password is too weak. It should be at least 6 characters long.';
    } else if (exception is EmailAlreadyInUseAuthException) {
      return 'An account with this email already exists. Please use a different email or try logging in.';
    } else if (exception is EmailVerificationException) {
      return 'There was a problem verifying your email. Please try again or contact support.';
    } else if (exception is UserNotLoggedInAuthException) {
      return 'You need to be logged in to perform this action. Please log in and try again.';
    } else if (exception is FacebookLoginFailureException) {
      return 'Facebook login failed. Please try again or use a different login method.';
    } else if (exception is GoogleLoginFailureException) {
      return 'Google login failed. Please try again or use a different login method.';
    } else if (exception is CancelledByUserAuthException) {
      return 'Sign-in was cancelled. Please try again when you\'re ready.';
    } else if (exception is SessionRefreshException) {
      return 'Your session has expired. Please log in again.';
    } else if (exception is SupabaseInitializationException) {
      return 'There was a problem connecting to our services. Please check your internet connection and try again.';
    } else if (exception is LogoutException) {
      return 'There was a problem logging you out. Please try again.';
    } else if (exception is EmailVerificationCheckException) {
      return 'We couldn\'t verify your email status. Please try again later.';
    } else if (exception is PasswordResetException) {
      return 'There was a problem resetting your password. Please try again.';
    } else if (exception is PasswordUpdateException) {
      return 'There was a problem updating your password. Please try again.';
    } else if (exception is UserProfileUpdateException) {
      return 'There was a problem updating your profile. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again later.';
    }
  }
}