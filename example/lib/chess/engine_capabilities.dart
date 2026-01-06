class EngineCapabilities {
  bool supportsSkillLevel = false;
  bool supportsUciElo = false;
  bool supportsUciLimitStrength = false;
  
  int minElo = 1320;  // Stockfish default
  int maxElo = 3190;  // Stockfish default
  
  Map<String, String> allOptions = {};
  
  bool get canLimitStrength => supportsSkillLevel || supportsUciElo;
  
  @override
  String toString() {
    return 'EngineCapabilities(\n'
        '  Skill Level: $supportsSkillLevel\n'
        '  UCI_Elo: $supportsUciElo (range: $minElo-$maxElo)\n'
        '  UCI_LimitStrength: $supportsUciLimitStrength\n'
        ')';
  }
}

class StrengthSettings {
  final int skillLevel;      // 0-20
  final int targetElo;       // 800-2800
  final int searchDepth;     // 1-25
  final int moveTime;        // milliseconds (optional)
  
  StrengthSettings({
    required this.skillLevel,
    required this.targetElo,
    required this.searchDepth,
    this.moveTime = 0,
  });
  
  factory StrengthSettings.fromLevel(int level) {
    // Map 0-20 to comprehensive settings
    // Level 0 = 800 ELO, depth 3
    // Level 10 = 1400 ELO, depth 10
    // Level 20 = 2400 ELO, depth 20
    
    final elo = 800 + (level * 80).clamp(0, 1600);
    final depth = 3 + level;  // 3-23
    
    return StrengthSettings(
      skillLevel: level,
      targetElo: elo,
      searchDepth: depth,
    );
  }
  
  @override
  String toString() {
    return 'StrengthSettings(level: $skillLevel, elo: $targetElo, depth: $searchDepth)';
  }
}