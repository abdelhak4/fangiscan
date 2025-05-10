import 'dart:io';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Repository interface for mushroom-related data operations.
/// This follows the Repository pattern to abstract the data sources from the business logic.
abstract class MushroomRepository {
  /// Get a mushroom by its ID
  Future<Mushroom?> getMushroomById(String id);
  
  /// Get all mushrooms in the database
  Future<List<Mushroom>> getAllMushrooms();
  
  /// Search for mushrooms using a set of traits/characteristics
  Future<List<Mushroom>> searchMushroomsByTraits(List<String> traits);
  
  /// Save a mushroom identification result
  Future<void> saveIdentificationResult(IdentificationResult result);
  
  /// Get all identification results for the current user
  Future<List<IdentificationResult>> getUserIdentificationHistory();
  
  /// Get recent identification results for the current user (limit by count)
  Future<List<IdentificationResult>> getRecentIdentifications({int limit = 10});
  
  /// Request expert verification for an identification result
  Future<void> requestExpertVerification(String identificationId, String userQuery);
  
  /// Save a foraging location
  Future<SavedLocation> saveForagingLocation({
    required String name,
    required String notes,
    required LatLng coordinates,
    List<LatLng>? path,
    List<String>? species,
    List<String>? photos,
  });
  
  /// Update an existing foraging location
  Future<SavedLocation> updateForagingLocation({
    required String id,
    String? name,
    String? notes,
    LatLng? coordinates,
    List<LatLng>? path,
    List<String>? species,
    List<String>? photos,
  });
  
  /// Delete a foraging location
  Future<void> deleteForagingLocation(String id);
  
  /// Add a species to a saved location
  Future<void> addSpeciesToLocation({
    required String locationId,
    required String speciesName,
    String? photoPath,
  });
  
  /// Get all saved foraging locations
  Future<List<SavedLocation>> getAllSavedLocations();
  
  /// Get a saved location by ID
  Future<SavedLocation?> getSavedLocationById(String id);
  
  /// Get user preferences
  Future<UserPreferences> getUserPreferences();
  
  /// Update user preferences
  Future<void> updateUserPreferences(UserPreferences preferences);
  
  /// Get dangerous lookalikes for a given mushroom
  Future<List<LookalikeSpecies>> getDangerousLookalikes(String mushroomId);
  
  /// Sync offline data with the server
  /// Returns true if sync was successful
  Future<bool> syncOfflineData();
  
  /// Check if the repository is online
  Future<bool> isOnline();
  
  /// Clear cached data
  Future<void> clearCache();
  
  /// Get total storage usage (for offline data)
  Future<int> getStorageUsage();
  
  /// Export user data to a file
  Future<File> exportUserData();
  
  /// Delete all user data
  Future<void> deleteAllUserData();
}
