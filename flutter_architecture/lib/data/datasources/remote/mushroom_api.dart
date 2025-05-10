import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:fungiscan/domain/models/mushroom.dart';

/// API client for the mushroom identification service
class MushroomApi {
  // Base URL for the API
  static const String baseUrl = 'https://api.fungiscan.com/v1';
  
  // API key
  final String apiKey;
  
  // HTTP client
  final http.Client _client;
  
  // Constructor
  MushroomApi({
    String? apiKey,
    http.Client? client,
  }) : 
    apiKey = apiKey ?? const String.fromEnvironment('FUNGISCAN_API_KEY', defaultValue: ''),
    _client = client ?? http.Client();
  
  /// Check if the server is reachable
  Future<bool> checkConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }
  
  /// Get a mushroom by ID
  Future<Mushroom?> getMushroomById(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/mushrooms/$id'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Mushroom.fromJson(json);
      }
      
      _handleErrorResponse(response);
      return null;
    } catch (e) {
      print('Error getting mushroom: $e');
      rethrow;
    }
  }
  
  /// Get all mushrooms
  Future<List<Mushroom>> getAllMushrooms() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/mushrooms'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((m) => Mushroom.fromJson(m)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error getting all mushrooms: $e');
      rethrow;
    }
  }
  
  /// Search for mushrooms by traits
  Future<List<Mushroom>> searchMushroomsByTraits(List<String> traits) async {
    try {
      final queryParams = {'traits': traits.join(',')};
      
      final response = await _client.get(
        Uri.parse('$baseUrl/mushrooms/search').replace(queryParameters: queryParams),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((m) => Mushroom.fromJson(m)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error searching mushrooms by traits: $e');
      rethrow;
    }
  }
  
  /// Save identification result
  Future<void> saveIdentificationResult(IdentificationResult result) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/identifications'),
        headers: _getHeaders(),
        body: jsonEncode(result.toJson()),
      );
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error saving identification result: $e');
      rethrow;
    }
  }
  
  /// Get user identification history
  Future<List<IdentificationResult>> getUserIdentificationHistory() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/identifications'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((r) => IdentificationResult.fromJson(r)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error getting identification history: $e');
      rethrow;
    }
  }
  
  /// Get recent identifications
  Future<List<IdentificationResult>> getRecentIdentifications({int limit = 10}) async {
    try {
      final queryParams = {'limit': limit.toString()};
      
      final response = await _client.get(
        Uri.parse('$baseUrl/identifications/recent').replace(queryParameters: queryParams),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((r) => IdentificationResult.fromJson(r)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error getting recent identifications: $e');
      rethrow;
    }
  }
  
  /// Request expert verification
  Future<void> requestExpertVerification(String identificationId, String userQuery) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/identifications/$identificationId/verify'),
        headers: _getHeaders(),
        body: jsonEncode({
          'userQuery': userQuery,
        }),
      );
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error requesting expert verification: $e');
      rethrow;
    }
  }
  
  /// Save foraging location
  Future<SavedLocation> saveForagingLocation(SavedLocation location) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/locations'),
        headers: _getHeaders(),
        body: jsonEncode(location.toJson()),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SavedLocation.fromJson(json);
      }
      
      _handleErrorResponse(response);
      return location; // Return original if failed
    } catch (e) {
      print('Error saving foraging location: $e');
      rethrow;
    }
  }
  
  /// Update foraging location
  Future<SavedLocation> updateForagingLocation(SavedLocation location) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/locations/${location.id}'),
        headers: _getHeaders(),
        body: jsonEncode(location.toJson()),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SavedLocation.fromJson(json);
      }
      
      _handleErrorResponse(response);
      return location; // Return original if failed
    } catch (e) {
      print('Error updating foraging location: $e');
      rethrow;
    }
  }
  
  /// Delete foraging location
  Future<void> deleteForagingLocation(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/locations/$id'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error deleting foraging location: $e');
      rethrow;
    }
  }
  
  /// Get all saved locations
  Future<List<SavedLocation>> getAllSavedLocations() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/locations'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((l) => SavedLocation.fromJson(l)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error getting saved locations: $e');
      rethrow;
    }
  }
  
  /// Get saved location by ID
  Future<SavedLocation?> getSavedLocationById(String id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/locations/$id'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SavedLocation.fromJson(json);
      }
      
      _handleErrorResponse(response);
      return null;
    } catch (e) {
      print('Error getting location by ID: $e');
      rethrow;
    }
  }
  
  /// Get user preferences
  Future<UserPreferences> getUserPreferences() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/user/preferences'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return UserPreferences.fromJson(json);
      }
      
      _handleErrorResponse(response);
      return UserPreferences(); // Return default if failed
    } catch (e) {
      print('Error getting user preferences: $e');
      rethrow;
    }
  }
  
  /// Update user preferences
  Future<void> updateUserPreferences(UserPreferences preferences) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/user/preferences'),
        headers: _getHeaders(),
        body: jsonEncode(preferences.toJson()),
      );
      
      if (response.statusCode != 200) {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error updating user preferences: $e');
      rethrow;
    }
  }
  
  /// Get dangerous lookalikes
  Future<List<LookalikeSpecies>> getDangerousLookalikes(String mushroomId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/mushrooms/$mushroomId/lookalikes/dangerous'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return json.map((l) => LookalikeSpecies.fromJson(l)).toList();
      }
      
      _handleErrorResponse(response);
      return [];
    } catch (e) {
      print('Error getting dangerous lookalikes: $e');
      rethrow;
    }
  }
  
  /// Delete all user data
  Future<void> deleteAllUserData() async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/user/data'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleErrorResponse(response);
      }
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }
  
  /// Upload an image for identification
  Future<IdentificationResult> identifyMushroom(File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/identify'),
      );
      
      // Add headers
      request.headers.addAll(_getHeaders());
      
      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return IdentificationResult.fromJson(json);
      }
      
      _handleErrorResponse(response);
      throw Exception('Failed to identify mushroom');
    } catch (e) {
      print('Error identifying mushroom: $e');
      rethrow;
    }
  }
  
  /// Get default headers for API requests
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }
  
  /// Handle error responses
  void _handleErrorResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please check your API key');
    } else if (response.statusCode == 404) {
      throw Exception('Resource not found');
    } else {
      try {
        final errorJson = jsonDecode(response.body);
        final errorMessage = errorJson['message'] ?? 'Unknown error';
        throw Exception('API error (${response.statusCode}): $errorMessage');
      } catch (e) {
        throw Exception('API error (${response.statusCode}): ${response.body}');
      }
    }
  }
  
  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
