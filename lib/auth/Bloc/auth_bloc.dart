import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        intendedView: AuthView.onboarding,
      ));
    }
  });
  //logged in
  on<AuthEventLoggedIn>((event, emit) {
    emit(AuthStateLoggedIn(
      user: event.user,
      isLoading: false,
    ));
  });
  //Companion selection screen
  


  //user profile
  on<AuthEventUserProfile>((event, emit) async {
    final currentUser = event.user;
    try {
    // Save updated user to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(currentUser.toJson()));

    emit(AuthStateUserProfile(
      user: currentUser,
      isLoading: false,
    ));

    if(currentUser.aiModel?.name == '' || currentUser.aiModel == null) {
      emit(AuthStateSelectCompanion(
        user: currentUser,
        isLoading: false,
      ));
    } else {
      emit(AuthStateLoggedIn(
        user: currentUser,
        isLoading: false,
      ));
    }
    }
    catch (e) {
      emit(AuthStateUserProfile(
        user: currentUser,
        isLoading: false,
        exception: e as Exception,
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
   }
}