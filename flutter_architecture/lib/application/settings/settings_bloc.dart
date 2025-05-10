import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fungiscan/infrastructure/services/encryption_service.dart';

// Events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class UpdateThemeMode extends SettingsEvent {
  final bool isDarkMode;
  const UpdateThemeMode(this.isDarkMode);

  @override
  List<Object?> get props => [isDarkMode];
}

class UpdateNotificationsEnabled extends SettingsEvent {
  final bool enabled;
  const UpdateNotificationsEnabled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateLocationTracking extends SettingsEvent {
  final bool enabled;
  const UpdateLocationTracking(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

// State
class SettingsState extends Equatable {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool locationTrackingEnabled;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.locationTrackingEnabled = true,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? locationTrackingEnabled,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationTrackingEnabled:
          locationTrackingEnabled ?? this.locationTrackingEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isDarkMode,
        notificationsEnabled,
        locationTrackingEnabled,
        isLoading,
        error,
      ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final EncryptionService encryptionService;

  SettingsBloc({required this.encryptionService})
      : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<UpdateNotificationsEnabled>(_onUpdateNotificationsEnabled);
    on<UpdateLocationTracking>(_onUpdateLocationTracking);
  }

  Future<void> _onLoadSettings(
      LoadSettings event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // In a real app, we would load settings from secure storage
      // For now, we'll just use default values
      emit(state.copyWith(
        isDarkMode: false,
        notificationsEnabled: true,
        locationTrackingEnabled: true,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateThemeMode(
      UpdateThemeMode event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isDarkMode: event.isDarkMode));
    // In a real app, we would save this to persistent storage
  }

  Future<void> _onUpdateNotificationsEnabled(
      UpdateNotificationsEnabled event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(notificationsEnabled: event.enabled));
    // In a real app, we would save this to persistent storage
  }

  Future<void> _onUpdateLocationTracking(
      UpdateLocationTracking event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(locationTrackingEnabled: event.enabled));
    // In a real app, we would save this to persistent storage
  }
}
