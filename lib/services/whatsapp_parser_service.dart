import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parses a WhatsApp exported chat file (.txt) and extracts meaningful words.
class WhatsAppParserService {
  // Common French/English stop words to filter out
  static const _stopWords = {
    'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'en',
    'à', 'au', 'aux', 'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils',
    'elles', 'me', 'te', 'se', 'mon', 'ton', 'son', 'ma', 'ta', 'sa',
    'notre', 'votre', 'leur', 'mes', 'tes', 'ses', 'que', 'qui', 'qu',
    'ne', 'pas', 'plus', 'très', 'bien', 'est', 'sont', 'was', 'were',
    'have', 'has', 'the', 'a', 'an', 'is', 'in', 'on', 'at', 'to',
    'for', 'of', 'and', 'or', 'but', 'this', 'that', 'it', 'with',
    'oui', 'non', 'ok', 'okay', 'ah', 'oh', 'eh', 'hah', 'lol',
    'haha', 'ahah', 'omg', 'ça', 'ce', 'ci', 'si', 'tout', 'tous',
    'aussi', 'donc', 'mais', 'ni', 'comme', 'moi', 'lui', 'eux',
    'suis', 'être', 'avoir', 'dis', 'dite', 'fait', 'va', 'vais', 'aller',
  };

  /// Parse WhatsApp txt export file content and extract nouns/meaningful words.
  static List<String> parseFromText(String content) {
    final words = <String, int>{};

    // Split lines
    final lines = content.split('\n');

    for (final line in lines) {
      // Skip lines with media/system messages
      if (line.contains('<Media omitted>') ||
          line.contains('image omitted') ||
          line.contains('video omitted') ||
          line.contains('audio omitted') ||
          line.contains('sticker omitted') ||
          line.contains('Messages and calls are end-to-end') ||
          line.contains('created group') ||
          line.contains('added') ||
          line.trim().isEmpty) {
        continue;
      }

      // Remove WhatsApp timestamp prefix: [DD/MM/YYYY, HH:MM:SS] Name: or DD/MM/YYYY HH:MM - Name:
      String message = line
          .replaceAll(RegExp(r'^\[\d{2}/\d{2}/\d{4}, \d{2}:\d{2}:\d{2}\] [^:]+: '), '')
          .replaceAll(RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2} - [^:]+: '), '')
          .replaceAll(RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}, \d{1,2}:\d{2}\s?[AP]M - [^:]+: '), '');

      // Extract words (4+ chars, letters only)
      final rawWords = message
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zàâçéèêëîïôùûüœæ\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 4 && !_stopWords.contains(w))
          .toList();

      for (final w in rawWords) {
        words[w] = (words[w] ?? 0) + 1;
      }
    }

    // Keep words that appear at least twice (they're more meaningful)
    final significant = words.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => words[b]!.compareTo(words[a]!));

    // Cap at 300 most frequent words
    return significant.take(300).toList();
  }

  static Future<List<String>> parseFromFile(File file) async {
    try {
      final content = await file.readAsString(encoding: utf8);
      return parseFromText(content);
    } catch (e) {
      if (kDebugMode) print('Error parsing file: $e');
      // Try latin1 fallback
      try {
        final content = await file.readAsString(encoding: latin1);
        return parseFromText(content);
      } catch (e2) {
        if (kDebugMode) print('Error with fallback encoding: $e2');
        return [];
      }
    }
  }

  static Map<String, dynamic> getStats(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).length;
    final words = parseFromText(content);
    return {
      'totalLines': lines,
      'uniqueWords': words.length,
      'topWords': words.take(10).toList(),
    };
  }
}
