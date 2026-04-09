import 'package:flutter/material.dart';

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int targetValue; // threshold to unlock
  final String statKey;  // which stat this tracks
  bool isUnlocked;
  int currentValue;
  DateTime? unlockedAt;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetValue,
    required this.statKey,
    this.isUnlocked = false,
    this.currentValue = 0,
    this.unlockedAt,
  });

  double get progress =>
      (currentValue / targetValue).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUnlocked': isUnlocked,
    'currentValue': currentValue,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory AchievementModel.fromJson(
      AchievementModel base, Map<String, dynamic> json) {
    return AchievementModel(
      id: base.id,
      title: base.title,
      description: base.description,
      icon: base.icon,
      color: base.color,
      targetValue: base.targetValue,
      statKey: base.statKey,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      currentValue: json['currentValue'] as int? ?? 0,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }

  static List<AchievementModel> defaultAchievements() => [
    AchievementModel(
      id: 'first_game',
      title: 'Premier Pas',
      description: 'Jouez votre première partie',
      icon: Icons.sports_esports_rounded,
      color: const Color(0xFFF59E0B),
      targetValue: 1,
      statKey: 'gamesPlayed',
    ),
    AchievementModel(
      id: 'games_10',
      title: 'Joueurs Assidus',
      description: 'Jouez 10 parties ensemble',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFEF4444),
      targetValue: 10,
      statKey: 'gamesPlayed',
    ),
    AchievementModel(
      id: 'games_50',
      title: 'Passionnés',
      description: 'Jouez 50 parties ensemble',
      icon: Icons.diamond_rounded,
      color: const Color(0xFF8B5CF6),
      targetValue: 50,
      statKey: 'gamesPlayed',
    ),
    AchievementModel(
      id: 'words_20',
      title: 'Vocabulaire Commun',
      description: 'Devinez 20 mots en tout',
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF3B82F6),
      targetValue: 20,
      statKey: 'wordsGuessed',
    ),
    AchievementModel(
      id: 'words_100',
      title: 'Bibliothèque Couple',
      description: 'Devinez 100 mots en tout',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF10B981),
      targetValue: 100,
      statKey: 'wordsGuessed',
    ),
    AchievementModel(
      id: 'coop_win',
      title: 'Équipe Unie',
      description: 'Terminez une partie coopérative',
      icon: Icons.handshake_rounded,
      color: const Color(0xFF06B6D4),
      targetValue: 1,
      statKey: 'coopGames',
    ),
    AchievementModel(
      id: 'calendar_5',
      title: 'Mémoire du Cœur',
      description: 'Ajoutez 5 souvenirs au calendrier',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFD0216E),
      targetValue: 5,
      statKey: 'memories',
    ),
    AchievementModel(
      id: 'streak_7',
      title: 'Amour Constant',
      description: 'Jouez 7 jours de suite',
      icon: Icons.local_florist_rounded,
      color: const Color(0xFFEC4899),
      targetValue: 7,
      statKey: 'streak',
    ),
    AchievementModel(
      id: 'whatsapp',
      title: 'Notre Langage',
      description: 'Importez vos conversations WhatsApp',
      icon: Icons.chat_rounded,
      color: const Color(0xFF25D366),
      targetValue: 1,
      statKey: 'whatsappImports',
    ),
  ];
}
