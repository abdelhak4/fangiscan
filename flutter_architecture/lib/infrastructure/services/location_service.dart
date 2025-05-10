import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:fungiscan/domain/models/foraging_site.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service for handling location tracking and foraging site management
/// Supports offline-first functionality for remote areas
class LocationService {
  final _logger = Logger('LocationService');
  final _uuid = const Uuid();

  // Stream controllers
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();
  final StreamController<List<ForagingSite>> _foragingSitesStreamController =
      StreamController<List<ForagingSite>>.broadcast();

  // Streams
  Stream<Position> get positionStream => _positionStreamController.stream;
  Stream<List<ForagingSite>> get foragingSitesStream =>
      _foragingSitesStreamController.stream;

  // Location tracking
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;
  bool _isTracking = false;
  List<LatLng> _currentTrack = [];
  ForagingSite? _activeForagingSite;

  // Local storage key for offline data
  static const String _foragingSitesBoxName = 'foragingSites';

  /// Initialize the location service
  Future<void> initialize() async {
    _logger.info('Initializing location service');

    // Check if location services are enabled
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      _logger.warning('Location services are disabled');
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.severe('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.severe('Location permission permanently denied');
      return;
    }

    // Get initial position
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _logger.info('Initial position: $_lastKnownPosition');
    } catch (e) {
      _logger.warning('Failed to get initial position: $e');
    }

