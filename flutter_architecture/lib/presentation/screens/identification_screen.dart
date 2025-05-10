import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fungiscan/application/identification/identification_bloc.dart';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:fungiscan/presentation/widgets/mushroom_card.dart';

class IdentificationScreen extends StatelessWidget {
  const IdentificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identify Mushroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showIdentificationHelp(context);
            },
          ),
        ],
      ),
      body: BlocConsumer<IdentificationBloc, IdentificationState>(
        listener: (context, state) {
          if (state.status == IdentificationStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image preview
                if (state.imageFile != null)
                  Container(
                    height: 300,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        state.imageFile!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 300,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[400]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Take or select a photo to identify',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Camera/Gallery buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          onPressed: () => _getImage(context, ImageSource.camera),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          onPressed: () => _getImage(context, ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Identification Results
                if (state.status == IdentificationStatus.loading)
                  const Center(
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Identifying mushroom...'),
                      ],
                    ),
                  )
                else if (state.status == IdentificationStatus.success && 
                        state.identifiedMushroom != null)
                  MushroomCard(
                    mushroom: state.identifiedMushroom!,
                    onSaveLocation: () {
                      // Save current location
                    },
                    onAskExpert: () {
                      _navigateToExpertChat(context, state.identifiedMushroom!);
                    },
                    onSave: () {
                      _saveToCollection(context, state.identifiedMushroom!);
                    },
                  ),
                
                const SizedBox(height: 24),
                
                // Additional options
                if (state.identifiedMushroom != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.error_outline),
                          label: const Text('Report Misidentification'),
                          onPressed: () {
                            _reportMisidentification(context);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (state.identifiedMushroom!.lookalikes.isNotEmpty)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.compare),
                            label: const Text('View Similar Species'),
                            onPressed: () {
                              _viewSimilarSpecies(context, state.identifiedMushroom!);
                            },
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Manual Search Option
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: () {
                      _showTraitBasedSearchDialog(context);
                    },
                    child: const Text('Search by Traits Instead'),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _getImage(BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    
    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);
      context.read<IdentificationBloc>().add(
        IdentifyMushroomEvent(imageFile: imageFile),
      );
    }
  }
  
  void _showIdentificationHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Identification Tips'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'For best results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Take clear, well-lit photos'),
              Text('• Capture multiple angles (top, gills, stem)'),
              Text('• Include the base/volva if possible'),
              Text('• Show the natural habitat'),
              Text('• Use the trait search for difficult species'),
              SizedBox(height: 16),
              Text(
                'IMPORTANT: Never consume a mushroom based solely on this app\'s identification.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  void _showTraitBasedSearchDialog(BuildContext context) {
    final List<String> colors = [
      'White', 'Yellow', 'Brown', 'Red', 'Black', 'Purple'
    ];
    final List<String> capShapes = [
      'Convex', 'Flat', 'Depressed', 'Conical', 'Bell-shaped'
    ];
    final List<String> gillTypes = [
      'Free', 'Attached', 'Decurrent', 'None (pores)'
    ];
    final List<String> habitats = [
      'Forest', 'Grassland', 'Urban', 'On wood', 'On dung'
    ];
    
    final selectedColors = <String>{};
    final selectedCapShapes = <String>{};
    final selectedGillTypes = <String>{};
    final selectedHabitats = <String>{};
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search by Traits',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Color section
                            const Text(
                              'Cap Color',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: colors.map((color) {
                                final isSelected = selectedColors.contains(color);
                                return FilterChip(
                                  label: Text(color),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedColors.add(color);
                                      } else {
                                        selectedColors.remove(color);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Cap Shape section
                            const Text(
                              'Cap Shape',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: capShapes.map((shape) {
                                final isSelected = selectedCapShapes.contains(shape);
                                return FilterChip(
                                  label: Text(shape),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedCapShapes.add(shape);
                                      } else {
                                        selectedCapShapes.remove(shape);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Gill Type section
                            const Text(
                              'Gill Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: gillTypes.map((type) {
                                final isSelected = selectedGillTypes.contains(type);
                                return FilterChip(
                                  label: Text(type),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedGillTypes.add(type);
                                      } else {
                                        selectedGillTypes.remove(type);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Habitat section
                            const Text(
                              'Habitat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: habitats.map((habitat) {
                                final isSelected = selectedHabitats.contains(habitat);
                                return FilterChip(
                                  label: Text(habitat),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        selectedHabitats.add(habitat);
                                      } else {
                                        selectedHabitats.remove(habitat);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            
                            // Combine all selected traits
                            final List<String> selectedTraits = [
                              ...selectedColors,
                              ...selectedCapShapes,
                              ...selectedGillTypes,
                              ...selectedHabitats,
                            ];
                            
                            // Dispatch search event
                            context.read<IdentificationBloc>().add(
                              SearchMushroomsByTraitsEvent(traits: selectedTraits),
                            );
                          },
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  void _navigateToExpertChat(BuildContext context, Mushroom mushroom) {
    // In a real implementation, this would navigate to an expert chat screen
    // with the identified mushroom details
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expert chat feature coming soon!'),
      ),
    );
  }
  
  void _saveToCollection(BuildContext context, Mushroom mushroom) {
    // In a real implementation, this would save the mushroom to the user's collection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mushroom.commonName} saved to your collection'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _reportMisidentification(BuildContext context) {
    // In a real implementation, this would open a form to report misidentification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Misidentification'),
        content: const Text(
          'Thank you for helping us improve! What do you think this mushroom actually is?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report submitted, thank you!'),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
  
  void _viewSimilarSpecies(BuildContext context, Mushroom mushroom) {
    // In a real implementation, this would navigate to a screen showing similar species
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Similar Species',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be careful! Some lookalikes can be dangerous.',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: mushroom.lookalikes.length,
                  itemBuilder: (context, index) {
                    final lookalike = mushroom.lookalikes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(lookalike.commonName),
                        subtitle: Text(
                          lookalike.scientificName,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getEdibilityColor(lookalike.edibility),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getEdibilityText(lookalike.edibility),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          // Show detailed comparison
                          Navigator.pop(context);
                          _showComparisonView(context, mushroom, lookalike);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showComparisonView(BuildContext context, Mushroom mushroom, LookalikeSpecies lookalike) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Side-by-Side Comparison'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          mushroom.commonName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _getEdibilityText(mushroom.edibility),
                          style: TextStyle(
                            color: _getEdibilityColor(mushroom.edibility),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          lookalike.commonName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _getEdibilityText(lookalike.edibility),
                          style: TextStyle(
                            color: _getEdibilityColor(lookalike.edibility),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Differences:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(lookalike.differentiationNotes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Color _getEdibilityColor(Edibility edibility) {
    switch (edibility) {
      case Edibility.edible:
        return Colors.green;
      case Edibility.inedible:
        return Colors.grey;
      case Edibility.poisonous:
        return Colors.red;
      case Edibility.psychoactive:
        return Colors.purple;
      case Edibility.unknown:
      default:
        return Colors.grey;
    }
  }
  
  String _getEdibilityText(Edibility edibility) {
    switch (edibility) {
      case Edibility.edible:
        return 'Edible';
      case Edibility.inedible:
        return 'Not Edible';
      case Edibility.poisonous:
        return 'Poisonous';
      case Edibility.psychoactive:
        return 'Psychoactive';
      case Edibility.unknown:
      default:
        return 'Unknown';
    }
  }
}
