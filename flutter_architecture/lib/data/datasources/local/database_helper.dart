import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fungiscan/domain/models/mushroom.dart';

// Class to represent an item that needs to be synced
class SyncItem {
  final String type; // 'identification', 'location', 'preferences', etc.
  final String id;
  final DateTime timestamp;

  SyncItem({
    required this.type,
    required this.id,
    required this.timestamp,
  });
}

/// Helper class for working with the local Hive database
class DatabaseHelper {
  // Box names
  static const String mushroomsBoxName = 'mushrooms';
  static const String identificationResultsBoxName = 'identification_results';
  static const String savedLocationsBoxName = 'saved_locations';
  static const String userPreferencesBoxName = 'user_preferences';
  static const String syncQueueBoxName = 'sync_queue';
  static const String syncDeleteQueueBoxName = 'sync_delete_queue';
  static const String expertVerificationBoxName = 'expert_verification';
  static const String cacheMetadataBoxName = 'cache_metadata';

  /// Initialize the database
  static Future<void> initialize() async {
    // Initialize Hive
    if (kIsWeb) {
      // For web, initialize without a specific path
      await Hive.initFlutter();
    } else {
      // For mobile platforms, use the application documents directory
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);
    }
    
    // Register adapters (would be implemented here)
    // Hive.registerAdapter(MushroomAdapter());
    // Hive.registerAdapter(EdibilityAdapter());
    // Hive.registerAdapter(LookalikeSpeciesAdapter());
    // Hive.registerAdapter(SavedLocationAdapter());
    // Hive.registerAdapter(LatLngAdapter());
    // etc.
    
