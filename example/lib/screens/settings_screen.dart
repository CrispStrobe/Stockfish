import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int opponentSkillLevel;
  final int hintSkillLevel;
  
  const SettingsScreen({
    Key? key, 
    required this.opponentSkillLevel,
    required this.hintSkillLevel,
  }) : super(key: key);
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _opponentSkillLevel;
  late int _hintSkillLevel;
  bool _showValidMoves = true;
  bool _animateMoves = true;
  
  @override
  void initState() {
    super.initState();
    _opponentSkillLevel = widget.opponentSkillLevel;
    _hintSkillLevel = widget.hintSkillLevel;
  }
  
  String getDifficultyLabel(int level) {
    if (level <= 5) return 'Beginner';
    if (level <= 10) return 'Intermediate';
    if (level <= 15) return 'Advanced';
    return 'Expert';
  }
  
  Color getColorForSkill(int level) {
    if (level <= 5) return Colors.green;
    if (level <= 10) return Colors.orange;
    if (level <= 15) return Colors.red;
    return Colors.purple;
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
            'Opponent Strength',
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
                        'Level: $_opponentSkillLevel',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(getDifficultyLabel(_opponentSkillLevel)),
                        backgroundColor: getColorForSkill(_opponentSkillLevel),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _opponentSkillLevel.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: _opponentSkillLevel.toString(),
                    onChanged: (value) {
                      setState(() => _opponentSkillLevel = value.round());
                    },
                  ),
                  Text(
                    'This controls how strong Stockfish plays against you',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          Text(
            'Hint System Strength',
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
                        'Level: $_hintSkillLevel',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(getDifficultyLabel(_hintSkillLevel)),
                        backgroundColor: getColorForSkill(_hintSkillLevel),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _hintSkillLevel.toDouble(),
                    min: 5,
                    max: 20,
                    divisions: 15,
                    label: _hintSkillLevel.toString(),
                    onChanged: (value) {
                      setState(() => _hintSkillLevel = value.round());
                    },
                  ),
                  Text(
                    'Higher levels give better hints (recommended: 15-20)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          Text(
            'Visual Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Show Valid Moves'),
                  subtitle: Text('Highlight legal moves when selecting a piece'),
                  value: _showValidMoves,
                  onChanged: (value) {
                    setState(() => _showValidMoves = value);
                  },
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text('Animate Moves'),
                  subtitle: Text('Smooth piece movement animation'),
                  value: _animateMoves,
                  onChanged: (value) {
                    setState(() => _animateMoves = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, {
            'opponent': _opponentSkillLevel,
            'hint': _hintSkillLevel,
            'showValidMoves': _showValidMoves,
            'animateMoves': _animateMoves,
          });
        },
        icon: Icon(Icons.check),
        label: Text('Save'),
      ),
    );
  }
}