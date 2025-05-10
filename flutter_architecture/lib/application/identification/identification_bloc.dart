import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:fungiscan/domain/repositories/mushroom_repository.dart';
import 'package:fungiscan/infrastructure/services/ml_service.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Events
abstract class IdentificationEvent extends Equatable {
  const IdentificationEvent();

  @override
  List<Object?> get props => [];
}

class IdentifyMushroomEvent extends IdentificationEvent {
  final dynamic imageData; // Can be File or Uint8List for web
  final LatLng? location;

  const IdentifyMushroomEvent({
    required this.imageData,
    this.location,
  });

  @override
  List<Object?> get props => [imageData, location];
}

class SearchMushroomsByTraitsEvent extends IdentificationEvent {
  final List<String> traits;

  const SearchMushroomsByTraitsEvent({required this.traits});

  @override
  List<Object> get props => [traits];
}

class SaveIdentificationEvent extends IdentificationEvent {
  final Mushroom mushroom;
  final String imageUrl;
  final LatLng? location;

  const SaveIdentificationEvent({
    required this.mushroom,
    required this.imageUrl,
    this.location,
  });

  @override
  List<Object?> get props => [mushroom, imageUrl, location];
}

class RequestExpertVerificationEvent extends IdentificationEvent {
  final String identificationId;
  final String userQuery;

  const RequestExpertVerificationEvent({
    required this.identificationId,
    required this.userQuery,
  });

  @override
  List<Object> get props => [identificationId, userQuery];
}

class ResetIdentificationStateEvent extends IdentificationEvent {}

class LoadRecentIdentificationsEvent extends IdentificationEvent {
  final int limit;

  const LoadRecentIdentificationsEvent({this.limit = 10});

  @override
  List<Object> get props => [limit];
}

class LoadIdentificationHistoryEvent extends IdentificationEvent {}

// States
abstract class IdentificationState extends Equatable {
  const IdentificationState();

  @override
  List<Object?> get props => [];
}

class IdentificationInitialState extends IdentificationState {}

class IdentificationLoadingState extends IdentificationState {}

class IdentificationSuccessState extends IdentificationState {
  final dynamic imageData; // Can be File or Uint8List
  final Mushroom identifiedMushroom;
  final List<Mushroom> alternatives;
  final String identificationId;

  const IdentificationSuccessState({
    required this.imageData,
    required this.identifiedMushroom,
    required this.alternatives,
    required this.identificationId,
  });

  @override
  List<Object?> get props => [imageData, identifiedMushroom, alternatives, identificationId];
}

class IdentificationFailureState extends IdentificationState {
  final String errorMessage;

  const IdentificationFailureState({required this.errorMessage});

  @override
  List<Object> get props => [errorMessage];
}

class IdentificationHistoryLoadedState extends IdentificationState {
  final List<IdentificationResult> identificationHistory;

  const IdentificationHistoryLoadedState({
    required this.identificationHistory,
  });

  @override
  List<Object> get props => [identificationHistory];
}

class RecentIdentificationsLoadedState extends IdentificationState {
  final List<IdentificationResult> recentIdentifications;

  const RecentIdentificationsLoadedState({
    required this.recentIdentifications,
  });

  @override
  List<Object> get props => [recentIdentifications];
}

class TraitSearchResultsState extends IdentificationState {
  final List<Mushroom> searchResults;

  const TraitSearchResultsState({required this.searchResults});

  @override
  List<Object> get props => [searchResults];
}

// Bloc
class IdentificationBloc extends Bloc<IdentificationEvent, IdentificationState> {
  final MushroomRepository mushroomRepository;
  final MLService mlService;
  final _uuid = const Uuid();

  IdentificationBloc({
    required this.mushroomRepository,
    required this.mlService,
  }) : super(IdentificationInitialState()) {
    on<IdentifyMushroomEvent>(_onIdentifyMushroom);
    on<SearchMushroomsByTraitsEvent>(_onSearchByTraits);
    on<SaveIdentificationEvent>(_onSaveIdentification);
    on<RequestExpertVerificationEvent>(_onRequestExpertVerification);
    on<ResetIdentificationStateEvent>(_onResetState);
    on<LoadRecentIdentificationsEvent>(_onLoadRecentIdentifications);
    on<LoadIdentificationHistoryEvent>(_onLoadIdentificationHistory);
  }