    try {
      // Open boxes
      await Hive.openBox<Map>(mushroomsBoxName);
      await Hive.openBox<Map>(identificationResultsBoxName);
      await Hive.openBox<Map>(savedLocationsBoxName);
      await Hive.openBox<Map>(userPreferencesBoxName);
      await Hive.openBox<Map>(syncQueueBoxName);
      await Hive.openBox<Map>(syncDeleteQueueBoxName);
      await Hive.openBox<Map>(expertVerificationBoxName);
      await Hive.openBox<Map>(cacheMetadataBoxName);
      
      print('Database initialized successfully');
    } catch (e) {
      print('Error opening Hive boxes: $e');
      // Continue without fully initialized database for web development
    }
  }
  
  // Mushroom operations
  static Future<List<Mushroom>> getAllMushrooms() async {
    final box = Hive.box<Map>(mushroomsBoxName);
    return box.values.map((json) => Mushroom.fromJson(Map<String, dynamic>.from(json))).toList();
  }
  
  static Future<Mushroom?> getMushroomById(String id) async {
    final box = Hive.box<Map>(mushroomsBoxName);
    final json = box.get(id);
    if (json == null) return null;
    return Mushroom.fromJson(Map<String, dynamic>.from(json));
  }
  
  static Future<void> saveMushroom(Mushroom mushroom) async {
    final box = Hive.box<Map>(mushroomsBoxName);
    await box.put(mushroom.id, mushroom.toJson());
    
    // Update cache metadata
    _updateCacheMetadata(mushroomsBoxName, mushroom.id);
  }
  
  static Future<List<Mushroom>> searchMushroomsByTraits(List<String> traits) async {
    final box = Hive.box<Map>(mushroomsBoxName);
    
    // Convert search traits to lowercase for case-insensitive matching
    final searchTraits = traits.map((t) => t.toLowerCase()).toList();
    
    return box.values
        .map((json) => Mushroom.fromJson(Map<String, dynamic>.from(json)))
        .where((mushroom) {
          // Convert mushroom traits to lowercase for comparison
          final mushroomTraits = mushroom.traits.map((t) => t.toLowerCase()).toList();
          
          // Check if any of the search traits are in the mushroom traits
          return searchTraits.any((trait) => mushroomTraits.contains(trait));
        })
        .toList();
  }
  
  // Identification results operations
  static Future<void> saveIdentificationResult(IdentificationResult result) async {
    final box = Hive.box<Map>(identificationResultsBoxName);
    await box.put(result.id, result.toJson());
    
    // Update cache metadata
    _updateCacheMetadata(identificationResultsBoxName, result.id);
  }
  
  static Future<List<IdentificationResult>> getUserIdentificationHistory() async {
    final box = Hive.box<Map>(identificationResultsBoxName);
    final results = box.values
        .map((json) => IdentificationResult.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    // Sort by timestamp descending (most recent first)
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }
  
  static Future<List<IdentificationResult>> getRecentIdentifications({int limit = 10}) async {
    final box = Hive.box<Map>(identificationResultsBoxName);
    
    final results = box.values
        .map((json) => IdentificationResult.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    // Sort by timestamp descending (most recent first)
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Return only the requested number of results
    return results.take(limit).toList();
  }
  
  static Future<IdentificationResult?> getIdentificationResultById(String id) async {
    final box = Hive.box<Map>(identificationResultsBoxName);
    final json = box.get(id);
    if (json == null) return null;
    return IdentificationResult.fromJson(Map<String, dynamic>.from(json));
  }
  
  // Expert verification operations
  static Future<void> saveExpertVerificationRequest(
    String identificationId,
    String userQuery,
  ) async {
    final box = Hive.box<Map>(expertVerificationBoxName);
    final requestId = '$identificationId-${DateTime.now().millisecondsSinceEpoch}';
    
    await box.put(requestId, {
      'id': requestId,
      'identificationId': identificationId,
      'userQuery': userQuery,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    
    // Mark for sync
    await markForSync('expert_verification', requestId);
  }
  
  // Location operations
  static Future<List<SavedLocation>> getAllSavedLocations() async {
    final box = Hive.box<Map>(savedLocationsBoxName);
    final locations = box.values
        .map((json) => SavedLocation.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    // Sort by timestamp descending (most recent first)
    locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return locations;
  }
  
  static Future<SavedLocation?> getSavedLocationById(String id) async {
    final box = Hive.box<Map>(savedLocationsBoxName);
    final json = box.get(id);
    if (json == null) return null;
    return SavedLocation.fromJson(Map<String, dynamic>.from(json));
  }
  
  static Future<void> saveLocation(SavedLocation location) async {
    final box = Hive.box<Map>(savedLocationsBoxName);
    await box.put(location.id, location.toJson());
    
    // Update cache metadata
    _updateCacheMetadata(savedLocationsBoxName, location.id);
  }
  
  static Future<void> deleteLocation(String id) async {
    final box = Hive.box<Map>(savedLocationsBoxName);
    await box.delete(id);
    
    // Remove from cache metadata
    _removeCacheMetadata(savedLocationsBoxName, id);
  }
  
  // User preferences operations
  static Future<UserPreferences> getUserPreferences() async {
    final box = Hive.box<Map>(userPreferencesBoxName);
    final json = box.get('user_preferences');
    if (json == null) return UserPreferences(); // Return default if not found
    return UserPreferences.fromJson(Map<String, dynamic>.from(json));
  }
  
  static Future<void> saveUserPreferences(UserPreferences preferences) async {
    final box = Hive.box<Map>(userPreferencesBoxName);
    await box.put('user_preferences', preferences.toJson());
    
    // Update cache metadata
    _updateCacheMetadata(userPreferencesBoxName, 'user_preferences');
  }
  
  // Convenience method for saving individual preferences
  static Future<void> saveUserPreference(String key, dynamic value) async {
    final preferences = await getUserPreferences();
    
    // This would be a dynamic way to update a specific preference
    // In a real implementation, you'd need to handle different types correctly
    final updatedPreferences = UserPreferences(
      privacyModeEnabled: key == 'privacy_mode' ? value as bool : preferences.privacyModeEnabled,
      darkModeEnabled: key == 'dark_mode' ? value as bool : preferences.darkModeEnabled,
      measurementUnit: key == 'measurement_unit' ? value as String : preferences.measurementUnit,
      offlineMapsCached: key == 'offline_maps_cached' ? value as bool : preferences.offlineMapsCached,
      cacheExpiryDays: key == 'cache_expiry_days' ? value as int : preferences.cacheExpiryDays,
      favoriteSpecies: key == 'favorite_species' ? value as List<String> : preferences.favoriteSpecies,
      favoriteLocations: key == 'favorite_locations' ? value as List<String> : preferences.favoriteLocations,
    );
    
    await saveUserPreferences(updatedPreferences);
  }
  
  // Sync queue operations
  static Future<void> markForSync(String type, String id) async {
    final box = Hive.box<Map>(syncQueueBoxName);
    final syncId = '$type-$id';
    
    await box.put(syncId, {
      'type': type,
      'id': id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<void> markAsSynced(String type, String id) async {
    final box = Hive.box<Map>(syncQueueBoxName);
    final syncId = '$type-$id';
    await box.delete(syncId);
  }
  
  static Future<List<SyncItem>> getItemsToSync() async {
    final box = Hive.box<Map>(syncQueueBoxName);
    
    return box.values.map((json) {
      return SyncItem(
        type: json['type'] as String,
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
    }).toList();
  }
  
  // Delete sync queue operations
  static Future<void> markForDeleteSync(String type, String id) async {
    final box = Hive.box<Map>(syncDeleteQueueBoxName);
    final syncId = '$type-$id';
    
    await box.put(syncId, {
      'type': type,
      'id': id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<void> markDeleteAsSynced(String type, String id) async {
    final box = Hive.box<Map>(syncDeleteQueueBoxName);
    final syncId = '$type-$id';
    await box.delete(syncId);
  }
  
  static Future<List<SyncItem>> getItemsToDeleteSync() async {
    final box = Hive.box<Map>(syncDeleteQueueBoxName);
    
    return box.values.map((json) {
      return SyncItem(
        type: json['type'] as String,
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
    }).toList();
  }
  
  // Cache metadata operations
  static Future<void> _updateCacheMetadata(String boxName, String id) async {
    final box = Hive.box<Map>(cacheMetadataBoxName);
    final metadataKey = '$boxName-$id';
    
    await box.put(metadataKey, {
      'boxName': boxName,
      'id': id,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<void> _removeCacheMetadata(String boxName, String id) async {
    final box = Hive.box<Map>(cacheMetadataBoxName);
    final metadataKey = '$boxName-$id';
    await box.delete(metadataKey);
  }
  
  // Clear expired cache
  static Future<void> clearExpiredCache() async {
    final box = Hive.box<Map>(cacheMetadataBoxName);
    final preferences = await getUserPreferences();
    final expiryDays = preferences.cacheExpiryDays;
    final now = DateTime.now();
    
    // Get all cache metadata entries
    final entriesToDelete = <Map<String, dynamic>>[];
    
    for (final entry in box.values) {
      final lastUpdated = DateTime.parse(entry['lastUpdated'] as String);
      final age = now.difference(lastUpdated).inDays;
      
      // If older than expiry threshold, add to deletion list
      if (age > expiryDays) {
        entriesToDelete.add(Map<String, dynamic>.from(entry));
      }
    }
    
    // Delete expired entries
    for (final entry in entriesToDelete) {
      final boxName = entry['boxName'] as String;
      final id = entry['id'] as String;
      
      // Delete from the original box
      final targetBox = Hive.box<Map>(boxName);
      await targetBox.delete(id);
      
      // Delete the metadata
      final metadataKey = '$boxName-$id';
      await box.delete(metadataKey);
    }
  }
  
  // Clear all cache
  static Future<void> clearCache() async {
    // Clear each box (except sync queues and user preferences)
    await Hive.box<Map>(mushroomsBoxName).clear();
    await Hive.box<Map>(identificationResultsBoxName).clear();
    await Hive.box<Map>(cacheMetadataBoxName).clear();
    
    // For saved locations, we don't want to lose user data, 
    // so we would need to save keys of user-created locations and restore them
    
    print('Cache cleared successfully');
  }
  
  // Get storage usage in bytes
  static Future<int> getStorageUsage() async {
    int totalSize = 0;
    
    if (kIsWeb) {
      // For web, we can't directly access the storage size
      // Return an estimate or a placeholder value
      return 0;
    }
    
    // For mobile platforms, calculate actual storage usage
    try {
      // Get app directory
      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory('${appDir.path}/hive');
      
      if (await dbDir.exists()) {
        // Calculate size of all files
        await for (final file in dbDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      print('Error calculating storage usage: $e');
    }
    
    return totalSize;
  }
  
  // Delete all user data
  static Future<void> deleteAllUserData() async {
    // Clear all boxes
    await Hive.box<Map>(identificationResultsBoxName).clear();
    await Hive.box<Map>(savedLocationsBoxName).clear();
    await Hive.box<Map>(userPreferencesBoxName).clear();
    await Hive.box<Map>(syncQueueBoxName).clear();
    await Hive.box<Map>(syncDeleteQueueBoxName).clear();
    await Hive.box<Map>(expertVerificationBoxName).clear();
    
    // We'll keep the mushroom database as it's reference data, not user data
    
    print('All user data deleted successfully');
  }
  
  // Close all boxes
  static void close() {
    Hive.close();
  }
}
