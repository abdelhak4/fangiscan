/// Represents a trait or characteristic of a mushroom species
/// Examples include cap color, gill type, stem shape, habitat, etc.
class MushroomTrait {
  /// Name of the trait (e.g., "Cap", "Gills", "Stem")
  final String name;

  /// Value or description of the trait (e.g., "Red with white spots")
  final String value;

  /// Optional image URL related to this trait, if available
  final String? imageUrl;

  /// Creates a mushroom trait
  MushroomTrait({
    required this.name,
    required this.value,
    this.imageUrl,
  });

  /// Creates a copy of this trait with modified fields
  MushroomTrait copyWith({
    String? name,
    String? value,
    String? imageUrl,
  }) {
    return MushroomTrait(
      name: name ?? this.name,
      value: value ?? this.value,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Converts trait to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'imageUrl': imageUrl,
    };
  }

  /// Creates a trait from JSON data
  factory MushroomTrait.fromJson(Map<String, dynamic> json) {
    return MushroomTrait(
      name: json['name'] as String,
      value: json['value'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  @override
  String toString() {
    return '$name: $value';
  }
}
