import 'package:flutter/material.dart';
import 'package:fungiscan/domain/models/mushroom.dart';
import 'package:fungiscan/infrastructure/services/ml_service.dart';
import 'package:fungiscan/presentation/widgets/app_drawer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MLService _mlService = MLService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Saved'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildSavedTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    // For web demonstration, we'll display a static mockup instead of using BlocBuilder
    // This avoids the need to initialize all the bloc machinery for the web preview
    
    // Show empty state for now
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No identification history yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Start identifying mushrooms to build your history',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSavedTab() {
    // This is a simplified mock of saved locations
    final savedLocations = [
      SavedLocation(
        id: '1',
        name: 'Oak Forest Trail',
        notes: 'Great spot for chanterelles in autumn',
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
        coordinates: const LatLng(37.7749, -122.4194),
        species: ['Chanterelle', 'Oyster Mushroom'],
      ),
      SavedLocation(
        id: '2',
        name: 'Pine Ridge',
        notes: 'Found porcini here after rain',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        coordinates: const LatLng(37.7749, -122.4194),
        species: ['Porcini', 'Morel'],
      ),
    ];
    
    if (savedLocations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved locations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Save foraging spots to track your favorite locations',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: savedLocations.length,
      itemBuilder: (context, index) {
        final location = savedLocations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.forest, color: Colors.white),
            ),
            title: Text(location.name),
            subtitle: Text(
              '${location.timestamp.day}/${location.timestamp.month}/${location.timestamp.year} - ${location.species.join(", ")}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to detailed view
            },
          ),
        );
      },
    );
  }
  
  Widget _buildSettingsTab() {
    return ListView(
      children: [
        _buildSettingsSection('Privacy Settings', [
          _buildSwitchSetting(
            'Privacy Mode',
            'Hide location data and personal information',
            true,
            (value) {
              // Update privacy setting
            },
          ),
          _buildSwitchSetting(
            'Share Statistics',
            'Contribute anonymous identification data for research',
            false,
            (value) {
              // Update statistics sharing setting
            },
          ),
        ]),
        _buildSettingsSection('Appearance', [
          _buildSwitchSetting(
            'Dark Mode',
            'Use dark theme throughout the app',
            Theme.of(context).brightness == Brightness.dark,
            (value) {
              // Update theme setting
            },
          ),
        ]),
        _buildSettingsSection('Units', [
          _buildRadioSetting(
            'Measurement Units',
            'Choose your preferred units',
            'metric',
            {
              'metric': 'Metric (km, m)',
              'imperial': 'Imperial (mi, ft)',
            },
            (value) {
              // Update units setting
            },
          ),
        ]),
        _buildSettingsSection('Data Management', [
          _buildSliderSetting(
            'Cache Duration',
            'How long to keep offline data (days)',
            30,
            7,
            90,
            5,
            (value) {
              // Update cache duration setting
            },
          ),
          _buildActionSetting(
            'Clear Cache',
            'Delete temporarily stored data',
            Icons.delete_outline,
            () async {
              // Show confirmation dialog then clear cache
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Cache?'),
                  content: const Text('This will delete all temporarily stored data but won\'t affect your saved locations or identification history.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                // Clear cache
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              }
            },
          ),
          _buildActionSetting(
            'Delete All Data',
            'Permanently remove all your data',
            Icons.delete_forever,
            () async {
              // Show confirmation dialog then delete data
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete All Data?'),
                  content: const Text('This will permanently delete all your saved locations, identification history, and preferences. This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('DELETE'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                // Delete all data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data deleted')),
                );
              }
            },
          ),
        ]),
        _buildSettingsSection('About', [
          _buildInfoSetting(
            'App Version',
            '1.0.0',
          ),
          _buildActionSetting(
            'Terms of Service',
            'View terms and conditions',
            Icons.description_outlined,
            () {
              // Show terms of service
            },
          ),
          _buildActionSetting(
            'Privacy Policy',
            'View our privacy policy',
            Icons.privacy_tip_outlined,
            () {
              // Show privacy policy
            },
          ),
        ]),
      ],
    );
  }
  
  Widget _buildSimpleActivitySection() {
    // This is a simplified activity chart as a placeholder
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActivityStat('12', 'Identifications'),
              _buildActivityStat('5', 'Species'),
              _buildActivityStat('3', 'Locations'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Most active month: May',
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return Colors.green.shade100;
    } else if (confidence >= 0.7) {
      return Colors.amber.shade100;
    } else {
      return Colors.red.shade100;
    }
  }
  
  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
  
  Widget _buildSwitchSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
  
  Widget _buildRadioSetting(
    String title,
    String subtitle,
    String currentValue,
    Map<String, String> options,
    Function(String?) onChanged,
  ) {
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(subtitle),
      children: options.entries.map((entry) {
        return RadioListTile<String>(
          title: Text(entry.value),
          value: entry.key,
          groupValue: currentValue,
          onChanged: onChanged,
        );
      }).toList(),
    );
  }
  
  Widget _buildSliderSetting(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    double divisions,
    Function(double) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions.toInt(),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(min.toInt().toString()),
                Text(max.toInt().toString()),
              ],
            ),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
  
  Widget _buildActionSetting(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(icon),
      onTap: onTap,
    );
  }
  
  Widget _buildInfoSetting(
    String title,
    String value,
  ) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

// A simple class for the activity data
class ActivityData {
  final String month;
  final int count;
  
  ActivityData(this.month, this.count);
}

// Helper extension for default location
extension LatLngExtension on Object {
  static const LatLng defaultLocation = LatLng(37.7749, -122.4194);
}