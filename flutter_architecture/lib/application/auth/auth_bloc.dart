import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fungiscan/infrastructure/services/authentication_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class SignIn extends AuthEvent {
  final String email;
  final String password;
  const SignIn({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUp extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const SignUp(
      {required this.email, required this.password, required this.displayName});

  @override
  List<Object?> get props => [email, password, displayName];
}

class SignOut extends AuthEvent {
  const SignOut();
}

// State
class AuthState extends Equatable {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? displayName;
  final String? email;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.displayName,
    this.email,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? displayName,
    String? email,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isAuthenticated,
        isLoading,
        userId,
        displayName,
        email,
        error,
      ];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthenticationService authService;

  AuthBloc({required this.authService}) : super(const AuthState()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignIn>(_onSignIn);
    on<SignUp>(_onSignUp);
    on<SignOut>(_onSignOut);
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Use the correct property instead of a method
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        emit(state.copyWith(
          isAuthenticated: true,
          userId: currentUser.id,
          displayName: currentUser.name,
          email: currentUser.email,
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(
          isAuthenticated: false,
          userId: null,
          displayName: null,
          email: null,
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSignIn(SignIn event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Use correct method signInWithEmail instead of signIn
      final user = await authService.signInWithEmail(
        event.email,
        event.password,
      );

      if (user != null) {
        emit(state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          userId: user.id,
          displayName: user.name,
          email: user.email,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: "Failed to sign in. Please check your credentials.",
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSignUp(SignUp event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Use correct method registerWithEmail instead of signUp
      final user = await authService.registerWithEmail(
        event.displayName,
        event.email,
        event.password,
      );

      if (user != null) {
        emit(state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          userId: user.id,
          displayName: user.name,
          email: user.email,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: "Failed to create account. Email may already be in use.",
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      await authService.signOut();
      emit(state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        userId: null,
        displayName: null,
        email: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
