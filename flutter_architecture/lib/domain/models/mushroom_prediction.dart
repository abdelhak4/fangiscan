import 'package:fungiscan/domain/models/mushroom_trait.dart';

/// Represents a mushroom identification prediction result from the ML model
class MushroomPrediction {
  /// Common/display name of the mushroom
  final String name;

  /// Scientific name of the mushroom (typically Latin name)
  final String scientificName;

  /// Confidence score from the ML model (0.0 to 1.0)
  final double confidence;

  /// Whether this mushroom is considered toxic/poisonous
  final bool isToxic;

  /// List of mushroom traits (cap, gills, stem, etc.)
  final List<MushroomTrait> traits;

  /// Similar edible species for comparison (important for safety)
  final String similarEdibleSpecies;

  /// Similar toxic species that could be confused (important for safety warnings)
  final String similarToxicSpecies;

  /// Optional notes or additional information
  final String? notes;

  /// URL for more detailed information (could be internal or external)
  final String? detailsUrl;

  /// Creates a new mushroom prediction instance
  MushroomPrediction({
    required this.name,
    required this.scientificName,
    required this.confidence,
    required this.isToxic,
    required this.traits,
    required this.similarEdibleSpecies,
    required this.similarToxicSpecies,
    this.notes,
    this.detailsUrl,
  });

  /// Creates a copy of this prediction with modified fields
  MushroomPrediction copyWith({
    String? name,
    String? scientificName,
    double? confidence,
    bool? isToxic,
    List<MushroomTrait>? traits,
    String? similarEdibleSpecies,
    String? similarToxicSpecies,
    String? notes,
    String? detailsUrl,
  }) {
    return MushroomPrediction(
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      confidence: confidence ?? this.confidence,
      isToxic: isToxic ?? this.isToxic,
      traits: traits ?? this.traits,
      similarEdibleSpecies: similarEdibleSpecies ?? this.similarEdibleSpecies,
      similarToxicSpecies: similarToxicSpecies ?? this.similarToxicSpecies,
      notes: notes ?? this.notes,
      detailsUrl: detailsUrl ?? this.detailsUrl,
    );
  }

  /// Converts mushroom prediction to JSON representation for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientificName': scientificName,
      'confidence': confidence,
      'isToxic': isToxic,
      'traits': traits.map((trait) => trait.toJson()).toList(),
      'similarEdibleSpecies': similarEdibleSpecies,
      'similarToxicSpecies': similarToxicSpecies,
      'notes': notes,
      'detailsUrl': detailsUrl,
    };
  }

  /// Creates a mushroom prediction from JSON data
  factory MushroomPrediction.fromJson(Map<String, dynamic> json) {
    return MushroomPrediction(
      name: json['name'] as String,
      scientificName: json['scientificName'] as String,
      confidence: json['confidence'] as double,
      isToxic: json['isToxic'] as bool,
      traits: (json['traits'] as List)
          .map((traitJson) => MushroomTrait.fromJson(traitJson))
          .toList(),
      similarEdibleSpecies: json['similarEdibleSpecies'] as String,
      similarToxicSpecies: json['similarToxicSpecies'] as String,
      notes: json['notes'] as String?,
      detailsUrl: json['detailsUrl'] as String?,
    );
  }

  /// Get formatted confidence percentage
  String get confidencePercentage {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  /// Get safety status for display
  String get safetyStatus {
    if (isToxic) {
      return 'WARNING: POTENTIALLY TOXIC';
    } else if (confidence > 0.90) {
      return 'Likely Edible (Always verify)';
    } else {
      return 'Consult Expert Before Consuming';
    }
  }
}
