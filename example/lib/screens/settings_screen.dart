import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int skillLevel;
  
  const SettingsScreen({Key? key, required this.skillLevel}) : super(key: key);
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _skillLevel;
  
  @override
  void initState() {
    super.initState();
    _skillLevel = widget.skillLevel;
  }
  
  String get difficultyLabel {
    if (_skillLevel <= 5) return 'Beginner';
    if (_skillLevel <= 10) return 'Intermediate';
    if (_skillLevel <= 15) return 'Advanced';
    return 'Expert';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Difficulty / Playing Strength',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Skill Level: $_skillLevel',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(difficultyLabel),
                        backgroundColor: _getColorForSkill(),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _skillLevel.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: _skillLevel.toString(),
                    onChanged: (value) {
                      setState(() => _skillLevel = value.round());
                    },
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lower = Easier, Higher = Harder',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Stockfish',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Stockfish is one of the strongest chess engines in the world. '
                    'Skill level controls how strong the engine plays:\n\n'
                    '• 0-5: Good for beginners\n'
                    '• 6-10: Intermediate players\n'
                    '• 11-15: Advanced players\n'
                    '• 16-20: Expert/Master level',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _skillLevel),
        icon: Icon(Icons.check),
        label: Text('Save'),
      ),
    );
  }
  
  Color _getColorForSkill() {
    if (_skillLevel <= 5) return Colors.green;
    if (_skillLevel <= 10) return Colors.orange;
    if (_skillLevel <= 15) return Colors.red;
    return Colors.purple;
  }
}