import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling location tracking and foraging path recording
class LocationService {
  // Stream for real-time location updates
  StreamSubscription<Position>? _positionStreamSubscription;
  final _locationController = StreamController<Position>.broadcast();
  
  /// Stream of location updates that can be listened to
  Stream<Position> get locationStream => _locationController.stream;
  
  // Track user path during foraging
  final List<LatLng> _currentPath = [];
  
  /// Current recorded path
  List<LatLng> get currentPath => List.unmodifiable(_currentPath);
  
  // Track if we're currently recording a path
  bool _isRecordingPath = false;
  
  /// Whether a path is currently being recorded
  bool get isRecordingPath => _isRecordingPath;
  
  /// Initialize the location service and check permissions
  Future<void> initialize() async {
    if (!kIsWeb) {
      await _checkLocationPermission();
    }
  }
  
  /// Check and request location permissions if needed
  Future<bool> _checkLocationPermission() async {
    if (kIsWeb) {
      // Web platform has different permission model
      return true;
    }
    
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request to enable location services
      // This would typically show a dialog to the user
      return false;
    }
    
    // Check location permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    // Handle permanently denied permission
    if (permission == LocationPermission.deniedForever) {
      // Direct user to app settings to enable permission
      await openAppSettings();
      return false;
    }
    
    return true;
  }
  
  /// Get the current device location
  Future<Position?> getCurrentLocation() async {
    if (kIsWeb) {
      // For web development, return a mock position
      return Position(
        latitude: 37.4219999,
        longitude: -122.0840575,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
    
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return null;
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  /// Start tracking location updates
  void startLocationTracking() {
    if (kIsWeb) {
      // For web, create a simulated position stream
      _simulatePositionUpdates();
      return;
    }
    
    _positionStreamSubscription?.cancel();
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (Position position) {
        _locationController.add(position);
        
        if (_isRecordingPath) {
          _currentPath.add(LatLng(position.latitude, position.longitude));
        }
      },
      onError: (error) {
        print('Error in location stream: $error');
      },
    );
  }
  
  // For web development, simulate location updates
  void _simulatePositionUpdates() {
    // Base coordinates
    double baseLat = 37.4219999;
    double baseLng = -122.0840575;
    
    // Cancel any existing subscription
    _positionStreamSubscription?.cancel();
    
    // Create a periodic timer to simulate movement
    _positionStreamSubscription = Stream.periodic(
      const Duration(seconds: 3),
      (i) {
        // Add small random variations to simulate movement
        final lat = baseLat + (math.Random().nextDouble() - 0.5) * 0.001;
        final lng = baseLng + (math.Random().nextDouble() - 0.5) * 0.001;
        
        return Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      },
    ).listen((position) {
      _locationController.add(position);
      
      if (_isRecordingPath) {
        _currentPath.add(LatLng(position.latitude, position.longitude));
      }
    });
  }
  
  /// Stop tracking location updates
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
  
  /// Start recording a foraging path
  void startPathRecording() {
    _currentPath.clear();
    _isRecordingPath = true;
    
    // Make sure we're tracking location
    if (_positionStreamSubscription == null) {
      startLocationTracking();
    }
  }
  
  /// Stop recording the current path and return it
  Future<List<LatLng>> stopPathRecording() async {
    _isRecordingPath = false;
    return _currentPath;
  }
  
  /// Calculate the distance of a path in meters
  double calculatePathDistance(List<LatLng> path) {
    double totalDistance = 0;
    
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
    }
    
    return totalDistance;
  }
  
  /// Format a distance in a human-readable way
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
  }
  
  /// Calculate the area encompassed by a path in square meters
  double calculateArea(List<LatLng> path) {
    // This is a simple implementation of the Shoelace formula (Gauss's area formula)
    if (path.length < 3) return 0; // Need at least 3 points for an area
    
    double area = 0;
    
    for (int i = 0; i < path.length; i++) {
      int j = (i + 1) % path.length;
      
      // Convert to cartesian coordinates (approximately)
      // This is a simplification and not accurate for large areas or near poles
      final lat1 = path[i].latitude * 111320; // 1 degree lat is about 111320 meters
      final lng1 = path[i].longitude * 111320 * math.cos(path[i].latitude * math.pi / 180);
      final lat2 = path[j].latitude * 111320;
      final lng2 = path[j].longitude * 111320 * math.cos(path[j].latitude * math.pi / 180);
      
      area += (lat1 * lng2) - (lng1 * lat2);
    }
    
    return area.abs() / 2;
  }
  
  /// Format an area in a human-readable way
  String formatArea(double areaInSquareMeters) {
    if (areaInSquareMeters < 10000) {
      return '${areaInSquareMeters.toStringAsFixed(0)} m²';
    } else {
      final hectares = areaInSquareMeters / 10000;
      return '${hectares.toStringAsFixed(2)} ha';
    }
  }
  
  /// Check if a location is within a geofenced area
  bool isLocationInArea(LatLng location, List<LatLng> area) {
    if (area.length < 3) return false; // Need at least 3 points for an area
    
    // Ray casting algorithm
    bool isInside = false;
    for (int i = 0, j = area.length - 1; i < area.length; i++) {
      j = (i > 0) ? i - 1 : area.length - 1;
      
      if (((area[i].latitude > location.latitude) != 
           (area[j].latitude > location.latitude)) &&
          (location.longitude < (area[j].longitude - area[i].longitude) * 
           (location.latitude - area[i].latitude) / 
           (area[j].latitude - area[i].latitude) + area[i].longitude)) {
        isInside = !isInside;
      }
    }
    
    return isInside;
  }
  
  /// Get a descriptive address for a location
  Future<String?> getAddressFromLocation(LatLng location) async {
    if (kIsWeb) {
      // For web, return a placeholder address
      return "1600 Amphitheatre Parkway, Mountain View, CA 94043, USA";
    }
    
    try {
      // This would use a geocoding service in a real app
      // For example, the geocoding package or Google Maps API
      
      // Placeholder for demo
      return "Location at ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}";
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }
  
  /// Clean up resources when the service is no longer needed
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationController.close();
  }
}