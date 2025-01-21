
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
      } else {
        if (user.hasCompletedProfile) {
          emit(AuthStateLoggedIn(
            user: user,
            isLoading: false,
          ));
        } else {
          emit(AuthStateUserProfile(
            user: user,
            isLoading: false,
          ));
        }
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
        if (!user.hasCompletedProfile) {
          emit( AuthStateUserProfile(
            user: user,
            isLoading: false,
          ));
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
    
  //Facebook Sign In
  on<AuthEventSignInWithFacebook>((event, emit) async {
    emit(const AuthStateLoggedOut(
        exception: null,
        isLoading: true,
        loadingText: 'Signing in with Facebook...',
      ));
     
      try {
        final user = await provider.signInWithFacebook();
        if (!user.hasCompletedProfile) {
          emit( AuthStateUserProfile(
            user: user,
            isLoading: false,
          ));
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
  // log in
  // on<AuthEventLogIn>((event, emit) async {
  //     emit(const AuthStateLoggedOut(
  //       exception: null,
  //       isLoading: true,
  //       loadingText: 'Signing in...',
  //     ));
      
  //     try {
  //       final user = await provider.login(
  //         email: event.email,
  //         password: event.password,
  //       );

  //       if (!user.hasCompletedProfile) {
  //         emit( AuthStateUserProfile(
  //           user: user,
  //           isLoading: false,
  //         ));
  //       } else {
  //         emit(AuthStateLoggedIn(
  //           user: user,
  //           isLoading: false,
  //         ));
  //       }
  //     } on Exception catch (e) {
  //       emit(AuthStateLoggedOut(
  //         exception: e,
  //         isLoading: false,
  //         intendedView: AuthView.signIn,
  //       ));
  //     }
  // });
   }
}