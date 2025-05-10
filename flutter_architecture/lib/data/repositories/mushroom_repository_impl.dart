import 'dart:io';
import 'dart:async';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:fungiscan/domain/repositories/mushroom_repository.dart';
import 'package:fungiscan/data/datasources/local/database_helper.dart';
import 'package:fungiscan/data/datasources/remote/mushroom_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

/// Implementation of the MushroomRepository interface
class MushroomRepositoryImpl implements MushroomRepository {
  final MushroomApi _api = MushroomApi();
  final Connectivity _connectivity = Connectivity();
  final _uuid = const Uuid();
  
  /// Cache for online status to avoid frequent checks
  bool? _isOnlineCache;
  DateTime? _lastOnlineCheck;
  
  @override
  Future<Mushroom?> getMushroomById(String id) async {
    try {
      // Try to get from local database first
      final localMushroom = await DatabaseHelper.getMushroomById(id);
      
      // If found locally and we're offline, return it
      if (localMushroom != null && !(await isOnline())) {
        return localMushroom;
      }
      
      // If online, try to get fresh data from API
      if (await isOnline()) {
        try {
          final remoteMushroom = await _api.getMushroomById(id);
          
          // Update local database with fresh data
          if (remoteMushroom != null) {
            await DatabaseHelper.saveMushroom(remoteMushroom);
            return remoteMushroom;
          }
        } catch (e) {
          // If API fails but we have local data, return that
          if (localMushroom != null) {
            return localMushroom;
          }
          rethrow;
        }
      }
      
      // Return local data as fallback
      return localMushroom;
    } catch (e) {
      print('Error in getMushroomById: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<Mushroom>> getAllMushrooms() async {
    try {
      // Get local mushrooms
      final localMushrooms = await DatabaseHelper.getAllMushrooms();
      
      // If offline, return local data
      if (!(await isOnline())) {
        return localMushrooms;
      }
      
      // If online, try to get fresh data
      try {
        final remoteMushrooms = await _api.getAllMushrooms();
        
        // Update local database with fresh data
        for (final mushroom in remoteMushrooms) {
          await DatabaseHelper.saveMushroom(mushroom);
        }
        
        return remoteMushrooms;
      } catch (e) {
        // If API fails, return local data
        return localMushrooms;
      }
    } catch (e) {
      print('Error in getAllMushrooms: $e');
      return [];
    }
  }
  
  @override
  Future<List<Mushroom>> searchMushroomsByTraits(List<String> traits) async {
    try {
      // Always search locally first for better performance
      final localResults = await DatabaseHelper.searchMushroomsByTraits(traits);
      
      // If offline or local results are sufficient, return them
      if (!(await isOnline()) || localResults.length > 5) {
        return localResults;
      }
      
      // If online and few local results, try API
      try {
        final remoteResults = await _api.searchMushroomsByTraits(traits);
        
        // Update local database with fresh data
        for (final mushroom in remoteResults) {
          await DatabaseHelper.saveMushroom(mushroom);
        }
        
        return remoteResults;
      } catch (e) {
        // If API fails, return local results
        return localResults;
      }
    } catch (e) {
      print('Error in searchMushroomsByTraits: $e');
      return [];
    }
  }
  
  @override
  Future<void> saveIdentificationResult(IdentificationResult result) async {
    try {
      // Always save locally first
      await DatabaseHelper.saveIdentificationResult(result);
      
      // If online, also save to API
      if (await isOnline()) {
        try {
          await _api.saveIdentificationResult(result);
        } catch (e) {
          // If API fails, mark for future sync
          await DatabaseHelper.markForSync('identification', result.id);
        }
      } else {
        // If offline, mark for future sync
        await DatabaseHelper.markForSync('identification', result.id);
      }
    } catch (e) {
      print('Error in saveIdentificationResult: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<IdentificationResult>> getUserIdentificationHistory() async {
    try {
      // Get local history
      final localHistory = await DatabaseHelper.getUserIdentificationHistory();
      
      // If offline, return local data
      if (!(await isOnline())) {
        return localHistory;
      }
      
      // If online, try to get complete history from API
      try {
        final remoteHistory = await _api.getUserIdentificationHistory();
        
        // Update local database with fresh data
        for (final result in remoteHistory) {
          await DatabaseHelper.saveIdentificationResult(result);
        }
        
        return remoteHistory;
      } catch (e) {
        // If API fails, return local data
        return localHistory;
      }
    } catch (e) {
      print('Error in getUserIdentificationHistory: $e');
      return [];
    }
  }
  
  @override
  Future<List<IdentificationResult>> getRecentIdentifications({int limit = 10}) async {
    try {
      // Get recent local history
      final localHistory = await DatabaseHelper.getRecentIdentifications(limit: limit);
      
      // If offline, return local data
      if (!(await isOnline())) {
        return localHistory;
      }
      
      // If online, try to get recent history from API
      try {
        final remoteHistory = await _api.getRecentIdentifications(limit: limit);
        
        // Update local database with fresh data
        for (final result in remoteHistory) {
          await DatabaseHelper.saveIdentificationResult(result);
        }
        
        return remoteHistory;
      } catch (e) {
        // If API fails, return local data
        return localHistory;
      }
    } catch (e) {
      print('Error in getRecentIdentifications: $e');
      return [];
    }
  }
  
  @override
  Future<void> requestExpertVerification(String identificationId, String userQuery) async {
    try {
      // If offline, save request locally for later
      if (!(await isOnline())) {
        await DatabaseHelper.saveExpertVerificationRequest(
          identificationId,
          userQuery,
        );
        return;
      }
      
      // If online, send to API
      await _api.requestExpertVerification(identificationId, userQuery);
    } catch (e) {
      // If API fails, save request locally for later
      await DatabaseHelper.saveExpertVerificationRequest(
        identificationId,
        userQuery,
      );
      print('Error in requestExpertVerification: $e');
    }
  }
  
  @override
  Future<SavedLocation> saveForagingLocation({
    required String name,
    required String notes,
    required LatLng coordinates,
    List<LatLng>? path,
    List<String>? species,
    List<String>? photos,
  }) async {
    try {
      final id = _uuid.v4();
      final timestamp = DateTime.now();
      
      final location = SavedLocation(
        id: id,
        name: name,
        notes: notes,
        timestamp: timestamp,
        coordinates: coordinates,
        path: path,
        species: species ?? [],
        photos: photos,
      );
      
      // Save locally first
      await DatabaseHelper.saveLocation(location);
      
      // If online, also save to API
      if (await isOnline()) {
        try {
          final remoteLocation = await _api.saveForagingLocation(location);
          
          // Update local with any changes from remote
          await DatabaseHelper.saveLocation(remoteLocation);
          
          return remoteLocation;
        } catch (e) {
          // If API fails, mark for future sync
          await DatabaseHelper.markForSync('location', id);
        }
      } else {
        // If offline, mark for future sync
        await DatabaseHelper.markForSync('location', id);
      }
      
      return location;
    } catch (e) {
      print('Error in saveForagingLocation: $e');
      rethrow;
    }
  }
  
  @override
  Future<SavedLocation> updateForagingLocation({
    required String id,
    String? name,
    String? notes,
    LatLng? coordinates,
    List<LatLng>? path,
    List<String>? species,
    List<String>? photos,
  }) async {
    try {
      // Get existing location
      final existingLocation = await getSavedLocationById(id);
      if (existingLocation == null) {
        throw Exception('Location not found');
      }
      
      // Create updated location
      final updatedLocation = existingLocation.copyWith(
        name: name,
        notes: notes,
        coordinates: coordinates,
        path: path,
        species: species,
        photos: photos,
      );
      
      // Save locally first
      await DatabaseHelper.saveLocation(updatedLocation);
      
      // If online, also update via API
      if (await isOnline()) {
        try {
          final remoteLocation = await _api.updateForagingLocation(updatedLocation);
          
          // Update local with any changes from remote
          await DatabaseHelper.saveLocation(remoteLocation);
          
          return remoteLocation;
        } catch (e) {
          // If API fails, mark for future sync
          await DatabaseHelper.markForSync('location', id);
        }
      } else {
        // If offline, mark for future sync
        await DatabaseHelper.markForSync('location', id);
      }
      
      return updatedLocation;
    } catch (e) {
      print('Error in updateForagingLocation: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> deleteForagingLocation(String id) async {
    try {
      // Delete locally first
      await DatabaseHelper.deleteLocation(id);
      
      // If online, also delete from API
      if (await isOnline()) {
        try {
          await _api.deleteForagingLocation(id);
        } catch (e) {
          // If API fails, mark for future delete sync
          await DatabaseHelper.markForDeleteSync('location', id);
        }
      } else {
        // If offline, mark for future delete sync
        await DatabaseHelper.markForDeleteSync('location', id);
      }
    } catch (e) {
      print('Error in deleteForagingLocation: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> addSpeciesToLocation({
    required String locationId,
    required String speciesName,
    String? photoPath,
  }) async {
    try {
      // Get existing location
      final existingLocation = await getSavedLocationById(locationId);
      if (existingLocation == null) {
        throw Exception('Location not found');
      }
      
      // Add species to the list
      final updatedSpecies = List<String>.from(existingLocation.species)
        ..add(speciesName);
      
      // Add photo if provided
      List<String>? updatedPhotos;
      if (photoPath != null) {
        if (existingLocation.photos != null) {
          updatedPhotos = List<String>.from(existingLocation.photos!);
          updatedPhotos!.add(photoPath);
        } else {
          updatedPhotos = [photoPath];
        }
      }
      
      // Update location
      await updateForagingLocation(
        id: locationId,
        species: updatedSpecies,
        photos: updatedPhotos,
      );
    } catch (e) {
      print('Error in addSpeciesToLocation: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<SavedLocation>> getAllSavedLocations() async {
    try {
      // Get local locations
      final localLocations = await DatabaseHelper.getAllSavedLocations();
      
      // If offline, return local data
      if (!(await isOnline())) {
        return localLocations;
      }
      
      // If online, try to get from API
      try {
        final remoteLocations = await _api.getAllSavedLocations();
        
        // Update local database with fresh data
        for (final location in remoteLocations) {
          await DatabaseHelper.saveLocation(location);
        }
        
        return remoteLocations;
      } catch (e) {
        // If API fails, return local data
        return localLocations;
      }
    } catch (e) {
      print('Error in getAllSavedLocations: $e');
      return [];
    }
  }
  
  @override
  Future<SavedLocation?> getSavedLocationById(String id) async {
    try {
      // Try to get from local database first
      final localLocation = await DatabaseHelper.getSavedLocationById(id);
      
      // If found locally and we're offline, return it
      if (localLocation != null && !(await isOnline())) {
        return localLocation;
      }
      
      // If online, try to get fresh data from API
      if (await isOnline()) {
        try {
          final remoteLocation = await _api.getSavedLocationById(id);
          
          // Update local database with fresh data
          if (remoteLocation != null) {
            await DatabaseHelper.saveLocation(remoteLocation);
            return remoteLocation;
          }
        } catch (e) {
          // If API fails but we have local data, return that
          if (localLocation != null) {
            return localLocation;
          }
          rethrow;
        }
      }
      
      // Return local data as fallback
      return localLocation;
    } catch (e) {
      print('Error in getSavedLocationById: $e');
      return null;
    }
  }
  
  @override
  Future<UserPreferences> getUserPreferences() async {
    try {
      // Get local preferences
      final localPreferences = await DatabaseHelper.getUserPreferences();
      
      // If offline, return local data
      if (!(await isOnline())) {
        return localPreferences;
      }
      
      // If online, try to get from API
      try {
        final remotePreferences = await _api.getUserPreferences();
        
        // Update local database with fresh data
        await DatabaseHelper.saveUserPreferences(remotePreferences);
        
        return remotePreferences;
      } catch (e) {
        // If API fails, return local data
        return localPreferences;
      }
    } catch (e) {
      print('Error in getUserPreferences: $e');
      // Return default preferences if there's an error
      return UserPreferences();
    }
  }
  
  @override
  Future<void> updateUserPreferences(UserPreferences preferences) async {
    try {
      // Save locally first
      await DatabaseHelper.saveUserPreferences(preferences);
      
      // If online, also save to API
      if (await isOnline()) {
        try {
          await _api.updateUserPreferences(preferences);
        } catch (e) {
          // If API fails, mark for future sync
          await DatabaseHelper.markForSync('preferences', 'user_preferences');
        }
      } else {
        // If offline, mark for future sync
        await DatabaseHelper.markForSync('preferences', 'user_preferences');
      }
    } catch (e) {
      print('Error in updateUserPreferences: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<LookalikeSpecies>> getDangerousLookalikes(String mushroomId) async {
    try {
      // Try to get the mushroom first
      final mushroom = await getMushroomById(mushroomId);
      if (mushroom == null) {
        return [];
      }
      
      // Filter dangerous lookalikes from the mushroom
      final dangerousLookalikes = mushroom.lookalikes
          .where((lookalike) => 
              lookalike.edibility == Edibility.poisonous ||
              lookalike.edibility == Edibility.psychoactive)
          .toList();
      
      // If offline, return filtered lookalikes
      if (!(await isOnline())) {
        return dangerousLookalikes;
      }
      
      // If online, try to get more complete data from API
      try {
        final remoteLookalikes = await _api.getDangerousLookalikes(mushroomId);
        return remoteLookalikes;
      } catch (e) {
        // If API fails, return local data
        return dangerousLookalikes;
      }
    } catch (e) {
      print('Error in getDangerousLookalikes: $e');
      return [];
    }
  }
  
  @override
  Future<bool> syncOfflineData() async {
    try {
      // Check if online
      if (!(await isOnline())) {
        return false;
      }
      
      // Get items to sync
      final itemsToSync = await DatabaseHelper.getItemsToSync();
      final itemsToDelete = await DatabaseHelper.getItemsToDeleteSync();
      
      bool success = true;
      
      // Sync items
      for (final item in itemsToSync) {
        try {
          switch (item.type) {
            case 'identification':
              final result = await DatabaseHelper.getIdentificationResultById(item.id);
              if (result != null) {
                await _api.saveIdentificationResult(result);
              }
              break;
            case 'location':
              final location = await DatabaseHelper.getSavedLocationById(item.id);
              if (location != null) {
                await _api.updateForagingLocation(location);
              }
              break;
            case 'preferences':
              final preferences = await DatabaseHelper.getUserPreferences();
              await _api.updateUserPreferences(preferences);
              break;
          }
          
          // Mark as synced
          await DatabaseHelper.markAsSynced(item.type, item.id);
        } catch (e) {
          print('Error syncing item: ${item.type}/${item.id}: $e');
          success = false;
        }
      }
      
      // Process deletes
      for (final item in itemsToDelete) {
        try {
          switch (item.type) {
            case 'location':
              await _api.deleteForagingLocation(item.id);
              break;
          }
          
          // Mark as synced
          await DatabaseHelper.markDeleteAsSynced(item.type, item.id);
        } catch (e) {
          print('Error syncing delete: ${item.type}/${item.id}: $e');
          success = false;
        }
      }
      
      return success;
    } catch (e) {
      print('Error in syncOfflineData: $e');
      return false;
    }
  }
  
  @override
  Future<bool> isOnline() async {
    try {
      // Check cache first (valid for 30 seconds)
      if (_isOnlineCache != null && _lastOnlineCheck != null) {
        final elapsed = DateTime.now().difference(_lastOnlineCheck!);
        if (elapsed.inSeconds < 30) {
          return _isOnlineCache!;
        }
      }
      
      // Check connectivity
      final result = await _connectivity.checkConnectivity();
      final hasConnectivity = result != ConnectivityResult.none;
      
      // If no connectivity, return false
      if (!hasConnectivity) {
        _isOnlineCache = false;
        _lastOnlineCheck = DateTime.now();
        return false;
      }
      
      // Test actual connection to API
      try {
        final isServerReachable = await _api.checkConnection();
        _isOnlineCache = isServerReachable;
        _lastOnlineCheck = DateTime.now();
        return isServerReachable;
      } catch (e) {
        _isOnlineCache = false;
        _lastOnlineCheck = DateTime.now();
        return false;
      }
    } catch (e) {
      print('Error checking online status: $e');
      return false;
    }
  }
  
  @override
  Future<void> clearCache() async {
    try {
      await DatabaseHelper.clearCache();
    } catch (e) {
      print('Error in clearCache: $e');
      rethrow;
    }
  }
  
  @override
  Future<int> getStorageUsage() async {
    try {
      return await DatabaseHelper.getStorageUsage();
    } catch (e) {
      print('Error in getStorageUsage: $e');
      return 0;
    }
  }
  
  @override
  Future<File> exportUserData() async {
    try {
      // Get all user data
      final identifications = await getUserIdentificationHistory();
      final locations = await getAllSavedLocations();
      final preferences = await getUserPreferences();
      
      // Create a JSON representation
      final userData = {
        'identifications': identifications.map((i) => i.toJson()).toList(),
        'locations': locations.map((l) => l.toJson()).toList(),
        'preferences': preferences.toJson(),
        'exportDate': DateTime.now().toIso8601String(),
      };
      
      // Convert to string
      final jsonData = userData.toString();
      
      // Save to a file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/fungiscan_export.json');
      await file.writeAsString(jsonData);
      
      return file;
    } catch (e) {
      print('Error in exportUserData: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> deleteAllUserData() async {
    try {
      // Delete local data
      await DatabaseHelper.deleteAllUserData();
      
      // If online, also delete from API
      if (await isOnline()) {
        try {
          await _api.deleteAllUserData();
        } catch (e) {
          print('Error deleting remote user data: $e');
          // Continue even if remote delete fails
        }
      }
    } catch (e) {
      print('Error in deleteAllUserData: $e');
      rethrow;
    }
  }
}
