import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

/// Represents a mushroom find at a specific location
class MushroomFind {
  /// Unique identifier
  final String id;

  /// Name of the mushroom found
  final String name;

  /// Latitude of the find location
  final double latitude;

  /// Longitude of the find location
  final double longitude;

  /// When the mushroom was found
  final DateTime timestamp;

  /// Notes about the find
  final String notes;

  /// Path to saved image of the mushroom
  final String? imagePath;

  MushroomFind({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.notes,
    this.imagePath,
  });

  /// Convert to LatLng for map display
  LatLng get position => LatLng(latitude, longitude);

  /// Create a copy with modified fields
  MushroomFind copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? notes,
    String? imagePath,
  }) {
    return MushroomFind(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'imagePath': imagePath,
    };
  }

  /// Create from JSON data
  factory MushroomFind.fromJson(Map<String, dynamic> json) {
    return MushroomFind(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}

/// Represents a foraging site with tracks and mushroom finds
class ForagingSite {
  /// Unique identifier
  final String id;

  /// Name of the foraging site (e.g., "North Woods")
  final String name;

  /// Latitude of the site's starting point
  final double latitude;

  /// Longitude of the site's starting point
  final double longitude;

  /// When the site was first recorded
  final DateTime createdAt;

  /// When the site was last updated
  final DateTime updatedAt;

  /// User notes about the site
  final String notes;

  /// GPS track points showing the path taken
  final List<LatLng> trackPoints;

  /// Mushrooms found at this site
  final List<MushroomFind> mushroomFinds;

  /// Weather conditions (could be expanded)
  final String? weatherConditions;

  /// Site accessibility rating (e.g. easy, moderate, difficult)
  final String? accessibility;

  ForagingSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    required this.notes,
    required this.trackPoints,
    required this.mushroomFinds,
    this.weatherConditions,
    this.accessibility,
  });

  /// Convert center point to LatLng for map display
  LatLng get position => LatLng(latitude, longitude);

  /// Create a copy with modified fields
  ForagingSite copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    List<LatLng>? trackPoints,
    List<MushroomFind>? mushroomFinds,
    String? weatherConditions,
    String? accessibility,
  }) {
    return ForagingSite(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      trackPoints: trackPoints ?? this.trackPoints,
      mushroomFinds: mushroomFinds ?? this.mushroomFinds,
      weatherConditions: weatherConditions ?? this.weatherConditions,
      accessibility: accessibility ?? this.accessibility,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
      'trackPoints': trackPoints
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(),
      'mushroomFinds': mushroomFinds.map((find) => find.toJson()).toList(),
      'weatherConditions': weatherConditions,
      'accessibility': accessibility,
    };
  }

  /// Create from JSON data
  factory ForagingSite.fromJson(Map<String, dynamic> json) {
    return ForagingSite(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      notes: json['notes'] as String,
      trackPoints: (json['trackPoints'] as List)
          .map((point) => LatLng(
                point['latitude'] as double,
                point['longitude'] as double,
              ))
          .toList(),
      mushroomFinds: (json['mushroomFinds'] as List)
          .map((find) => MushroomFind.fromJson(find as Map<String, dynamic>))
          .toList(),
      weatherConditions: json['weatherConditions'] as String?,
      accessibility: json['accessibility'] as String?,
    );
  }

  /// Create a new empty foraging site
  static ForagingSite createNew({
    required String name,
    required double latitude,
    required double longitude,
    required String notes,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();

    return ForagingSite(
      id: uuid.v4(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
      updatedAt: now,
      notes: notes,
      trackPoints: [],
      mushroomFinds: [],
    );
  }
}
