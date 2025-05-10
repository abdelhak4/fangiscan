import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:fungiscan/domain/repositories/mushroom_repository.dart';
import 'package:fungiscan/infrastructure/services/location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Events
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class GetCurrentLocationEvent extends MapEvent {}

class StartPathRecordingEvent extends MapEvent {}

class StopPathRecordingEvent extends MapEvent {}

class SaveForagingLocationEvent extends MapEvent {
  final String name;
  final String notes;
  final List<String> species;
  final LatLng coordinates;
  final List<String>? photos;

  const SaveForagingLocationEvent({
    required this.name,
    required this.notes,
    required this.species,
    required this.coordinates,
    this.photos,
  });

  @override
  List<Object?> get props => [name, notes, species, coordinates, photos];
}

class UpdateForagingLocationEvent extends MapEvent {
  final String id;
  final String? name;
  final String? notes;
  final LatLng? coordinates;
  final List<String>? species;
  final List<String>? photos;

  const UpdateForagingLocationEvent({
    required this.id,
    this.name,
    this.notes,
    this.coordinates,
    this.species,
    this.photos,
  });

  @override
  List<Object?> get props => [id, name, notes, coordinates, species, photos];
}

class DeleteForagingLocationEvent extends MapEvent {
  final String id;

  const DeleteForagingLocationEvent({required this.id});

  @override
  List<Object> get props => [id];
}

class LoadSavedLocationsEvent extends MapEvent {}

class AddSpeciesToLocationEvent extends MapEvent {
  final String locationId;
  final String speciesName;
  final String? photoPath;

  const AddSpeciesToLocationEvent({
    required this.locationId,
    required this.speciesName,
    this.photoPath,
  });

  @override
  List<Object?> get props => [locationId, speciesName, photoPath];
}

class ChangeMapTypeEvent extends MapEvent {
  final MapType mapType;

  const ChangeMapTypeEvent({required this.mapType});

  @override
  List<Object> get props => [mapType];
}

class SyncDataEvent extends MapEvent {}

// States
enum MapStatus {
  initial,
  loading,
  locationUpdated,
  savedLocationsLoaded,
  locationSaved,
  pathUpdated,
  error,
}

class MapState extends Equatable {
  final MapStatus status;
  final LatLng? currentLocation;
  final List<SavedLocation> savedLocations;
  final List<LatLng> currentPath;
  final bool isRecordingPath;
  final MapType mapType;
  final bool isOnline;
  final String? errorMessage;

  const MapState({
    this.status = MapStatus.initial,
    this.currentLocation,
    this.savedLocations = const [],
    this.currentPath = const [],
    this.isRecordingPath = false,
    this.mapType = MapType.normal,
    this.isOnline = true,
    this.errorMessage,
  });

  MapState copyWith({
    MapStatus? status,
    LatLng? currentLocation,
    List<SavedLocation>? savedLocations,
    List<LatLng>? currentPath,
    bool? isRecordingPath,
    MapType? mapType,
    bool? isOnline,
    String? errorMessage,
  }) {
    return MapState(
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      savedLocations: savedLocations ?? this.savedLocations,
      currentPath: currentPath ?? this.currentPath,
      isRecordingPath: isRecordingPath ?? this.isRecordingPath,
      mapType: mapType ?? this.mapType,
      isOnline: isOnline ?? this.isOnline,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentLocation,
        savedLocations,
        currentPath,
        isRecordingPath,
        mapType,
        isOnline,
        errorMessage,
      ];
}

// Bloc
class MapBloc extends Bloc<MapEvent, MapState> {
  final MushroomRepository mushroomRepository;
  final LocationService locationService;
  // Removed unused _uuid field

  MapBloc({
    required this.mushroomRepository,
    required this.locationService,
  }) : super(const MapState()) {
    // Updated to match LocationService's actual stream name
    locationService.positionStream.listen((position) {
      if (state.isRecordingPath) {
        final latLng = LatLng(position.latitude, position.longitude);
        final updatedPath = List<LatLng>.from(state.currentPath)..add(latLng);

        add(_UpdatePathEvent(updatedPath));
      }
    });

    on<GetCurrentLocationEvent>(_onGetCurrentLocation);
    on<StartPathRecordingEvent>(_onStartPathRecording);
    on<StopPathRecordingEvent>(_onStopPathRecording);
    on<SaveForagingLocationEvent>(_onSaveForagingLocation);
    on<UpdateForagingLocationEvent>(_onUpdateForagingLocation);
    on<DeleteForagingLocationEvent>(_onDeleteForagingLocation);
    on<LoadSavedLocationsEvent>(_onLoadSavedLocations);
    on<AddSpeciesToLocationEvent>(_onAddSpeciesToLocation);
    on<ChangeMapTypeEvent>(_onChangeMapType);
    on<SyncDataEvent>(_onSyncData);
    on<_UpdatePathEvent>(_onUpdatePath);
    on<_CheckOnlineStatusEvent>(_onCheckOnlineStatus);
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocationEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      // Updated to match LocationService's method
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        emit(state.copyWith(
          status: MapStatus.locationUpdated,
          currentLocation: LatLng(position.latitude, position.longitude),
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to get current location: ${e.toString()}',
      ));
    }
  }

