import 'package:flutter/material.dart';
import 'package:fungiscan/domain/models/mushroom.dart';

class MushroomCard extends StatelessWidget {
  final Mushroom mushroom;
  final VoidCallback onSaveLocation;
  final VoidCallback onAskExpert;
  final VoidCallback onSave;

  const MushroomCard({
    Key? key,
    required this.mushroom,
    required this.onSaveLocation,
    required this.onAskExpert,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (mushroom.confidence * 100).toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with confidence score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getEdibilityColor(mushroom.edibility).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mushroom.commonName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        mushroom.scientificName,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(mushroom.confidence),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$confidencePercent% Match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Edibility & Safety
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getEdibilityColor(mushroom.edibility),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getEdibilityIcon(mushroom.edibility),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getEdibilityText(mushroom.edibility),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(mushroom.description),
                
                const SizedBox(height: 16),
                
                // Habitat
                const Text(
                  'Habitat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(mushroom.habitat),
                
                const SizedBox(height: 16),
                
                // Traits/Characteristics
                const Text(
                  'Characteristics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mushroom.traits.map((trait) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        trait,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Seasons
                const Text(
                  'Seasons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSeasonsIndicator(mushroom.seasons),
                
                const SizedBox(height: 16),
                
                // Lookalikes
                if (mushroom.lookalikes.isNotEmpty) ...[
                  const Text(
                    'Similar Species',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: mushroom.lookalikes.map((lookalike) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getEdibilityColor(lookalike.edibility),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(lookalike.commonName),
                        subtitle: Text(
                          lookalike.scientificName,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          _showLookalikeDetails(context, lookalike);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Warning for dangerous mushrooms
                if (mushroom.edibility == Edibility.poisonous) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'WARNING: Poisonous Species',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'This mushroom is toxic and should not be consumed. Always verify with an expert.',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.map,
                      label: 'Save Location',
                      onTap: onSaveLocation,
                    ),
                    _buildActionButton(
                      icon: Icons.chat,
                      label: 'Ask Expert',
                      onTap: onAskExpert,
                    ),
                    _buildActionButton(
                      icon: Icons.bookmark_border,
                      label: 'Save',
                      onTap: onSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 12,
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeasonsIndicator(List<String> seasons) {
    final allSeasons = ['Spring', 'Summer', 'Fall', 'Winter'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: allSeasons.map((season) {
        final isActive = seasons.contains(season);
        return Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive
                    ? _getSeasonColor(season)
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getSeasonEmoji(season),
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              season,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? _getSeasonColor(season) : Colors.grey,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
  
  void _showLookalikeDetails(BuildContext context, LookalikeSpecies lookalike) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lookalike.commonName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lookalike.scientificName,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getEdibilityColor(lookalike.edibility),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getEdibilityText(lookalike.edibility),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'How to Differentiate:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
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
  
  IconData _getEdibilityIcon(Edibility edibility) {
    switch (edibility) {
      case Edibility.edible:
        return Icons.check_circle;
      case Edibility.inedible:
        return Icons.not_interested;
      case Edibility.poisonous:
        return Icons.warning;
      case Edibility.psychoactive:
        return Icons.psychology;
      case Edibility.unknown:
      default:
        return Icons.help;
    }
  }
  
  String _getEdibilityText(Edibility edibility) {
    switch (edibility) {
      case Edibility.edible:
        return 'Edible';
      case Edibility.inedible:
        return 'Not Edible';
      case Edibility.poisonous:
        return 'Poisonous - DO NOT EAT';
      case Edibility.psychoactive:
        return 'Psychoactive';
      case Edibility.unknown:
      default:
        return 'Edibility Unknown';
    }
  }
  
  Color _getSeasonColor(String season) {
    switch (season) {
      case 'Spring':
        return Colors.green[300]!;
      case 'Summer':
        return Colors.orange[300]!;
      case 'Fall':
        return Colors.brown[300]!;
      case 'Winter':
        return Colors.blue[300]!;
      default:
        return Colors.grey;
    }
  }
  
  String _getSeasonEmoji(String season) {
    switch (season) {
      case 'Spring':
        return '🌱';
      case 'Summer':
        return '☀️';
      case 'Fall':
        return '🍂';
      case 'Winter':
        return '❄️';
      default:
        return '🍄';
    }
  }
}
