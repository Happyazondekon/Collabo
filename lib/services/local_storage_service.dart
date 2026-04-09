import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_session_model.dart';
import '../models/achievement_model.dart';

/// Local storage service — Firestore will be layered on top.
class LocalStorageService {
  static const _sessionsKey = 'game_sessions';
  static const _achievementsKey = 'achievements';
  static const _statsKey = 'player_stats';
  static const _customWordsKey = 'custom_words';

  // ─── Game Sessions ────────────────────────────────────────────────

  Future<List<GameSessionModel>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list
          .map((e) => GameSessionModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    } catch (e) {
      if (kDebugMode) print('Error loading sessions: $e');
      return [];
    }
  }

  Future<void> saveSession(GameSessionModel session) async {
    final sessions = await getSessions();
    sessions.insert(0, session);
    // Keep max 200 sessions
    final trimmed = sessions.take(200).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionsKey, json.encode(trimmed.map((s) => s.toJson()).toList()));
    await _updateStats(session);
  }

  // ─── Stats ────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) {
      return {
        'gamesPlayed': 0,
        'wordsGuessed': 0,
        'coopGames': 0,
        'memories': 0,
        'whatsappImports': 0,
        'streak': 0,
        'totalScore': 0,
      };
    }
    return Map<String, int>.from(json.decode(raw) as Map);
  }

  Future<void> incrementStat(String key, [int amount = 1]) async {
    final stats = await getStats();
    stats[key] = (stats[key] ?? 0) + amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats));
  }

  Future<void> _updateStats(GameSessionModel session) async {
    final stats = await getStats();
    stats['gamesPlayed'] = (stats['gamesPlayed'] ?? 0) + 1;
    stats['wordsGuessed'] = (stats['wordsGuessed'] ?? 0) + session.wordsGuessed;
    if (session.mode == 'cooperatif') {
      stats['coopGames'] = (stats['coopGames'] ?? 0) + 1;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats));
  }

  // ─── Achievements ─────────────────────────────────────────────────

  Future<List<AchievementModel>> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_achievementsKey);
    final defaults = AchievementModel.defaultAchievements();
    if (raw == null) return defaults;
    try {
      final savedMap = Map<String, dynamic>.from(json.decode(raw) as Map);
      return defaults.map((a) {
        final saved = savedMap[a.id];
        if (saved == null) return a;
        return AchievementModel.fromJson(a, saved as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      return defaults;
    }
  }

  Future<List<AchievementModel>> checkAndUpdateAchievements() async {
    final stats = await getStats();
    final achievements = await getAchievements();
    final newlyUnlocked = <AchievementModel>[];

    for (final ach in achievements) {
      if (ach.isUnlocked) continue;
      final val = stats[ach.statKey] ?? 0;
      ach.currentValue = val;
      if (val >= ach.targetValue) {
        ach.isUnlocked = true;
        ach.unlockedAt = DateTime.now();
        newlyUnlocked.add(ach);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final toSave = {for (var a in achievements) a.id: a.toJson()};
    await prefs.setString(_achievementsKey, json.encode(toSave));
    return newlyUnlocked;
  }

  // ─── Custom Words ─────────────────────────────────────────────────

  Future<List<String>> getCustomWords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customWordsKey);
    if (raw == null) return [];
    return List<String>.from(json.decode(raw) as List);
  }

  Future<void> saveCustomWords(List<String> words) async {
    final existing = await getCustomWords();
    final merged = {...existing, ...words}.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customWordsKey, json.encode(merged));
    await incrementStat('whatsappImports');
  }

  Future<void> clearCustomWords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customWordsKey);
  }
}
