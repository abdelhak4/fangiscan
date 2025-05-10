import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fungiscan/application/map/map_bloc.dart';
import 'package:fungiscan/domain/models/mushroom.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();
    // Load saved locations when the screen initializes
    context.read<MapBloc>().add(LoadSavedLocationsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foraging Map'),
        actions: [
          BlocBuilder<MapBloc, MapState>(
            builder: (context, state) {
              final isRecording = state.isRecordingPath;
              return IconButton(
                icon: Icon(
                  isRecording ? Icons.stop_circle : Icons.play_circle,
                  color: isRecording ? Colors.red : Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  if (isRecording) {
                    context.read<MapBloc>().add(StopPathRecordingEvent());
                  } else {
                    context.read<MapBloc>().add(StartPathRecordingEvent());
                  }
                },
                tooltip: isRecording ? 'Stop Recording' : 'Start Recording Path',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              _showMapLayersDialog();
            },
            tooltip: 'Map Layers',
          ),
        ],
      ),
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state.status == MapStatus.locationUpdated && 
              state.currentLocation != null) {
            _updateCurrentLocation(state.currentLocation!);
          }
          
          if (state.status == MapStatus.savedLocationsLoaded) {
            _updateSavedLocations(state.savedLocations);
          }
          
          if (state.status == MapStatus.pathUpdated) {
            _updatePathPolyline(state.currentPath);
          }
          
          if (state.status == MapStatus.locationSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          if (state.status == MapStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (!_mapInitialized && state.currentLocation == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            );
          }
          
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: state.currentLocation ?? const LatLng(37.42796, -122.08574),
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapType: state.mapType,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  setState(() {
                    _mapInitialized = true;
                  });
                  
                  // Get current location when map is created
                  context.read<MapBloc>().add(GetCurrentLocationEvent());
                },
                onLongPress: (LatLng position) {
                  _showAddLocationDialog(position);
                },
              ),
              
              // Path recording indicator
              if (state.isRecordingPath)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Recording Path',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Offline mode indicator
              if (!state.isOnline)
                Positioned(
                  top: state.isRecordingPath ? 70 : 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Offline Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'centerMap',
            onPressed: () {
              context.read<MapBloc>().add(GetCurrentLocationEvent());
            },
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'listLocations',
            onPressed: () {
              _showSavedLocationsList();
            },
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.list),
          ),
        ],
      ),
    );
  }
  
  void _updateCurrentLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(location),
    );
  }
  
  void _updateSavedLocations(List<SavedLocation> locations) {
    setState(() {
      _markers.clear();
      
      for (final location in locations) {
        _markers.add(
          Marker(
            markerId: MarkerId(location.id),
            position: location.coordinates,
            infoWindow: InfoWindow(
              title: location.name,
              snippet: '${location.species.length} species found',
              onTap: () {
                _showLocationDetails(location);
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    });
  }
  
  void _updatePathPolyline(List<LatLng> path) {
    setState(() {
      _polylines.clear();
      
      if (path.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('currentPath'),
            points: path,
            color: Colors.blue,
            width: 5,
          ),
        );
      }
    });
  }
  
  void _showMapLayersDialog() {
    final state = context.read<MapBloc>().state;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Map Layers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Normal'),
                  leading: Radio<MapType>(
                    value: MapType.normal,
                    groupValue: state.mapType,
                    onChanged: (value) {
                      context.read<MapBloc>().add(
                        ChangeMapTypeEvent(mapType: value!),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Satellite'),
                  leading: Radio<MapType>(
                    value: MapType.satellite,
                    groupValue: state.mapType,
                    onChanged: (value) {
                      context.read<MapBloc>().add(
                        ChangeMapTypeEvent(mapType: value!),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Terrain'),
                  leading: Radio<MapType>(
                    value: MapType.terrain,
                    groupValue: state.mapType,
                    onChanged: (value) {
                      context.read<MapBloc>().add(
                        ChangeMapTypeEvent(mapType: value!),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Hybrid'),
                  leading: Radio<MapType>(
                    value: MapType.hybrid,
                    groupValue: state.mapType,
                    onChanged: (value) {
                      context.read<MapBloc>().add(
                        ChangeMapTypeEvent(mapType: value!),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showAddLocationDialog(LatLng position) {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Foraging Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g., Pine Forest Trail',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Terrain type, landmarks, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<MapBloc>().add(
                  SaveForagingLocationEvent(
                    name: nameController.text.trim(),
                    notes: notesController.text.trim(),
                    species: const [],
                    coordinates: position,
                  ),
                );
                Navigator.pop(context);
              } else {
                // Show error for empty name
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a location name'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showSavedLocationsList() {
    final state = context.read<MapBloc>().state;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Foraging Locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<MapBloc>().add(LoadSavedLocationsEvent());
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.savedLocations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No saved locations yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Long-press on the map to add a location',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.savedLocations.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final location = state.savedLocations[index];
                        return ListTile(
                          title: Text(location.name),
                          subtitle: Text(
                            location.notes.isEmpty
                                ? '${location.species.isEmpty ? "No" : location.species.length} species found • ${_formatDate(location.timestamp)}'
                                : '${location.notes}\n${location.species.isEmpty ? "No" : location.species.length} species found • ${_formatDate(location.timestamp)}',
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.forest,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View Details'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (value) {
                              Navigator.pop(context);
                              if (value == 'view') {
                                _showLocationDetails(location);
                              } else if (value == 'edit') {
                                _showEditLocationDialog(location);
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(location);
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                location.coordinates,
                                15.0,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showLocationDetails(SavedLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(location.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                if (location.notes.isNotEmpty) ...[
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(location.notes),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.spa,  // Using a plant icon instead of mushroom which isn't available
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${location.species.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const Text(
                              'Species',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pin_drop,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.path != null ? '${location.path!.length}' : '0',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const Text(
                              'Waypoints',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.photos != null ? '${location.photos!.length}' : '0',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const Text(
                              'Photos',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (location.species.isNotEmpty) ...[
                  const Text(
                    'Species Found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: location.species.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(location.species[index]),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '🍄',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          onTap: () {
                            // Navigate to species details
                          },
                        );
                      },
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No species recorded at this location',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Species'),
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddSpeciesDialog(location);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showEditLocationDialog(SavedLocation location) {
    final nameController = TextEditingController(text: location.name);
    final notesController = TextEditingController(text: location.notes);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<MapBloc>().add(
                  UpdateForagingLocationEvent(
                    id: location.id,
                    name: nameController.text.trim(),
                    notes: notesController.text.trim(),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation(SavedLocation location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "${location.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<MapBloc>().add(
                DeleteForagingLocationEvent(id: location.id),
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddSpeciesDialog(SavedLocation location) {
    final speciesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Species'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: speciesController,
              decoration: const InputDecoration(
                labelText: 'Species Name',
                hintText: 'e.g., Chanterelle',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              onPressed: () {
                // Handle photo capture
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (speciesController.text.trim().isNotEmpty) {
                context.read<MapBloc>().add(
                  AddSpeciesToLocationEvent(
                    locationId: location.id,
                    speciesName: speciesController.text.trim(),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
