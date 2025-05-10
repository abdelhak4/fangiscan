import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fungiscan/domain/models/mushroom_prediction.dart';
import 'package:fungiscan/domain/models/mushroom_trait.dart';
import 'package:logging/logging.dart';

/// Service responsible for handling mushroom identification using ML
class MLService {
  // Logger
  final _logger = Logger('MLService');

  // Model paths
  static const String _mushroomModelPath = 'assets/ml/mushroom_model.tflite';
  static const String _mushroomLabelsPath = 'assets/ml/mushroom_labels.txt';
  static const String _toxicityModelPath = 'assets/ml/toxicity_model.tflite';

  // Model instances
  late Interpreter _mushroomInterpreter;
  late Interpreter _toxicityInterpreter;
  List<String> _labels = [];

  // Model metadata
  final int _inputSize = 224; // Standard input size for MobileNet models
  final int _numChannels = 3; // RGB
  final int _numResults = 5; // Top 5 predictions

  /// Initialize and load ML models
  Future<void> loadModel() async {
    _logger.info('Loading ML models...');

    try {
      // Load main mushroom identification model
      final mushroomModelOptions = InterpreterOptions()..threads = 4;
      _mushroomInterpreter = await Interpreter.fromAsset(
        _mushroomModelPath,
        options: mushroomModelOptions,
      );
      _logger.info('Mushroom identification model loaded successfully');

      // Load toxicity classification model
      final toxicityModelOptions = InterpreterOptions()..threads = 2;
      _toxicityInterpreter = await Interpreter.fromAsset(
        _toxicityModelPath,
        options: toxicityModelOptions,
      );
      _logger.info('Toxicity classification model loaded successfully');

      // Load labels
      final labelsData = await rootBundle.loadString(_mushroomLabelsPath);
      _labels = labelsData.split('\n');
      _logger.info('${_labels.length} mushroom labels loaded successfully');
    } catch (e) {
      _logger.severe('Failed to load ML model: $e');
      // Create a fallback model for demo purposes if needed
      _createFallbackModel();
    }
  }

  /// Create a fallback model if the real model can't be loaded
  /// This allows the app to function in demo mode
  void _createFallbackModel() {
    _logger.warning('Creating fallback model for demo purposes');
    _labels = [
      'Amanita muscaria (Fly agaric)',
      'Cantharellus cibarius (Chanterelle)',
      'Boletus edulis (Porcini)',
      'Agaricus bisporus (Button mushroom)',
      'Morchella esculenta (Morel)',
      'Ganoderma lucidum (Reishi)',
      'Pleurotus ostreatus (Oyster mushroom)',
      'Laetiporus sulphureus (Chicken of the woods)',
      'Coprinus comatus (Shaggy ink cap)',
      'Amanita phalloides (Death cap)'
    ];
  }

  /// Process an image file for mushroom identification
  Future<List<MushroomPrediction>> identifyMushroom(File imageFile) async {
    _logger.info('Processing image for identification');

    try {
      // Load and process the image
      final imageData = await _processImageForInference(imageFile);

      // Create output tensor
      final outputShape = [1, _labels.length];
      final outputBuffer =
          List<double>.filled(outputShape.reduce((a, b) => a * b), 0);

      // Run inference
      _mushroomInterpreter.run(imageData, outputBuffer);

      // Process results
      final results = _processResults(outputBuffer.sublist(0, _labels.length));
      _logger.info('Identification completed successfully');
      return results;
    } catch (e) {
      _logger.severe('Error during mushroom identification: $e');
      // Return mock results if in demo mode
      return _getMockResults();
    }
  }

