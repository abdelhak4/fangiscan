import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Service for handling machine learning operations
/// This is a web-compatible version for development purposes
class MLService {
  static const String MODEL_PATH = 'assets/ml/mushroom_model.tflite';
  static const String LABELS_PATH = 'assets/ml/mushroom_labels.txt';
  
  bool _isInitialized = false;
  final Random _random = Random();
  
  // Sample mushroom data for development/testing
  final List<Map<String, dynamic>> _sampleMushrooms = [
    {
      'commonName': 'Chanterelle',
      'scientificName': 'Cantharellus cibarius',
      'confidence': 0.92,
      'edibility': 'Edible',
      'description': 'Funnel-shaped with a wavy cap, often yellow to orange, and has false gills that are forked and run down the stem.',
      'habitat': 'Forests, especially under oak and pine trees',
      'season': 'Summer to fall',
      'lookalikes': ['False Chanterelle (Hygrophoropsis aurantiaca)'],
      'toxicity': 'None',
      'traits': ['Yellow', 'Funnel-shaped', 'Forked gills', 'No distinct cap']
    },
    {
      'commonName': 'Oyster Mushroom',
      'scientificName': 'Pleurotus ostreatus',
      'confidence': 0.88,
      'edibility': 'Edible',
      'description': 'Shell or fan-shaped caps with short or absent stems. Usually white to light gray or tan.',
      'habitat': 'Grows on dead or dying hardwood trees',
      'season': 'Spring, fall, winter',
      'lookalikes': ['Angel Wings (Pleurocybella porrigens)'],
      'toxicity': 'None',
      'traits': ['Shell-shaped', 'Grows on wood', 'Whitish', 'Decurrent gills']
    },
    {
      'commonName': 'Shiitake',
      'scientificName': 'Lentinula edodes',
      'confidence': 0.85,
      'edibility': 'Edible',
      'description': 'Brown cap with curved edges and cream-colored gills. Stems are fibrous.',
      'habitat': 'Grown commercially on hardwood logs',
      'season': 'Year-round (cultivated)',
      'lookalikes': ['None significant'],
      'toxicity': 'None',
      'traits': ['Brown cap', 'White gills', 'Grows on wood', 'Curved cap edge']
    },
    {
      'commonName': 'Button Mushroom',
      'scientificName': 'Agaricus bisporus',
      'confidence': 0.95,
      'edibility': 'Edible',
      'description': 'Smooth, rounded cap that starts white and turns brown with age. Pink gills that darken over time.',
      'habitat': 'Grasslands, meadows, cultivated commercially',
      'season': 'Year-round (cultivated)',
      'lookalikes': ['False parasol (Chlorophyllum molybdites)'],
      'toxicity': 'None',
      'traits': ['White cap', 'Pink to brown gills', 'Ring on stem', 'Round cap']
    },
    {
      'commonName': 'Porcini',
      'scientificName': 'Boletus edulis',
      'confidence': 0.84,
      'edibility': 'Edible (choice)',
      'description': 'Reddish-brown cap with white pores underneath instead of gills. Thick stem often with a bulbous base.',
      'habitat': 'Mixed forests, especially with pine, oak, and spruce',
      'season': 'Summer to fall',
      'lookalikes': ['Bitter Bolete (Tylopilus felleus)'],
      'toxicity': 'None',
      'traits': ['Brown cap', 'Bulbous stem', 'Pores not gills', 'Not bruising blue']
    },
    {
      'commonName': 'Death Cap',
      'scientificName': 'Amanita phalloides',
      'confidence': 0.91,
      'edibility': 'Deadly poisonous',
      'description': 'Pale green to yellow cap with white gills. Has a sack-like volva at the base of the stem and a skirt-like ring.',
      'habitat': 'Forests, especially near oak trees',
      'season': 'Summer to fall',
      'lookalikes': ['Paddy Straw Mushroom (Volvariella volvacea)', 'Button mushrooms'],
      'toxicity': 'Deadly - contains amatoxins that cause liver failure',
      'traits': ['White gills', 'Greenish cap', 'Ring on stem', 'Volva at base', 'Cup at base']
    },
    {
      'commonName': 'Morel',
      'scientificName': 'Morchella esculenta',
      'confidence': 0.89,
      'edibility': 'Edible (cook thoroughly)',
      'description': 'Distinctive honeycomb pattern on a hollow cap. Tan to dark brown with a whitish stem.',
      'habitat': 'Forests, especially after fires or in disturbed areas',
      'season': 'Spring',
      'lookalikes': ['False Morel (Gyromitra species)'],
      'toxicity': 'None when cooked',
      'traits': ['Honeycomb cap', 'Hollow stem', 'Hollow cap', 'Attached at bottom of cap']
    },
  ];
  