  void _onStartPathRecording(
    StartPathRecordingEvent event,
    Emitter<MapState> emit,
  ) {
    // Updated to match LocationService's method
    locationService.startTracking();
    emit(state.copyWith(
      isRecordingPath: true,
      currentPath: [],
    ));
  }

  Future<void> _onStopPathRecording(
    StopPathRecordingEvent event,
    Emitter<MapState> emit,
  ) async {
    // Updated to use correct LocationService methods
    locationService.stopTracking();
    final path = locationService.getCurrentTrack();
    emit(state.copyWith(
      isRecordingPath: false,
      currentPath: path,
      status: MapStatus.pathUpdated,
    ));
  }

  Future<void> _onSaveForagingLocation(
    SaveForagingLocationEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MapStatus.loading));

      final savedLocation = await mushroomRepository.saveForagingLocation(
        name: event.name,
        notes: event.notes,
        coordinates: event.coordinates,
        path: state.currentPath.isNotEmpty ? state.currentPath : null,
        species: event.species,
        photos: event.photos,
      );

      // Update saved locations list
      final updatedLocations = List<SavedLocation>.from(state.savedLocations)
        ..add(savedLocation);

      emit(state.copyWith(
        status: MapStatus.locationSaved,
        savedLocations: updatedLocations,
        currentPath: [], // Clear current path after saving
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to save location: ${e.toString()}',
      ));
    }
  }

  Future<void> _onUpdateForagingLocation(
    UpdateForagingLocationEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MapStatus.loading));

      final updatedLocation = await mushroomRepository.updateForagingLocation(
        id: event.id,
        name: event.name,
        notes: event.notes,
        coordinates: event.coordinates,
        species: event.species,
        photos: event.photos,
      );

      // Update the location in the list
      final updatedLocations = state.savedLocations.map((location) {
        return location.id == event.id ? updatedLocation : location;
      }).toList();

      emit(state.copyWith(
        status: MapStatus.locationSaved,
        savedLocations: updatedLocations,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to update location: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteForagingLocation(
    DeleteForagingLocationEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MapStatus.loading));

      await mushroomRepository.deleteForagingLocation(event.id);

      // Remove the location from the list
      final updatedLocations = state.savedLocations
          .where((location) => location.id != event.id)
          .toList();

      emit(state.copyWith(
        status: MapStatus.savedLocationsLoaded,
        savedLocations: updatedLocations,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to delete location: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadSavedLocations(
    LoadSavedLocationsEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MapStatus.loading));

      final locations = await mushroomRepository.getAllSavedLocations();

      emit(state.copyWith(
        status: MapStatus.savedLocationsLoaded,
        savedLocations: locations,
      ));

      // Check online status
      add(_CheckOnlineStatusEvent());
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to load locations: ${e.toString()}',
      ));
    }
  }

  Future<void> _onAddSpeciesToLocation(
    AddSpeciesToLocationEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(status: MapStatus.loading));

      await mushroomRepository.addSpeciesToLocation(
        locationId: event.locationId,
        speciesName: event.speciesName,
        photoPath: event.photoPath,
      );

      // Reload the updated location
      final updatedLocation =
          await mushroomRepository.getSavedLocationById(event.locationId);

      if (updatedLocation != null) {
        // Update the location in the list
        final updatedLocations = state.savedLocations.map((location) {
          return location.id == event.locationId ? updatedLocation : location;
        }).toList();

        emit(state.copyWith(
          status: MapStatus.locationSaved,
          savedLocations: updatedLocations,
        ));
      } else {
        // Reload all locations if we couldn't get the specific updated one
        add(LoadSavedLocationsEvent());
      }
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Failed to add species to location: ${e.toString()}',
      ));
    }
  }

  void _onChangeMapType(
    ChangeMapTypeEvent event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(mapType: event.mapType));
  }

  Future<void> _onSyncData(
    SyncDataEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final success = await mushroomRepository.syncOfflineData();

      if (success) {
        // Reload data after successful sync
        add(LoadSavedLocationsEvent());
      } else {
        emit(state.copyWith(
          status: MapStatus.error,
          errorMessage: 'Sync failed. Please try again later.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'Sync error: ${e.toString()}',
      ));
    }
  }

  void _onUpdatePath(
    _UpdatePathEvent event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(
      status: MapStatus.pathUpdated,
      currentPath: event.path,
    ));
  }

  Future<void> _onCheckOnlineStatus(
    _CheckOnlineStatusEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final isOnline = await mushroomRepository.isOnline();

      if (isOnline != state.isOnline) {
        emit(state.copyWith(isOnline: isOnline));

        // If we just came back online, try to sync data
        if (isOnline && !state.isOnline) {
          add(SyncDataEvent());
        }
      }
    } catch (e) {
      // Silently ignore errors checking online status
      print('Error checking online status: $e');
    }
  }

  @override
  Future<void> close() {
    locationService.dispose();
    return super.close();
  }
}

// Private events
class _UpdatePathEvent extends MapEvent {
  final List<LatLng> path;

  const _UpdatePathEvent(this.path);

  @override
  List<Object> get props => [path];
}

class _CheckOnlineStatusEvent extends MapEvent {}
