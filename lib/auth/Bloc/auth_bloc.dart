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
  
  //Companion selection screen
  on<AuthEventSelectCompanion>((event, emit) async {
    final currentUser = event.user;
    try {
      
      emit(AuthStateSelectCompanion(
      user: currentUser,
      isLoading: false,
    ));
    } catch (e) {
      emit(AuthStateSelectCompanion(
        user: currentUser,
        isLoading: false,
        exception: e as Exception,
      ));
    }
  });

  //user profile
  on<AuthEventUserProfile>((event, emit) async {
    final currentUser = event.user;
    try {

    await provider.updateUserProfile(event.user);

    emit(AuthStateUserProfile(
      user: currentUser,
      isLoading: false,
    ));

    // Use factory to get repository instance
    final chatRepository = await ChatRepositoryFactory.getInstance();
    final hasConversations = await chatRepository.hasConversations(currentUser.id);
    
    if (!hasConversations) {
      // No conversations - navigate to companion selection
      emit(AuthStateSelectCompanion(
        user: currentUser,
        isLoading: false,
      ));
    } else {
      // User has conversations - navigate to home
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

  //navigate to user profile
  on<AuthEventNavigateToUserProfile>((event, emit) {
    try {
        emit(AuthStateUserProfile(
        user: event.user,
        isLoading: false,
      ));
    } catch (e) {
      emit(AuthStateUserProfile(
        user: event.user,
        isLoading: false,
        exception: e as Exception,
      ));
    }
  });

  on<AuthEventNavigateToHome>((event, emit) {
    try {
      print('Navigating to home');
      emit(AuthStateLoggedIn(
      user: event.user,
      isLoading: false,
    ));
    } catch (e) {
      emit(AuthStateLoggedIn(
        user: event.user,
        isLoading: false,
        exception: e as Exception,
      ));
    }
  });
  
  on<AuthEventNavigateToCompanion>((event, emit) {
    emit(AuthStateSelectCompanion(
      user: event.user,
      isLoading: false,
    ));
  });
  
  on<AuthEventNavigateToChat>((event, emit) {
    emit(AuthStateChatPage(
      user: event.user,
      companion: event.companion,
      conversationId: event.conversationId,
      isLoading: false,
      navigationSource: event.navigationSource, // Pass the navigation source
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