  /// Initialize the service
  Future<void> loadModel() async {
    // For web demo, we just simulate loading a model
    await Future.delayed(const Duration(seconds: 1));
    _isInitialized = true;
    print('ML service initialized for web demo');
    return;
  }
  
  /// Process an image and return simulated mushroom identification results
  /// Accepts both File and Uint8List to work on web and mobile
  Future<Map<String, dynamic>> identifyMushroom(dynamic imageInput) async {
    if (!_isInitialized) {
      await loadModel();
    }
    
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      // Select random sample mushroom as top result
      final topIndex = _random.nextInt(_sampleMushrooms.length);
      final topResult = _sampleMushrooms[topIndex];
      
      // Create list of alternative results (exclude top result)
      final alternatives = <Map<String, dynamic>>[];
      final usedIndices = <int>{topIndex};
      
      // Add 2 alternatives
      for (int i = 0; i < 2; i++) {
        int altIndex;
        do {
          altIndex = _random.nextInt(_sampleMushrooms.length);
        } while (usedIndices.contains(altIndex));
        
        usedIndices.add(altIndex);
        final confidence = 0.5 + _random.nextDouble() * 0.3; // Between 0.5 and 0.8
        
        alternatives.add({
          'label': _sampleMushrooms[altIndex]['commonName'],
          'confidence': confidence,
        });
      }
      
      // Sort alternatives by confidence
      alternatives.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
      
      // Create a list of sample scores for raw output
      final rawScores = List<double>.generate(
        _sampleMushrooms.length,
        (i) => usedIndices.contains(i) 
            ? _sampleMushrooms[i]['confidence'] as double
            : _random.nextDouble() * 0.5
      );
      
      return {
        'topResult': {
          'label': topResult['commonName'],
          'scientificName': topResult['scientificName'],
          'confidence': topResult['confidence'],
          'edibility': topResult['edibility'],
          'description': topResult['description'],
          'habitat': topResult['habitat'],
          'season': topResult['season'],
          'lookalikes': topResult['lookalikes'],
          'toxicity': topResult['toxicity'],
          'traits': topResult['traits'],
        },
        'top3Results': [
          {
            'label': topResult['commonName'],
            'scientificName': topResult['scientificName'],
            'confidence': topResult['confidence'],
          },
          ...alternatives,
        ],
        'rawScores': rawScores,
      };
    } catch (e) {
      print('Error in mushroom identification: $e');
      rethrow;
    }
  }
  
  /// Check if a file is an image
  bool isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }
  
  /// Create a temporary file from an asset for testing
  Future<dynamic> getImageFromAssets(String assetPath) async {
    if (kIsWeb) {
      // For web, return the byte data directly
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes, 
        byteData.lengthInBytes
      );
    } else {
      // For mobile, create a file
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${assetPath.split('/').last}');
      await file.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes, 
        byteData.lengthInBytes
      ));
      return file;
    }
  }
  
  /// Clean up resources
  void dispose() {
    _isInitialized = false;
  }
}