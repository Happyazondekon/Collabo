enum GameDifficulty {
  easy,    // 40% des lettres visibles
  normal,  // 30% des lettres visibles (actuel)
  expert   // Seulement la première lettre visible
}

class DifficultyHelper {
  static String getName(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 'Facile';
      case GameDifficulty.normal:
        return 'Normal';
      case GameDifficulty.expert:
        return 'Expert';
    }
  }

  static double getRevealPercentage(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 0.4;  // 40% des lettres visibles
      case GameDifficulty.normal:
        return 0.3;  // 30% des lettres visibles
      case GameDifficulty.expert:
        return 0.0;  // Seulement la première lettre (gérée différemment)
    }
  }
}