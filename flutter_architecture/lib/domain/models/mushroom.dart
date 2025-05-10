import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Edibility classification for mushrooms
enum Edibility {
  edible,     // Safe to eat
  inedible,   // Not poisonous but not pleasant to eat
  poisonous,  // Toxic, should not be consumed
  psychoactive, // Has mind-altering effects
  unknown,    // Edibility not confirmed
}

/// Primary model class for mushroom data
class Mushroom {
  final String id;
  final String commonName;
  final String scientificName;
  final String description;
  final Edibility edibility;
  final String habitat;
  final List<String> traits;
  final List<String> seasons;
  final List<LookalikeSpecies> lookalikes;
  final double confidence; // Confidence score from AI identification

  Mushroom({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.description,
    required this.edibility,
    required this.habitat,
    required this.traits,
    required this.seasons,
    required this.lookalikes,
    this.confidence = 1.0,
  });

  /// Create a Mushroom from JSON data
  factory Mushroom.fromJson(Map<String, dynamic> json) {
    return Mushroom(
      id: json['id'],
      commonName: json['commonName'],
      scientificName: json['scientificName'],
      description: json['description'],
      edibility: _parseEdibility(json['edibility']),
      habitat: json['habitat'],
      traits: List<String>.from(json['traits']),
      seasons: List<String>.from(json['seasons']),
      lookalikes: (json['lookalikes'] as List)
          .map((l) => LookalikeSpecies.fromJson(l))
          .toList(),
      confidence: json['confidence'] ?? 1.0,
    );
  }

  /// Convert Mushroom to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'description': description,
      'edibility': edibility.toString().split('.').last,
      'habitat': habitat,
      'traits': traits,
      'seasons': seasons,
      'lookalikes': lookalikes.map((l) => l.toJson()).toList(),
      'confidence': confidence,
    };
  }

  /// Helper method to parse edibility from string
  static Edibility _parseEdibility(String value) {
    switch (value.toLowerCase()) {
      case 'edible':
        return Edibility.edible;
      case 'inedible':
        return Edibility.inedible;
      case 'poisonous':
        return Edibility.poisonous;
      case 'psychoactive':
        return Edibility.psychoactive;
      default:
        return Edibility.unknown;
    }
  }
  
  /// Create a copy of this Mushroom with modified fields
  Mushroom copyWith({
    String? id,
    String? commonName,
    String? scientificName,
    String? description,
    Edibility? edibility,
    String? habitat,
    List<String>? traits,
    List<String>? seasons,
    List<LookalikeSpecies>? lookalikes,
    double? confidence,
  }) {
    return Mushroom(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      description: description ?? this.description,
      edibility: edibility ?? this.edibility,
      habitat: habitat ?? this.habitat,
      traits: traits ?? this.traits,
      seasons: seasons ?? this.seasons,
      lookalikes: lookalikes ?? this.lookalikes,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Model class for lookalike species that might be confused with the main mushroom
class LookalikeSpecies {
  final String id;
  final String commonName;
  final String scientificName;
  final Edibility edibility;
  final String differentiationNotes;

  LookalikeSpecies({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.edibility,
    required this.differentiationNotes,
  });

  /// Create a LookalikeSpecies from JSON data
  factory LookalikeSpecies.fromJson(Map<String, dynamic> json) {
    return LookalikeSpecies(
      id: json['id'],
      commonName: json['commonName'],
      scientificName: json['scientificName'],
      edibility: Mushroom._parseEdibility(json['edibility']),
      differentiationNotes: json['differentiationNotes'],
    );
  }

  /// Convert LookalikeSpecies to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'edibility': edibility.toString().split('.').last,
      'differentiationNotes': differentiationNotes,
    };
  }
}

/// Model class for saved foraging locations
class SavedLocation {
  final String id;
  final String name;
  final String notes;
  final DateTime timestamp;
  final LatLng coordinates;
  final List<LatLng>? path;
  final List<String> species;
  final List<String>? photos;

  SavedLocation({
    required this.id,
    required this.name,
    required this.notes,
    required this.timestamp,
    required this.coordinates,
    this.path,
    required this.species,
    this.photos,
  });

