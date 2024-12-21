
import 'package:bloc/bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/auth_providers.dart';

class AuthBloc extends Bloc<AuthEvents, AuthState> {

  AuthBloc(AuthProvider provider)
      : super(const AuthStateUninitialized(isLoading: true)) {
    // log out
    on<AuthEventLogOut>((event, emit) async {
    try {
      await provider.logout();
      emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: false,
        intendedView: AuthView.onboarding,
      ));
    } on Exception catch (e) {
      emit(AuthStateLoggedOut(
        exception: e,
        isLoading: false,
        intendedView: AuthView.signIn,
      ));
    }
  });

  //Email Verification
  on<AuthEventEmailVerification>((event, emit) async {
      final user = provider.currentUser;
      if (user == null) {
        emit(const AuthStateLoggedOut(
          exception: null,
          isLoading: false,
          intendedView: AuthView.signIn,
        ));
        return;
      }
      emit(const AuthStateNeedsVerification(isLoading: true));
      try {
        if (await provider.isEmailVerified()) {
          emit(AuthStateLoggedIn(user: user, isLoading: false));
        } else {
          emit(const AuthStateNeedsVerification(isLoading: false));
        }
      } on Exception catch (e) {
        emit(AuthStateNeedsVerification(isLoading: false, exception: e));
      }
  });
  //Resend Verification Email
  on<AuthEventResendVerificationEmail>((event, emit) async {
      final user = provider.currentUser;
      if (user == null) {
        emit(const AuthStateLoggedOut(
          exception: null,
          isLoading: false,
          intendedView: AuthView.signIn,
        ));
        return;
      }
      emit(const AuthStateNeedsVerification(isLoading: true));
      try {
        await provider.resendEmailVerification();
        emit(const AuthStateNeedsVerification(
          isLoading: false,
          emailSent: true,
        ));
      } on Exception catch (e) {
        emit(AuthStateNeedsVerification(
          isLoading: false,
          exception: e,
        ));
      }
  });
  //navigate to register
  on<AuthEventNavigateToRegister>((event, emit) {
      emit(const AuthStateRegistering(
        exception: null,
        isLoading: false,
      ));
  });
  //navigate to sign in
  on<AuthEventNavigateToSignIn>((event, emit) {
      emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: false,
        intendedView: AuthView.signIn,
      ));
    });
  //navigate to onboarding
  on<AuthEventNavigateToOnboarding>((event, emit) {
      emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: false,
        intendedView: AuthView.onboarding,
      ));
  });
  //forgot password
  on<AuthEventForgotPassword>((event, emit) async {
      emit(const AuthStateForgotPassword(
        exception: null,
        hasSentEmail: false,
        isLoading: false,
      ));
      final email = event.email;
      if (email == null) {
        return; // user just wants to go to forgot-password screen
      }
      // user wants to actually send a forgot-password email
      emit(const AuthStateForgotPassword(
        exception: null,
        hasSentEmail: false,
        isLoading: true,
      ));

      bool didSendEmail;
      Exception? exception;
      try {
        await provider.sendPasswordReset(toEmail: email);
        didSendEmail = true;
        exception = null;
      } on Exception catch (e) {
        didSendEmail = false;
        exception = e;
      }
      emit(AuthStateForgotPassword(
        exception: exception,
        hasSentEmail: didSendEmail,
        isLoading: false,
      ));
  });
  // register
  on<AuthEventRegister>((event, emit) async {
    emit(const AuthStateRegistering(
        exception: null,
        isLoading: true,
      ));
      final email = event.email;
      final password = event.password;
      try {
        await provider.createUser(
          email: email,
          password: password,
        );
        emit(const AuthStateNeedsVerification(isLoading: false));
      } on Exception catch (e) {
        emit( AuthStateRegistering(
        exception: e,
        isLoading: false,
      ));
      }
  });
  // initialize
  on<AuthEventInitialise>((event, emit) async {
      await provider.initialize();
      final user = provider.currentUser;
      if (user == null) {
        emit(
          const AuthStateLoggedOut(
            exception: null,
            isLoading: false,
            intendedView: AuthView.onboarding,
          ),
        );
      } else if (!user.isEmailVerified) {
        emit(const AuthStateNeedsVerification(isLoading: false));
      } else {
        emit(AuthStateLoggedIn(
          user: user,
          isLoading: false,
        ));
      }
  });
  //Google Sign In
  on<AuthEventGoogleSignIn>((event, emit) async {
      emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: true,
        loadingText: 'Signing in with Google...',
      ));

      try {
        final user = await provider.signInWithGoogle();
        emit(AuthStateLoggedIn(
          user: user,
          isLoading: false,
        ));
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(
          exception: e,
          isLoading: false,
          intendedView: AuthView.signIn,
          ));
      }
  });
    
  //Facebook Sign In
  on<AuthEventSignInWithFacebook>((event, emit) async {
    emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: true,
        loadingText: 'Signing in with Facebook...',
      ));
     
      try {
        final user = await provider.signInWithFacebook();
        emit(AuthStateLoggedIn(
          user: user,
          isLoading: false,
        ));
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(
          exception: e,
          isLoading: false,
          intendedView: AuthView.signIn,
        ));
      }
  });
  // log in
  on<AuthEventLogIn>((event, emit) async {
      emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: true,
        loadingText: 'Signing in...',
      ));
      
      try {
        final user = await provider.login(
          email: event.email,
          password: event.password,
        );

        if (!user.isEmailVerified) {
          emit(const AuthStateNeedsVerification(isLoading: false));
        } else {
          emit(AuthStateLoggedIn(
            user: user,
            isLoading: false,
          ));
        }
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(
          exception: e,
          isLoading: false,
          intendedView: AuthView.signIn,
        ));
      }
  });
  }
}