    // Load saved foraging sites
    await _loadForagingSites();
  }

  /// Get current user position with accuracy options
  /// High accuracy for mapping, low for general area
  Future<Position?> getCurrentPosition({
    bool highAccuracy = true,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      _logger.warning('Failed to get current position: $e');
      return _lastKnownPosition; // Return last known as fallback
    }
  }

  /// Get last known position (may be null if never obtained)
  Position? getLastKnownPosition() {
    return _lastKnownPosition;
  }

  /// Start tracking user location (for creating foraging paths)
  Future<void> startTracking() async {
    if (_isTracking) return;

    _logger.info('Starting location tracking');
    _isTracking = true;
    _currentTrack = [];

    // Get current position as starting point
    final currentPosition = await getCurrentPosition();
    if (currentPosition != null) {
      _currentTrack
          .add(LatLng(currentPosition.latitude, currentPosition.longitude));
    }

    // Subscribe to position updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _lastKnownPosition = position;
      _positionStreamController.add(position);

      if (_isTracking) {
        _currentTrack.add(LatLng(position.latitude, position.longitude));
      }
    }, onError: (e) {
      _logger.severe('Error in position stream: $e');
    });
  }

  /// Stop tracking user location
  void stopTracking() {
    if (!_isTracking) return;

    _logger.info('Stopping location tracking');
    _isTracking = false;
    _positionSubscription?.cancel();
  }

  /// Get current track points (path walked while tracking)
  List<LatLng> getCurrentTrack() {
    return List.unmodifiable(_currentTrack);
  }

  /// Start a new foraging session at the current location
  Future<ForagingSite> startForagingSite(String name, String notes) async {
    final currentPosition = await getCurrentPosition();
    if (currentPosition == null) {
      throw Exception('Cannot start foraging site: location unavailable');
    }

    _logger.info('Starting new foraging site: $name');

    // Create new foraging site
    final site = ForagingSite(
      id: _uuid.v4(),
      name: name,
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: notes,
      trackPoints: [],
      mushroomFinds: [],
    );

    // Start tracking
    _activeForagingSite = site;
    await startTracking();

    // Save to storage
    await _saveForagingSite(site);

    return site;
  }

  /// End current foraging session and save track
  Future<ForagingSite?> endForagingSite() async {
    if (_activeForagingSite == null) {
      _logger.warning('No active foraging site to end');
      return null;
    }

    _logger.info('Ending foraging site: ${_activeForagingSite!.name}');

    // Stop tracking
    stopTracking();

    // Update site with track points
    final updatedSite = _activeForagingSite!.copyWith(
      trackPoints: _currentTrack,
      updatedAt: DateTime.now(),
    );

    // Save to storage
    await _saveForagingSite(updatedSite);

    // Clear active site
    final result = updatedSite;
    _activeForagingSite = null;
    _currentTrack = [];

    return result;
  }

  /// Record a mushroom find at current location
  Future<void> recordMushroomFind({
    required String mushroomName,
    required String notes,
    File? image,
  }) async {
    if (_activeForagingSite == null) {
      _logger.warning('No active foraging site to record find');
      return;
    }

    final currentPosition = await getCurrentPosition();
    if (currentPosition == null) {
      throw Exception('Cannot record mushroom find: location unavailable');
    }

    _logger.info('Recording mushroom find: $mushroomName');

    // Save image if provided
    String? imagePath;
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${_uuid.v4()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage =
          await image.copy('${appDir.path}/mushroom_finds/$fileName');
      imagePath = savedImage.path;
    }

    // Add find to active site
    final newFind = MushroomFind(
      id: _uuid.v4(),
      name: mushroomName,
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
      timestamp: DateTime.now(),
      notes: notes,
      imagePath: imagePath,
    );

    final updatedSite = _activeForagingSite!.copyWith(
      mushroomFinds: [..._activeForagingSite!.mushroomFinds, newFind],
      updatedAt: DateTime.now(),
    );

    _activeForagingSite = updatedSite;

    // Save to storage
    await _saveForagingSite(updatedSite);

    // Update stream
    await _loadForagingSites();
  }

  /// Get all saved foraging sites
  Future<List<ForagingSite>> getForagingSites() async {
    try {
      final box = await Hive.openBox<Map>(_foragingSitesBoxName);

      final List<ForagingSite> sites = [];
      for (var i = 0; i < box.length; i++) {
        final Map? rawSite = box.getAt(i);
        if (rawSite != null) {
          sites.add(ForagingSite.fromJson(Map<String, dynamic>.from(rawSite)));
        }
      }

      return sites;
    } catch (e) {
      _logger.severe('Error retrieving foraging sites: $e');
      return [];
    }
  }

  /// Get foraging site by ID
  Future<ForagingSite?> getForagingSiteById(String id) async {
    final sites = await getForagingSites();
    return sites.firstWhere(
      (site) => site.id == id,
      orElse: () => throw Exception('Foraging site not found: $id'),
    );
  }

  /// Delete a foraging site
  Future<void> deleteForagingSite(String id) async {
    _logger.info('Deleting foraging site: $id');

    try {
      final box = await Hive.openBox<Map>(_foragingSitesBoxName);

      // Find and delete the site
      for (var i = 0; i < box.length; i++) {
        final Map? rawSite = box.getAt(i);
        if (rawSite != null) {
          final site =
              ForagingSite.fromJson(Map<String, dynamic>.from(rawSite));
          if (site.id == id) {
            await box.deleteAt(i);
            break;
          }
        }
      }

      // Update stream
      await _loadForagingSites();
    } catch (e) {
      _logger.severe('Error deleting foraging site: $e');
      throw Exception('Failed to delete foraging site: $e');
    }
  }

  /// Save a foraging site to storage
  Future<void> _saveForagingSite(ForagingSite site) async {
    try {
      final box = await Hive.openBox<Map>(_foragingSitesBoxName);

      // Check if site already exists to update it
      bool found = false;
      for (var i = 0; i < box.length; i++) {
        final Map? rawSite = box.getAt(i);
        if (rawSite != null) {
          final existingSite =
              ForagingSite.fromJson(Map<String, dynamic>.from(rawSite));
          if (existingSite.id == site.id) {
            await box.putAt(i, site.toJson());
            found = true;
            break;
          }
        }
      }

      // Add new site if not found
      if (!found) {
        await box.add(site.toJson());
      }

      // Update stream
      await _loadForagingSites();
    } catch (e) {
      _logger.severe('Error saving foraging site: $e');
      throw Exception('Failed to save foraging site: $e');
    }
  }

  /// Load all foraging sites and update stream
  Future<void> _loadForagingSites() async {
    final sites = await getForagingSites();
    _foragingSitesStreamController.add(sites);
  }

  /// Calculate distance between two LatLng points in meters
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate total distance of a track in kilometers
  double calculateTrackDistance(List<LatLng> track) {
    double totalDistance = 0;
    for (int i = 0; i < track.length - 1; i++) {
      totalDistance += calculateDistance(track[i], track[i + 1]);
    }
    return totalDistance / 1000; // Convert to kilometers
  }

  /// Clean up resources
  void dispose() {
    _logger.info('Disposing location service');
    _positionSubscription?.cancel();
    _positionStreamController.close();
    _foragingSitesStreamController.close();
  }
}
