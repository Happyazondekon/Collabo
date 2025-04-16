import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final int winner;
  final String player1Color;
  final String player2Color;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ConfettiController _confettiController;
  late String _romanticSuggestion;
  final List<String> _romanticSuggestions = [
    "Envoyez un message vocal pour dire 'Je t'aime' dans la langue de l'autre",
    "Partagez un screenshot de votre premier échange sur Telegram",
    "Racontez votre souvenir préféré de cette année",
    "Faites un compliment inspiré de vos échanges (ex: 'Tu es ma plus belle surprise')",
    "Écrivez une petite note sur ce que vous appréciez chez l'autre",
    "Choisissez une chanson qui représente votre relation et dansez ensemble",
    "Recréez votre premier rendez-vous",
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _romanticSuggestion = _romanticSuggestions[Random().nextInt(_romanticSuggestions.length)];
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _getPlayerColor(int playerNumber) {
    final color = playerNumber == 1 ? widget.player1Color : widget.player2Color;
    switch (color) {
      case 'Rouge': return Colors.red[400]!;
      case 'Bleu': return Colors.blue[400]!;
      case 'Rose': return Colors.pink[300]!;
      case 'Vert': return Colors.green[400]!;
      case 'Violet': return Colors.purple[400]!;
      case 'Orange': return Colors.orange[400]!;
      case 'Jaune': return Colors.yellow[600]!;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final winnerColor = _getPlayerColor(widget.winner);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFfff5f5), Color(0xFFfef9ff)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Couronne du gagnant
                  Icon(
                    Icons.emoji_events,
                    size: 60,
                    color: winnerColor,
                  ),
                  const SizedBox(height: 20),

                  // Titre
                  Text(
                    'Félicitations !',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: winnerColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sous-titre
                  Text(
                    'Joueur ${widget.winner} a gagné',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Carte de suggestion
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            winnerColor.withOpacity(0.1),
                            winnerColor.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.pink,
                            size: 30,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Suggestion romantique',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _romanticSuggestion,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Boutons d'action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _romanticSuggestion = _romanticSuggestions[
                            Random().nextInt(_romanticSuggestions.length)];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: winnerColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: winnerColor),
                          ),
                        ),
                        child: const Text('Autre idée'),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen()),
                                (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: winnerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Nouvelle partie'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Message de fin
                  Text(
                    'Continuez à créer de beaux souvenirs ensemble',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confettis
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.pink,
                Colors.red,
                Colors.purple,
                Colors.blue,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }
}