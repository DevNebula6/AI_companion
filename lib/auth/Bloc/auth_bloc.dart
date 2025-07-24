import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/auth_providers.dart';

class AuthBloc extends Bloc<AuthEvents, AuthState> {
  final bool isInitialized;

  AuthBloc(AuthProvider provider, {this.isInitialized = false})
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

  //user profile
  on<AuthEventUserProfile>((event, emit) async {
    final currentUser = event.user;

    try {

      await provider.updateUserProfile(event.user);

      // Use factory to get repository instance
      final chatRepository = await ChatRepositoryFactory.getInstance();
      final hasConversations = await chatRepository.hasConversations(currentUser.id);
      
      if (!hasConversations) {
      print('AuthBloc: No conversations, emitting AuthStateSelectCompanion');
        emit(AuthStateLoggedIn(
          user: currentUser,
          isLoading: false,
          intendedView: LoggedInView.companionSelection
        ));
      } else {
      print('AuthBloc: Has conversations, emitting AuthStateLoggedIn');
        emit(AuthStateLoggedIn(
          user: currentUser,
          isLoading: false,
          intendedView: LoggedInView.home, // Default to home view
        ));
      }
    }
    catch (e) {
    print('AuthBloc: Error updating profile: $e');
      emit(AuthStateLoggedIn(
        user: currentUser,
        isLoading: false,
        exception: e as Exception,
        intendedView: LoggedInView.userProfile, // Default to user profile view
      ));
    }
      
  });
  
  //Navigate to home from select companion
  on<NavigateToHome>((event, emit) async {
    emit(AuthStateLoggedIn(
      user: event.user,
      isLoading: false,
      intendedView: LoggedInView.home,
    ));
  });
  
  // initialize
  on<AuthEventInitialise>((event, emit) async {
    if (!isInitialized) {
        await provider.initialize();
      }
    final user = await CustomAuthUser.getCurrentUser(); 
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
          emit(AuthStateLoggedIn(
            user: user,
            isLoading: false,
            intendedView: LoggedInView.userProfile, // Default to user profile view
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
        await provider.signInWithGoogle();
        final user = await CustomAuthUser.getCurrentUser();
        
        if (user == null) {
          emit(const AuthStateLoggedOut(
            exception: null,
            isLoading: false,
            intendedView: AuthView.onboarding,
          ));
          return;
        }
        if (!user.hasCompletedProfile) {
          emit(AuthStateLoggedIn(
            user: user,
            isLoading: false,
            intendedView: LoggedInView.userProfile,
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