  Future<void> _onIdentifyMushroom(
    IdentifyMushroomEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    emit(IdentificationLoadingState());

    try {
      // 1. Run the image through ML model
      final result = await mlService.identifyMushroom(event.imageData);
      
      // 2. Get the top result and confidence score
      final topResultLabel = result['topResult']['label'] as String;
      final confidence = result['topResult']['confidence'] as double;
      
      // 3. Get the full mushroom data for the top result
      final mushrooms = await mushroomRepository.getAllMushrooms();
      final identifiedMushroom = mushrooms.firstWhere(
        (m) => m.commonName.toLowerCase() == topResultLabel.toLowerCase(),
        orElse: () => mushrooms.firstWhere(
          (m) => m.scientificName.toLowerCase() == topResultLabel.toLowerCase(),
          orElse: () => throw Exception('Could not find mushroom data for $topResultLabel'),
        ),
      );
      
      // 4. Create updated mushroom with confidence score
      final mushroomWithConfidence = identifiedMushroom.copyWith(
        confidence: confidence,
      );
      
      // 5. Get alternative identifications
      final List<Mushroom> alternatives = [];
      if (result['top3Results'] != null) {
        final top3 = result['top3Results'] as List;
        // Skip the first one as it's already our top result
        for (var i = 1; i < top3.length; i++) {
          final altLabel = top3[i]['label'] as String;
          final altConfidence = top3[i]['confidence'] as double;
          
          try {
            final altMushroom = mushrooms.firstWhere(
              (m) => m.commonName.toLowerCase() == altLabel.toLowerCase() || 
                   m.scientificName.toLowerCase() == altLabel.toLowerCase(),
            ).copyWith(confidence: altConfidence);
            
            alternatives.add(altMushroom);
          } catch (e) {
            print('Could not find mushroom data for alternative: $altLabel');
          }
        }
      }
      
      // 6. Generate a new identification ID
      final identificationId = _uuid.v4();
      
      // 7. Emit the success state
      emit(IdentificationSuccessState(
        imageData: event.imageData,
        identifiedMushroom: mushroomWithConfidence,
        alternatives: alternatives,
        identificationId: identificationId,
      ));
      
      // 8. Save the identification result in background
      String imageUrl;
      if (kIsWeb) {
        // For web, we can't use file paths
        imageUrl = 'https://placeholder.com/mushroom_image.jpg';
      } else {
        // For mobile, we can use the file path
        imageUrl = 'file://${(event.imageData as File).path}';
      }
      
      final identificationResult = IdentificationResult(
        id: identificationId,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        identifiedMushroom: mushroomWithConfidence,
        alternatives: alternatives,
        location: event.location,
        verifiedByExpert: false,
      );
      
      await mushroomRepository.saveIdentificationResult(identificationResult);
      
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Identification failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _onSearchByTraits(
    SearchMushroomsByTraitsEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    if (event.traits.isEmpty) {
      emit(const TraitSearchResultsState(searchResults: []));
      return;
    }

    emit(IdentificationLoadingState());

    try {
      final results = await mushroomRepository.searchMushroomsByTraits(event.traits);
      
      emit(TraitSearchResultsState(searchResults: results));
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Search failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _onSaveIdentification(
    SaveIdentificationEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    try {
      final identificationId = _uuid.v4();
      
      final identificationResult = IdentificationResult(
        id: identificationId,
        timestamp: DateTime.now(),
        imageUrl: event.imageUrl,
        identifiedMushroom: event.mushroom,
        alternatives: const [],
        location: event.location,
        verifiedByExpert: false,
      );
      
      await mushroomRepository.saveIdentificationResult(identificationResult);
      
      // Reload recent identifications
      add(const LoadRecentIdentificationsEvent());
      
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Failed to save identification: ${e.toString()}',
      ));
    }
  }

  Future<void> _onRequestExpertVerification(
    RequestExpertVerificationEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    try {
      await mushroomRepository.requestExpertVerification(
        event.identificationId,
        event.userQuery,
      );
      
      // No state update needed, could show a success message via another mechanism
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Failed to request verification: ${e.toString()}',
      ));
    }
  }

  void _onResetState(
    ResetIdentificationStateEvent event,
    Emitter<IdentificationState> emit,
  ) {
    emit(IdentificationInitialState());
  }

  Future<void> _onLoadRecentIdentifications(
    LoadRecentIdentificationsEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    try {
      final recentIdentifications = 
          await mushroomRepository.getRecentIdentifications(limit: event.limit);
      
      emit(RecentIdentificationsLoadedState(
        recentIdentifications: recentIdentifications,
      ));
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Failed to load recent identifications: ${e.toString()}',
      ));
    }
  }
  
  Future<void> _onLoadIdentificationHistory(
    LoadIdentificationHistoryEvent event,
    Emitter<IdentificationState> emit,
  ) async {
    emit(IdentificationLoadingState());
    
    try {
      final history = await mushroomRepository.getUserIdentificationHistory();
      
      emit(IdentificationHistoryLoadedState(
        identificationHistory: history,
      ));
    } catch (e) {
      emit(IdentificationFailureState(
        errorMessage: 'Failed to load identification history: ${e.toString()}',
      ));
    }
  }
}