  /// Process image for model inference
  Future<List<double>> _processImageForInference(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // Resize and normalize
    final resizedImage = img.copyResize(
      decodedImage,
      width: _inputSize,
      height: _inputSize,
    );

    // Create a flat list for the input tensor
    final buffer =
        List<double>.filled(_inputSize * _inputSize * _numChannels, 0.0);
    int pixelIndex = 0;

    // Normalize pixel values between 0 and 1
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // Access RGB values directly via pixel properties
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        buffer[pixelIndex++] = r;
        buffer[pixelIndex++] = g;
        buffer[pixelIndex++] = b;
      }
    }

    return buffer;
  }

  /// Process model results into mushroom predictions
  List<MushroomPrediction> _processResults(List<double> outputs) {
    // Create list of label/score pairs
    final List<MapEntry<String, double>> labelScores = [];

    for (int i = 0; i < outputs.length && i < _labels.length; i++) {
      labelScores.add(MapEntry(_labels[i], outputs[i]));
    }

    // Sort by score in descending order
    labelScores.sort((a, b) => b.value.compareTo(a.value));

    // Convert to MushroomPrediction objects for the top results
    final predictions = <MushroomPrediction>[];

    for (int i = 0; i < _numResults && i < labelScores.length; i++) {
      final entry = labelScores[i];
      final prediction = MushroomPrediction(
        name: entry.key,
        scientificName: _extractScientificName(entry.key),
        confidence: entry.value,
        isToxic: _checkToxicity(entry.key),
        traits: _getTraitsForMushroom(entry.key),
        similarEdibleSpecies: _getSimilarEdible(entry.key),
        similarToxicSpecies: _getSimilarToxic(entry.key),
      );
      predictions.add(prediction);
    }

    return predictions;
  }

  /// Extract scientific name from label
  String _extractScientificName(String label) {
    final RegExp scientificNamePattern = RegExp(r'\((.*?)\)');
    final match = scientificNamePattern.firstMatch(label);
    return match != null ? match.group(1) ?? '' : '';
  }

  /// Determine toxicity of identified mushroom
  bool _checkToxicity(String mushroomName) {
    // In a real implementation, this would use the toxicity model
    // For now, we'll use a simple check against known toxic mushrooms
    final toxicMushrooms = [
      'Amanita phalloides',
      'Amanita muscaria',
      'Galerina marginata',
      'Gyromitra esculenta',
      'Omphalotus olearius'
    ];

    return toxicMushrooms.any(
        (toxic) => mushroomName.toLowerCase().contains(toxic.toLowerCase()));
  }

  /// Get traits for a specific mushroom
  List<MushroomTrait> _getTraitsForMushroom(String mushroomName) {
    // This would be replaced with a database lookup in production
    // For now, we'll return sample traits

    if (mushroomName.toLowerCase().contains('amanita')) {
      return [
        MushroomTrait(
            name: 'Cap', value: 'Convex to flat, bright red with white warts'),
        MushroomTrait(name: 'Gills', value: 'Free, white'),
        MushroomTrait(name: 'Stem', value: 'White with skirt, bulbous base'),
        MushroomTrait(
            name: 'Habitat', value: 'Mixed woodland, especially with birch'),
        MushroomTrait(name: 'Season', value: 'Summer to late autumn')
      ];
    }

    if (mushroomName.toLowerCase().contains('cantharellus')) {
      return [
        MushroomTrait(name: 'Cap', value: 'Yellow to orange, funnel-shaped'),
        MushroomTrait(name: 'Gills', value: 'False gills, forked ridges'),
        MushroomTrait(name: 'Stem', value: 'Same color as cap, tapers down'),
        MushroomTrait(
            name: 'Habitat', value: 'Mixed woodland, often near oak, beech'),
        MushroomTrait(name: 'Season', value: 'Summer to late autumn')
      ];
    }

    // Default traits
    return [
      MushroomTrait(name: 'Cap', value: 'Variable'),
      MushroomTrait(name: 'Gills', value: 'Present'),
      MushroomTrait(name: 'Stem', value: 'Present'),
      MushroomTrait(name: 'Habitat', value: 'Various woodland environments'),
      MushroomTrait(name: 'Season', value: 'Depends on species and region')
    ];
  }

  /// Get similar edible species for comparison
  String _getSimilarEdible(String mushroomName) {
    // This would be replaced with a database lookup
    if (mushroomName.toLowerCase().contains('amanita')) {
      return 'Amanita caesarea (Caesar\'s mushroom)';
    }

    if (mushroomName.toLowerCase().contains('cantharellus')) {
      return 'No dangerous lookalikes with proper identification';
    }

    return 'Always consult an expert for positive identification';
  }

  /// Get similar toxic species for warning
  String _getSimilarToxic(String mushroomName) {
    // This would be replaced with a database lookup
    if (mushroomName.toLowerCase().contains('cantharellus')) {
      return 'Omphalotus olearius (Jack-o\'lantern mushroom)';
    }

    if (mushroomName.toLowerCase().contains('boletus edulis')) {
      return 'Boletus satanas (Satan\'s bolete)';
    }

    return 'Several toxic lookalikes may exist; always verify identification';
  }

  /// For demo purposes - return mock results if model loading fails
  List<MushroomPrediction> _getMockResults() {
    return [
      MushroomPrediction(
        name: 'Cantharellus cibarius (Chanterelle)',
        scientificName: 'Chanterelle',
        confidence: 0.92,
        isToxic: false,
        traits: [
          MushroomTrait(name: 'Cap', value: 'Yellow to orange, funnel-shaped'),
          MushroomTrait(name: 'Gills', value: 'False gills, forked ridges'),
          MushroomTrait(name: 'Stem', value: 'Same color as cap, tapers down'),
          MushroomTrait(
              name: 'Habitat', value: 'Mixed woodland, often near oak, beech'),
          MushroomTrait(name: 'Season', value: 'Summer to late autumn')
        ],
        similarEdibleSpecies:
            'No dangerous lookalikes with proper identification',
        similarToxicSpecies: 'Omphalotus olearius (Jack-o\'lantern mushroom)',
      ),
      MushroomPrediction(
        name: 'Amanita muscaria (Fly agaric)',
        scientificName: 'Fly agaric',
        confidence: 0.85,
        isToxic: true,
        traits: [
          MushroomTrait(
              name: 'Cap',
              value: 'Convex to flat, bright red with white warts'),
          MushroomTrait(name: 'Gills', value: 'Free, white'),
          MushroomTrait(name: 'Stem', value: 'White with skirt, bulbous base'),
          MushroomTrait(
              name: 'Habitat', value: 'Mixed woodland, especially with birch'),
          MushroomTrait(name: 'Season', value: 'Summer to late autumn')
        ],
        similarEdibleSpecies: 'Amanita caesarea (Caesar\'s mushroom)',
        similarToxicSpecies: 'Other Amanita species including death cap',
      ),
    ];
  }

  /// Search mushrooms by traits
  Future<List<MushroomPrediction>> searchByTraits(
      Map<String, String> traits) async {
    _logger.info('Searching mushrooms by traits: $traits');

    // In a real app, this would search a local database of mushrooms
    // For demo purposes, we'll return mock results

    // Check color trait
    if (traits['color']?.toLowerCase() == 'yellow') {
      return [
        MushroomPrediction(
          name: 'Cantharellus cibarius (Chanterelle)',
          scientificName: 'Chanterelle',
          confidence: 0.95,
          isToxic: false,
          traits: [
            MushroomTrait(
                name: 'Cap', value: 'Yellow to orange, funnel-shaped'),
            MushroomTrait(name: 'Gills', value: 'False gills, forked ridges'),
            MushroomTrait(
                name: 'Stem', value: 'Same color as cap, tapers down'),
            MushroomTrait(
                name: 'Habitat',
                value: 'Mixed woodland, often near oak, beech'),
            MushroomTrait(name: 'Season', value: 'Summer to late autumn')
          ],
          similarEdibleSpecies:
              'No dangerous lookalikes with proper identification',
          similarToxicSpecies: 'Omphalotus olearius (Jack-o\'lantern mushroom)',
        ),
      ];
    }

    if (traits['color']?.toLowerCase() == 'red') {
      return [
        MushroomPrediction(
          name: 'Amanita muscaria (Fly agaric)',
          scientificName: 'Fly agaric',
          confidence: 0.90,
          isToxic: true,
          traits: [
            MushroomTrait(
                name: 'Cap',
                value: 'Convex to flat, bright red with white warts'),
            MushroomTrait(name: 'Gills', value: 'Free, white'),
            MushroomTrait(
                name: 'Stem', value: 'White with skirt, bulbous base'),
            MushroomTrait(
                name: 'Habitat',
                value: 'Mixed woodland, especially with birch'),
            MushroomTrait(name: 'Season', value: 'Summer to late autumn')
          ],
          similarEdibleSpecies: 'Amanita caesarea (Caesar\'s mushroom)',
          similarToxicSpecies: 'Other Amanita species including death cap',
        ),
      ];
    }

    // Default response
    return _getMockResults();
  }

  /// Clean up resources when service is disposed
  void dispose() {
    _logger.info('Disposing ML models');
    _mushroomInterpreter.close();
    _toxicityInterpreter.close();
  }
}