  /// Create a SavedLocation from JSON data
  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'],
      name: json['name'],
      notes: json['notes'],
      timestamp: DateTime.parse(json['timestamp']),
      coordinates: LatLng(
        json['coordinates']['latitude'],
        json['coordinates']['longitude'],
      ),
      path: json['path'] != null
          ? (json['path'] as List)
              .map((p) => LatLng(p['latitude'], p['longitude']))
              .toList()
          : null,
      species: List<String>.from(json['species']),
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
    );
  }

  /// Convert SavedLocation to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'coordinates': {
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
      },
      'path': path?.map((p) => {
            'latitude': p.latitude,
            'longitude': p.longitude,
          }).toList(),
      'species': species,
      'photos': photos,
    };
  }
  
  /// Create a copy of this SavedLocation with modified fields
  SavedLocation copyWith({
    String? id,
    String? name,
    String? notes,
    DateTime? timestamp,
    LatLng? coordinates,
    List<LatLng>? path,
    List<String>? species,
    List<String>? photos,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      coordinates: coordinates ?? this.coordinates,
      path: path ?? this.path,
      species: species ?? this.species,
      photos: photos ?? this.photos,
    );
  }
}

/// Model class for identification history
class IdentificationResult {
  final String id;
  final DateTime timestamp;
  final String imageUrl;
  final Mushroom identifiedMushroom;
  final List<Mushroom> alternatives;
  final LatLng? location;
  final bool verifiedByExpert;
  final String? expertComment;

  IdentificationResult({
    required this.id,
    required this.timestamp,
    required this.imageUrl,
    required this.identifiedMushroom,
    required this.alternatives,
    this.location,
    this.verifiedByExpert = false,
    this.expertComment,
  });

  /// Create an IdentificationResult from JSON data
  factory IdentificationResult.fromJson(Map<String, dynamic> json) {
    return IdentificationResult(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      imageUrl: json['imageUrl'],
      identifiedMushroom: Mushroom.fromJson(json['identifiedMushroom']),
      alternatives: (json['alternatives'] as List)
          .map((a) => Mushroom.fromJson(a))
          .toList(),
      location: json['location'] != null
          ? LatLng(
              json['location']['latitude'],
              json['location']['longitude'],
            )
          : null,
      verifiedByExpert: json['verifiedByExpert'] ?? false,
      expertComment: json['expertComment'],
    );
  }

  /// Convert IdentificationResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'identifiedMushroom': identifiedMushroom.toJson(),
      'alternatives': alternatives.map((a) => a.toJson()).toList(),
      'location': location != null
          ? {
              'latitude': location!.latitude,
              'longitude': location!.longitude,
            }
          : null,
      'verifiedByExpert': verifiedByExpert,
      'expertComment': expertComment,
    };
  }
}

/// Model class for user settings/preferences
class UserPreferences {
  final bool privacyModeEnabled;
  final bool darkModeEnabled;
  final String measurementUnit; // 'metric' or 'imperial'
  final bool offlineMapsCached;
  final int cacheExpiryDays;
  final List<String> favoriteSpecies;
  final List<String> favoriteLocations;

  UserPreferences({
    this.privacyModeEnabled = false,
    this.darkModeEnabled = false,
    this.measurementUnit = 'metric',
    this.offlineMapsCached = true,
    this.cacheExpiryDays = 30,
    this.favoriteSpecies = const [],
    this.favoriteLocations = const [],
  });

  /// Create UserPreferences from JSON data
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      privacyModeEnabled: json['privacyModeEnabled'] ?? false,
      darkModeEnabled: json['darkModeEnabled'] ?? false,
      measurementUnit: json['measurementUnit'] ?? 'metric',
      offlineMapsCached: json['offlineMapsCached'] ?? true,
      cacheExpiryDays: json['cacheExpiryDays'] ?? 30,
      favoriteSpecies: json['favoriteSpecies'] != null
          ? List<String>.from(json['favoriteSpecies'])
          : [],
      favoriteLocations: json['favoriteLocations'] != null
          ? List<String>.from(json['favoriteLocations'])
          : [],
    );
  }

  /// Convert UserPreferences to JSON
  Map<String, dynamic> toJson() {
    return {
      'privacyModeEnabled': privacyModeEnabled,
      'darkModeEnabled': darkModeEnabled,
      'measurementUnit': measurementUnit,
      'offlineMapsCached': offlineMapsCached,
      'cacheExpiryDays': cacheExpiryDays,
      'favoriteSpecies': favoriteSpecies,
      'favoriteLocations': favoriteLocations,
    };
  }
  
  /// Create a copy of this UserPreferences with modified fields
  UserPreferences copyWith({
    bool? privacyModeEnabled,
    bool? darkModeEnabled,
    String? measurementUnit,
    bool? offlineMapsCached,
    int? cacheExpiryDays,
    List<String>? favoriteSpecies,
    List<String>? favoriteLocations,
  }) {
    return UserPreferences(
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      offlineMapsCached: offlineMapsCached ?? this.offlineMapsCached,
      cacheExpiryDays: cacheExpiryDays ?? this.cacheExpiryDays,
      favoriteSpecies: favoriteSpecies ?? this.favoriteSpecies,
      favoriteLocations: favoriteLocations ?? this.favoriteLocations,
    );
  }
}
