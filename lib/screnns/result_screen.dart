import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final int winner;
  final int player1Score;
  final int player2Score;
  final int wordsGuessed;
  final Color primaryColor;
  final Color accentColor;
  final String player1Name;
  final String player2Name;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.player1Score,
    required this.player2Score,
    required this.wordsGuessed,
    required this.primaryColor,
    required this.accentColor,
    this.player1Name = 'Joueur 1',
    this.player2Name = 'Joueur 2',
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ConfettiController _confetti;
  late String _suggestion;

  static const _suggestions = [
    "Envoyez un message vocal pour dire « Je t'aime » dans la langue de l'autre",
    "Partagez le screenshot de votre premier échange ensemble",
    "Racontez votre souvenir préféré de cette année",
    "Faites un compliment inspiré de vos échanges — soyez créatifs !",
    "Écrivez une note sur ce que vous appréciez chez l'autre",
    "Choisissez une chanson qui représente votre relation et dansez",
    "Recréez votre premier rendez-vous ce soir",
    "Préparez une surprise pour demain, aussi petite soit-elle",
  ];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    _suggestion = _suggestions[Random().nextInt(_suggestions.length)];
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Color get _winnerColor =>
      widget.winner == 1 ? widget.primaryColor : widget.accentColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                AppColors.primary,
                AppColors.accent,
                Colors.amber,
                Colors.orange,
                Colors.pink
              ],
              numberOfParticles: 30,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Trophy
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_winnerColor, widget.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _winnerColor.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 20),
                  const Text('Félicitations !',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.winner == 1 ? widget.player1Name : widget.player2Name} remporte la partie',
                    style: TextStyle(
                        fontSize: 16,
                        color: _winnerColor,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 28),
                  // Score card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ScoreColumn(
                          label: widget.player1Name,
                          score: widget.player1Score,
                          color: widget.primaryColor,
                          isWinner: widget.winner == 1,
                        ),
                        Container(
                            height: 60,
                            width: 1,
                            color: Colors.grey.shade100),
                        _ScoreColumn(
                          label: widget.player2Name,
                          score: widget.player2Score,
                          color: widget.accentColor,
                          isWinner: widget.winner == 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Words stat
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(Icons.text_fields_rounded,
                            color: AppColors.accent, size: 22),
                        const SizedBox(width: 10),
                        Text(
                            '${widget.wordsGuessed} mots devinés ensemble',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Romantic suggestion
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [
                            widget.primaryColor.withValues(alpha: 0.08),
                            widget.accentColor.withValues(alpha: 0.08)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: widget.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.favorite_rounded,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text('Suggestion romantique',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _suggestion,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textDark,
                              height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => setState(() =>
                              _suggestion = _suggestions[
                                  Random().nextInt(_suggestions.length)]),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary),
                          child: const Text('Autre idée',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _winnerColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Rejouer',
                              style: TextStyle(
                                  color: _winnerColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (_) => false,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _winnerColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Accueil',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isWinner;

  const _ScoreColumn(
      {required this.label,
      required this.score,
      required this.color,
      required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isWinner)
          Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$score',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: color)),
        const SizedBox(height: 2),
        const Text('pts',
            style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
      ],
    );
  }
}
